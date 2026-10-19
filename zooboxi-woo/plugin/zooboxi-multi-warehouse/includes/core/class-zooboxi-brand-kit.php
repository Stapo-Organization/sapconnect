<?php

/**
 * Zooboxi_Brand_Kit — what the app's brand page knows about a brand beyond
 * its products: its identity (colours, country, founding year, who it is for,
 * its mood), its product lines, how its range splits into shelves, and where
 * its bigger pack is honestly cheaper.
 *
 * Identity comes from sapconnect's brand design kits (GET /api/woo/brand-kits,
 * 87 brands on file), pulled by Zooboxi_Brand_Sync into an option and kept on
 * failure. A brand without a kit simply has none — the page falls back to the
 * store's own look rather than borrowing a house line.
 *
 * Product lines are curated per brand (the words a title shares are too noisy
 * to trust: «زولكس» spelled three ways, «بخاخ» read as a line), matched on the
 * Arabic title and the English name, and indexed as the `line` facet so the
 * filter sheet counts and narrows them like any other facet. The option
 * `zooboxi_brand_lines` overrides a brand's lines without a release.
 */

if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Brand_Kit
{
    public const OPTION_KITS    = 'zooboxi_brand_kits';
    public const OPTION_KITS_AT = 'zooboxi_brand_kits_synced_at';
    public const OPTION_LINES   = 'zooboxi_brand_lines';

    /**
     * brand slug => [line key => [ar, en, regex over the folded «title | english name»]].
     * Verified against the live catalogue 2026-09-24 (counts in comments).
     */
    private const LINES = [
        'inaba' => [
            'churu'  => ['تشورو', 'Churu', '/churu|تشورو/u'],                        // 72
            'dashi'  => ['داشي ديلايت', 'Dashi Delights', '/dashi|داشي/u'],          // 23
            'grill'  => ['فيليه بالمرق', 'Grilled fillets', '/grilled|فيليه/u'],     // 10
            'ciao'   => ['سياو سوجوي', 'CIAO Sugoi', '/ciao|sugoi|سياو|سوجوي/u'],   // 6
            'juicy'  => ['جوسي بايتس', 'Juicy Bites', '/juicy bites/u'],             // 5
        ],
        'josera' => [
            'josidog' => ['جوسي دوغ', 'JosiDog', '/josi ?dog|جوسي ?دوغ/u'],         // 12
            'josicat' => ['جوسي كات', 'JosiCat', '/josi ?cat|جوسي ?كات/u'],         // 9
            'help'    => ['جوسيرا هيلب', 'Josera Help', '/\bhelp\b|هيلب/u'],        // 5
        ],
        'versele-laga' => [
            'prestige'  => ['بريستيج', 'Prestige', '/prestige|بريستيج/u'],          // 40
            'oropharma' => ['أوروفارما', 'Oropharma', '/oropharma|اوروفارما/u'],    // 9
            'crispy'    => ['كريسبي', 'Crispy', '/crispy|كريسبي/u'],                // 7
            'nature'    => ['نيتشر', 'Nature', '/\bnature\b|نيتشر|نايتشر|نايشتر|ناتشر/u'], // 6
            'orlux'     => ['أورلوكس', 'Orlux', '/orlux|اورلوكس/u'],               // 5
        ],
        'zupreem' => [
            'fruitblend' => ['فروت بلند', 'FruitBlend', '/fruit ?blend|فروت ?بلند|فورت ?بلند/u'], // 9
            'natural'    => ['ناتشرال', 'Natural', '/\bnatural\b|ناتشرال|ناتشورال/u'],          // 8
            'rewards'    => ['ريل ريواردز', 'Real Rewards', '/real rewards|ريل ريوارد/u'],      // 6
            'smart'      => ['سمارت سيلكت', 'Smart Selects', '/smart ?selects?|سمارت/u'],      // 5
            'sensible'   => ['سنسبل', 'Sensible Seed', '/sensible|سنسبل/u'],                   // 4
            'purefun'    => ['بيور فان', 'Pure Fun', '/pure fun|بيور فان|بيور فن/u'],          // 4
        ],
        'zolux' => [
            'ethicat'  => ['إيثيكات', 'Ethicat', '/ethicat|اثيكات|ايثيكات/u'],       // 34
            'anah'     => ['آنا', 'Anah', '/\banah\b|زولكس انا /u'],                 // 32
            'sweeties' => ['سويتيز', 'Sweeties', '/sweeties|سويتيز/u'],             // 20
            'moov'     => ['مووف', 'Moov', '/\bmoov\b|مووف/u'],                      // 14
        ],
        'garden-bites' => [
            'vegan'  => ['تريبل فيغان', 'Triple Vegan', '/triple vegan|تريبل فيغان/u'],   // 6
            'veggie' => ['فيجي باديز', 'Veggie Buddies', '/veggie buddies|فيجي باديز/u'], // 5
        ],
        'solid-gold' => [
            'indigo'   => ['إندقو مون', 'Indigo Moon', '/indigo moon|اندقو مون/u'],       // 9
            'nutrient' => ['نيوتري بوست', 'Nutrient Boost', '/nutrient boost|نيوتري ?بوست|نيوترينت بوست/u'], // 5
        ],
    ];

    /** A line appears once it holds this many products — and only with a second line beside it. */
    private const LINE_MIN = 3;

    /** Countries as the kits spell them → [ar, en]. The first part of «UK / Ireland» wins. */
    private const COUNTRIES = [
        'japan' => ['اليابان', 'Japan'], 'united kingdom' => ['المملكة المتحدة', 'United Kingdom'],
        'uk' => ['المملكة المتحدة', 'United Kingdom'], 'france' => ['فرنسا', 'France'],
        'italy' => ['إيطاليا', 'Italy'], 'germany' => ['ألمانيا', 'Germany'],
        'belgium' => ['بلجيكا', 'Belgium'], 'netherlands' => ['هولندا', 'Netherlands'],
        'usa' => ['الولايات المتحدة', 'USA'], 'united states' => ['الولايات المتحدة', 'USA'],
        'canada' => ['كندا', 'Canada'], 'singapore' => ['سنغافورة', 'Singapore'],
        'saudi arabia' => ['السعودية', 'Saudi Arabia'], 'turkey' => ['تركيا', 'Türkiye'],
        'spain' => ['إسبانيا', 'Spain'], 'new zealand' => ['نيوزيلندا', 'New Zealand'],
        'estonia' => ['إستونيا', 'Estonia'], 'czech republic' => ['التشيك', 'Czechia'],
        'china' => ['الصين', 'China'], 'ireland' => ['أيرلندا', 'Ireland'],
        'switzerland' => ['سويسرا', 'Switzerland'], 'thailand' => ['تايلاند', 'Thailand'],
    ];

    /** Kit category → [ar, en] specialty line. */
    private const SPECIALTY = [
        'cat'    => ['للقطط', 'For cats'],
        'dog'    => ['للكلاب', 'For dogs'],
        'bird'   => ['للطيور', 'For birds'],
        'small'  => ['للحيوانات الصغيرة', 'For small pets'],
        'fish'   => ['للأسماك', 'For fish'],
        'multi'  => ['لكل الأليفة', 'For every pet'],
        'health' => ['صحة وعناية', 'Health and care'],
        'litter' => ['رمل ونظافة', 'Litter and hygiene'],
        'accessories' => ['مستلزمات', 'Supplies'],
    ];

    /* ══════════════════════════════════════════════════════════════
       IDENTITY
       ══════════════════════════════════════════════════════════════ */

    /** Pull every kit from sapconnect; keeps the previous copy on any failure. */
    public static function sync(string $api_base, string $api_token): int
    {
        $res = wp_remote_get(rtrim($api_base, '/') . '/brand-kits', [
            'headers' => ['Authorization' => 'Bearer ' . $api_token, 'Accept' => 'application/json'],
            'timeout' => 30,
        ]);
        if (is_wp_error($res) || (int) wp_remote_retrieve_response_code($res) !== 200) {
            return -1;
        }
        $body = json_decode(wp_remote_retrieve_body($res), true);
        $data = is_array($body) && isset($body['data']) && is_array($body['data']) ? $body['data'] : null;
        if ($data === null) {
            return -1;
        }
        $kits = [];
        foreach ($data as $code => $kit) {
            if (is_array($kit) && (string) $code !== '') {
                $kits[(string) $code] = $kit;
            }
        }
        update_option(self::OPTION_KITS, $kits, false);
        update_option(self::OPTION_KITS_AT, current_time('mysql'), false);
        return count($kits);
    }

    /** The stored kit for a SAP brand code, or null. */
    public static function kit(string $code): ?array
    {
        if ($code === '') {
            return null;
        }
        $kits = get_option(self::OPTION_KITS, []);
        return (is_array($kits) && isset($kits[$code]) && is_array($kits[$code])) ? $kits[$code] : null;
    }

    /**
     * What the page says about the brand, in the request language. English
     * gets only what exists in English (no Arabic audience line in an English UI).
     *
     * @return array{lead:string,country:string,founded:string,mood:string[],specialty:string,category:string,tagline:string}
     */
    public static function story(?array $kit, string $lang): array
    {
        $en = $lang === 'en';
        $kit = $kit ?? [];

        $country = '';
        $raw = strtolower(trim((string) ($kit['country'] ?? '')));
        if ($raw !== '') {
            $first = trim((string) preg_split('/[\/(,]/', $raw)[0]);
            if (isset(self::COUNTRIES[$first])) {
                $country = self::COUNTRIES[$first][$en ? 1 : 0];
            }
        }

        $founded = '';
        if (preg_match('/(?<!\d)(1[5-9]\d\d|20[0-2]\d)(?!\d)/', (string) ($kit['founded'] ?? ''), $m)) {
            $founded = $m[1];
        }

        $mood = [];
        if (!$en) {
            foreach (preg_split('/[·•،,]/u', (string) ($kit['mood_ar'] ?? '')) as $word) {
                $word = trim($word);
                if ($word !== '' && mb_strlen($word) <= 14) {
                    $mood[] = $word;
                }
            }
            $mood = array_slice($mood, 0, 4);
        }

        $category = strtolower(trim((string) ($kit['category'] ?? '')));
        $specialty = isset(self::SPECIALTY[$category]) ? self::SPECIALTY[$category][$en ? 1 : 0] : '';

        return [
            'lead'      => $en ? '' : trim((string) ($kit['audience_ar'] ?? '')),
            'country'   => $country,
            'founded'   => $founded,
            'mood'      => $mood,
            'specialty' => $specialty,
            'category'  => $category,
            'tagline'   => trim((string) ($en ? ($kit['tagline_en'] ?? '') : ($kit['tagline_ar'] ?? ''))),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       LINES
       ══════════════════════════════════════════════════════════════ */

    /** @return array<string,array<string,array{0:string,1:string,2:string}>> */
    private static function all_lines(): array
    {
        static $lines = null;
        if ($lines === null) {
            $lines = self::LINES;
            $override = get_option(self::OPTION_LINES, []);
            if (is_array($override)) {
                foreach ($override as $slug => $defs) {
                    if (is_array($defs)) {
                        $lines[(string) $slug] = $defs;
                    }
                }
            }
        }
        return $lines;
    }

    /** The facet value for one brand's line — unique across brands. */
    public static function line_value(string $brand_slug, string $key): string
    {
        return sanitize_key($brand_slug . '_' . $key);
    }

    /**
     * The lines a product belongs to (facet values), from its folded Arabic
     * title and English name.
     *
     * @param string[] $brand_slugs
     * @return string[]
     */
    public static function lines_of(array $brand_slugs, string $title_norm, string $en_norm): array
    {
        $all = self::all_lines();
        $text = $title_norm . ' | ' . $en_norm;
        $out = [];
        foreach ($brand_slugs as $slug) {
            foreach ($all[$slug] ?? [] as $key => $def) {
                if (is_array($def) && isset($def[2]) && @preg_match((string) $def[2], $text)) {
                    $out[] = self::line_value($slug, (string) $key);
                }
            }
        }
        return $out;
    }

    /** [ar, en] for a line facet value, or null. */
    public static function line_label(string $value): ?array
    {
        foreach (self::all_lines() as $slug => $defs) {
            foreach ($defs as $key => $def) {
                if (self::line_value((string) $slug, (string) $key) === $value) {
                    return [(string) $def[0], (string) $def[1]];
                }
            }
        }
        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       PACKS
       ══════════════════════════════════════════════════════════════ */

    /**
     * A title's pack: «4×14غ», «20 ظرف × 14غ», «(4+4+4) × 70غ», «14g x4»,
     * «3 × 380 غ» → units × unit weight. Single packs («400غ», «1.5 كجم»)
     * come back with units 1. Title must be folded (× → x).
     *
     * @return array{units:int,unit_g:float,grams:float}|null
     */
    public static function pack(string $title_norm): ?array
    {
        $unit = '(كجم|كغ|كيلو|kg|غ|جم|جرام|غرام|g|gr)';
        $num  = '(\d+(?:[.,]\d+)?)';
        $to_g = static function (string $n, string $u): float {
            $v = (float) str_replace(',', '.', $n);
            return in_array(mb_strtolower($u), ['كجم', 'كغ', 'كيلو', 'kg'], true) ? $v * 1000 : $v;
        };

        // (4+4+4) x 70g
        if (preg_match('/\(\s*(\d+(?:\s*\+\s*\d+)+)\s*\)\s*x\s*' . $num . '\s*' . $unit . '/u', $title_norm, $m)) {
            $units = array_sum(array_map('intval', preg_split('/\s*\+\s*/', $m[1])));
            $g = $to_g($m[2], $m[3]);
            return $units > 0 && $g > 0 ? ['units' => $units, 'unit_g' => $g, 'grams' => $units * $g] : null;
        }
        // 4x14g · 20 ظرف x 14g · 50 x 14 g
        if (preg_match('/(?<![\d.])(\d{1,3})\s*(?:ظرف|اظرف|انبوب|انابيب|قطعه|حبه|tubes?|pcs?|sachets?)?\s*x\s*' . $num . '\s*' . $unit . '/u', $title_norm, $m)) {
            $units = (int) $m[1];
            $g = $to_g($m[2], $m[3]);
            return $units > 1 && $g > 0 ? ['units' => $units, 'unit_g' => $g, 'grams' => $units * $g] : null;
        }
        // 14g x4 · 14g x 20 tubes
        if (preg_match('/' . $num . '\s*' . $unit . '\s*x\s*(\d{1,3})(?![\d.])/u', $title_norm, $m)) {
            $units = (int) $m[3];
            $g = $to_g($m[1], $m[2]);
            return $units > 1 && $g > 0 ? ['units' => $units, 'unit_g' => $g, 'grams' => $units * $g] : null;
        }
        if (preg_match('/' . $num . '\s*' . $unit . '(?![a-z])/u', $title_norm, $m)) {
            $g = $to_g($m[1], $m[2]);
            return $g > 0 ? ['units' => 1, 'unit_g' => $g, 'grams' => $g] : null;
        }
        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       THE PAGE'S SHELVES
       ══════════════════════════════════════════════════════════════ */

    /**
     * Lines, shelves, the honest bigger-pack saving and stock numbers for one
     * brand's ids in the current shelf scope, read from the facet index.
     *
     * @param int[] $ids brand products visible on this shelf
     * @return array{lines:array,shelves:array,value:?array,in_stock:int,total:int}
     */
    public static function page(string $brand_slug, array $ids, string $lang): array
    {
        $empty = ['lines' => [], 'shelves' => [], 'value' => null, 'in_stock' => 0, 'total' => count($ids), 'species' => ''];
        if (empty($ids) || !class_exists('Zooboxi_Facet_Index') || !Zooboxi_Facet_Index::ensure()) {
            return $empty;
        }

        global $wpdb;
        $en = $lang === 'en';
        $list = implode(',', array_map('intval', $ids));
        $rows = [];
        foreach ($wpdb->get_results("SELECT product_id, facet, value FROM " . Zooboxi_Facet_Index::table() . " WHERE product_id IN ({$list})", ARRAY_N) as [$pid, $facet, $value]) {
            $rows[(int) $pid][$facet][$value] = true;
        }
        $meta = [];
        foreach ($wpdb->get_results("SELECT product_id, price, price_express, per_kg, instock FROM " . Zooboxi_Facet_Index::meta_table() . " WHERE product_id IN ({$list})", ARRAY_A) as $m) {
            $meta[(int) $m['product_id']] = $m;
        }
        $rank = [];
        foreach ($wpdb->get_results("SELECT post_id, meta_value FROM {$wpdb->postmeta} WHERE meta_key = '_zb_rank_score' AND post_id IN ({$list})", ARRAY_N) as [$pid, $score]) {
            $rank[(int) $pid] = (float) $score;
        }

        $in_stock = 0;
        foreach ($ids as $pid) {
            if ((int) ($meta[$pid]['instock'] ?? 1) === 1) {
                $in_stock++;
            }
        }

        // The best-ranked in-stock member of a set — its picture stands for the shelf.
        $face = static function (array $members) use ($meta, $rank): ?int {
            usort($members, static function ($a, $b) use ($meta, $rank) {
                $sa = (int) ($meta[$a]['instock'] ?? 1);
                $sb = (int) ($meta[$b]['instock'] ?? 1);
                return $sa !== $sb ? $sb <=> $sa : (($rank[$b] ?? 0) <=> ($rank[$a] ?? 0));
            });
            return $members[0] ?? null;
        };
        $image = static function (?int $pid): ?string {
            if (!$pid) {
                return null;
            }
            $thumb = get_post_thumbnail_id($pid);
            $url = $thumb ? wp_get_attachment_image_url($thumb, 'woocommerce_thumbnail') : null;
            return $url ? esc_url_raw($url) : null;
        };

        $members = static function (string $facet) use ($rows, $ids): array {
            $by = [];
            foreach ($ids as $pid) {
                foreach (array_keys($rows[$pid][$facet] ?? []) as $v) {
                    $by[(string) $v][] = $pid;
                }
            }
            return $by;
        };

        // ── Lines (curated).
        $lines = [];
        $byLine = $members('line');
        $prefix = sanitize_key($brand_slug) . '_';
        foreach ($byLine as $value => $pids) {
            if (strpos($value, $prefix) !== 0 || count($pids) < self::LINE_MIN) {
                continue;
            }
            $label = self::line_label($value);
            if ($label === null) {
                continue;
            }
            $lines[] = [
                'group' => 'line', 'key' => $value, 'name' => $en ? $label[1] : $label[0],
                'count' => count($pids), 'image' => $image($face($pids)), 'icon' => null,
            ];
        }
        usort($lines, static fn($a, $b) => $b['count'] <=> $a['count']);
        if (count($lines) < 2) {
            $lines = [];
        }

        // ── Shelves: the one facet that splits this brand best — the pets for a
        //    brand that serves several, else the food type, else the needs.
        $shelves = [];
        foreach (['species', 'form', 'need'] as $facet) {
            $by = array_filter($members($facet), static fn($p) => count($p) >= self::LINE_MIN);
            if (count($by) < 2) {
                continue;
            }
            uasort($by, static fn($a, $b) => count($b) <=> count($a));
            foreach (array_slice($by, 0, 6, true) as $value => $pids) {
                $label = self::facet_label($facet, (string) $value, $en);
                if ($label === null) {
                    continue;
                }
                $shelves[] = [
                    'group' => $facet, 'key' => (string) $value, 'name' => $label[0],
                    'count' => count($pids), 'image' => $image($face($pids)), 'icon' => $label[1],
                ];
            }
            if (count($shelves) >= 2) {
                break;
            }
            $shelves = [];
        }

        // The pet the brand is for: one species holding 70% of it, else several.
        $species = '';
        $bySpecies = $members('species');
        if (!empty($bySpecies)) {
            uasort($bySpecies, static fn($a, $b) => count($b) <=> count($a));
            $top = (string) array_key_first($bySpecies);
            $species = count($bySpecies[$top]) >= 0.7 * count($ids) ? $top : (count($bySpecies) > 1 ? 'multi' : $top);
        }

        return [
            'lines'    => $lines,
            'shelves'  => $shelves,
            'value'    => self::value($ids, $rows, $meta, $lang),
            'in_stock' => $in_stock,
            'total'    => count($ids),
            'species'  => $species,
        ];
    }

    /** Label + sticker for the shelf facets the page may use. */
    private static function facet_label(string $facet, string $value, bool $en): ?array
    {
        $map = [
            'species' => ['cat' => ['قطط', 'Cats', 'cat_adult'], 'dog' => ['كلاب', 'Dogs', 'dog_adult'],
                          'bird' => ['طيور', 'Birds', 'budgie'], 'small' => ['حيوانات صغيرة', 'Small pets', 'hamster']],
            'form'    => ['wet' => ['رطب', 'Wet', 'pouch'], 'dry' => ['جاف', 'Dry', 'dry'],
                          'milk' => ['حليب', 'Milk', 'milk'], 'treat' => ['مكافآت', 'Treats', 'treat']],
            'need'    => ['grain_free' => ['خالٍ من الحبوب', 'Grain free', 'grain_free'], 'sterilised' => ['للمعقّمة', 'Sterilised', 'sterilised'],
                          'urinary' => ['المسالك البولية', 'Urinary care', 'urinary'], 'hairball' => ['كرات الشعر', 'Hairball', 'hairball'],
                          'weight' => ['التحكم بالوزن', 'Weight control', 'light'], 'digest' => ['هضم حساس', 'Sensitive digestion', 'digest'],
                          'hypo' => ['الحساسية', 'Hypoallergenic', 'hypo'], 'skin' => ['الجلد والفرو', 'Skin and coat', 'brush'],
                          'dental' => ['الأسنان', 'Dental', 'tooth'], 'indoor' => ['داخل المنزل', 'Indoor', 'indoor'],
                          'joints' => ['المفاصل', 'Joints', 'treat'], 'calm' => ['التهدئة', 'Calming', 'moon']],
        ];
        $row = $map[$facet][$value] ?? null;
        return $row ? [$en ? $row[1] : $row[0], $row[2]] : null;
    }

    /**
     * Where the bigger pack is honestly cheaper: within one line (or one food
     * type), the cheapest-per-unit in-stock pack against the smallest pack of
     * the same unit — per piece when both are multipacks of the same weight,
     * per kilo otherwise. Only savings of 12% or more are worth a band.
     */
    private static function value(array $ids, array $rows, array $meta, string $lang): ?array
    {
        $en = $lang === 'en';
        $express = class_exists('Zooboxi_Price_Book') && Zooboxi_Price_Book::is_express();
        $pkey = $express ? 'price_express' : 'price';

        global $wpdb;
        $titles = [];
        $list = implode(',', array_map('intval', $ids));
        foreach ($wpdb->get_results("SELECT ID, post_title FROM {$wpdb->posts} WHERE ID IN ({$list})", ARRAY_N) as [$pid, $title]) {
            $titles[(int) $pid] = (string) $title;
        }

        $packs = [];
        foreach ($ids as $pid) {
            if ((int) ($meta[$pid]['instock'] ?? 1) !== 1) {
                continue;
            }
            $price = (float) ($meta[$pid][$pkey] ?? 0);
            if ($price <= 0) {
                continue;
            }
            $pack = self::pack(Zooboxi_Facet_Index::norm($titles[$pid] ?? ''));
            if ($pack === null || $pack['grams'] < 20) {
                continue;
            }
            // A family is one line, one form, one animal: a parrot stick is
            // not the bigger pack of a cat snack, nor a pouch box of a broth.
            $lines = array_keys($rows[$pid]['line'] ?? []);
            $forms = array_keys($rows[$pid]['form'] ?? []);
            if (empty($lines) && empty($forms)) {
                continue;
            }
            $families = [];
            foreach ($lines ?: ['-'] as $line) {
                foreach ($forms ?: ['-'] as $form) {
                    foreach (array_keys($rows[$pid]['species'] ?? []) ?: ['-'] as $sp) {
                        $families[] = $line . '|' . $form . '|' . $sp;
                    }
                }
            }
            foreach ($families as $family) {
                $packs[$family][] = $pack + ['id' => $pid, 'price' => $price, 'per_kg' => $price / $pack['grams'] * 1000];
            }
        }

        $best = null;
        foreach ($packs as $family => $list) {
            if (count($list) < 2) {
                continue;
            }
            // Same-unit multipacks compare per piece; anything else per kilo.
            $byUnit = [];
            foreach ($list as $p) {
                if ($p['units'] > 1) {
                    $byUnit[(string) $p['unit_g']][] = $p;
                }
            }
            foreach ($byUnit as $same) {
                if (count($same) < 2) {
                    continue;
                }
                usort($same, static fn($a, $b) => ($a['price'] / $a['units']) <=> ($b['price'] / $b['units']));
                $cheap = $same[0];
                $small = $same[0];
                foreach ($same as $p) {
                    if ($p['units'] < $small['units']) {
                        $small = $p;
                    }
                }
                if ($small['id'] === $cheap['id'] || $cheap['units'] <= $small['units']) {
                    continue;
                }
                $a = $cheap['price'] / $cheap['units'];
                $b = $small['price'] / $small['units'];
                $saving = 1 - $a / $b;
                // Same tube, more of them: this beats any kilo comparison.
                if ($saving >= 0.12 && ($best === null || $best['mode'] === 'kg' || $saving > $best['saving'])) {
                    $best = ['mode' => 'unit', 'big' => $cheap, 'small' => $small, 'a' => $a, 'b' => $b, 'saving' => $saving];
                }
            }
            usort($list, static fn($x, $y) => $x['per_kg'] <=> $y['per_kg']);
            $cheap = $list[0];
            $small = $list[0];
            foreach ($list as $p) {
                if ($p['grams'] < $small['grams']) {
                    $small = $p;
                }
            }
            if ($small['id'] !== $cheap['id'] && $cheap['grams'] > $small['grams']) {
                $saving = 1 - $cheap['per_kg'] / $small['per_kg'];
                // Past 50% a kilo price is telling two products apart, not a bargain.
                if ($saving >= 0.12 && $saving <= 0.5 && ($best === null || ($best['mode'] === 'kg' && $saving > $best['saving']))) {
                    $best = ['mode' => 'kg', 'big' => $cheap, 'small' => $small, 'a' => $cheap['per_kg'], 'b' => $small['per_kg'], 'saving' => $saving];
                }
            }
        }
        if ($best === null) {
            return null;
        }

        $card = Zooboxi_Product_DTO::card((int) $best['big']['id']);
        if ($card === null) {
            return null;
        }
        $label = static function (array $p) use ($en): string {
            $g = rtrim(rtrim(number_format($p['unit_g'], 1, '.', ''), '0'), '.');
            $w = $p['unit_g'] >= 1000
                ? rtrim(rtrim(number_format($p['unit_g'] / 1000, 2, '.', ''), '0'), '.') . ($en ? ' kg' : ' كجم')
                : $g . ($en ? ' g' : ' جم');
            return $p['units'] > 1 ? $p['units'] . ' × ' . $w : $w;
        };

        return [
            'mode'    => $best['mode'],            // unit | kg
            'product' => $card,
            'big'     => ['label' => $label($best['big']), 'each' => round($best['a'], 2)],
            'small'   => ['label' => $label($best['small']), 'each' => round($best['b'], 2), 'id' => (int) $best['small']['id']],
            'saving'  => (int) round($best['saving'] * 100),
        ];
    }
}
