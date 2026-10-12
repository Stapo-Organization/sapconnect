<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Warehouse;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Public catalogue feed for the Muntajat B2B storefront.
 *
 * The storefront holds no data of its own; it renders whatever these two
 * endpoints return.
 *
 *   GET /api/store/b2b/catalog        browse payload — every sellable product,
 *                                     minus the long-form marketing copy
 *   GET /api/store/b2b/product/{code} full marketing content for one product,
 *                                     fetched when a product page is opened
 *
 * PRICING — deliberate, do not "fix":
 * SAP carries 14 price lists. List 1 is "01-Wholesale PL" and NEVER leaves this
 * server. Only list 2, "Retail PL - Muntajat" (RRP), is published.
 *
 * Where each field comes from:
 *   names, barcode, UoM, price    SAP Items       (products)
 *   per-branch stock              SAP             (warehouse_item_stocks)
 *   branches                      SAP + zooboxi_warehouses + config/b2b_showrooms
 *   taxonomy + Arabic labels      Zooboxi         (products.zb_categories_en/ar)
 *   Arabic brand names            Zooboxi         ("Brands > X" breadcrumb)
 *   marketing copy                Zooboxi         (products.zb_description_en/ar)
 *   images                        Zooboxi zb_images, else the ppte.sa convention
 */
class B2bCatalogController extends Controller
{
    /** SAP price list published publicly: 2 = "Retail PL - Muntajat" (RRP). */
    private const PRICE_LIST = 2;

    /** Muntajat has served the trade since this year. */
    private const TRADING_SINCE = 2004;

    /** The retail walk-in card; every other card is a trade account. */
    private const RETAIL_CARD = 'C0000001';

    private const TTL = 900;

    /** Retail showrooms are the SAP warehouses named "... Store ...". */
    private const SHOWROOM_PATTERN = '%Store%';

    /** Zooboxi top-level category -> the storefront's animal buckets. */
    private const ANIMAL = [
        'Cat' => 'Cats', 'Cats' => 'Cats',
        'Dog' => 'Dogs', 'Dogs' => 'Dogs',
        'Bird' => 'Birds', 'Birds' => 'Birds',
        'Small Animals' => 'Small Pets', 'Small Pet' => 'Small Pets',
        'Fish' => 'Fish',
    ];

    /**
     * Zooboxi top-level nodes that are facets, not animals. "Brands" is handled
     * separately (it carries the Arabic brand name); the rest are dropped.
     */
    private const NOT_AN_ANIMAL = ['Brands', 'Health Criteria', 'Offers', 'New Arrivals'];

    private const ANIMAL_AR = [
        'Cats' => 'قطط', 'Dogs' => 'كلاب', 'Birds' => 'طيور',
        'Small Pets' => 'حيوانات صغيرة', 'Fish' => 'أسماك',
    ];

    /**
     * Item whose photo fronts each animal section on the home page.
     *
     * Taking "the first product in the category" put a picture-less item on the
     * two biggest tiles — roughly a fifth of the catalogue has no photo on the
     * image host at all. These four are the ones the published storefront used
     * and each was checked to resolve. If a code here ever stops resolving the
     * tile falls back to the first product, so a stale entry degrades quietly.
     */
    private const ANIMAL_TILE = [
        'Cats'       => 'P10500034',
        'Dogs'       => 'P10500066',
        'Birds'      => 'P15000024',
        'Small Pets' => 'P15300003',
        'Fish'       => 'P11000001',
    ];

    /** Fallback animal mapping from the SAP user field, for un-enriched items. */
    private const SAP_PET = [
        'cats' => 'Cats', 'cat' => 'Cats', 'dogs' => 'Dogs', 'dog' => 'Dogs',
        'birds' => 'Birds', 'bird' => 'Birds', 'small pet' => 'Small Pets',
        'small pets' => 'Small Pets', 'fish' => 'Fish',
    ];

    /** City and administrative region per SAP warehouse-code prefix. */
    private const CITY = [
        'RUH' => ['Riyadh', 'الرياض', 'Riyadh Province'],
        'JED' => ['Jeddah', 'جدة', 'Makkah Province'],
        'DMM' => ['Dammam', 'الدمام', 'Eastern Province'],
        'MED' => ['Madinah', 'المدينة المنورة', 'Al Madinah Province'],
        'ABH' => ['Abha', 'أبها', 'Asir Province'],
        'UZH' => ['Unaizah', 'عنيزة', 'Al-Qassim Province'],
    ];

    /** Marketing section headings, matched on the emoji-prefixed <h3> text. */
    private const SECTIONS = [
        'desc'   => ['Overview', 'نظرة عامة'],
        'feat'   => ['Key Features', 'المميزات الرئيسية'],
        'ing'    => ['Ingredients', 'المكونات'],
        'nutr'   => ['Nutritional Analysis', 'التحليل الغذائي'],
        'howto'  => ['How to Use', 'طريقة الاستخدام'],
        'breeds' => ['Suitable Breeds', 'السلالات المناسبة'],
    ];

    // ── endpoints ────────────────────────────────────────────────────────────

    public function catalog(Request $request)
    {
        $withStock = $request->boolean('stock', true);
        $key = 'b2b:catalog:v2:' . ($withStock ? 'stock' : 'nostock');

        return response()
            ->json(Cache::remember($key, self::TTL, fn () => $this->build($withStock)))
            ->header('Cache-Control', 'public, max-age=300');
    }

    /** Long-form marketing content, loaded when a product page is opened. */
    public function product(string $code)
    {
        $payload = Cache::remember('b2b:product:v2:' . $code, self::TTL, function () use ($code) {
            $p = Product::where('item_code', $code)->first([
                'item_code', 'zb_description_en', 'zb_description_ar',
                'zb_short_description_en', 'zb_short_description_ar', 'zb_keywords',
            ]);
            if (! $p) {
                return null;
            }

            $en = $this->sections($p->zb_description_en);
            $ar = $this->sections($p->zb_description_ar);
            $kw = array_values(array_filter(array_map('trim', explode(',', (string) $p->zb_keywords))));

            return [
                'id'      => $p->item_code,
                'desc'    => $en['desc'] ?? $this->plain($p->zb_short_description_en),
                'descar'  => $ar['desc'] ?? $this->plain($p->zb_short_description_ar),
                'feat'    => $en['feat'] ?? [],
                'featar'  => $ar['feat'] ?? [],
                'ing'     => $en['ing'] ?? [],
                'ingar'   => $ar['ing'] ?? [],
                'nutr'    => $en['nutr'] ?? [],
                'nutrar'  => $ar['nutr'] ?? [],
                'howto'   => $en['howto'] ?? '',
                'howtoar' => $ar['howto'] ?? '',
                'breeds'  => $en['breeds'] ?? [],
                'kw'      => $kw,
            ];
        });

        return $payload
            ? response()->json($payload)->header('Cache-Control', 'public, max-age=600')
            : response()->json(['message' => 'Not found'], 404);
    }

    // ── build ────────────────────────────────────────────────────────────────

    private function build(bool $withStock): array
    {
        // `brands` directly, not via the Brand model: that model swaps to
        // `brands_test` when the active SAP company DB is not production.
        $brandNames = DB::table('brands')->pluck('name', 'code')->all();

        $showrooms = $this->showrooms();
        $stock = $withStock ? $this->stock(array_column($showrooms, 'code')) : [];

        $products = [];
        $brandAr = [];
        $catAr = [];

        Product::select([
            'item_code', 'item_name', 'foreign_name', 'items_group_code',
            'piece_barcode', 'inventory_uom', 'sales_items_per_unit', 'prices',
            'u_proprt2', 'u_proprt3', 'u_proprt4',
            'zb_name_ar', 'zb_categories_en', 'zb_categories_ar', 'zb_images',
            'zb_description_en', 'zb_weight', 'zb_weight_unit',
        ])->orderBy('item_code')->chunk(500, function ($rows) use (
            &$products, &$brandAr, &$catAr, $brandNames, $stock
        ) {
            foreach ($rows as $p) {
                $price = $this->priceOf($p->prices, self::PRICE_LIST);
                if ($price <= 0) {
                    continue;                       // no published price -> not sellable
                }

                $tax = $this->taxonomy($p, $brandAr, $catAr);
                if (empty($tax['pets'])) {
                    continue;                       // uncategorised -> not browsable
                }

                $code = $p->item_code;
                $brand = $brandNames[$p->items_group_code] ?? '';

                $products[$code] = [
                    'id'    => $code,
                    'sku'   => $code,
                    't'     => trim($p->item_name ?? ''),
                    'tar'   => trim($p->zb_name_ar ?: $p->foreign_name ?: ''),
                    'b'     => $brand,
                    'bar'   => '',                  // filled after the sweep
                    'img'   => $this->image($p, false),
                    'imghd' => $this->image($p, true),
                    'bc'    => trim($p->piece_barcode ?? ''),
                    'size'  => $this->size($p),
                    'price' => number_format($price, 2, '.', ''),
                    'uom'   => trim($p->inventory_uom ?? ''),
                    'spu'   => (float) ($p->sales_items_per_unit ?? 0),
                    'pets'  => $tax['pets'],
                    'cats'  => $tax['cats'],
                    'sub'   => $tax['sub'],
                    'subar' => $tax['subar'],
                    'stock' => $stock[$code] ?? (object) [],
                    // 1 = /product/{code} has features, ingredients, nutrition
                    'enr'   => $p->zb_description_en ? 1 : 0,
                ];
            }
        });

        // Arabic brand names come out of the "Brands > X" breadcrumbs, so they
        // are only known once every product has been read.
        foreach ($products as $code => $p) {
            $products[$code]['bar'] = $brandAr[$p['b']] ?? '';
        }

        $this->canonicaliseSubLabels($products);

        [$index, $animals] = $this->index($products);

        return [
            'meta' => [
                'source'       => 'sapconnect',
                'price_list'   => self::PRICE_LIST,
                'price_label'  => 'Retail PL - Muntajat (RRP)',
                'generated_at' => now()->toIso8601String(),
                'products'     => count($products),
                'enriched'     => count(array_filter($products, fn ($p) => $p['enr'])),
            ],
            'stats' => $this->stats($products, $showrooms),
            'showrooms' => $showrooms,
            'brands'    => $this->brands($products, $brandNames, $brandAr),
            'store'     => [
                'products'  => (object) $products,
                'index'     => $index,
                'animals'   => $animals,
                'catlabels' => (object) $catAr,
            ],
        ];
    }

    /**
     * The headline figures on the storefront's home page.
     *
     * Every one is counted from live data. Two carry caveats worth knowing
     * before they are quoted elsewhere:
     *
     *  - `brands` is every brand with a sellable product, not "exclusive"
     *    brands. Distribution exclusivity is not recorded in any system here,
     *    so the storefront must not claim it.
     *  - `accounts_active` counts trade cards that bought within the window,
     *    but sapconnect's invoice history only starts at the earliest
     *    `doc_date` present — reported as `accounts_window_from` so the figure
     *    is read as the lower bound it is.
     */
    private function stats(array $products, array $showrooms): array
    {
        $accountsTotal = (int) DB::table('customers')
            ->where('card_code', '!=', self::RETAIL_CARD)
            ->count();

        $since = now()->subMonths(24)->toDateString();
        $accountsActive = (int) DB::table('sap_invoices')
            ->where('doc_date', '>=', $since)
            ->where('card_code', '!=', self::RETAIL_CARD)
            ->distinct()
            ->count('card_code');

        $earliest = DB::table('sap_invoices')->min('doc_date');

        return [
            'years'                => (int) now()->year - self::TRADING_SINCE,
            'trading_since'        => self::TRADING_SINCE,
            'brands'               => count(array_unique(array_filter(array_column($products, 'b')))),
            'products'             => count($products),
            'showrooms'            => count($showrooms),
            'accounts'             => $accountsTotal,
            'accounts_active'      => $accountsActive,
            'accounts_window_from' => $earliest && $earliest > $since ? $earliest : $since,
        ];
    }

    // ── showrooms ────────────────────────────────────────────────────────────

    /**
     * SAP owns which branches exist; `zooboxi_warehouses` and
     * config/b2b_showrooms.php supply the address, phone and coordinates that
     * SAP has no field for. Anything still unknown stays null — never guessed.
     */
    private function showrooms(): array
    {
        $cfg = config('b2b_showrooms', []);

        $zb = collect();
        if (Schema::hasTable('zooboxi_warehouses')) {
            $zb = ZooboxiWarehouse::query()->get();
        }

        return Warehouse::where('warehouse_name', 'like', self::SHOWROOM_PATTERN)
            ->orderBy('warehouse_code')
            ->get(['warehouse_code', 'warehouse_name'])
            ->map(function ($w) use ($cfg, $zb) {
                $code = $w->warehouse_code;
                $c = $cfg[$code] ?? [];
                [$cityEn, $cityAr, $regionEn] = self::CITY[substr($code, 0, 3)] ?? ['', '', null];

                // a Zooboxi warehouse may map to several SAP codes
                $z = $zb->first(function ($row) use ($code) {
                    if ($row->warehouse_code === $code) {
                        return true;
                    }
                    $mapped = $row->sap_warehouse_codes;
                    if (is_string($mapped)) {
                        $mapped = json_decode($mapped, true) ?: array_map('trim', explode(',', $mapped));
                    }

                    return is_array($mapped) && in_array($code, $mapped, true);
                });

                // zooboxi_warehouses.city holds the Arabic name, so it must not
                // be used for the English field.
                return [
                    'code'    => $code,
                    'name'    => $this->branchName($w->warehouse_name),
                    'name_ar' => $z->display_name_ar ?? $c['name_ar'] ?? '',
                    'city'    => $c['city'] ?? $cityEn,
                    'city_ar' => $z->city ?? $c['city_ar'] ?? $cityAr,
                    'region'  => $c['region'] ?? $regionEn,
                    'addr'    => $z->address_en ?? $c['addr'] ?? null,
                    'addr_ar' => $z->address_ar ?? $c['addr_ar'] ?? null,
                    'map'     => $c['map'] ?? null,
                    'lat'     => isset($z->latitude) ? (float) $z->latitude : ($c['lat'] ?? null),
                    'lng'     => isset($z->longitude) ? (float) $z->longitude : ($c['lng'] ?? null),
                    // No per-branch phone or opening hours exist in either
                    // system; these are the company-wide values.
                    // `?:` alone would fault when no zooboxi row matched, so the
                    // property is null-coalesced first.
                    'phone'   => ($z->phone ?? null) ?: ($c['phone'] ?? config('b2b_showrooms._contact.phone')),
                    'hours'   => ($z->working_hours ?? null) ?: config('b2b_showrooms._contact.hours'),
                ];
            })->values()->all();
    }

    private function stock(array $codes): array
    {
        $stock = [];
        WarehouseItemStock::whereIn('warehouse_code', $codes)
            ->where('in_stock', '>', 0)
            ->select('item_code', 'warehouse_code', 'in_stock')
            ->chunk(5000, function ($rows) use (&$stock) {
                foreach ($rows as $r) {
                    $stock[$r->item_code][$r->warehouse_code] = (float) $r->in_stock;
                }
            });

        return $stock;
    }

    // ── taxonomy ─────────────────────────────────────────────────────────────

    /**
     * Read the animal / category / sub-category off the Zooboxi breadcrumbs,
     * which carry an Arabic path parallel to the English one, and harvest the
     * Arabic brand and category labels while walking them. Falls back to the
     * SAP user fields for products Zooboxi has never seen.
     */
    private function taxonomy($p, array &$brandAr, array &$catAr): array
    {
        $en = array_filter(array_map('trim', explode(',', (string) $p->zb_categories_en)));
        $ar = array_filter(array_map('trim', explode(',', (string) $p->zb_categories_ar)));
        $en = array_values($en);
        $ar = array_values($ar);

        $pets = [];
        $cats = [];
        $sub = '';
        $subar = '';

        foreach ($en as $i => $path) {
            $se = array_map('trim', explode('>', $path));
            $sa = isset($ar[$i]) ? array_map('trim', explode('>', $ar[$i])) : [];
            if (count($sa) !== count($se)) {
                $sa = [];                            // paths out of step — ignore Arabic
            }

            if ($se[0] === 'Brands') {
                if (isset($se[1], $sa[1])) {
                    $brandAr[$se[1]] = $sa[1];
                }
                continue;
            }
            if (in_array($se[0], self::NOT_AN_ANIMAL, true)) {
                continue;
            }

            $animal = self::ANIMAL[$se[0]] ?? null;
            if (! $animal) {
                continue;
            }
            if (! in_array($animal, $pets, true)) {
                $pets[] = $animal;
            }

            if (isset($se[1])) {
                $cats[$animal] = $se[1];
                if (isset($sa[1])) {
                    $catAr[$se[1]] = $sa[1];
                }
            }
            if (isset($se[2]) && $sub === '') {
                $sub = $se[2];
                $subar = $sa[2] ?? '';
            }
        }

        if (empty($pets)) {                          // no Zooboxi data — use SAP
            foreach (preg_split('~[,/|]+~', (string) $p->u_proprt4) as $part) {
                $key = strtolower(trim($part, " \t\n\r\0\x0B\""));
                if (isset(self::SAP_PET[$key]) && ! in_array(self::SAP_PET[$key], $pets, true)) {
                    $pets[] = self::SAP_PET[$key];
                }
            }
            $cat = $this->sapLabel($p->u_proprt2) ?: 'Other';
            $cats = array_fill_keys($pets, $cat);
            $sub = $this->sapLabel($p->u_proprt3);

            // SAP is English-only; config/b2b_labels_ar.php covers these.
            if ($cat !== '' && ! isset($catAr[$cat])) {
                $catAr[$cat] = $this->arabicLabel($cat);
            }
            $subar = $this->arabicLabel($sub);
        }

        return ['pets' => $pets, 'cats' => $cats, 'sub' => $sub, 'subar' => $subar];
    }

    /**
     * SAP holds the same sub-category under several spellings — "Litter" and
     * "litter", "Carrier" and "Carriers", "Litter Box-Tray" and "Litter
     * Box-tray" — which would render as different chips on the storefront.
     * Collapse each set onto whichever spelling is used most, so the label is
     * consistent without inventing a name. The underlying SAP value is
     * untouched; this is presentation only.
     */
    private function canonicaliseSubLabels(array &$products): void
    {
        $counts = [];
        foreach ($products as $p) {
            if ($p['sub'] !== '') {
                $key = preg_replace('~[^a-z]~', '', mb_strtolower($p['sub']));
                $key = rtrim($key, 's');
                $counts[$key][$p['sub']] = ($counts[$key][$p['sub']] ?? 0) + 1;
            }
        }

        $canonical = [];
        foreach ($counts as $key => $variants) {
            arsort($variants);
            $canonical[$key] = array_key_first($variants);
        }

        foreach ($products as $code => $p) {
            if ($p['sub'] === '') {
                continue;
            }
            $key = rtrim(preg_replace('~[^a-z]~', '', mb_strtolower($p['sub'])), 's');
            if (isset($canonical[$key])) {
                $products[$code]['sub'] = $canonical[$key];
            }
        }
    }

    /** Arabic for a SAP-only label; '' lets the storefront show the English. */
    private function arabicLabel(string $en): string
    {
        if ($en === '') {
            return '';
        }
        static $map = null;
        if ($map === null) {
            $map = [];
            foreach (config('b2b_labels_ar', []) as $k => $v) {
                $map[mb_strtolower($k)] = $v;
            }
        }

        return $map[mb_strtolower(trim($en))] ?? '';
    }

    /** SAP user fields carry unmapped placeholder codes (DEPT002, MAIN007). */
    private function sapLabel(?string $raw): string
    {
        $v = trim((string) $raw, " \t\n\r\0\x0B\"");

        return preg_match('~^(DEPT|MAIN|PET|SUB|CAT|GRP)\d+$~i', $v) ? '' : $v;
    }

    private function index(array $products): array
    {
        $index = [];
        foreach ($products as $code => $p) {
            foreach ($p['pets'] as $pet) {
                $cat = $p['cats'][$pet] ?? 'Other';
                $index[$pet][$cat]['total'] = ($index[$pet][$cat]['total'] ?? 0) + 1;
                $index[$pet][$cat]['ids'][] = $code;
            }
        }
        ksort($index);

        $animals = [];
        foreach ($index as $pet => $cats) {
            $first = null;
            foreach ($cats as $c) {
                $first = $c['ids'][0];
                break;
            }
            $tile = self::ANIMAL_TILE[$pet] ?? null;
            $animals[$pet] = [
                'count' => array_sum(array_column($cats, 'total')),
                'ncats' => count($cats),
                'ar'    => self::ANIMAL_AR[$pet] ?? $pet,
                'img'   => $tile
                    ? 'https://ppte.sa/img/' . substr($tile, 0, 4) . '/' . $tile . '.png'
                    : ($first ? $products[$first]['img'] : ''),
            ];
        }

        return [$index, $animals];
    }

    private function brands(array $products, array $names, array $brandAr): array
    {
        $codeByName = array_flip($names);
        $first = [];
        foreach ($products as $code => $p) {
            if ($p['b'] !== '' && ! isset($first[$p['b']])) {
                $first[$p['b']] = $code;
            }
        }
        ksort($first);

        $out = [];
        foreach ($first as $name => $itemCode) {
            $out[] = [
                'name'    => $name,
                'name_ar' => $brandAr[$name] ?? '',
                'code'    => (string) ($codeByName[$name] ?? ''),
                'logo'    => 'https://ppte.sa/imghd/brands/' . substr($itemCode, 0, 4) . '.png',
            ];
        }

        return $out;
    }

    // ── marketing copy ───────────────────────────────────────────────────────

    /**
     * Split a Zooboxi product description into the storefront's fields.
     *
     * The copy is HTML built from a fixed template: an <h3> per section, with
     * bullets under the list-shaped ones and a two-column table under the
     * nutrition one. Headings carry an emoji, so they are matched on a
     * contained keyword rather than an exact string.
     */
    private function sections(?string $html): array
    {
        if (! $html) {
            return [];
        }

        $parts = preg_split('~<h3[^>]*>(.*?)</h3>~i', $html, -1,
            PREG_SPLIT_DELIM_CAPTURE | PREG_SPLIT_NO_EMPTY);

        $out = [];
        for ($i = 0; $i + 1 < count($parts); $i += 2) {
            $heading = $this->plain($parts[$i]);
            $body = $parts[$i + 1];

            foreach (self::SECTIONS as $field => $keywords) {
                foreach ($keywords as $kw) {
                    if (mb_stripos($heading, $kw) === false) {
                        continue;
                    }
                    $out[$field] = match ($field) {
                        'nutr'           => $this->table($body),
                        'feat', 'ing',
                        'breeds'         => $this->bullets($body),
                        default          => $this->plain($body),
                    };
                    break 2;
                }
            }
        }

        // Ingredients are sometimes one prose sentence instead of a list;
        // split it so the storefront can render chips either way. Arabic uses
        // the ، separator.
        if (isset($out['ing']) && count($out['ing']) === 1 && mb_strlen($out['ing'][0]) > 60) {
            $parts = preg_split('~[,،]~u', $out['ing'][0]);
            $parts = array_values(array_filter(array_map(
                fn ($x) => trim($x, " \t\n\r\0\x0B."), $parts
            )));
            if (count($parts) > 1) {
                $out['ing'] = $parts;
            }
        }

        return $out;
    }

    private function bullets(string $html): array
    {
        preg_match_all('~<li[^>]*>(.*?)</li>~is', $html, $m);
        $items = array_values(array_filter(array_map(fn ($x) => $this->plain($x), $m[1] ?? [])));

        return $items ?: array_values(array_filter(
            array_map('trim', explode(',', $this->plain($html)))
        ));
    }

    /** Nutrition table -> [[label, value], ...]. */
    private function table(string $html): array
    {
        preg_match_all('~<tr[^>]*>(.*?)</tr>~is', $html, $rows);
        $out = [];
        foreach ($rows[1] ?? [] as $row) {
            preg_match_all('~<t[dh][^>]*>(.*?)</t[dh]>~is', $row, $cells);
            $c = array_map(fn ($x) => $this->plain($x), $cells[1] ?? []);
            $c = array_values(array_filter($c, fn ($x) => $x !== ''));
            if (count($c) >= 2) {
                $out[] = [$c[0], $c[1]];
            }
        }
        // drop the header row ("Nutrient | Percentage" / "المكون الغذائي | النسبة")
        if ($out && preg_match('~nutrient|analysis|العنصر|المكون|التحليل~iu', $out[0][0])) {
            array_shift($out);
        }

        return $out;
    }

    /**
     * HTML to text. Also drops zooboxi.com links: this is the wholesale
     * storefront and must not push readers to the consumer shop.
     */
    private function plain(?string $html): string
    {
        $s = preg_replace('~<a[^>]*zooboxi\.com[^>]*>(.*?)</a>~is', '$1', (string) $html);
        $s = preg_replace('~<[^>]+>~', ' ', $s);
        $s = html_entity_decode($s, ENT_QUOTES | ENT_HTML5, 'UTF-8');

        return trim(preg_replace('~\s+~u', ' ', $s));
    }

    // ── small helpers ────────────────────────────────────────────────────────

    private function priceOf($prices, int $list): float
    {
        if (is_string($prices)) {
            $prices = json_decode($prices, true);
        }
        if (! is_array($prices)) {
            return 0.0;
        }
        foreach ($prices as $p) {
            if ((int) ($p['PriceList'] ?? 0) === $list) {
                return (float) ($p['Price'] ?? 0);
            }
        }

        return 0.0;
    }

    /**
     * Prefer the image registered against the product; otherwise fall back to
     * the folder convention. Both hosts carry the same products, so the
     * fallback adds no coverage — it only covers rows Zooboxi never indexed.
     */
    private function image($p, bool $hd): string
    {
        $code = $p->item_code;

        if ($hd) {
            $imgs = $p->zb_images;
            if (is_string($imgs)) {
                $imgs = json_decode($imgs, true);
            }
            if (is_array($imgs) && ! empty($imgs[0])) {
                return $imgs[0];
            }

            return 'https://ppte.sa/imghd/' . substr($code, 0, 4) . '/' . $code . '.png';
        }

        return 'https://ppte.sa/img/' . substr($code, 0, 4) . '/' . $code . '.png';
    }

    /** Pack size: Zooboxi weight if known, else read it off the SAP name. */
    private function size($p): string
    {
        if ($p->zb_weight > 0 && $p->zb_weight_unit) {
            return rtrim(rtrim(number_format((float) $p->zb_weight, 3, '.', ''), '0'), '.')
                . ' ' . strtoupper($p->zb_weight_unit);
        }

        if (! preg_match_all('~(\d+(?:[.,]\d+)?)\s*(kg|gm|gr|g|ml|ltr|lt|l|cm|mm|pcs|pc|oz|lb)\b~i',
            (string) $p->item_name, $m, PREG_SET_ORDER)) {
            return '';
        }
        $last = end($m);

        return str_replace(',', '.', $last[1]) . ' ' . strtoupper($last[2]);
    }

    /** "Al Rabie Store - RUH" -> "Al Rabie". */
    private function branchName(string $warehouseName): string
    {
        return trim(preg_replace('~\s*Store\s*-?.*$~i', '', $warehouseName));
    }
}
