<?php
/**
 * Zooboxi_V2_Auth_Controller — phone/OTP sign-in for the mobile app.
 *
 * Reuses Zooboxi_OTP_Auth verbatim (same otp_log table, same Taqnyat sender, same
 * rate limits, same find-or-create-user rules) and differs in exactly one way: instead
 * of setting a WordPress auth cookie it mints a `zbat_` bearer token.
 *
 * There is no nonce on /auth/otp/send — a fresh app install has no way to get one. The
 * defence is the rate limiting: the shared per-phone (3/15min) and per-IP (10/hour)
 * limits, plus a tighter per-IP burst throttle added here.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Auth_Controller
{
    /** Extra app-side burst throttle: N sends per IP per window. */
    private const IP_BURST_MAX    = 5;
    private const IP_BURST_WINDOW = 600; // 10 minutes

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/auth/otp/send', 'POST', [$this, 'otp_send']);
        Zooboxi_V2_Bootstrap::route('/auth/otp/verify', 'POST', [$this, 'otp_verify']);
        Zooboxi_V2_Bootstrap::route('/auth/logout', 'POST', [$this, 'logout']);
        Zooboxi_V2_Bootstrap::route('/me', 'GET', [$this, 'me']);
        Zooboxi_V2_Bootstrap::route('/me', 'PATCH,PUT,POST', [$this, 'update_me']);
    }

    /* ── POST /auth/otp/send ───────────────────────── */

    public function otp_send(\WP_REST_Request $request): \WP_REST_Response
    {
        $phone = sanitize_text_field((string) $request->get_param('phone'));
        if ($phone === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'phone_required',
                __('يرجى إدخال رقم جوال سعودي صالح', 'zooboxi'),
                'A valid Saudi mobile number is required.',
                422
            );
        }

        $ip = Zooboxi_OTP_Auth::client_ip();

        if (!$this->ip_burst_ok($ip)) {
            return Zooboxi_V2_Bootstrap::fail(
                'rate_limited',
                __('تم تجاوز الحد المسموح. حاول مرة أخرى لاحقاً', 'zooboxi'),
                'Too many requests. Please try again later.',
                429
            );
        }

        $result = Zooboxi_OTP_Auth::send_otp($phone, $ip);

        if (empty($result['success'])) {
            $code   = (string) ($result['error']['code'] ?? 'otp_send_failed');
            $status = $code === 'rate_limited' ? 429 : 422;
            return Zooboxi_V2_Bootstrap::fail(
                $code,
                (string) ($result['error']['message'] ?? __('حدث خطأ في إرسال الرمز. حاول مرة أخرى', 'zooboxi')),
                $code === 'rate_limited' ? 'Too many requests. Please try again later.' : 'Could not send the verification code.',
                $status
            );
        }

        return Zooboxi_V2_Bootstrap::ok([
            'display_phone' => (string) ($result['data']['display_phone'] ?? ''),
            'resend_after'  => (int) ($result['data']['resend_after'] ?? 60),
            'expires_in'    => (int) ($result['data']['expires_in'] ?? 180),
        ]);
    }

    /** Modest per-IP burst counter on top of Zooboxi_OTP_Auth's own limits. */
    private function ip_burst_ok(string $ip): bool
    {
        $key   = 'zb_v2_otp_ip_' . md5($ip);
        $count = (int) get_transient($key);
        if ($count >= self::IP_BURST_MAX) {
            return false;
        }
        set_transient($key, $count + 1, self::IP_BURST_WINDOW);
        return true;
    }

    /* ── POST /auth/otp/verify ─────────────────────── */

    public function otp_verify(\WP_REST_Request $request): \WP_REST_Response
    {
        $phone    = sanitize_text_field((string) $request->get_param('phone'));
        $otp      = sanitize_text_field((string) $request->get_param('otp'));
        $platform = sanitize_key((string) $request->get_param('platform'));
        $device   = sanitize_text_field((string) $request->get_param('device_name'));

        // Read the guest basket BEFORE the login switches the session identity.
        $guest_id    = Zooboxi_V2_Bootstrap::guest_id($request);
        $guest_items = $guest_id !== '' ? Zooboxi_V2_Cart_Controller::read_guest_cart_items($guest_id) : [];

        $result = Zooboxi_OTP_Auth::verify_otp($phone, $otp);

        if (empty($result['success'])) {
            $code = (string) ($result['error']['code'] ?? 'otp_invalid');
            return Zooboxi_V2_Bootstrap::fail(
                $code,
                (string) ($result['error']['message'] ?? __('بيانات غير صالحة', 'zooboxi')),
                'The verification code could not be validated.',
                in_array($code, ['blocked', 'rate_limited'], true) ? 429 : 422,
                isset($result['error']['remaining']) ? ['remaining' => (int) $result['error']['remaining']] : null
            );
        }

        $user_id = (int) $result['user_id'];

        // Bearer token instead of an auth cookie — the app is stateless.
        $token = Zooboxi_App_Tokens::issue($user_id, $platform, $device);
        if ($token === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'token_issue_failed',
                __('تعذر إنشاء الجلسة. حاول مرة أخرى', 'zooboxi'),
                'Could not create the session. Please try again.',
                500
            );
        }

        wp_set_current_user($user_id);

        $merged = 0;
        if (!empty($guest_items)) {
            $merged = Zooboxi_V2_Cart_Controller::merge_guest_items_into_user_cart($guest_items, $guest_id);
        }

        $user = get_userdata($user_id);

        return Zooboxi_V2_Bootstrap::ok([
            'token'       => $token,
            'is_new'      => !empty($result['is_new']),
            'user'        => $this->user_dto($user_id),
            'cart_merged' => $merged > 0,
            'merged_lines' => $merged,
            'needs_profile' => $user ? ($user->first_name === '') : true,
        ]);
    }

    /* ── POST /auth/logout ─────────────────────────── */

    public function logout(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!get_current_user_id()) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        $raw = Zooboxi_V2_Bootstrap::bearer_token();
        if ($raw !== '') {
            Zooboxi_App_Tokens::revoke($raw);
        }
        return Zooboxi_V2_Bootstrap::ok(['revoked' => true]);
    }

    /* ── GET /me ───────────────────────────────────── */

    public function me(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        return Zooboxi_V2_Bootstrap::ok($this->user_dto($user_id));
    }

    /* ── PATCH /me ─────────────────────────────────── */

    /**
     * Same rules as the web's "complete profile" step: name is required, an email is
     * only taken when it is valid and not already in use, and the WooCommerce billing
     * mirror (billing_first_name / billing_country = SA) is kept in sync.
     */
    public function update_me(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $name  = sanitize_text_field((string) $request->get_param('name'));
        $email = sanitize_email((string) $request->get_param('email'));

        if ($name === '' && $email === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'nothing_to_update',
                __('لا توجد بيانات للتحديث', 'zooboxi'),
                'Nothing to update.',
                422
            );
        }

        $update = ['ID' => $user_id];

        if ($name !== '') {
            $update['first_name']   = $name;
            $update['display_name'] = $name;
        }

        if ($email !== '') {
            if (!is_email($email)) {
                return Zooboxi_V2_Bootstrap::fail(
                    'invalid_email',
                    __('البريد الإلكتروني غير صالح', 'zooboxi'),
                    'That email address is not valid.',
                    422
                );
            }
            $existing = get_user_by('email', $email);
            if ($existing && (int) $existing->ID !== $user_id) {
                return Zooboxi_V2_Bootstrap::fail(
                    'email_taken',
                    __('البريد الإلكتروني مستخدم بالفعل', 'zooboxi'),
                    'That email address is already in use.',
                    409
                );
            }
            $update['user_email'] = $email;
            update_user_meta($user_id, 'billing_email', $email);
        }

        $result = wp_update_user($update);
        if (is_wp_error($result)) {
            return Zooboxi_V2_Bootstrap::fail(
                'update_failed',
                __('تعذر حفظ البيانات', 'zooboxi'),
                'Could not save your details.',
                500
            );
        }

        if ($name !== '') {
            update_user_meta($user_id, 'billing_first_name', $name);
        }
        update_user_meta($user_id, 'billing_country', 'SA');

        return Zooboxi_V2_Bootstrap::ok($this->user_dto($user_id));
    }

    /* ── Helpers ───────────────────────────────────── */

    /** Explicit allowlist — never dump the WP_User object. */
    private function user_dto(int $user_id): array
    {
        $user  = get_userdata($user_id);
        $phone = (string) get_user_meta($user_id, 'billing_phone', true);
        $email = (string) ($user ? $user->user_email : '');

        // The OTP flow parks new accounts on a placeholder address — never show it.
        if (substr($email, -strlen('@zooboxi.local')) === '@zooboxi.local') {
            $email = '';
        }

        // A fresh OTP account's display_name is its auto username (zb_5xxxxxxxx) —
        // that is not a name; an empty string lets the app ask for one instead.
        $name = $user ? ($user->first_name ?: $user->display_name) : '';
        if ($user && $user->first_name === '' && $name === $user->user_login) {
            $name = '';
        }

        return [
            'id'    => $user_id,
            'name'  => $name,
            'phone' => $phone,
            'email' => $email,
        ];
    }
}
