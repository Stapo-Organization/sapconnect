<?php
/**
 * Zooboxi_Mail_Kit — the email design «D · المزيج» as email-safe blocks.
 *
 * Every block is a table with inline styles: Gmail drops <style>, SVG,
 * positioning and negative margins, Outlook drops most of the rest. Images are
 * PNGs next to this file; every one has a background colour or alt text
 * behind it, so the email still reads with images blocked. One kit per
 * language: it knows its direction and which side «start» is.
 */

defined('ABSPATH') || exit;

final class Zooboxi_Mail_Kit
{
    public const INK    = '#5A2C2F';
    public const MUTED  = '#7A6260';
    public const PAGE   = '#F6EFE3';
    public const TEAL   = '#429D9C';
    public const DEEP   = '#1F5E5D';
    public const BUTTON = '#297978';
    public const CORAL  = '#BD4E3A';
    public const LINE   = '#F1E9DE';

    public string $lang;
    public string $dir;
    public string $start;
    public string $end;
    private string $font;
    private string $display;

    public function __construct(string $lang)
    {
        $this->lang    = $lang === 'en' ? 'en' : 'ar';
        $this->dir     = $this->lang === 'en' ? 'ltr' : 'rtl';
        $this->start   = $this->lang === 'en' ? 'left' : 'right';
        $this->end     = $this->lang === 'en' ? 'right' : 'left';
        $this->font    = $this->lang === 'en'
            ? "Manrope,'Helvetica Neue',Helvetica,Arial,sans-serif"
            : "Tajawal,'Geeza Pro','Segoe UI',Tahoma,Arial,sans-serif";
        $this->display = "'Baloo Bhaijaan 2'," . $this->font;
    }

    public static function img(string $file): string
    {
        // https always: cron and WP-CLI build these without a request to detect it from.
        return set_url_scheme(content_url('mu-plugins/zooboxi-emails/img/' . $file), 'https');
    }

    public function e(string $text): string
    {
        return esc_html($text);
    }

    /* ── page ─────────────────────────────────────────── */

    /** The whole email: head, hidden preview line, logo, blocks, footer. */
    public function page(string $title, string $preheader, string $blocks, string $footer): string
    {
        $fonts = 'https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&family=Manrope:wght@400;600;700;800&family=Baloo+Bhaijaan+2:wght@700;800&display=swap';
        return '<!DOCTYPE html><html lang="' . $this->lang . '" dir="' . $this->dir . '"><head>'
            . '<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            . '<meta name="color-scheme" content="light only"><meta name="supported-color-schemes" content="light">'
            . '<title>' . $this->e($title) . '</title>'
            . '<link href="' . esc_url($fonts) . '" rel="stylesheet">'
            . '<style>body{margin:0;padding:0}a{color:' . self::BUTTON . '}@media (max-width:620px){.zb-pad{padding-left:16px!important;padding-right:16px!important}.zb-h1{font-size:38px!important}.zb-big{font-size:42px!important}}</style>'
            . '</head><body dir="' . $this->dir . '" style="margin:0;padding:0;background:' . self::PAGE . ';">'
            . '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:' . self::PAGE . ';font-size:1px;line-height:1px;">' . $this->e($preheader) . str_repeat('&#8204;&nbsp;', 40) . '</div>'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="' . self::PAGE . '" style="background:' . self::PAGE . ';">'
            . '<tr><td align="center" style="padding:0;">'
            . '<table role="presentation" dir="' . $this->dir . '" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;font-family:' . $this->font . ';color:' . self::INK . ';">'
            . '<tr><td align="center" style="padding:24px 0 16px;"><img src="' . esc_url(self::img('logo.png')) . '" width="96" alt="' . ($this->lang === 'en' ? 'Zooboxi' : 'زوبوكسي') . '" style="display:block;width:96px;height:auto;border:0;"></td></tr>'
            . $blocks
            . $footer
            . '</table></td></tr></table></body></html>';
    }

    /** A block row with the page's side gutter. */
    public function row(string $html, string $pad = '0 16px'): string
    {
        return '<tr><td class="zb-pad" style="padding:' . $pad . ';" dir="' . $this->dir . '" align="' . $this->start . '">' . $html . '</td></tr>';
    }

    /* ── the board ────────────────────────────────────── */

    /**
     * The coloured board at the top: pill, headline, line, then the art row.
     * $tone: teal (good news), cream (needs you), coral (family moments).
     */
    public function board(string $tone, string $pill, string $title, string $line, string $art = ''): string
    {
        $tones = [
            'teal'  => ['#429D9C', 'dots-teal.png', '#FFF7EA', '#F2FBFA', '#1F5E5D', 'rgba(255,255,255,0.2)', '#FFFFFF'],
            'cream' => ['#F4EBDA', 'dots-cream.png', self::INK, '#6B4A47', '#E2D5C3', 'rgba(90,44,47,0.08)', self::INK],
            'coral' => ['#D46856', 'dots-coral.png', '#FFF7EA', '#FFFFFF', '#8E3626', 'rgba(255,255,255,0.22)', '#FFFFFF'],
        ];
        [$bg, $tile, $head, $sub, $shadow, $pillBg, $pillInk] = $tones[$tone] ?? $tones['teal'];
        $shadowCss = $tone === 'cream' ? '' : 'text-shadow:3px 3px 0 ' . $shadow . ';';

        $html = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="' . $bg . '" background="' . esc_url(self::img($tile)) . '" style="background-color:' . $bg . ';background-image:url(' . esc_url(self::img($tile)) . ');border-radius:30px;">'
            . '<tr><td align="center" style="padding:30px 24px ' . ($art === '' ? '34px' : '8px') . ';text-align:center;">';
        if ($pill !== '') {
            $html .= '<span style="display:inline-block;background:' . $pillBg . ';color:' . $pillInk . ';border-radius:999px;padding:6px 14px;font-size:14px;font-weight:800;">' . $this->e($pill) . '</span>';
        }
        $html .= '<h1 class="zb-h1" style="margin:14px 0 10px;font-family:' . $this->display . ';font-size:46px;line-height:1.15;font-weight:800;color:' . $head . ';' . $shadowCss . '">' . $this->e($title) . '</h1>'
            . '<p style="margin:0;font-size:19px;line-height:1.6;font-weight:700;color:' . $sub . ';">' . $this->e($line) . '</p>'
            . '</td></tr>';
        if ($art !== '') {
            $html .= '<tr><td style="padding:0;">' . $art . '</td></tr>';
        }
        return $this->row($html . '</table>');
    }

    /** A character at the board's «start» edge with a speech bubble beside it. */
    public function talking(string $char, string $words, int $width = 104): string
    {
        $file = $this->lang === 'en' && file_exists(__DIR__ . '/img/' . $char . '-ltr.png') ? $char . '-ltr.png' : $char . '.png';
        $tail = $this->lang === 'en' ? '18px 18px 18px 4px' : '18px 18px 4px 18px';
        return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>'
            . '<td width="' . ($width + 20) . '" valign="bottom" align="' . $this->start . '" style="padding:0 18px 0 18px;"><img src="' . esc_url(self::img($file)) . '" width="' . $width . '" alt="" style="display:block;width:' . $width . 'px;height:auto;border:0;"></td>'
            . '<td valign="middle" align="' . $this->start . '" style="padding:0 0 40px;"><span style="display:inline-block;background:#FFFFFF;color:' . self::INK . ';border-radius:' . $tail . ';padding:9px 15px;font-size:15px;font-weight:800;">' . $this->e($words) . '</span></td>'
            . '</tr></table>';
    }

    /** Full-width art (a scene, or characters side by side), centred. */
    public function art(string $html): string
    {
        return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" style="padding:6px 0 0;line-height:0;">' . $html . '</td></tr></table>';
    }

    public function pic(string $file, int $width, string $style = ''): string
    {
        return '<img src="' . esc_url(self::img($file)) . '" width="' . $width . '" alt="" style="display:inline-block;width:' . $width . 'px;height:auto;border:0;vertical-align:bottom;' . $style . '">';
    }

    /* ── the ticket ───────────────────────────────────── */

    /** Main part, perforation, stub. $stub_href makes the stub a link. */
    public function ticket(string $main, string $stub, string $stub_bg = '#E4F2EF', string $stub_href = '', string $bg = '#FFFFFF', string $border = '#EADFCE'): string
    {
        $stubInner = $stub_href !== ''
            ? '<a href="' . esc_url($stub_href) . '" style="text-decoration:none;color:' . self::DEEP . ';display:block;">' . $stub . '</a>'
            : $stub;
        $html = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="' . $bg . '" style="background:' . $bg . ';border:1px solid ' . $border . ';border-radius:22px;border-collapse:separate;overflow:hidden;"><tr>'
            . '<td valign="middle" align="' . $this->start . '" style="padding:18px 18px;">' . $main . '</td>'
            . '<td width="1" style="border-' . $this->end . ':2px dashed #E2D5C3;font-size:0;line-height:0;">&nbsp;</td>'
            . '<td width="104" valign="middle" align="center" bgcolor="' . $stub_bg . '" style="background:' . $stub_bg . ';padding:14px 10px;text-align:center;border-radius:' . ($this->lang === 'en' ? '0 21px 21px 0' : '21px 0 0 21px') . ';">' . $stubInner . '</td>'
            . '</tr></table>';
        return $this->row($html, '16px 24px 0');
    }

    public function ticket_main(string $label, string $big, string $small): string
    {
        // A short promise («ساعتين») is the hero; a long one (a courier's full name) must not shout.
        $long = mb_strlen(wp_strip_all_tags($big)) > 10;
        return '<div style="font-size:14px;font-weight:800;color:' . self::MUTED . ';">' . $this->e($label) . '</div>'
            . '<div' . ($long ? '' : ' class="zb-big"') . ' style="font-family:' . $this->display . ';font-size:' . ($long ? '28px' : '50px') . ';line-height:1.15;font-weight:800;color:' . self::BUTTON . ';">' . $big . '</div>'
            . ($small !== '' ? '<div style="font-size:14px;color:' . self::MUTED . ';">' . $this->e($small) . '</div>' : '');
    }

    public function ticket_stub(string $icon, string $title, string $sub = '', string $ink = self::DEEP): string
    {
        return '<img src="' . esc_url(self::img($icon)) . '" width="26" height="26" alt="" style="display:block;margin:0 auto 6px;border:0;">'
            . '<div style="font-size:16px;font-weight:800;color:' . $ink . ';">' . $this->e($title) . '</div>'
            . ($sub !== '' ? '<div style="font-size:13px;font-weight:700;color:' . $ink . ';">' . $this->e($sub) . '</div>' : '');
    }

    /* ── the paw path ─────────────────────────────────── */

    /** @param array<int,array{0:string,1:string,2:bool}> $steps [image, label, reached] */
    public function path(array $steps): string
    {
        $cells = '';
        $last  = count($steps) - 1;
        foreach ($steps as $i => [$image, $label, $reached]) {
            $cells .= '<td width="54" align="center" valign="top" style="padding:0;">'
                . '<img src="' . esc_url(self::img($image)) . '" width="44" height="44" alt="" style="display:block;margin:0 auto;border:0;">'
                . '<div style="padding-top:6px;font-size:13px;font-weight:' . ($reached ? '800' : '500') . ';color:' . ($reached ? self::BUTTON : self::MUTED) . ';">' . $this->e($label) . '</div></td>';
            if ($i < $last) {
                $paw   = 'paw-' . ($steps[$i + 1][2] ? 'teal' : 'beige') . '-' . $this->dir . '.png';
                $cells .= '<td align="center" valign="top" style="padding:14px 0 0;">'
                    . '<img src="' . esc_url(self::img($paw)) . '" width="14" height="14" alt="" style="display:inline-block;border:0;margin:0 1px;">'
                    . '<img src="' . esc_url(self::img($paw)) . '" width="14" height="14" alt="" style="display:inline-block;border:0;margin:0 1px;"></td>';
            }
        }
        return $this->row('<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>' . $cells . '</tr></table>', '26px 24px 0');
    }

    /* ── buttons, money, text ─────────────────────────── */

    public function button(string $label, string $url, string $color = self::CORAL, string $pad = '24px 32px 0'): string
    {
        return $this->row(
            '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center" bgcolor="' . $color . '" style="background:' . $color . ';border-radius:999px;">'
            . '<a href="' . esc_url($url) . '" style="display:block;padding:17px 24px;font-family:' . $this->font . ';font-size:19px;font-weight:800;color:#FFFFFF;text-decoration:none;text-align:center;">' . $this->e($label) . '</a>'
            . '</td></tr></table>',
            $pad
        );
    }

    /** The official riyal symbol as a small image (alt «ر.س»/«SAR»), then the amount. */
    public function money(float $amount, int $size = 16, string $tone = 'ink', string $weight = '800'): string
    {
        $h = (int) round($size * 0.78);
        return '<span dir="ltr" style="white-space:nowrap;font-size:' . $size . 'px;font-weight:' . $weight . ';">'
            . '<img src="' . esc_url(self::img('riyal-' . $tone . '.png')) . '" height="' . $h . '" alt="' . ($this->lang === 'en' ? 'SAR' : 'ر.س') . '" style="height:' . $h . 'px;width:auto;border:0;vertical-align:-1px;"> '
            . number_format($amount, 2, '.', ',') . '</span>';
    }

    public function text(string $html, string $pad = '16px 32px 0', string $size = '15px', string $color = self::MUTED): string
    {
        return $this->row('<div style="font-size:' . $size . ';line-height:1.7;color:' . $color . ';">' . $html . '</div>', $pad);
    }

    /* ── the receipt «صندوق لولو» ─────────────────────── */

    /**
     * @param array<int,array{name:string,sub:string,image:string,amount:float}> $lines
     * @param array<int,array{0:string,1:float}> $totals
     */
    public function receipt(string $title, string $meta, array $lines, array $totals, float $total, string $total_note): string
    {
        $rows = '';
        foreach ($lines as $i => $line) {
            $rows .= '<tr><td style="padding:12px 0;' . ($i ? 'border-top:1px solid ' . self::LINE . ';' : '') . '">'
                . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>'
                . '<td width="60" valign="middle" style="padding-' . $this->end . ':14px;">' . $this->thumb($line['image'], 60) . '</td>'
                . '<td valign="middle" align="' . $this->start . '" style="font-size:15px;font-weight:700;line-height:1.45;color:' . self::INK . ';">' . $this->e($line['name'])
                . '<div style="font-size:13px;font-weight:500;color:' . self::MUTED . ';">' . $this->e($line['sub']) . '</div></td>'
                . '<td valign="middle" align="' . $this->end . '" style="padding-' . $this->start . ':10px;white-space:nowrap;">' . $this->money($line['amount'], 16) . '</td>'
                . '</tr></table></td></tr>';
        }
        $sums = '';
        foreach ($totals as [$label, $amount]) {
            $sums .= '<tr><td align="' . $this->start . '" style="padding:4px 0;font-size:15px;color:' . self::MUTED . ';">' . $this->e($label) . '</td>'
                . '<td align="' . $this->end . '" style="padding:4px 0;">' . $this->money($amount, 15, $amount < 0 ? 'coral' : 'ink', '500') . '</td></tr>';
        }

        $html = '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border-radius:26px 26px 0 0;">'
            . '<tr><td style="padding:24px 24px 18px;">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '">'
            . '<tr><td align="' . $this->start . '" style="padding-bottom:10px;border-bottom:2px dashed #EFE4D6;font-family:' . $this->display . ';font-size:25px;font-weight:800;color:' . self::INK . ';">' . $this->e($title) . '</td>'
            . '<td align="' . $this->end . '" style="padding-bottom:10px;border-bottom:2px dashed #EFE4D6;font-size:14px;color:' . self::MUTED . ';">' . $this->e($meta) . '</td></tr>'
            . '<tr><td colspan="2"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' . $rows . '</table></td></tr>'
            . '<tr><td colspan="2" style="padding-top:10px;border-top:2px dashed #EFE4D6;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '">' . $sums . '</table></td></tr>'
            . '<tr><td colspan="2" style="padding-top:12px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>'
            . '<td align="' . $this->start . '" valign="bottom"><div style="font-size:18px;font-weight:800;color:' . self::INK . ';">' . ($this->lang === 'en' ? 'Total' : 'الإجمالي') . '</div><div style="font-size:13px;color:' . self::MUTED . ';">' . $this->e($total_note) . '</div></td>'
            . '<td align="' . $this->end . '" valign="bottom" style="font-family:' . $this->display . ';color:' . self::DEEP . ';">' . $this->money($total, 40, 'teal') . '</td>'
            . '</tr></table></td></tr>'
            . '</table></td></tr></table>'
            . '<img src="' . esc_url(self::img('zigzag.png')) . '" width="568" alt="" style="display:block;width:100%;max-width:568px;height:auto;border:0;">';
        return $this->row($html, '24px 16px 0');
    }

    /** A product photo on a mint tile. */
    public function thumb(string $url, int $size): string
    {
        $inner = (int) round($size * 0.86);
        $img   = $url !== ''
            ? '<img src="' . esc_url($url) . '" width="' . $inner . '" height="' . $inner . '" alt="" style="display:block;width:' . $inner . 'px;height:' . $inner . 'px;object-fit:contain;border:0;margin:0 auto;">'
            : '&nbsp;';
        return '<table role="presentation" width="' . $size . '" cellpadding="0" cellspacing="0" border="0"><tr><td width="' . $size . '" height="' . $size . '" align="center" valign="middle" bgcolor="#F1F8F7" style="background:#F1F8F7;border-radius:16px;">' . $img . '</td></tr></table>';
    }

    /** A white card with optional title. */
    public function card(string $title, string $body, string $pad = '24px 16px 0'): string
    {
        $head = $title !== '' ? '<div style="font-family:' . $this->display . ';font-size:24px;font-weight:800;color:' . self::INK . ';padding-bottom:6px;">' . $this->e($title) . '</div>' : '';
        return $this->row('<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#FFFFFF" style="background:#FFFFFF;border-radius:26px;"><tr><td align="' . $this->start . '" style="padding:22px 24px;">' . $head . $body . '</td></tr></table>', $pad);
    }

    /** A row of product photos with quantity badges. */
    public function strip(array $lines): string
    {
        $cells = '';
        foreach (array_slice($lines, 0, 4) as $line) {
            $cells .= '<td width="25%" align="center" style="padding:0 3px;">' . $this->thumb($line['image'], 60)
                . ($line['qty'] > 1 ? '<div style="padding-top:4px;font-size:12px;font-weight:800;color:' . self::BUTTON . ';">×' . (int) $line['qty'] . '</div>' : '') . '</td>';
        }
        return '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>' . $cells . '</tr></table>';
    }

    /* ── the character who signs off ──────────────────── */

    public function signoff(string $char, string $html): string
    {
        $file = $this->lang === 'en' && file_exists(__DIR__ . '/img/' . $char . '-ltr.png') ? $char . '-ltr.png' : $char . '.png';
        $tail = $this->lang === 'en' ? '22px 22px 22px 6px' : '22px 22px 6px 22px';
        return $this->row(
            '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" dir="' . $this->dir . '"><tr>'
            . '<td width="118" valign="bottom" style="padding-' . $this->end . ':10px;"><img src="' . esc_url(self::img($file)) . '" width="118" alt="" style="display:block;width:118px;height:auto;border:0;"></td>'
            . '<td valign="bottom" style="padding-bottom:30px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td bgcolor="#FFFFFF" align="' . $this->start . '" style="background:#FFFFFF;border-radius:' . $tail . ';padding:16px 18px;font-size:15px;line-height:1.7;color:' . self::INK . ';">' . $html . '</td></tr></table></td>'
            . '</tr></table>',
            '28px 24px 0'
        );
    }

    /* ── footer ───────────────────────────────────────── */

    public function footer(string $lines_html): string
    {
        return '<tr><td style="padding:28px 0 0;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="' . self::DEEP . '" style="background:' . self::DEEP . ';">'
            . '<tr><td align="center" style="padding:28px 32px 32px;text-align:center;font-family:' . $this->font . ';color:#FFFFFF;">' . $lines_html . '</td></tr></table></td></tr>';
    }

    public function footer_line(string $html, string $size = '13px', string $color = '#CFE7E4'): string
    {
        return '<div style="font-size:' . $size . ';line-height:1.8;color:' . $color . ';padding-top:6px;">' . $html . '</div>';
    }

    public function footer_apps(string $title, string $url): string
    {
        return '<div style="font-size:16px;font-weight:800;color:#FFFFFF;">' . $this->e($title) . '</div>'
            . '<div style="padding:12px 0 6px;"><a href="' . esc_url($url) . '" style="display:inline-block;background:#FFFFFF;color:' . self::DEEP . ';text-decoration:none;font-size:14px;font-weight:800;padding:10px 18px;border-radius:12px;margin:0 4px;">App Store</a>'
            . '<a href="' . esc_url($url) . '" style="display:inline-block;background:#FFFFFF;color:' . self::DEEP . ';text-decoration:none;font-size:14px;font-weight:800;padding:10px 18px;border-radius:12px;margin:0 4px;">Google Play</a></div>';
    }
}
