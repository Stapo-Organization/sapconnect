<?php
/**
 * «قصة المنتج» — the product description as structured data.
 *
 * Every catalogue description arrived from ZID as one HTML blob, but 99% of
 * them share the same headed sections (نظرة عامة، المميزات، المواصفات،
 * المكونات، التحليل الغذائي، جدول التغذية، السلالات، طريقة الاستخدام،
 * تحذيرات السلامة). This class reads that blob once and hands every surface —
 * the web product page and the app — the same typed pieces:
 *
 *   highlights   the bold lead titles of «المميزات» (the "why buy" chips)
 *   facts        up to 4 key specs for the summary strip
 *   sections     ordered, typed: paragraphs / lists / tables per section
 *   composition  the ingredient split for the donut, when percentages exist
 *   feeding      the feeding table as rows keyed by pet weight (calculator)
 *
 * Nothing is invented: every value is lifted from the stored copy. Cleaning
 * happens on the way through — links to the old ZID store are unwrapped,
 * emoji leave the headings, and stray runs of Thai/Korean/Cyrillic/CJK that
 * the AI copywriter once left inside Arabic sentences are dropped.
 *
 * Parsed output is cached in post meta per language, keyed by a hash of the
 * source, so an edited description re-parses itself on the next read.
 */

defined('ABSPATH') || exit;

class Zooboxi_Product_Story
{
    /** Bump to re-parse every product (the hash alone only tracks the source). */
    public const VERSION = 7;

    private const META = '_zb_story_';

    /** Section key → words its heading carries (AR + EN). First match wins. */
    private const KEYS = [
        'overview'    => ['نظرة عامة', 'overview'],
        'features'    => ['المميزات', 'المزايا', 'key features', 'features', 'benefits'],
        'ingredients' => ['المكونات', 'التركيب', 'التركيبة', 'ingredients', 'composition'],
        'analysis'    => ['التحليل', 'analysis', 'analytical', 'nutritional'],
        'feeding'     => ['التغذية', 'الجرعة', 'الجرعات', 'التقديم', 'feeding', 'dosage', 'dosing', 'serving'],
        'breeds'      => ['السلالات', 'الأنواع المناسبة', 'الحيوانات المناسبة', 'الأسماك المناسبة', 'breeds', 'suitable for'],
        'usage'       => ['طريقة الاستخدام', 'إرشادات الاستخدام', 'إرشادات التحضير', 'how to use', 'usage', 'directions', 'instructions'],
        'safety'      => ['تحذيرات', 'تحذير', 'السلامة', 'warning', 'safety', 'caution'],
        'storage'     => ['التخزين', 'الحفظ', 'storage'],
        'specs'       => ['المواصفات', 'specifications', 'specs'],
        'contents'    => ['محتويات', 'contents', "what's in"],
    ];

    /** Order a page reads in, whatever order the copy was written in. */
    private const ORDER = ['overview', 'features', 'feeding', 'ingredients', 'analysis', 'specs', 'contents',
                           'breeds', 'usage', 'storage', 'safety', 'other'];

    /** Spec labels worth a place in the summary strip, best first. */
    private const FACT_LABELS = [
        'weight'     => ['الوزن', 'الوزن الصافي', 'weight', 'net weight'],
        'size'       => ['الحجم', 'المقاس', 'السعة', 'الكمية', 'size', 'capacity', 'volume'],
        'dimensions' => ['الأبعاد', 'الأبعاد التقريبية', 'dimensions'],
        'material'   => ['المادة', 'الخامة', 'material'],
        'form'       => ['الشكل', 'نوع المنتج', 'النوع', 'form', 'type'],
        'color'      => ['اللون', 'color', 'colour'],
        'species'    => ['الأنواع المستهدفة', 'نوع الحيوان الأليف', 'مناسب لـ', 'suitable for', 'pet type'],
        'origin'     => ['بلد الصنع', 'بلد المنشأ', 'country of origin', 'made in'],
    ];

    /** Ingredient words that mean an animal source (for the donut's centre line). */
    private const ANIMAL = ['دجاج', 'بط', 'لحم', 'سلمون', 'سمك', 'أسماك', 'تونة', 'ديك رومي', 'ضأن', 'خروف', 'أرنب',
                            'كبد', 'سردين', 'تونا', 'سالمون', 'دواجن', 'فيليه', 'أوز', 'حمام', 'لحوم', 'غزال', 'رنجة', 'ماكريل', 'قلوب', 'بقري', 'عجل', 'سمان', 'حبار', 'روبيان',
                            'chicken', 'duck', 'meat', 'salmon', 'fish', 'tuna', 'turkey', 'lamb', 'rabbit', 'liver',
                            'sardine', 'venison', 'beef', 'herring', 'mackerel', 'quail', 'shrimp', 'heart'];

    /* ══════════════════════════════════════════════════════════════
       PUBLIC
       ══════════════════════════════════════════════════════════════ */

    /**
     * The structured story of a product in a language ('ar' | 'en'), or null
     * when the product has no usable description. Variations read their parent.
     */
    public static function get($product, string $lang = 'ar'): ?array
    {
        $product = $product instanceof WC_Product ? $product : wc_get_product((int) $product);
        if (! $product instanceof WC_Product) {
            return null;
        }
        if ($product->is_type('variation')) {
            $product = wc_get_product($product->get_parent_id());
            if (! $product instanceof WC_Product) {
                return null;
            }
        }
        $id   = $product->get_id();
        $lang = $lang === 'en' ? 'en' : 'ar';

        $source = $lang === 'en'
            ? trim((string) get_post_meta($id, '_zooboxi_description_en', true))
            : (string) get_post_field('post_content', $id);
        if ($lang === 'en' && $source === '') {
            return null;
        }
        if (trim(wp_strip_all_tags($source)) === '') {
            return null;
        }

        $cats   = self::category_names($id, $lang);
        $hash   = md5(self::VERSION . '|' . $source . '|' . $product->get_name() . '|' . implode(',', $cats));
        $cached = get_post_meta($id, self::META . $lang, true);
        if (is_array($cached) && ($cached['h'] ?? '') === $hash) {
            return $cached['s'] ?: null;
        }

        $story = self::parse($source, $lang, $product->get_name(), $cats);
        update_post_meta($id, self::META . $lang, ['h' => $hash, 's' => $story ?: []]);

        return $story ?: null;
    }

    /**
     * Parse one description. Public so WP-CLI audits can run it over the
     * catalogue without touching the cache.
     */
    public static function parse(string $html, string $lang = 'ar', string $name = '', array $cats = []): array
    {
        $sections = self::sections($html);
        if (! $sections) {
            return [];
        }

        // One section per key: a duplicate heading (a handful of products
        // repeat «المكونات») folds its blocks into the first.
        $byKey = [];
        foreach ($sections as $s) {
            if ($s['key'] !== 'other' && isset($byKey[$s['key']])) {
                $byKey[$s['key']]['blocks'] = array_merge($byKey[$s['key']]['blocks'], $s['blocks']);
                continue;
            }
            $byKey[$s['key'] === 'other' ? 'other_' . count($byKey) : $s['key']] = $s;
        }

        $ordered = [];
        foreach (self::ORDER as $key) {
            foreach ($byKey as $k => $s) {
                if ($s['key'] === $key) {
                    $ordered[] = self::enrich($s);
                }
            }
        }

        $find = static function (string $key) use ($ordered) {
            foreach ($ordered as $s) {
                if ($s['key'] === $key) {
                    return $s;
                }
            }
            return null;
        };

        return [
            'v'           => self::VERSION,
            'lang'        => $lang,
            'species'     => self::species($cats),
            'highlights'  => self::highlights($find('features')),
            'facts'       => self::facts($find('specs'), $find('analysis'), $name, $lang, $cats),
            'composition' => self::composition($find('ingredients'), $lang),
            'feeding'     => self::feeding($find('feeding'), $name),
            'sections'    => $ordered,
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       SPLITTING
       ══════════════════════════════════════════════════════════════ */

    /** @return array<int, array{key:string,title:string,blocks:array}> */
    private static function sections(string $html): array
    {
        $doc = new DOMDocument();
        $prev = libxml_use_internal_errors(true);
        $doc->loadHTML('<?xml encoding="utf-8"?><div id="zbroot">' . $html . '</div>', LIBXML_NOERROR | LIBXML_NOWARNING);
        libxml_clear_errors();
        libxml_use_internal_errors($prev);

        $root = $doc->getElementById('zbroot');
        if (! $root) {
            return [];
        }

        $sections = [];
        $current  = ['key' => 'overview', 'title' => '', 'blocks' => [], 'implicit' => true];
        $loose    = []; // inline text between blocks (copy that forgot its <p>)

        $flushLoose = static function () use (&$loose, &$current) {
            $t = self::clean(implode(' ', $loose));
            if ($t !== '') {
                $current['blocks'][] = ['type' => 'p', 'text' => $t];
            }
            $loose = [];
        };

        foreach (self::flatten($root) as $node) {
            if ($node instanceof DOMText) {
                $loose[] = $node->textContent;
                continue;
            }
            if (! $node instanceof DOMElement) {
                continue;
            }
            $tag = strtolower($node->tagName);
            if (preg_match('/^h[1-6]$/', $tag)) {
                $flushLoose();
                if ($current['blocks']) {
                    $sections[] = $current;
                }
                $title   = self::heading(self::clean($node->textContent));
                $current = ['key' => self::classify($title), 'title' => $title, 'blocks' => []];
                continue;
            }
            if (in_array($tag, ['b', 'strong', 'span', 'a', 'em', 'i', 'u', 'small', 'sup', 'sub'], true)) {
                $loose[] = $node->textContent;
                continue;
            }
            if ($tag === 'br') {
                $flushLoose();
                continue;
            }
            $flushLoose();
            $block = self::block($node);
            if ($block) {
                $current['blocks'][] = $block;
            }
        }
        $flushLoose();
        if ($current['blocks']) {
            $sections[] = $current;
        }

        // A description with no headings at all is one overview.
        foreach ($sections as &$s) {
            unset($s['implicit']);
        }
        unset($s);

        return $sections;
    }

    /**
     * Top-level children, descending through wrapper <div>/<section> so
     * headings nested in a container still split sections.
     */
    private static function flatten(DOMNode $node): array
    {
        $out = [];
        foreach ($node->childNodes as $child) {
            if ($child instanceof DOMElement && in_array(strtolower($child->tagName), ['div', 'section', 'article'], true)) {
                $hasBlock = false;
                foreach ($child->childNodes as $g) {
                    if ($g instanceof DOMElement && preg_match('/^(h[1-6]|p|ul|ol|table|div|section)$/i', $g->tagName)) {
                        $hasBlock = true;
                        break;
                    }
                }
                if ($hasBlock) {
                    array_push($out, ...self::flatten($child));
                    continue;
                }
            }
            $out[] = $child;
        }
        return $out;
    }

    private static function block(DOMElement $node): ?array
    {
        $tag = strtolower($node->tagName);
        if ($tag === 'ul' || $tag === 'ol') {
            $items = [];
            foreach ($node->getElementsByTagName('li') as $li) {
                $item = self::list_item($li);
                if ($item) {
                    $items[] = $item;
                }
            }
            return $items ? ['type' => 'list', 'ordered' => $tag === 'ol', 'items' => $items] : null;
        }
        if ($tag === 'table') {
            $rows = [];
            foreach ($node->getElementsByTagName('tr') as $tr) {
                $cells = [];
                foreach ($tr->childNodes as $td) {
                    if ($td instanceof DOMElement && in_array(strtolower($td->tagName), ['td', 'th'], true)) {
                        $cells[] = self::clean($td->textContent);
                    }
                }
                if (array_filter($cells, 'strlen')) {
                    $rows[] = $cells;
                }
            }
            if (! $rows) {
                return null;
            }
            // A first row with no digits is a header row («المواصفة | التفاصيل»).
            $headers = [];
            if (count($rows) > 1 && ! preg_match('/\d/u', implode('', $rows[0]))) {
                $headers = array_shift($rows);
            }
            return ['type' => 'table', 'headers' => $headers, 'rows' => $rows];
        }
        // <li> leaking outside a list (seen in «السلالات»): a paragraph with items.
        $lis = $node->getElementsByTagName('li');
        if ($lis->length) {
            $items = [];
            foreach ($lis as $li) {
                $item = self::list_item($li);
                if ($item) {
                    $items[] = $item;
                }
            }
            $lead = '';
            foreach ($node->childNodes as $c) {
                if ($c instanceof DOMText) {
                    $lead .= $c->textContent;
                }
            }
            return $items ? ['type' => 'list', 'ordered' => false, 'items' => $items, 'lead' => self::clean($lead)] : null;
        }
        $text = self::clean($node->textContent);
        return $text === '' ? null : ['type' => 'p', 'text' => $text];
    }

    /** «<strong>صحة المسالك:</strong> نص…» → {title, text}; plain items → {text}. */
    private static function list_item(DOMElement $li): ?array
    {
        $title = '';
        foreach ($li->childNodes as $c) {
            if ($c instanceof DOMElement && in_array(strtolower($c->tagName), ['strong', 'b'], true)) {
                $title = self::clean($c->textContent);
                break;
            }
            if ($c instanceof DOMText && trim($c->textContent) !== '') {
                break; // bold must lead the item to count as its title
            }
        }
        $full = self::clean($li->textContent);
        if ($full === '') {
            return null;
        }
        $title = preg_replace('/[\s:：]+$/u', '', $title);
        if ($title !== '' && mb_strpos($full, $title) === 0) {
            $text = preg_replace('/^[\s:：\-–—\x{00A0}]+/u', '', mb_substr($full, mb_strlen($title)));
            return ['title' => $title, 'text' => self::clean($text)];
        }
        // «الشيرازي: نص…» without bold — a short label before a colon.
        if (preg_match('/^([^:：]{2,40})[:：]\s*(.+)$/u', $full, $m)) {
            return ['title' => self::clean($m[1]), 'text' => self::clean($m[2])];
        }
        return ['text' => $full];
    }

    /* ══════════════════════════════════════════════════════════════
       DERIVED PIECES
       ══════════════════════════════════════════════════════════════ */

    /** Adds the one-line teaser each tile and accordion row shows. */
    private static function enrich(array $s): array
    {
        $s['count'] = 0;
        foreach ($s['blocks'] as $b) {
            if ($b['type'] === 'list') {
                $s['count'] += count($b['items']);
            } elseif ($b['type'] === 'table') {
                $s['count'] += count($b['rows']);
            }
        }
        return $s;
    }

    private static function highlights(?array $features): array
    {
        if (! $features) {
            return [];
        }
        $out = [];
        foreach ($features['blocks'] as $b) {
            if ($b['type'] !== 'list') {
                continue;
            }
            foreach ($b['items'] as $item) {
                $t = $item['title'] ?? '';
                if ($t !== '' && mb_strlen($t) <= 40) {
                    $out[] = ['title' => $t, 'text' => $item['text'] ?? ''];
                }
            }
        }
        return array_slice($out, 0, 6);
    }

    private static function facts(?array $specs, ?array $analysis, string $name, string $lang, array $cats = []): array
    {
        $rows = [];
        foreach ($specs['blocks'] ?? [] as $b) {
            if ($b['type'] === 'table') {
                foreach ($b['rows'] as $r) {
                    if (count($r) >= 2 && $r[0] !== '' && $r[1] !== '') {
                        $rows[] = [$r[0], $r[1]];
                    }
                }
            }
        }

        $facts = [];
        $taken = [];
        foreach (self::FACT_LABELS as $kind => $labels) {
            foreach ($rows as $i => [$label, $value]) {
                if (isset($taken[$i])) {
                    continue;
                }
                $l = mb_strtolower(trim($label));
                foreach ($labels as $want) {
                    if ($l === mb_strtolower($want) || mb_strpos($l, mb_strtolower($want)) === 0) {
                        $facts[] = ['kind' => $kind, 'label' => $label, 'value' => self::short_value($value)];
                        $taken[$i] = true;
                        continue 3;
                    }
                }
            }
        }

        // Food rarely has a spec table: the pack size lives in the name and
        // the protein in the analysis — both real, both worth the strip.
        // A bundle's name lists several pieces («… + … 85غ هدية»), so the
        // first size in it is one piece, never the bundle: no weight fact.
        $has    = array_column($facts, 'kind');
        $bundle = mb_strpos($name, '+') !== false || in_array('البكجات', $cats, true) || in_array('Bundles', $cats, true);
        if (! $bundle && ! in_array('weight', $has, true) && ! in_array('size', $has, true)) {
            $w = self::multipack_size($name, $lang) ?? self::pack_size($name, $lang);
            if ($w) {
                array_unshift($facts, ['kind' => 'weight', 'label' => $lang === 'en' ? 'Weight' : 'الوزن', 'value' => $w['label']]);
            }
        }
        foreach ($analysis['blocks'] ?? [] as $b) {
            if ($b['type'] !== 'table') {
                continue;
            }
            foreach ($b['rows'] as $r) {
                if (count($r) >= 2 && preg_match('/بروتين|protein/iu', $r[0]) && preg_match('/\d/', $r[1])) {
                    $facts[] = ['kind' => 'protein', 'label' => $lang === 'en' ? 'Protein' : 'البروتين', 'value' => self::short_value($r[1])];
                    break 2;
                }
            }
        }

        // Still room: the shelf the product sits on says what it is and who
        // it is for — «طعام رطب»، «قطط» — straight from its categories.
        $has = array_column($facts, 'kind');
        if (count($facts) < 4 && ! in_array('form', $has, true)) {
            foreach (self::TYPE_CATS as $needle => [$ar, $en]) {
                foreach ($cats as $c) {
                    if (mb_stripos($c, $needle) !== false) {
                        $facts[] = ['kind' => 'form', 'label' => $lang === 'en' ? 'Type' : 'النوع', 'value' => $lang === 'en' ? $en : $ar];
                        break 2;
                    }
                }
            }
        }
        if (count($facts) < 4 && ! in_array('species', $has, true)) {
            foreach (self::SPECIES_CATS as $needle => [$ar, $en]) {
                if (in_array($needle, $cats, true)) {
                    $facts[] = ['kind' => 'species', 'label' => $lang === 'en' ? 'For' : 'مناسب لـ', 'value' => $lang === 'en' ? $en : $ar];
                    break;
                }
            }
        }

        return array_slice($facts, 0, 4);
    }

    /** Category (AR name) → product type, first match wins. */
    private const TYPE_CATS = [
        'الطعام الرطب' => ['طعام رطب', 'Wet food'], 'الطعام الجاف' => ['طعام جاف', 'Dry food'],
        'مكافآت' => ['مكافآت', 'Treats'], 'مكافات' => ['مكافآت', 'Treats'], 'رمل' => ['رمل', 'Litter'],
        'الحليب' => ['حليب', 'Milk'], 'مكمل' => ['مكمّل غذائي', 'Supplement'], 'فيتامين' => ['فيتامينات', 'Vitamins'],
        'ألعاب' => ['لعبة', 'Toy'], 'العاب' => ['لعبة', 'Toy'], 'أطواق' => ['طوق', 'Collar'], 'اطواق' => ['طوق', 'Collar'],
        'أسرّة' => ['سرير', 'Bed'], 'أسرة' => ['سرير', 'Bed'], 'أقفاص' => ['قفص', 'Cage'], 'شامبو' => ['شامبو', 'Shampoo'],
    ];

    /** Species root category (AR name) → label. */
    private const SPECIES_CATS = [
        'قطط' => ['القطط', 'Cats'], 'كلاب' => ['الكلاب', 'Dogs'], 'طيور' => ['الطيور', 'Birds'],
        'أسماك' => ['الأسماك', 'Fish'], 'اسماك' => ['الأسماك', 'Fish'], 'حيوانات صغيرة' => ['الحيوانات الصغيرة', 'Small pets'],
        'قوارض' => ['القوارض', 'Rodents'], 'زواحف' => ['الزواحف', 'Reptiles'],
    ];

    /** Who the product is for — the app casts the matching character. */
    private const SPECIES_KEYS = [
        'قطط' => 'cat', 'كلاب' => 'dog', 'طيور' => 'bird', 'أسماك' => 'fish', 'اسماك' => 'fish',
        'حيوانات صغيرة' => 'small', 'قوارض' => 'small', 'زواحف' => 'reptile',
    ];

    private static function species(array $cats): ?string
    {
        foreach (self::SPECIES_KEYS as $needle => $key) {
            if (in_array($needle, $cats, true)) {
                return $key;
            }
        }
        foreach (self::SPECIES_KEYS as $needle => $key) {
            foreach ($cats as $c) {
                if (mb_strpos($c, $needle) !== false) {
                    return $key;
                }
            }
        }
        return null;
    }

    /** The product's category names (Arabic — the matching keys above are Arabic). */
    private static function category_names(int $id, string $lang): array
    {
        $terms = get_the_terms($id, 'product_cat');
        if (! is_array($terms)) {
            return [];
        }
        $names = array_values(array_unique(array_map(static fn ($t) => (string) $t->name, $terms)));
        sort($names);
        return $names;
    }

    /** «حوالي 5.0 سم × 3.2 سم (حجم كبير)» → «5.0 سم × 3.2 سم». */
    public static function short_value(string $v): string
    {
        $v = trim(preg_replace('/\s*\([^)]*\)\s*/u', ' ', $v));
        $v = preg_replace('/^(~|≈|حوالي|تقريبًا|تقريباً|approx\.?|approximately|about)\s*/iu', '', $v);
        if (mb_strlen($v) > 26) {
            $cut = trim(preg_split('/[،,؛;]| مع | with /u', $v)[0]);
            if (mb_strlen($cut) > 26) {
                $words = preg_split('/\s+/u', $cut);
                $cut = '';
                foreach ($words as $w) {
                    if (mb_strlen(trim($cut . ' ' . $w)) > 24) {
                        break;
                    }
                    $cut = trim($cut . ' ' . $w);
                }
            }
            $v = $cut;
        }
        return trim($v);
    }

    /** Pack size from a product name: «… 85غ», «2 كجم», «400 g». */
    /**
     * «8×12غ», «4×14g», «15غ × 40»: the pack is all its pieces, so the fact
     * reads «8 × 12 جم» instead of one piece passing for the whole pack.
     */
    private static function multipack_size(string $name, string $lang = 'ar'): ?array
    {
        if (! class_exists('Zooboxi_Brand_Kit') || ! class_exists('Zooboxi_Facet_Index')) {
            return null;
        }
        $m = Zooboxi_Brand_Kit::pack(Zooboxi_Facet_Index::norm($name));
        if (! $m || ($m['units'] ?? 1) < 2) {
            return null;
        }
        $g = rtrim(rtrim(number_format((float) $m['unit_g'], 1, '.', ''), '0'), '.');
        return ['grams' => $m['grams'], 'label' => $m['units'] . ' × ' . $g . ($lang === 'en' ? ' g' : ' جم')];
    }

    public static function pack_size(string $name, string $lang = 'ar'): ?array
    {
        if (! preg_match('/(\d+(?:[.,]\d+)?)\s*(كجم|كغ|كيلو|kg|غ|جم|جرام|غرام|g|gr|مل|ml|لتر|l)\b/iu', $name . ' ', $m)) {
            // Arabic unit glued to the number with no word boundary after it.
            if (! preg_match('/(\d+(?:[.,]\d+)?)\s*(كجم|كغ|كيلو|غ|جم|جرام|غرام|مل|لتر)/u', $name, $m)) {
                return null;
            }
        }
        $n = (float) str_replace(',', '.', $m[1]);
        $u = mb_strtolower($m[2]);
        $grams = null;
        if (in_array($u, ['كجم', 'كغ', 'كيلو', 'kg'], true)) {
            $grams = $n * 1000;
            $label = rtrim(rtrim(number_format($n, 2, '.', ''), '0'), '.') . ($lang === 'en' ? ' kg' : ' كجم');
        } elseif (in_array($u, ['غ', 'جم', 'جرام', 'غرام', 'g', 'gr'], true)) {
            $grams = $n;
            $label = rtrim(rtrim(number_format($n, 1, '.', ''), '0'), '.') . ($lang === 'en' ? ' g' : ' جم');
        } elseif (in_array($u, ['مل', 'ml'], true)) {
            $label = rtrim(rtrim(number_format($n, 1, '.', ''), '0'), '.') . ($lang === 'en' ? ' ml' : ' مل');
        } else {
            $label = rtrim(rtrim(number_format($n, 2, '.', ''), '0'), '.') . ($lang === 'en' ? ' L' : ' لتر');
        }
        return ['grams' => $grams, 'label' => $label];
    }

    /**
     * The donut: named ingredient shares when the copy states them.
     * Only top-level percentages count, and only when they add up to a
     * believable part of the whole (≥15%, ≤100%).
     */
    private static function composition(?array $ingredients, string $lang): ?array
    {
        if (! $ingredients) {
            return null;
        }
        $text = '';
        foreach ($ingredients['blocks'] as $b) {
            if ($b['type'] === 'p') {
                $text .= ($text === '' ? '' : '، ') . $b['text'];
            } elseif ($b['type'] === 'list') {
                foreach ($b['items'] as $it) {
                    $text .= ($text === '' ? '' : '، ') . trim(($it['title'] ?? '') . ' ' . ($it['text'] ?? ''));
                }
            }
        }
        $items = self::split_ingredients($text);
        if (count($items) < 2) {
            return null;
        }

        $named = array_values(array_filter($items, static fn ($i) => $i['pct'] !== null && $i['pct'] >= 1));
        $sum = array_sum(array_column($named, 'pct'));
        if (! $named || $sum < 15 || $sum > 100.5) {
            return ['items' => $items, 'slices' => [], 'center' => null];
        }

        usort($named, static fn ($a, $b) => $b['pct'] <=> $a['pct']);
        $top    = array_slice($named, 0, 3);
        $slices = array_map(static fn ($i) => ['name' => $i['name'], 'pct' => round($i['pct'], 1)], $top);
        $rest   = round(100 - array_sum(array_column($top, 'pct')), 1);
        if ($rest >= 0.5) {
            $slices[] = ['name' => $lang === 'en' ? 'Everything else' : 'باقي المكونات', 'pct' => $rest, 'rest' => true];
        }

        $animal = 0.0;
        foreach ($named as $i) {
            if (self::is_animal($i['name'])) {
                $animal += $i['pct'];
            }
        }
        $center = $animal >= 20
            ? ['value' => round($animal) . '%', 'label' => $lang === 'en' ? 'animal sources' : 'مصادر حيوانية']
            : ['value' => round($top[0]['pct']) . '%', 'label' => $top[0]['name']];

        return ['items' => $items, 'slices' => $slices, 'center' => $center];
    }

    /**
     * Word-level match so «بط» (duck) never fires on «بطاطا» (potato):
     * a token equals the word after dropping «ال»/«و», or starts with it
     * when the word is long enough to be unambiguous («دجاج» → «دجاجة»).
     */
    private static function is_animal(string $name): bool
    {
        foreach (preg_split('/[\s\-\/]+/u', mb_strtolower($name)) as $tok) {
            $tok = preg_replace('/^(وال|ال|و)(?=\X{2,})/u', '', $tok);
            foreach (self::ANIMAL as $w) {
                if ($tok === $w || (mb_strlen($w) >= 4 && mb_strpos($tok, $w) === 0)) {
                    return true;
                }
            }
        }
        // two-word sources («ديك رومي»)
        foreach (self::ANIMAL as $w) {
            if (mb_strpos($w, ' ') !== false && mb_strpos($name, $w) !== false) {
                return true;
            }
        }
        return false;
    }

    /** Split on commas that sit outside parentheses; lift a trailing «35%». */
    private static function split_ingredients(string $text): array
    {
        $text  = preg_replace('/[\s.。]+$/u', '', trim($text));
        $parts = [];
        $depth = 0;
        $buf   = '';
        foreach (preg_split('//u', $text, -1, PREG_SPLIT_NO_EMPTY) as $ch) {
            if ($ch === '(' || $ch === '[') {
                $depth++;
            } elseif (($ch === ')' || $ch === ']') && $depth > 0) {
                $depth--;
            }
            if ($depth === 0 && ($ch === '،' || $ch === ',' || $ch === '؛' || $ch === ';')) {
                $parts[] = $buf;
                $buf = '';
                continue;
            }
            $buf .= $ch;
        }
        $parts[] = $buf;

        $items = [];
        foreach ($parts as $p) {
            $p = self::clean($p);
            if ($p === '' || mb_strlen($p) > 120) {
                continue;
            }
            $pct = null;
            $detail = '';
            if (preg_match_all('/[(\[]([^)\]]*)[)\]]/u', $p, $m)) {
                $detail = self::clean(implode('، ', array_filter(array_map([self::class, 'clean'], $m[1]), 'strlen')));
                $p = self::clean(str_replace($m[0], ' ', $p));
            }
            $p = str_replace(['(', ')', '[', ']'], ' ', $p);
            if (preg_match('/(\d+(?:[.,]\d+)?)\s*[%٪]/u', $p, $m)) {
                $pct = (float) str_replace(',', '.', $m[1]);
                $p = self::clean(str_replace($m[0], ' ', $p));
            }
            $p = preg_replace('/^(و|and\s+)/u', '', $p);
            $name = self::clean($p);
            if ($name === '') {
                continue;
            }
            $items[] = ['name' => $name, 'detail' => $detail, 'pct' => $pct];
        }
        return array_slice($items, 0, 40);
    }

    /**
     * Feeding table → calculator rows when the first column is a pet weight
     * («2-3 كجم»). Each row keeps its cells for display and, when the
     * amount is a count of packs or grams, a daily number the page can turn
     * into "how long a pack lasts".
     */
    private static function feeding(?array $feeding, string $name): ?array
    {
        if (! $feeding) {
            return null;
        }
        $table = null;
        foreach ($feeding['blocks'] as $b) {
            if ($b['type'] === 'table' && count($b['rows']) >= 2) {
                $table = $b;
                break;
            }
        }
        if (! $table) {
            return null;
        }
        $h0 = $table['headers'][0] ?? '';
        if (! preg_match('/وزن|الوزن|weight/iu', $h0)) {
            return null; // not a weight table: the section still shows it as a table
        }
        $unitInHeader = (bool) preg_match('/كجم|كغ|كيلو|kg/iu', $h0);

        $rows = [];
        foreach ($table['rows'] as $r) {
            if (count($r) < 2) {
                continue;
            }
            if (! $unitInHeader && ! preg_match('/كجم|كغ|كيلو|kg/iu', $r[0])) {
                continue; // «5 - 6 أشهر» rows of an age×weight grid are not weights
            }
            $range = self::range($r[0]);
            if (! $range) {
                continue;
            }
            $amount = self::daily_amount($r[1]);
            $rows[] = [
                'label'  => $r[0],
                'min'    => $range[0] ?? null,
                'max'    => $range[1] ?? null,
                'cells'  => array_slice($r, 1),
                'daily'  => $amount['n'] ?? null,
                'lo'     => $amount['lo'] ?? null,
                'hi'     => $amount['hi'] ?? null,
                'unit'   => $amount['unit'] ?? null,
            ];
        }
        if (count($rows) < 2) {
            return null;
        }
        $pack = self::multipack_size($name) ?? self::pack_size($name);

        return [
            'headers'    => $table['headers'],
            'rows'       => $rows,
            'pack_grams' => $pack['grams'] ?? null,
        ];
    }

    /** «2-3 كجم» → [2, 3]; «أكثر من 10 كجم» → [10, null]; «5 كجم» → [5, 5]. */
    private static function range(string $s): ?array
    {
        $s = self::latin_digits($s);
        if (preg_match('/(\d+(?:\.\d+)?)\s*[-–—إلى to]+\s*(\d+(?:\.\d+)?)/u', $s, $m)) {
            return [(float) $m[1], (float) $m[2]];
        }
        if (preg_match('/(أكثر|فوق|أعلى|over|above|\+)/iu', $s) && preg_match('/(\d+(?:\.\d+)?)/', $s, $m)) {
            return [(float) $m[1], null];
        }
        if (preg_match('/(أقل|تحت|حتى|لغاية|under|below|up to)/iu', $s) && preg_match('/(\d+(?:\.\d+)?)/', $s, $m)) {
            return [0.0, (float) $m[1]];
        }
        if (preg_match('/^\D*(\d+(?:\.\d+)?)\D*$/u', $s, $m)) {
            return [(float) $m[1], (float) $m[1]];
        }
        return null;
    }

    /** «2 - 2.5 كيس» → {n: 2.25, unit: piece}; «60-80 جرام» → {n: 70, unit: g}. */
    private static function daily_amount(string $s): ?array
    {
        $s = self::latin_digits($s);
        $unit = null;
        if (preg_match('/كيس|أكياس|علبة|علب|ظرف|أظرف|pouch|can|sachet|tray/iu', $s)) {
            $unit = 'piece';
        } elseif (preg_match('/جرام|غرام|جم|\bغ\b|\bg\b|grams?/iu', $s)) {
            $unit = 'g';
        }
        if (! $unit || ! preg_match_all('/\d+(?:\.\d+)?/', $s, $m) || count($m[0]) > 2) {
            return null;
        }
        $nums = array_map('floatval', $m[0]);
        return ['n' => round(array_sum($nums) / count($nums), 2), 'lo' => min($nums), 'hi' => max($nums), 'unit' => $unit];
    }

    /* ══════════════════════════════════════════════════════════════
       TEXT
       ══════════════════════════════════════════════════════════════ */

    private static function classify(string $title): string
    {
        $t = mb_strtolower($title);
        foreach (self::KEYS as $key => $words) {
            foreach ($words as $w) {
                if (mb_strpos($t, mb_strtolower($w)) !== false) {
                    return $key;
                }
            }
        }
        return 'other';
    }

    /** «🐱 نظرة عامة 🐶» → «نظرة عامة»; «دليل الجرعات اليومية:» → «دليل الجرعات اليومية». */
    private static function heading(string $t): string
    {
        $t = preg_replace('/[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}\x{200D}\x{E0020}-\x{E007F}]/u', '', $t);
        return trim(preg_replace('/[\s:：]+$/u', '', trim($t)));
    }

    /** Whitespace, entities and foreign-script debris out; emoji kept in prose. */
    public static function clean(string $t): string
    {
        $t = html_entity_decode($t, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        // Thai, Hangul, Cyrillic, CJK, kana, Devanagari: never part of our copy.
        $t = preg_replace('/[\x{0E00}-\x{0E7F}\x{AC00}-\x{D7AF}\x{1100}-\x{11FF}\x{0400}-\x{04FF}\x{4E00}-\x{9FFF}\x{3040}-\x{30FF}\x{0900}-\x{097F}]+/u', '', $t);
        $t = preg_replace('/[\s\x{00A0}\x{200B}]+/u', ' ', $t);
        // «ل» orphaned by a dropped foreign word («لเพื่อนك» → «لك»).
        $t = preg_replace('/(^|\s)ل\s+ك(\s|$)/u', '$1لك$2', $t);
        return trim($t);
    }

    private static function latin_digits(string $s): string
    {
        return strtr($s, ['٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6',
                          '٧' => '7', '٨' => '8', '٩' => '9', '٫' => '.', ',' => '.']);
    }
}
