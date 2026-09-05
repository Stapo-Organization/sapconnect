<?php
/**
 * Zooboxi_Loyalty_Mail — the program's one mail template and its weekly cap.
 *
 * The customer app has no push channel yet, so the only way to reach someone who is
 * NOT looking at the app is mail. Two rules keep it from becoming noise:
 *   1. one message per (customer, kind, ref), ever — the `zb_notices` UNIQUE key;
 *   2. at most `mail_weekly_cap` (2) marketing messages per customer per ISO week —
 *      the plan's "no more than two notifications a week outside orders".
 *
 * OTP accounts are created with a placeholder address (`…@zooboxi.local`); those are
 * skipped silently rather than bounced.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Mail
{
    /** Kinds that count against the weekly cap. */
    private const MARKETING = ['supply', 'subscription', 'birthday', 'winback'];

    public static function enabled(): bool
    {
        return Zooboxi_Loyalty::is_enabled() && Zooboxi_Loyalty::opt('mail_enabled', 'yes') === 'yes';
    }

    /**
     * Send one notice. Returns true when it actually went out.
     *
     * @param array{subject_ar:string,subject_en:string,lines_ar:string[],lines_en:string[],cta_ar?:string,cta_en?:string,cta_url?:string} $m
     */
    public static function send(int $user_id, string $kind, string $ref, array $m): bool
    {
        if ($user_id <= 0 || !self::enabled()) {
            return false;
        }
        $user = get_user_by('id', $user_id);
        if (!$user) {
            return false;
        }
        $email = (string) $user->user_email;
        if ($email === '' || !is_email($email) || substr($email, -strlen('@zooboxi.local')) === '@zooboxi.local') {
            return false;
        }

        Zooboxi_Loyalty_Schema::maybe_install();
        global $wpdb;

        $marketing = in_array($kind, self::MARKETING, true);
        if ($marketing && !self::under_cap($user_id)) {
            return false;
        }

        // Reserve the (user, kind, ref) slot first — a duplicate means "already sent".
        $prev_show     = $wpdb->hide_errors();
        $prev_suppress = $wpdb->suppress_errors(true);
        $ok = $wpdb->insert(Zooboxi_Loyalty_Schema::notices(), [
            'user_id' => $user_id,
            'kind'    => mb_substr($kind, 0, 24),
            'ref'     => mb_substr($ref, 0, 40),
            'channel' => 'mail',
            'sent_at' => Zooboxi_Loyalty::now(),
        ], ['%d', '%s', '%s', '%s', '%s']);
        $wpdb->suppress_errors($prev_suppress);
        if ($prev_show) {
            $wpdb->show_errors();
        }
        if (!$ok) {
            return false;
        }

        $subject = $m['subject_ar'] . ' · ' . $m['subject_en'];
        $html    = self::template(
            (string) ($user->first_name ?: $user->display_name),
            (string) $m['subject_ar'],
            (string) $m['subject_en'],
            (array) ($m['lines_ar'] ?? []),
            (array) ($m['lines_en'] ?? []),
            (string) ($m['cta_ar'] ?? ''),
            (string) ($m['cta_en'] ?? ''),
            (string) ($m['cta_url'] ?? home_url('/'))
        );

        $sent = (bool) wp_mail($email, $subject, $html, ['Content-Type: text/html; charset=UTF-8']);
        if ($sent && $marketing) {
            self::count_week($user_id);
        }
        return $sent;
    }

    /** Has this member room left in the week? */
    private static function under_cap(int $user_id): bool
    {
        $cap = max(0, Zooboxi_Loyalty::opt_int('mail_weekly_cap', 2));
        if ($cap <= 0) {
            return false;
        }
        $row = Zooboxi_Loyalty_Members::get($user_id);
        if ($row === null) {
            return true;
        }
        $week = gmdate('o-\WW');
        if ((string) ($row['nudge_week'] ?? '') !== $week) {
            return true;
        }
        return (int) ($row['nudge_count'] ?? 0) < $cap;
    }

    private static function count_week(int $user_id): void
    {
        $row  = Zooboxi_Loyalty_Members::get($user_id);
        $week = gmdate('o-\WW');
        $n    = ($row !== null && (string) ($row['nudge_week'] ?? '') === $week) ? (int) $row['nudge_count'] + 1 : 1;
        global $wpdb;
        $wpdb->update(
            Zooboxi_Loyalty_Schema::members(),
            ['nudge_week' => $week, 'nudge_count' => $n],
            ['user_id' => $user_id],
            ['%s', '%d'],
            ['%d']
        );
        Zooboxi_Loyalty_Members::forget($user_id);
    }

    /** Bilingual, brand-coloured, table-based (mail clients). */
    private static function template(string $name, string $subject_ar, string $subject_en, array $ar, array $en, string $cta_ar, string $cta_en, string $url): string
    {
        $teal   = '#429D9C';
        $coral  = '#D46856';
        $paper  = '#FFF9F2';
        $ink    = '#2B2A28';
        $muted  = '#6F6A62';
        $logo   = esc_url(home_url('/'));
        $hello  = $name !== '' ? esc_html($name) : '';

        $block = static function (array $lines, string $dir, string $align) use ($ink): string {
            $out = '';
            foreach ($lines as $line) {
                $out .= '<p dir="' . $dir . '" style="margin:0 0 10px;font-size:15px;line-height:1.7;color:' . $ink . ';text-align:' . $align . ';">' . esc_html((string) $line) . '</p>';
            }
            return $out;
        };

        $cta = '';
        if ($cta_ar !== '' || $cta_en !== '') {
            $cta = '<table role="presentation" cellpadding="0" cellspacing="0" style="margin:18px auto 6px;"><tr><td style="background:' . $coral . ';border-radius:999px;">'
                . '<a href="' . esc_url($url) . '" style="display:inline-block;padding:12px 26px;color:#fff;font-weight:700;text-decoration:none;font-size:15px;">'
                . esc_html(trim($cta_ar . ' · ' . $cta_en, ' ·')) . '</a></td></tr></table>';
        }

        return '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>'
            . '<body style="margin:0;background:' . $paper . ';font-family:Tajawal,Segoe UI,Arial,sans-serif;">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:' . $paper . ';padding:28px 12px;"><tr><td align="center">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#fff;border-radius:20px;overflow:hidden;border:1px solid #F1E4D4;">'
            . '<tr><td style="background:' . $teal . ';padding:22px 24px;text-align:center;">'
            . '<a href="' . $logo . '" style="color:#fff;font-size:22px;font-weight:800;text-decoration:none;letter-spacing:.3px;">Zooboxi · زوبوكسي</a>'
            . '<div style="color:#E6F4F3;font-size:13px;margin-top:4px;">عائلة زوبوكسي · Zooboxi Family 🐾</div></td></tr>'
            . '<tr><td style="padding:26px 26px 8px;">'
            . ($hello !== '' ? '<p dir="rtl" style="margin:0 0 6px;font-size:15px;color:' . $muted . ';text-align:right;">مرحباً ' . $hello . '،</p>' : '')
            . '<h1 dir="rtl" style="margin:0 0 14px;font-size:22px;line-height:1.4;color:' . $ink . ';text-align:right;">' . esc_html($subject_ar) . '</h1>'
            . $block($ar, 'rtl', 'right')
            . '<hr style="border:0;border-top:1px solid #F1E4D4;margin:18px 0;">'
            . '<h2 dir="ltr" style="margin:0 0 10px;font-size:17px;color:' . $ink . ';text-align:left;">' . esc_html($subject_en) . '</h2>'
            . $block($en, 'ltr', 'left')
            . $cta
            . '</td></tr>'
            . '<tr><td style="padding:14px 26px 24px;text-align:center;color:' . $muted . ';font-size:12px;line-height:1.6;">'
            . 'وصلتك هذه الرسالة لأنك عضو في عائلة زوبوكسي. لا نرسل أكثر من رسالتين أسبوعياً.<br>'
            . 'You received this because you are a Zooboxi Family member. Never more than two a week.'
            . '</td></tr></table></td></tr></table></body></html>';
    }
}
