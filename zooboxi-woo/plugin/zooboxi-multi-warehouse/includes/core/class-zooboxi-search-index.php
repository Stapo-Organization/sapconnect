<?php
/**
 * Zooboxi_Search_Index — finds products the way shoppers type them.
 *
 * WordPress search only finds the exact Arabic letters of a product title, so
 * «applaws», «أبلوز» (for «أبلاوز») or «اكل قطط» (for «طعام قطط») found nothing.
 * This index holds, per published product, its Arabic title, English name,
 * brand (Arabic and English), categories, and every barcode / SAP code of the
 * product and its sizes — all normalised the same way (Zooboxi_Facet_Index::norm).
 *
 * A query matches when every word matches somewhere: as typed, without «ال»,
 * through a pet-shop synonym (اكل = طعام = food), or — only for a word nothing
 * matched exactly — by its consonant skeleton (أبلوز ≈ ابلاوز, aplaws ≈ applaws).
 *
 * Used by WordPress product searches (posts_search: the website search page and
 * the app's listing search) and by the suggest endpoint.
 */

defined('ABSPATH') || exit;

final class Zooboxi_Search_Index
{
    private const OPTION   = 'zooboxi_search_index_v1';
    private const LOCK     = 'zooboxi_search_index_lock';
    private const MAX_AGE  = 3 * HOUR_IN_SECONDS;

    /** Words shoppers use for one another (normalised forms). */
    private const SYNONYMS = [
        ['قطط', 'قطه', 'قط', 'cat', 'cats', 'kitten', 'kitty'],
        ['كلاب', 'كلب', 'جرو', 'جراء', 'dog', 'dogs', 'puppy'],
        ['طيور', 'طير', 'عصفور', 'عصافير', 'ببغاء', 'ببغاوات', 'bird', 'birds', 'parrot'],
        ['اكل', 'اكله', 'طعام', 'غذاء', 'اطعمه', 'وجبه', 'وجبات', 'food'],
        ['رمل', 'رمال', 'ليتر', 'litter'],
        ['طوق', 'اطواق', 'collar', 'collars'],
        ['لعبه', 'العاب', 'لعب', 'toy', 'toys'],
        ['سرير', 'اسره', 'فراش', 'bed', 'beds'],
        ['معلبات', 'معلب', 'علب', 'علبه', 'رطب', 'wet', 'can', 'cans', 'pouch', 'اظرف', 'ظرف'],
        ['جاف', 'ناشف', 'dry', 'kibble'],
        ['مكافات', 'مكافاه', 'سناك', 'treat', 'treats', 'snack', 'snacks'],
        ['شامبو', 'shampoo'],
        ['فيتامين', 'فيتامينات', 'مكمل', 'مكملات', 'vitamin', 'vitamins', 'supplement'],
        ['مشط', 'فرشاه', 'brush', 'comb'],
        ['قفص', 'اقفاص', 'cage'],
        ['مقود', 'رسن', 'leash', 'lead'],
        ['حمام', 'تواليت', 'toilet', 'tray'],
    ];

    private static ?array $rows = null;
    private static ?array $syn  = null;

    public static function hooks(): void
    {
        add_filter('posts_search', [__CLASS__, 'widen_wp_search'], 20, 2);
    }

    /* ── Normalising ─────────────────────────────────────────────── */

    public static function norm(string $s): string
    {
        $s = class_exists('Zooboxi_Facet_Index') ? Zooboxi_Facet_Index::norm($s) : mb_strtolower($s, 'UTF-8');
        $s = strtr($s, ['ؤ' => 'و', 'ئ' => 'ي', '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9']);
        $s = preg_replace('/[^\p{L}\p{N}]+/u', ' ', $s) ?? $s;
        return trim(preg_replace('/\s+/u', ' ', $s) ?? $s);
    }

    /** Consonants only, doubles folded: «ابلوز» and «ابلاوز» → «بلز», «aplaws» and «applaws» → «plws». */
    public static function skeleton(string $s): string
    {
        $s = preg_replace('/[اويىaeiou]/u', '', $s) ?? $s;
        return preg_replace('/(.)\1+/u', '$1', $s) ?? $s;
    }

    /** Query → words, each with the spellings that count as it. */
    private static function words(string $q): array
    {
        $out = [];
        foreach (explode(' ', self::norm($q)) as $w) {
            if ($w === '' || (mb_strlen($w) < 2 && !ctype_digit($w))) {
                continue;
            }
            $alts = [$w => true];
            foreach (['وال', 'بال', 'فال', 'كال', 'لل', 'ال'] as $pre) {
                if (mb_strlen($w) >= mb_strlen($pre) + 2 && mb_strpos($w, $pre) === 0) {
                    $alts[mb_substr($w, mb_strlen($pre))] = true;
                    break;
                }
            }
            foreach (array_keys($alts) as $a) {
                foreach (self::synonyms()[$a] ?? [] as $s) {
                    $alts[$s] = true;
                }
            }
            // array_map: PHP turns a barcode-looking key into an int.
            $out[] = ['w' => $w, 'alts' => array_map('strval', array_keys($alts)), 'skel' => self::skeleton($w)];
        }
        return $out;
    }

    private static function synonyms(): array
    {
        if (self::$syn === null) {
            self::$syn = [];
            foreach (self::SYNONYMS as $group) {
                foreach ($group as $w) {
                    self::$syn[$w] = $group;
                }
            }
        }
        return self::$syn;
    }

    /** Does [$alt] occur in [$text] as a word (short) or a word start / part (longer)? */
    private static function hit(string $text, string $alt): bool
    {
        $len = mb_strlen($alt);
        if ($len <= 2) {
            return strpos(' ' . $text . ' ', ' ' . $alt . ' ') !== false;
        }
        if ($len === 3) {
            return strpos(' ' . $text, ' ' . $alt) !== false;
        }
        return strpos($text, $alt) !== false;
    }

    /** [$alt] as a whole word of [$text], also behind «ال / لل / بال / وال / و / ب / ل». */
    private static function word(string $text, string $alt): bool
    {
        if ($text === '' || strpos($text, $alt) === false) {
            return false;
        }
        return (bool) preg_match('/(?:^|\s)(?:وال|بال|فال|لل|ال|و|ب|ل)?' . preg_quote($alt, '/') . '(?:\s|$)/u', $text);
    }

    /* ── Searching ───────────────────────────────────────────────── */

    /**
     * Published product ids matching [$q], best first.
     *
     * @return int[]
     */
    public static function search(string $q, int $limit = 300): array
    {
        $words = self::words($q);
        if (!$words) {
            return [];
        }
        $rows = self::rows();
        if (!$rows) {
            return [];
        }

        // Words nothing matches as spelled fall back to their skeleton.
        $fuzzy = [];
        foreach ($words as $i => $w) {
            $any = false;
            foreach ($rows as $r) {
                foreach ($w['alts'] as $a) {
                    if (self::hit($r['h'], $a)) {
                        $any = true;
                        break 2;
                    }
                }
            }
            $fuzzy[$i] = !$any && mb_strlen($w['skel']) >= 3;
        }

        $scored = [];
        $partial = [];
        foreach ($rows as $id => $r) {
            $total = 0.0;
            $matched = 0;
            foreach ($words as $i => $w) {
                $best = 0.0;
                $topic = false;
                foreach ($w['alts'] as $k => $a) {
                    $syn = $k > 0 ? 0.9 : 1.0;
                    if (!self::hit($r['h'], $a)) {
                        continue;
                    }
                    if (self::word($r['t'], $a)) {
                        $best = max($best, 4.0 * $syn);
                    } elseif (self::hit($r['t'], $a)) {
                        $best = max($best, 2.5 * $syn);
                    }
                    if (self::hit($r['b'], $a)) {
                        $best = max($best, 3.5 * $syn);
                    }
                    if (self::word($r['e'], $a)) {
                        $best = max($best, 3.0 * $syn);
                    } elseif (self::hit($r['e'], $a)) {
                        $best = max($best, 2.0 * $syn);
                    }
                    if (self::hit($r['c'], $a)) {
                        $best = max($best, 1.5 * $syn);
                        $topic = true;
                    }
                    if ($a === $w['w'] && strpos(' ' . $r['i'] . ' ', ' ' . $a) !== false) {
                        $best = max($best, 5.0);
                    }
                }
                // The word also names the product's department: «اكل قطط» is food first.
                if ($best > 0 && $topic) {
                    $best += 1.0;
                }
                // Spelling slips match only from a word's start: «ابلوز» → ابلاوز, not فروتابلز.
                if ($best === 0.0 && $fuzzy[$i] && strpos(' ' . $r['s'], ' ' . $w['skel']) !== false) {
                    $best = 1.0;
                }
                if ($best > 0) {
                    $matched++;
                    $total += $best;
                }
            }
            if ($matched === count($words)) {
                $scored[$id] = $total + min(1.0, max(0.0, (float) $r['r']) / 100);
            } elseif ($matched > 0 && count($words) > 2 && $matched >= count($words) - 1) {
                $partial[$id] = $total;
            }
        }
        // Every word or nothing — except a long query one word too specific.
        if (!$scored) {
            $scored = $partial;
        }
        arsort($scored);
        return array_slice(array_map('intval', array_keys($scored)), 0, $limit);
    }

    /**
     * WordPress product searches also accept what the index finds. Leaves wp-admin
     * searches alone; runs after the plugin's barcode/item-code injection.
     */
    public static function widen_wp_search($search, $query)
    {
        if (!is_string($search) || $search === '' || !($query instanceof \WP_Query)) {
            return $search;
        }
        if (is_admin() && !wp_doing_ajax()) {
            return $search;
        }
        $s  = (string) $query->get('s');
        $pt = $query->get('post_type');
        $is_product = $pt === 'product' || (is_array($pt) && in_array('product', $pt, true));
        if ($s === '' || !$is_product) {
            return $search;
        }
        try {
            $ids = self::search($s, 600);
        } catch (\Throwable $e) {
            return $search;
        }
        if (!$ids) {
            return $search;
        }
        global $wpdb;
        $in = implode(',', array_map('intval', $ids));
        return (string) (preg_replace('/^\s*AND\s*\(/', " AND ( {$wpdb->posts}.ID IN ({$in}) OR ", $search, 1) ?? $search);
    }

    /* ── The index ───────────────────────────────────────────────── */

    /** id → [t title, e english, b brand, c categories, i identifiers, h all, s skeleton, r rank]. */
    private static function rows(): array
    {
        if (self::$rows !== null) {
            return self::$rows;
        }
        $saved = get_option(self::OPTION);
        $fresh = is_array($saved) && isset($saved['built'], $saved['rows']) && (time() - (int) $saved['built']) < self::MAX_AGE;
        if (!$fresh) {
            $lock = (int) get_option(self::LOCK, 0);
            if ($lock < time() - 120 || !is_array($saved)) {
                update_option(self::LOCK, time(), false);
                $saved = ['built' => time(), 'rows' => self::build()];
                update_option(self::OPTION, $saved, false);
                delete_option(self::LOCK);
            }
        }
        return self::$rows = is_array($saved['rows'] ?? null) ? $saved['rows'] : [];
    }

    /** Throw the index away; the next search rebuilds it. */
    public static function forget(): void
    {
        delete_option(self::OPTION);
        self::$rows = null;
    }

    private static function build(): array
    {
        global $wpdb;
        $rows = [];
        foreach ($wpdb->get_results("SELECT ID, post_title FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status = 'publish'", ARRAY_N) as [$id, $title]) {
            $rows[(int) $id] = ['t' => self::norm((string) $title), 'e' => '', 'b' => '', 'c' => '', 'i' => '', 'r' => 0.0];
        }
        if (!$rows) {
            return [];
        }
        $meta = $wpdb->get_results(
            "SELECT m.post_id, m.meta_key, m.meta_value FROM {$wpdb->postmeta} m
               JOIN {$wpdb->posts} p ON p.ID = m.post_id AND p.post_type = 'product' AND p.post_status = 'publish'
              WHERE m.meta_key IN ('_zooboxi_name_en', '_sku', '_zooboxi_item_code', '_zb_rank_score')",
            ARRAY_N
        );
        foreach ($meta as [$id, $key, $val]) {
            $id = (int) $id;
            if (!isset($rows[$id]) || $val === null || $val === '') {
                continue;
            }
            if ($key === '_zooboxi_name_en') {
                $rows[$id]['e'] .= ' ' . self::norm((string) $val);
            } elseif ($key === '_zb_rank_score') {
                $rows[$id]['r'] = (float) $val;
            } else {
                $rows[$id]['i'] .= ' ' . self::norm((string) $val);
            }
        }
        // A size's own barcode finds its product.
        $vars = $wpdb->get_results(
            "SELECT p.post_parent, m.meta_value FROM {$wpdb->posts} p
               JOIN {$wpdb->postmeta} m ON m.post_id = p.ID AND m.meta_key IN ('_sku', '_zooboxi_item_code')
              WHERE p.post_type = 'product_variation' AND p.post_status = 'publish' AND m.meta_value <> ''",
            ARRAY_N
        );
        foreach ($vars as [$parent, $val]) {
            $parent = (int) $parent;
            if (isset($rows[$parent])) {
                $rows[$parent]['i'] .= ' ' . self::norm((string) $val);
            }
        }
        $terms = $wpdb->get_results(
            "SELECT tr.object_id, tt.taxonomy, t.name FROM {$wpdb->term_relationships} tr
               JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id = tr.term_taxonomy_id
                    AND tt.taxonomy IN ('product_brand', 'pa_brand', 'product_cat')
               JOIN {$wpdb->terms} t ON t.term_id = tt.term_id
               JOIN {$wpdb->posts} p ON p.ID = tr.object_id AND p.post_type = 'product' AND p.post_status = 'publish'",
            ARRAY_N
        );
        foreach ($terms as [$id, $tax, $name]) {
            $id = (int) $id;
            if (!isset($rows[$id])) {
                continue;
            }
            $rows[$id][$tax === 'product_cat' ? 'c' : 'b'] .= ' ' . self::norm((string) $name);
        }
        foreach ($rows as $id => $r) {
            foreach (['e', 'b', 'c', 'i'] as $k) {
                $rows[$id][$k] = trim($r[$k]);
            }
            $all = trim($r['t'] . ' ' . $rows[$id]['e'] . ' ' . $rows[$id]['b'] . ' ' . $rows[$id]['c'] . ' ' . $rows[$id]['i']);
            $rows[$id]['h'] = $all;
            $rows[$id]['s'] = self::skeleton($r['t'] . ' ' . $rows[$id]['e'] . ' ' . $rows[$id]['b']);
        }
        return $rows;
    }
}
