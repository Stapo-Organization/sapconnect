<?php

namespace App\Services\Zooboxi;

use Anthropic\Client;
use Anthropic\Core\Exceptions\APIConnectionException;
use Anthropic\Core\Exceptions\APIStatusException;
use App\Models\Product;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Writes the storefront copy for a product that has none: Arabic + English
 * names as shoppers search for them, short and long descriptions, SEO fields,
 * keywords and — importantly — a category PATH chosen from the store's real
 * tree. Facts come only from SAP (item name, brand, UoM, pack size) and the
 * ShipGo master; the model is told to say nothing it cannot derive from them.
 *
 * Owner decision 2026-09-19: AI copy publishes directly and is flagged
 * `zb_content_source = ai` for later review — the backlog (750 items) beats
 * a review queue nobody has time for.
 */
class CatalogCopywriter
{
    private const DAILY_CAP_KEY = 'zooboxi.copywriter.daily';

    public function __construct(private ?Client $client = null)
    {
    }

    public function configured(): bool
    {
        return (string) config('services.anthropic.api_key', '') !== '';
    }

    /**
     * @param  string[] $categoryPaths  the store's existing category tree ("قطط > طعام رطب")
     * @param  array    $facts          extra facts: name_ar/name_en/weight_g from ShipGo, etc.
     * @return array|null  keys: name_ar, name_en, short_ar, short_en, desc_ar, desc_en,
     *                     category_path, keywords, seo_title_ar, seo_description_ar
     */
    public function write(Product $product, array $categoryPaths, array $facts = []): ?array
    {
        if (!$this->configured()) {
            return null;
        }
        if (!$this->underDailyCap()) {
            Log::warning('Zooboxi copywriter: daily cap reached');
            return null;
        }

        $brand = $product->brand?->name ?? '';
        $lines = array_filter([
            'SAP item code: ' . $product->item_code,
            'Name (SAP, English): ' . ($product->item_name ?: '—'),
            'Name (SAP, Arabic): ' . ($product->foreign_name ?: '—'),
            $brand !== '' ? 'Brand: ' . $brand : null,
            !empty($facts['name_en']) ? 'Name (WMS, English): ' . $facts['name_en'] : null,
            !empty($facts['name_ar']) ? 'Name (WMS, Arabic): ' . $facts['name_ar'] : null,
            !empty($product->piece_barcode) ? 'Barcode: ' . $product->piece_barcode : null,
            !empty($product->inventory_uom) ? 'Unit of measure: ' . $product->inventory_uom : null,
            (float) ($product->sales_items_per_unit ?? 0) > 1 ? 'Pieces per carton: ' . (int) $product->sales_items_per_unit : null,
            !empty($facts['weight_g']) ? 'Weight (g): ' . $facts['weight_g'] : null,
            !empty($product->u_proprt1) ? 'Property 1: ' . $product->u_proprt1 : null,
            !empty($product->u_proprt2) ? 'Property 2: ' . $product->u_proprt2 : null,
        ]);

        // Keep the prompt prefix stable (system + tree) so repeated calls hit the cache;
        // the product facts go last.
        $system = <<<TXT
You write product listings for Zooboxi (زوبوكسي), a Saudi pet-supplies store (cats, dogs, birds, fish, small pets). Output Arabic first; English second. Saudi retail tone: clear, warm, no hype, no medical claims, no invented ingredients, sizes or benefits. Use only the facts given. If a fact is unknown, leave it out rather than guess. Always write digits as Western numerals (0-9). Never mention a branch or warehouse. Names: keep the brand name as-is (Latin script in the English name, transliterated in Arabic only if that is how shoppers search for it, e.g. "رويال كانين"). The Arabic name must include the size/weight when known (e.g. "85 جم"). Descriptions: short = one sentence; long = 2 short paragraphs, factual, usable on a product page. Category: choose ONE path from the provided tree, the most specific that truly fits; never invent a category. Keywords: 5-10 Arabic search terms, comma-separated. SEO title ≤ 60 chars; SEO description ≤ 155 chars.
TXT;

        $tree = empty($categoryPaths) ? '(no tree available — set category_path to "")' : implode("\n", $categoryPaths);

        $schema = [
            'type' => 'object',
            'properties' => [
                'name_ar' => ['type' => 'string'],
                'name_en' => ['type' => 'string'],
                'short_ar' => ['type' => 'string'],
                'short_en' => ['type' => 'string'],
                'desc_ar' => ['type' => 'string'],
                'desc_en' => ['type' => 'string'],
                'category_path' => ['type' => 'string', 'description' => 'exactly one path copied from the tree, or "" if none fits'],
                'keywords' => ['type' => 'string'],
                'seo_title_ar' => ['type' => 'string'],
                'seo_description_ar' => ['type' => 'string'],
            ],
            'required' => ['name_ar', 'name_en', 'short_ar', 'short_en', 'desc_ar', 'desc_en', 'category_path', 'keywords', 'seo_title_ar', 'seo_description_ar'],
            'additionalProperties' => false,
        ];

        try {
            $message = $this->client()->messages->create(
                model: (string) config('services.anthropic.model', 'claude-opus-5'),
                maxTokens: 4000,
                system: [
                    ['type' => 'text', 'text' => $system],
                    ['type' => 'text', 'text' => "Store category tree (one path per line):\n" . $tree, 'cacheControl' => ['type' => 'ephemeral']],
                ],
                messages: [
                    ['role' => 'user', 'content' => "Product facts:\n" . implode("\n", $lines)],
                ],
                outputConfig: ['format' => ['type' => 'json_schema', 'schema' => $schema]],
            );
        } catch (APIStatusException $e) {
            Log::warning('Zooboxi copywriter API error', ['item' => $product->item_code, 'type' => $e->type?->value, 'msg' => $e->getMessage()]);
            return null;
        } catch (APIConnectionException $e) {
            Log::warning('Zooboxi copywriter connection error', ['item' => $product->item_code, 'msg' => $e->getMessage()]);
            return null;
        } catch (\Throwable $e) {
            Log::warning('Zooboxi copywriter failed', ['item' => $product->item_code, 'msg' => $e->getMessage()]);
            return null;
        }

        if ($message->stopReason === 'refusal') {
            Log::warning('Zooboxi copywriter refusal', ['item' => $product->item_code]);
            return null;
        }

        $text = null;
        foreach ($message->content as $block) {
            if ($block->type === 'text') {
                $text = $block->text;
                break;
            }
        }
        $data = is_string($text) ? json_decode($text, true) : null;
        if (!is_array($data) || empty($data['name_ar'])) {
            return null;
        }

        // A path the tree does not contain is dropped — the plugin would create it.
        if (!empty($categoryPaths) && $data['category_path'] !== '' && !in_array($data['category_path'], $categoryPaths, true)) {
            $data['category_path'] = '';
        }

        Cache::increment(self::DAILY_CAP_KEY . '.' . now()->format('Ymd'));
        return $data;
    }

    private function underDailyCap(): bool
    {
        $cap = (int) config('services.anthropic.catalog_daily_cap', 400);
        $key = self::DAILY_CAP_KEY . '.' . now()->format('Ymd');
        Cache::add($key, 0, now()->addDays(2));
        return (int) Cache::get($key, 0) < $cap;
    }

    private function client(): Client
    {
        return $this->client ??= new Client(apiKey: (string) config('services.anthropic.api_key'));
    }
}
