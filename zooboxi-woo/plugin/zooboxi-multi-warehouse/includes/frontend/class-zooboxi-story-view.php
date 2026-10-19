<?php
/**
 * «قصة المنتج» on the web product page — the owner's pick «الألواح، ملوّن جريء»
 * (design canvas 2026-09-23).
 *
 *   beside the price   highlight chips + a key-facts strip
 *   under the summary  coloured tiles (one per section, each showing its best
 *                      number) and, below them, every section in full as a
 *                      <details> panel — all of it in the HTML, so search
 *                      engines read what a shopper can open.
 *
 * The WooCommerce «الوصف» and «معلومات إضافية» tabs step aside only for
 * products whose description parsed; the rest keep the stock tabs.
 */

defined('ABSPATH') || exit;

class Zooboxi_Story_View
{
    /** Section palette (bold): [tile fill, tile ink, soft tint, deep ink]. */
    private const HUE = [
        'feeding'     => ['#1F5C5B', '#FFFFFF', '#DCEFEE', '#1F5C5B'],
        'ingredients' => ['#FFFFFF', '#1E2A24', '#FDF0EC', '#9A3A2B'],
        'analysis'    => ['#8A6A00', '#FFFFFF', '#FFF4DB', '#6B4E00'],
        'breeds'      => ['#5B4BC0', '#FFFFFF', '#EEEAFB', '#4B3DA8'],
        'usage'       => ['#00796F', '#FFFFFF', '#DDF1EE', '#005A52'],
        'safety'      => ['#1E5E96', '#FFFFFF', '#E3F0FA', '#1E4E79'],
        'storage'     => ['#1E5E96', '#FFFFFF', '#E3F0FA', '#1E4E79'],
        'overview'    => ['#C8473A', '#FFFFFF', '#FDEEE9', '#9A3A2B'],
        'features'    => ['#FFFFFF', '#1E2A24', '#E3F3F1', '#1F5C5B'],
        'specs'       => ['#FFFFFF', '#1E2A24', '#F1F4F3', '#3F4E47'],
        'contents'    => ['#FFFFFF', '#1E2A24', '#F1F4F3', '#3F4E47'],
        'other'       => ['#FFFFFF', '#1E2A24', '#F1F4F3', '#3F4E47'],
    ];

    /** Chip colours for the highlights, in order. */
    private const CHIPS = [['#1F7A74', '#FFFFFF'], ['#C8473A', '#FFFFFF'], ['#8A6A00', '#FFFFFF'], ['#5B4BC0', '#FFFFFF'],
                           ['#00796F', '#FFFFFF'], ['#1E5E96', '#FFFFFF']];

    /** Donut slices: validated categorical order (dataviz check, light surface). */
    private const SLICES = ['#C8473A', '#B08A00', '#00968C', '#9AA7A1'];

    private const TITLES = [
        'overview'    => 'عن المنتج',
        'features'    => 'المميزات',
        'feeding'     => 'كم أقدّم؟',
        'ingredients' => 'مما يتكوّن؟',
        'analysis'    => 'التحليل الغذائي',
        'specs'       => 'المواصفات',
        'contents'    => 'محتويات العبوة',
        'breeds'      => 'السلالات المناسبة',
        'usage'       => 'طريقة الاستخدام',
        'storage'     => 'التخزين',
        'safety'      => 'تنبيهات السلامة',
    ];

    private const ICON = [
        'overview' => 'info', 'features' => 'sparkle', 'feeding' => 'bowl', 'ingredients' => 'leaf',
        'analysis' => 'chart', 'specs' => 'ruler', 'contents' => 'box', 'breeds' => 'paw', 'usage' => 'steps',
        'storage' => 'snow', 'safety' => 'shield', 'other' => 'info',
        'weight' => 'scale', 'size' => 'scale', 'dimensions' => 'ruler', 'material' => 'box', 'form' => 'box',
        'color' => 'drop', 'species' => 'paw', 'origin' => 'pin', 'protein' => 'chart',
    ];

    private const PATHS = [
        'info'    => '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>',
        'sparkle' => '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
        'bowl'    => '<path d="M3 11h18a9 9 0 0 1-18 0zM8 7c0-1 1-1 1-2M12 7c0-1 1-1 1-2M16 7c0-1 1-1 1-2"/>',
        'leaf'    => '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14zM5 19l7-7"/>',
        'chart'   => '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
        'ruler'   => '<path d="M3 17L17 3l4 4L7 21z"/><path d="M7 13l2 2M10 10l2 2M13 7l2 2"/>',
        'box'     => '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M12 12l8-4.5M12 12v9M12 12L4 7.5"/>',
        'paw'     => '<circle cx="7" cy="9" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><circle cx="17" cy="9" r="1.8"/><path d="M7.5 17c0-3 2-5.5 4.5-5.5s4.5 2.5 4.5 5.5c0 1.6-1.4 2.5-2.8 2.1-1.2-.4-2.2-.4-3.4 0C8.9 19.5 7.5 18.6 7.5 17z"/>',
        'steps'   => '<path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/>',
        'snow'    => '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/>',
        'shield'  => '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M12 8v5M12 16h.01"/>',
        'scale'   => '<path d="M5 7h14l-2 12H7zM9 7a3 3 0 0 1 6 0"/>',
        'drop'    => '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
        'pin'     => '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
        'check'   => '<path d="M5 12l4 4 10-10"/>',
        'down'    => '<path d="M6 9l6 6 6-6"/>',
    ];

    private static ?array $story = null;
    private static int $storyFor = 0;

    public static function hooks(): void
    {
        if (is_admin() && ! wp_doing_ajax()) {
            return;
        }
        add_action('wp_enqueue_scripts', [self::class, 'enqueue'], 30);
        add_action('woocommerce_single_product_summary', [self::class, 'summary_block'], 21);
        add_action('woocommerce_after_single_product_summary', [self::class, 'details_block'], 5);
        add_filter('woocommerce_product_tabs', [self::class, 'tabs'], 50);
        add_filter('woocommerce_structured_data_product', [self::class, 'structured_data'], 20, 2);
    }

    private static function story(): ?array
    {
        global $product;
        $p = $product instanceof WC_Product ? $product : (is_product() ? wc_get_product(get_queried_object_id()) : null);
        if (! $p instanceof WC_Product) {
            return null;
        }
        if (self::$storyFor !== $p->get_id()) {
            self::$storyFor = $p->get_id();
            self::$story = Zooboxi_Product_Story::get($p, 'ar');
            // A story with nothing but an overview adds no structure: keep the stock page.
            if (self::$story && count(self::$story['sections']) < 2) {
                self::$story = null;
            }
        }
        return self::$story;
    }

    public static function enqueue(): void
    {
        if (! is_product() || ! self::story()) {
            return;
        }
        $css = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/css/zooboxi-story.css') ?: ZOOBOXI_VERSION;
        $js  = @filemtime(ZOOBOXI_PLUGIN_DIR . 'public/js/zooboxi-story.js') ?: ZOOBOXI_VERSION;
        wp_enqueue_style('zooboxi-story', ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-story.css', [], $css);
        wp_enqueue_script('zooboxi-story', ZOOBOXI_PLUGIN_URL . 'public/js/zooboxi-story.js', [], $js, true);
    }

    public static function tabs(array $tabs): array
    {
        if (self::story()) {
            unset($tabs['description'], $tabs['additional_information']);
        }
        return $tabs;
    }

    /* ══════════════════════════════════════════════════════════════
       BESIDE THE PRICE
       ══════════════════════════════════════════════════════════════ */

    public static function summary_block(): void
    {
        $s = self::story();
        if (! $s) {
            return;
        }
        echo '<div class="zbs-top" dir="rtl">';
        if ($s['highlights']) {
            echo '<ul class="zbs-chips" aria-label="أبرز المزايا">';
            foreach (array_slice($s['highlights'], 0, 4) as $i => $h) {
                [$bg, $fg] = self::CHIPS[$i % count(self::CHIPS)];
                printf('<li style="background:%s;color:%s" title="%s">%s%s</li>', $bg, $fg, esc_attr($h['text']),
                    self::icon('check', $fg, 15), esc_html($h['title']));
            }
            echo '</ul>';
        }
        if (count($s['facts']) >= 2) {
            echo '<dl class="zbs-facts">';
            $tints = [['#E3F3F1', '#1F7A74'], ['#FCE9E3', '#C8473A'], ['#FFF1D6', '#8A6A00'], ['#ECE8FB', '#5B4BC0']];
            foreach ($s['facts'] as $i => $f) {
                [$bg, $fg] = $tints[$i % 4];
                printf('<div><span class="zbs-fi" style="background:%s">%s</span><dt>%s</dt><dd>%s</dd></div>', $bg,
                    self::icon(self::ICON[$f['kind']] ?? 'info', $fg, 18), esc_html($f['label']), esc_html($f['value']));
            }
            echo '</dl>';
        }
        echo '<a class="zbs-jump" href="#zbs">كل التفاصيل' . self::icon('down', 'currentColor', 16) . '</a>';
        echo '</div>';
    }

    /* ══════════════════════════════════════════════════════════════
       UNDER THE SUMMARY
       ══════════════════════════════════════════════════════════════ */

    public static function details_block(): void
    {
        $s = self::story();
        if (! $s) {
            return;
        }
        $carton = self::carton_units();

        echo '<section id="zbs" class="zbs" dir="rtl" aria-labelledby="zbs-h">';
        echo '<h2 id="zbs-h" class="zbs-h">تفاصيل المنتج</h2>';

        // ── tiles ───────────────────────────────────────────
        // Tiles lead with what decides a purchase; «عن المنتج» closes the grid.
        $rank = array_flip(['feeding', 'ingredients', 'analysis', 'breeds', 'usage', 'specs', 'safety', 'storage', 'overview']);
        $secs = $s['sections'];
        usort($secs, static fn ($a, $b) => ($rank[$a['key']] ?? 99) <=> ($rank[$b['key']] ?? 99));
        $tiles = [];
        foreach ($secs as $sec) {
            $tile = self::tile($sec, $s, $carton);
            if ($tile !== '') {
                $tiles[] = $tile; // built from escaped parts
            }
        }
        // Two columns on a phone: an odd small tile out stretches across the row.
        $small = array_keys(array_filter($tiles, static fn ($t) => strpos($t, ' is-wide') === false));
        if (count($small) % 2 === 1) {
            $last = end($small);
            $tiles[$last] = preg_replace('/class="zbs-tile/', 'class="zbs-tile is-wide-m', $tiles[$last], 1);
        }
        // Four columns on a wide screen: no holes — a tile that ends a short row
        // widens to close it.
        $spans = [];
        $col = 0;
        foreach ($tiles as $i => $t) {
            $w = strpos($t, ' is-wide"') !== false || strpos($t, ' is-wide ') !== false ? 2 : 1;
            if ($col + $w > 4 && $i > 0) {
                $spans[$i - 1] += 4 - $col;
                $col = 0;
            }
            $spans[$i] = $w;
            $col = ($col + $w) % 4;
        }
        if ($col > 0 && $spans) {
            $spans[array_key_last($spans)] += 4 - $col;
        }
        foreach ($tiles as $i => $t) {
            $tiles[$i] = preg_replace('/ style="/', ' style="--d:' . min(4, $spans[$i]) . ';', $t, 1);
        }
        echo '<div class="zbs-tiles">' . implode('', $tiles) . '</div>';

        // ── full sections ───────────────────────────────────
        echo '<div class="zbs-secs">';
        foreach ($s['sections'] as $n => $sec) {
            echo self::section($sec, $s, $carton, $n);
        }
        echo '</div>';
        echo '</section>';
    }

    private static function title(array $sec): string
    {
        return self::TITLES[$sec['key']] ?? ($sec['title'] !== '' ? $sec['title'] : 'تفاصيل');
    }

    private static function tile(array $sec, array $s, int $carton): string
    {
        $key = $sec['key'];
        if (in_array($key, ['features', 'other', 'contents'], true)) {
            return ''; // features already sit beside the price
        }
        [$bg, $fg, $tint, $deep] = self::HUE[$key] ?? self::HUE['other'];
        $dark = $fg === '#FFFFFF';
        $wide = false;
        $body = '';

        switch ($key) {
            case 'feeding':
                $f = $s['feeding'];
                if ($f) {
                    $row = $f['rows'][min(1, count($f['rows']) - 1)];
                    $wide = true;
                    $body = '<span class="zbs-k">' . esc_html(self::weight_label($row)) . '</span>'
                        . '<strong class="zbs-big">' . esc_html($row['cells'][0] ?? '') . '</strong>'
                        . self::lasts_line($row, $f, $carton, true)
                        . '<span class="zbs-cta">احسب لحيوانك</span>';
                } else {
                    $body = '<span class="zbs-sub">' . esc_html(self::teaser($sec)) . '</span>';
                }
                break;
            case 'ingredients':
                $c = $s['composition'];
                if ($c && $c['slices']) {
                    $wide = true;
                    $body = '<div class="zbs-donut-row">' . self::donut($c, 118) . self::legend($c) . '</div>';
                } else {
                    $names = array_slice(array_column($c['items'] ?? [], 'name'), 0, 3);
                    $body = $names
                        ? '<span class="zbs-sub">' . esc_html(implode(' · ', $names)) . '</span>'
                        : '<span class="zbs-sub">' . esc_html(self::teaser($sec)) . '</span>';
                }
                break;
            case 'analysis':
                $bars = self::analysis_rows($sec);
                if (! $bars) {
                    return '';
                }
                $body = self::bars(array_slice($bars, 0, 3), $dark ? 'rgba(255,255,255,.22)' : '#FFE3A3', $dark ? '#FFD27A' : '#B07A00', true);
                break;
            case 'breeds':
                $names = [];
                foreach (self::items($sec) as $it) {
                    if (! empty($it['title'])) {
                        $names[] = $it['title'];
                    }
                }
                if (! $names) {
                    return '';
                }
                $body = '<div class="zbs-pills">';
                foreach (array_slice($names, 0, 5) as $nm) {
                    $body .= '<span>' . esc_html($nm) . '</span>';
                }
                $body .= '</div>';
                break;
            case 'usage':
            case 'safety':
            case 'storage':
                $count = max(count(self::items($sec)), 1);
                $noun = $key === 'usage' ? ($count > 2 ? 'خطوات' : 'خطوة') : ($key === 'safety' ? ($count > 2 ? 'تنبيهات' : 'تنبيه') : 'نصائح');
                $first = self::items($sec)[0]['text'] ?? self::teaser($sec);
                $body = '<strong class="zbs-big"><b class="zbs-num">' . $count . '</b> ' . $noun . '</strong>'
                    . '<span class="zbs-sub">' . esc_html(self::clip($first, 60)) . '</span>';
                break;
            case 'specs':
                $rows = self::table_rows($sec);
                if (! $rows) {
                    return '';
                }
                $body = '<ul class="zbs-mini">';
                foreach (array_slice($rows, 0, 3) as $r) {
                    $body .= '<li><span>' . esc_html($r[0]) . '</span><b>' . esc_html(Zooboxi_Product_Story::short_value($r[1] ?? '')) . '</b></li>';
                }
                $body .= '</ul>';
                break;
            case 'overview':
                $wide = true;
                $body = '<p>' . esc_html(self::clip(self::teaser($sec, 400), 170)) . '</p><span class="zbs-cta">اقرأ الوصف كاملًا</span>';
                break;
            default:
                return '';
        }

        return sprintf(
            '<a class="zbs-tile%s%s" href="#zbs-%s" style="--bg:%s;--fg:%s;--tint:%s">'
            . '<span class="zbs-th"><span class="zbs-ti">%s</span><span>%s</span>%s</span>%s</a>',
            $wide ? ' is-wide' : '', $dark ? ' is-dark' : '', esc_attr($key), $bg, $fg, $dark ? 'rgba(255,255,255,.16)' : $tint,
            self::icon(self::ICON[$key] ?? 'info', $dark ? $fg : $deep, 16), esc_html(self::title($sec)),
            self::icon('down', $dark ? 'rgba(255,255,255,.8)' : '#56665E', 16), $body
        );
    }

    private static function section(array $sec, array $s, int $carton, int $n): string
    {
        $key = $sec['key'];
        [, , $tint, $deep] = self::HUE[$key] ?? self::HUE['other'];
        $id  = 'zbs-' . ($key === 'other' ? 'other-' . $n : $key);
        $out = sprintf('<details class="zbs-sec zbs-%s" id="%s" open style="--tint:%s;--deep:%s"><summary>'
            . '<span class="zbs-si">%s</span><span class="zbs-st"><b>%s</b><small>%s</small></span>%s</summary><div class="zbs-body">',
            esc_attr($key), esc_attr($id), $tint, $deep, self::icon(self::ICON[$key] ?? 'info', $deep, 20),
            esc_html(self::title($sec)), esc_html(self::teaser_line($sec, $s)), self::icon('down', '#56665E', 20));

        switch ($key) {
            case 'feeding':
                $out .= self::feeding_body($sec, $s, $carton);
                break;
            case 'ingredients':
                $out .= self::ingredients_body($sec, $s);
                break;
            case 'analysis':
                $bars = self::analysis_rows($sec);
                $out .= $bars ? '<div class="zbs-card">' . self::bars($bars, '#FFE3A3', '#B07A00', false) . '</div>' : '';
                $out .= self::blocks($sec, $bars ? ['table'] : []);
                break;
            case 'features':
                $out .= '<div class="zbs-feats">';
                foreach (self::items($sec) as $i => $it) {
                    [$bg] = self::CHIPS[$i % count(self::CHIPS)];
                    $out .= sprintf('<div class="zbs-feat"><span class="zbs-fdot" style="background:%s">%s</span><div><b>%s</b><p>%s</p></div></div>',
                        $bg, self::icon('check', '#FFFFFF', 14), esc_html($it['title'] ?? ''), esc_html($it['text'] ?? ''));
                }
                $out .= '</div>' . self::blocks($sec, ['list']);
                break;
            case 'breeds':
                $out .= '<div class="zbs-breeds">';
                foreach (self::items($sec) as $it) {
                    $out .= '<div class="zbs-breed">' . (! empty($it['title']) ? '<b>' . esc_html($it['title']) . '</b>' : '')
                        . '<p>' . esc_html($it['text'] ?? '') . '</p></div>';
                }
                $out .= '</div>' . self::blocks($sec, ['list']);
                break;
            case 'usage':
                $out .= '<ol class="zbs-steps">';
                foreach (self::items($sec) as $it) {
                    $out .= '<li>' . (! empty($it['title']) ? '<b>' . esc_html($it['title']) . ':</b> ' : '') . esc_html($it['text'] ?? '') . '</li>';
                }
                $out .= '</ol>' . self::blocks($sec, ['list']);
                break;
            case 'safety':
            case 'storage':
                $out .= '<ul class="zbs-warn">';
                foreach (self::items($sec) as $it) {
                    $out .= '<li>' . self::icon($key === 'safety' ? 'shield' : 'snow', $deep, 18) . '<span>'
                        . (! empty($it['title']) ? '<b>' . esc_html($it['title']) . ':</b> ' : '') . esc_html($it['text'] ?? '') . '</span></li>';
                }
                $out .= '</ul>' . self::blocks($sec, ['list']);
                break;
            case 'specs':
                $out .= '<dl class="zbs-spec">';
                foreach (self::table_rows($sec) as $r) {
                    $out .= '<div><dt>' . esc_html($r[0]) . '</dt><dd>' . esc_html(implode(' · ', array_slice($r, 1))) . '</dd></div>';
                }
                $out .= '</dl>' . self::blocks($sec, ['table']);
                break;
            default:
                $out .= self::blocks($sec, []);
        }

        return $out . '</div></details>';
    }

    /* ── section bodies ──────────────────────────────────── */

    private static function feeding_body(array $sec, array $s, int $carton): string
    {
        $f = $s['feeding'];
        if (! $f) {
            return self::blocks($sec, []);
        }
        $pick = min(1, count($f['rows']) - 1);
        $out = '<div class="zbs-calc" data-zbs-calc>';
        $out .= '<div class="zbs-calc-q">' . esc_html($f['headers'][0] ?? 'الوزن') . '</div><div class="zbs-calc-w" role="group">';
        foreach ($f['rows'] as $i => $r) {
            $out .= sprintf('<button type="button" data-i="%d" aria-pressed="%s">%s</button>', $i, $i === $pick ? 'true' : 'false', esc_html($r['label']));
        }
        $out .= '</div>';
        foreach ($f['rows'] as $i => $r) {
            $out .= sprintf('<div class="zbs-calc-r" data-i="%d"%s>', $i, $i === $pick ? '' : ' hidden');
            foreach ($r['cells'] as $c => $cell) {
                $label = $f['headers'][$c + 1] ?? '';
                $out .= $c === 0
                    ? '<span class="zbs-k">' . esc_html($label ?: 'الكمية اليومية') . '</span><strong class="zbs-big">' . esc_html($cell) . '</strong>'
                    : '<span class="zbs-alt">' . ($label !== '' ? esc_html($label) . ': ' : '') . esc_html($cell) . '</span>';
            }
            $out .= self::lasts_line($r, $f, $carton, false) . '</div>';
        }
        $out .= '</div>';

        // The full table stays for anyone who wants to read across rows.
        $out .= '<div class="zbs-table"><table><thead><tr>';
        foreach ($f['headers'] as $h) {
            $out .= '<th>' . esc_html($h) . '</th>';
        }
        $out .= '</tr></thead><tbody>';
        foreach ($f['rows'] as $r) {
            $out .= '<tr><td>' . esc_html($r['label']) . '</td>';
            foreach ($r['cells'] as $cell) {
                $out .= '<td>' . esc_html($cell) . '</td>';
            }
            $out .= '</tr>';
        }
        $out .= '</tbody></table></div>';
        $rest = self::blocks($sec, ['table']);
        if ($rest === '') {
            $out .= '<p class="zbs-note">الكميات إرشادية من الشركة المصنّعة — عدّلها حسب نشاط حيوانك ووزنه.</p>';
        }
        return $out . $rest;
    }

    private static function ingredients_body(array $sec, array $s): string
    {
        $c = $s['composition'];
        $out = '';
        if ($c && $c['slices']) {
            $out .= '<div class="zbs-donut-row zbs-card is-tint">' . self::donut($c, 160) . self::legend($c) . '</div>';
        }
        if ($c && $c['items']) {
            $out .= '<ol class="zbs-ingr">';
            foreach ($c['items'] as $i => $it) {
                $out .= sprintf('<li class="%s"><span class="zbs-n">%d</span><span class="zbs-in"><b>%s</b>%s</span>%s</li>',
                    $i < 2 ? 'is-top' : '', $i + 1, esc_html($it['name']),
                    $it['detail'] !== '' ? '<small>' . esc_html($it['detail']) . '</small>' : '',
                    $it['pct'] !== null ? '<span class="zbs-pct">' . esc_html(self::num($it['pct'])) . '%</span>' : '');
            }
            $out .= '</ol>';
            return $out . self::blocks($sec, ['p', 'list']);
        }
        return $out . self::blocks($sec, []);
    }

    /** Generic renderer for whatever a section holds, minus the block types already drawn. */
    private static function blocks(array $sec, array $skip): string
    {
        $out = '';
        foreach ($sec['blocks'] as $b) {
            if (in_array($b['type'], $skip, true)) {
                continue;
            }
            if ($b['type'] === 'p') {
                $out .= '<p class="zbs-p">' . esc_html($b['text']) . '</p>';
            } elseif ($b['type'] === 'list') {
                if (! empty($b['lead'])) {
                    $out .= '<p class="zbs-p">' . esc_html($b['lead']) . '</p>';
                }
                $tag = $b['ordered'] ? 'ol' : 'ul';
                $out .= '<' . $tag . ' class="zbs-list">';
                foreach ($b['items'] as $it) {
                    $out .= '<li>' . (! empty($it['title']) ? '<b>' . esc_html($it['title']) . ':</b> ' : '') . esc_html($it['text'] ?? '') . '</li>';
                }
                $out .= '</' . $tag . '>';
            } elseif ($b['type'] === 'table') {
                $out .= '<div class="zbs-table"><table>';
                if ($b['headers']) {
                    $out .= '<thead><tr>';
                    foreach ($b['headers'] as $h) {
                        $out .= '<th>' . esc_html($h) . '</th>';
                    }
                    $out .= '</tr></thead>';
                }
                $out .= '<tbody>';
                foreach ($b['rows'] as $r) {
                    $out .= '<tr>';
                    foreach ($r as $cell) {
                        $out .= '<td>' . esc_html($cell) . '</td>';
                    }
                    $out .= '</tr>';
                }
                $out .= '</tbody></table></div>';
            }
        }
        return $out;
    }

    /* ── charts ──────────────────────────────────────────── */

    private static function donut(array $c, int $size): string
    {
        $acc = 0.0;
        $arcs = '';
        foreach ($c['slices'] as $i => $sl) {
            $col = ! empty($sl['rest']) ? self::SLICES[3] : self::SLICES[min($i, 2)];
            $len = max(0.4, (float) $sl['pct'] - 1.2); // 1.2-unit surface gap between segments
            $arcs .= sprintf('<circle cx="21" cy="21" r="15.9155" fill="none" stroke="%s" stroke-width="6.5" stroke-dasharray="%s %s" stroke-dashoffset="%s"><title>%s %s%%</title></circle>',
                $col, self::num($len), self::num(100 - $len), self::num(25 - $acc), esc_html($sl['name']), esc_html(self::num($sl['pct'])));
            $acc += (float) $sl['pct'];
        }
        $center = $c['center'] ?? null;
        $mid = $center ? sprintf('<text x="21" y="21" text-anchor="middle" class="zbs-dv">%s</text><text x="21" y="27" text-anchor="middle" class="zbs-dl">%s</text>',
            esc_html($center['value']), esc_html(self::clip($center['label'], 16))) : '';
        $aria = implode('، ', array_map(static fn ($sl) => $sl['name'] . ' ' . self::num($sl['pct']) . '%', $c['slices']));

        return sprintf('<svg class="zbs-donut" viewBox="0 0 42 42" width="%1$d" height="%1$d" role="img" aria-label="%2$s">%3$s%4$s</svg>',
            $size, esc_attr('تركيبة الوصفة: ' . $aria), $arcs, $mid);
    }

    private static function legend(array $c): string
    {
        $out = '<ul class="zbs-legend">';
        foreach ($c['slices'] as $i => $sl) {
            $col = ! empty($sl['rest']) ? self::SLICES[3] : self::SLICES[min($i, 2)];
            $out .= sprintf('<li><i style="background:%s"></i><span>%s</span><b>%s%%</b></li>', $col, esc_html($sl['name']), esc_html(self::num($sl['pct'])));
        }
        return $out . '</ul>';
    }

    /** [[label, pct], …] from the analysis table rows that carry a percentage. */
    private static function analysis_rows(array $sec): array
    {
        $out = [];
        foreach (self::table_rows($sec) as $r) {
            if (count($r) >= 2 && preg_match('/(\d+(?:[.,]\d+)?)\s*%/u', $r[1], $m)) {
                $out[] = [$r[0], (float) str_replace(',', '.', $m[1])];
            }
        }
        return $out;
    }

    private static function bars(array $rows, string $track, string $fill, bool $compact): string
    {
        // Moisture is most of a wet food: scale bars to the largest nutrient, show moisture as a line.
        $moist = null;
        $rows = array_values(array_filter($rows, static function ($r) use (&$moist) {
            if (preg_match('/رطوبة|moisture/iu', $r[0])) {
                $moist = $r;
                return false;
            }
            return true;
        }));
        $max = max(array_merge([1], array_column($rows, 1)));
        $out = '<div class="zbs-bars' . ($compact ? ' is-compact' : '') . '">';
        foreach ($rows as [$label, $v]) {
            $out .= sprintf('<div class="zbs-bar"><span>%s</span><b>%s%%</b><i style="background:%s"><em style="width:%s%%;background:%s"></em></i></div>',
                esc_html(self::clip(preg_replace('/\s*(الخام|الخامة|crude)\s*/iu', ' ', $label), 22)), esc_html(self::num($v)),
                $track, max(4, round($v / $max * 100)), $fill);
        }
        if ($moist) {
            $out .= '<div class="zbs-moist">' . esc_html($moist[0]) . ' <bdi><b>' . esc_html(self::num($moist[1])) . '%</b></bdi></div>';
        }
        return $out . '</div>';
    }

    /* ── feeding helpers ─────────────────────────────────── */

    private static function weight_label(array $row): string
    {
        return $row['label'];
    }

    /** «الكرتون يكفيه نحو 6 أيام» / «العبوة تكفيه نحو 25 يومًا» — only from real numbers. */
    private static function lasts_line(array $row, array $f, int $carton, bool $short): string
    {
        $daily = $row['daily'] ?? null;
        if (! $daily || $daily <= 0) {
            return '';
        }
        $days = null;
        $what = '';
        if ($row['unit'] === 'piece' && $carton > 1) {
            $days = $carton / $daily;
            $what = sprintf('الكرتون (%d حبة)', $carton);
        } elseif ($row['unit'] === 'g' && ! empty($f['pack_grams']) && $f['pack_grams'] > $daily * 2) {
            $days = $f['pack_grams'] / $daily;
            $what = 'العبوة';
        }
        if (! $days || $days < 2) {
            return '';
        }
        $d = (int) round($days);
        $unit = $d >= 3 && $d <= 10 ? 'أيام' : 'يومًا';
        return sprintf('<span class="zbs-lasts">%s يكفيه نحو <b>%d</b> %s</span>', esc_html($short ? str_replace(sprintf(' (%d حبة)', $carton), '', $what) : $what), $d, $unit);
    }

    /** Pieces in the largest pack variation (the carton), or 0. */
    private static function carton_units(): int
    {
        global $product;
        if (! $product instanceof WC_Product || ! $product->is_type('variable') || ! class_exists('Zooboxi_Units')) {
            return 0;
        }
        $max = 0;
        foreach ($product->get_children() as $vid) {
            $max = max($max, (int) Zooboxi_Units::for_id((int) $vid));
        }
        return $max > 1 ? $max : 0;
    }

    /* ── text helpers ────────────────────────────────────── */

    private static function items(array $sec): array
    {
        $out = [];
        foreach ($sec['blocks'] as $b) {
            if ($b['type'] === 'list') {
                array_push($out, ...$b['items']);
            }
        }
        return $out;
    }

    private static function table_rows(array $sec): array
    {
        $out = [];
        foreach ($sec['blocks'] as $b) {
            if ($b['type'] === 'table') {
                array_push($out, ...$b['rows']);
            }
        }
        return $out;
    }

    private static function teaser(array $sec, int $len = 90): string
    {
        foreach ($sec['blocks'] as $b) {
            if ($b['type'] === 'p') {
                return self::clip($b['text'], $len);
            }
            if ($b['type'] === 'list' && $b['items']) {
                return self::clip(implode(' · ', array_map(static fn ($i) => $i['title'] ?? $i['text'], array_slice($b['items'], 0, 4))), $len);
            }
            if ($b['type'] === 'table' && $b['rows']) {
                return self::clip(implode(' · ', array_map(static fn ($r) => implode(' ', array_slice($r, 0, 2)), array_slice($b['rows'], 0, 3))), $len);
            }
        }
        return '';
    }

    /** The grey line under each section title: what is inside, before opening it. */
    private static function teaser_line(array $sec, array $s): string
    {
        switch ($sec['key']) {
            case 'ingredients':
                $c = $s['composition'];
                if ($c && $c['items']) {
                    $parts = array_map(static fn ($i) => $i['name'] . ($i['pct'] !== null ? ' ' . self::pct($i['pct']) : ''), array_slice($c['items'], 0, 3));
                    $more = count($c['items']) - 3;
                    return implode(' · ', $parts) . ($more > 0 ? ' · +' . $more : '');
                }
                break;
            case 'analysis':
                $rows = self::analysis_rows($sec);
                if ($rows) {
                    return implode(' · ', array_map(static fn ($r) => preg_replace('/\s*(الخام|crude)\s*/iu', '', $r[0]) . ' ' . self::pct($r[1]), array_slice($rows, 0, 3)));
                }
                break;
            case 'feeding':
                if ($s['feeding']) {
                    return 'حسب الوزن — ' . count($s['feeding']['rows']) . ' فئات';
                }
                break;
            case 'usage':
                return count(self::items($sec)) . ' خطوات';
        }
        return self::teaser($sec, 80);
    }

    private static function clip(string $t, int $len): string
    {
        $t = trim($t);
        if (mb_strlen($t) <= $len) {
            return $t;
        }
        $cut = mb_substr($t, 0, $len);
        $sp = mb_strrpos($cut, ' ');
        return rtrim($sp > $len * 0.6 ? mb_substr($cut, 0, $sp) : $cut, '،,.؛ ') . '…';
    }

    /** «80%» isolated left-to-right so the sign stays after the number inside Arabic text. */
    private static function pct(float $n): string
    {
        return "\u{2066}" . self::num($n) . "%\u{2069}";
    }

    private static function num(float $n): string
    {
        return rtrim(rtrim(number_format($n, 2, '.', ''), '0'), '.');
    }

    private static function icon(string $name, string $color, int $size): string
    {
        return sprintf('<svg class="zbs-ic" viewBox="0 0 24 24" width="%1$d" height="%1$d" fill="none" stroke="%2$s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%3$s</svg>',
            $size, esc_attr($color), self::PATHS[$name] ?? self::PATHS['info']);
    }

    /* ══════════════════════════════════════════════════════════════
       STRUCTURED DATA
       ══════════════════════════════════════════════════════════════ */

    /** Key facts as schema.org additionalProperty; material/color where Google reads them. */
    public static function structured_data($markup, $product)
    {
        if (! is_array($markup) || ! $product instanceof WC_Product) {
            return $markup;
        }
        $s = Zooboxi_Product_Story::get($product, 'ar');
        if (! $s || ! $s['facts']) {
            return $markup;
        }
        $props = [];
        foreach ($s['facts'] as $f) {
            if ($f['kind'] === 'material' && empty($markup['material'])) {
                $markup['material'] = $f['value'];
            } elseif ($f['kind'] === 'color' && empty($markup['color'])) {
                $markup['color'] = $f['value'];
            }
            $props[] = ['@type' => 'PropertyValue', 'name' => $f['label'], 'value' => $f['value']];
        }
        $markup['additionalProperty'] = $props;
        return $markup;
    }
}
