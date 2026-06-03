<?php
/**
 * OTP Authentication — phone-based login/registration via SMS.
 * Uses Taqnyat API for SMS delivery.
 */
class Zooboxi_OTP_Auth
{
    const TABLE_NAME      = 'zooboxi_otp_log';
    const OTP_LENGTH      = 4;
    const OTP_EXPIRY_MINS = 3;
    const MAX_ATTEMPTS    = 5;
    const BLOCK_MINS      = 15;
    const RESEND_SECS     = 60;
    const MAX_OTP_PER_PHONE_PER_15M = 3;
    const MAX_OTP_PER_IP_PER_HOUR   = 10;

    /**
     * Create OTP log table on plugin activation.
     */
    public static function create_table(): void
    {
        global $wpdb;
        $table = $wpdb->prefix . self::TABLE_NAME;
        $charset = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE IF NOT EXISTS {$table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            phone VARCHAR(20) NOT NULL,
            otp_hash VARCHAR(255) NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME NOT NULL,
            attempts INT UNSIGNED NOT NULL DEFAULT 0,
            verified TINYINT(1) NOT NULL DEFAULT 0,
            ip_address VARCHAR(45) NOT NULL DEFAULT '',
            PRIMARY KEY (id),
            INDEX idx_phone_expires (phone, expires_at),
            INDEX idx_ip_created (ip_address, created_at)
        ) {$charset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
    }

    /**
     * Register AJAX handlers.
     */
    public static function register_hooks(): void
    {
        add_action('wp_ajax_zooboxi_send_otp', [self::class, 'ajax_send_otp']);
        add_action('wp_ajax_nopriv_zooboxi_send_otp', [self::class, 'ajax_send_otp']);
        add_action('wp_ajax_zooboxi_verify_otp', [self::class, 'ajax_verify_otp']);
        add_action('wp_ajax_nopriv_zooboxi_verify_otp', [self::class, 'ajax_verify_otp']);
        add_action('wp_ajax_zooboxi_complete_profile', [self::class, 'ajax_complete_profile']);
        add_action('wp_ajax_nopriv_zooboxi_complete_profile', [self::class, 'ajax_complete_profile']);
    }

    /**
     * AJAX: Send OTP to phone number.
     */
    public static function ajax_send_otp(): void
    {
        check_ajax_referer('zooboxi_nonce', 'nonce');

        $rawPhone = sanitize_text_field($_POST['phone'] ?? '');
        $phone = self::format_saudi_phone($rawPhone);

        if (!$phone) {
            wp_send_json_error(['message' => __('يرجى إدخال رقم جوال سعودي صالح', 'zooboxi')]);
        }

        $ip = self::get_client_ip();

        // Rate limiting
        if (self::is_rate_limited($phone, $ip)) {
            wp_send_json_error([
                'message' => __('تم تجاوز الحد المسموح. حاول مرة أخرى لاحقاً', 'zooboxi'),
                'code'    => 'rate_limited',
            ]);
        }

        // Generate OTP
        $otp = str_pad((string) random_int(0, 9999), self::OTP_LENGTH, '0', STR_PAD_LEFT);
        $otpHash = wp_hash_password($otp);

        // Store in DB
        global $wpdb;
        $table = $wpdb->prefix . self::TABLE_NAME;
        $expiresAt = gmdate('Y-m-d H:i:s', time() + (self::OTP_EXPIRY_MINS * 60));

        $wpdb->insert($table, [
            'phone'      => $phone,
            'otp_hash'   => $otpHash,
            'created_at' => current_time('mysql', true),
            'expires_at' => $expiresAt,
            'attempts'   => 0,
            'verified'   => 0,
            'ip_address' => $ip,
        ]);

        // Send SMS via Taqnyat
        $message = sprintf('رمز التحقق الخاص بك في ZooBoxi: %s', $otp);
        $result = Zooboxi_Taqnyat::send($phone, $message);

        if (!$result['success']) {
            error_log('[Zooboxi OTP] Failed to send SMS to ' . $phone . ': ' . $result['message']);
            wp_send_json_error(['message' => __('حدث خطأ في إرسال الرمز. حاول مرة أخرى', 'zooboxi')]);
        }

        // Mask phone for display: 05XX XXX XX72
        $displayPhone = self::mask_phone($rawPhone);

        wp_send_json_success([
            'message'      => __('تم إرسال رمز التحقق', 'zooboxi'),
            'display_phone' => $displayPhone,
            'resend_after' => self::RESEND_SECS,
            'expires_in'   => self::OTP_EXPIRY_MINS * 60,
        ]);
    }

    /**
     * AJAX: Verify OTP code.
     */
    public static function ajax_verify_otp(): void
    {
        check_ajax_referer('zooboxi_nonce', 'nonce');

        $rawPhone = sanitize_text_field($_POST['phone'] ?? '');
        $otp = sanitize_text_field($_POST['otp'] ?? '');
        $phone = self::format_saudi_phone($rawPhone);

        if (!$phone || strlen($otp) !== self::OTP_LENGTH) {
            wp_send_json_error(['message' => __('بيانات غير صالحة', 'zooboxi')]);
        }

        global $wpdb;
        $table = $wpdb->prefix . self::TABLE_NAME;

        // Get latest unverified OTP for this phone
        $record = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM {$table} WHERE phone = %s AND verified = 0 ORDER BY created_at DESC LIMIT 1",
            $phone
        ));

        if (!$record) {
            wp_send_json_error(['message' => __('لا يوجد رمز تحقق. أعد الطلب', 'zooboxi'), 'code' => 'no_otp']);
        }

        // Check if blocked (too many attempts)
        if ((int) $record->attempts >= self::MAX_ATTEMPTS) {
            wp_send_json_error([
                'message' => sprintf(
                    __('تم حظرك مؤقتاً لمدة %d دقيقة', 'zooboxi'),
                    self::BLOCK_MINS
                ),
                'code' => 'blocked',
            ]);
        }

        // Check expiry
        if (strtotime($record->expires_at) < time()) {
            wp_send_json_error(['message' => __('انتهت صلاحية الرمز. اطلب رمزاً جديداً', 'zooboxi'), 'code' => 'expired']);
        }

        // Verify OTP
        if (!wp_check_password($otp, $record->otp_hash)) {
            // Increment attempts
            $wpdb->update($table, ['attempts' => $record->attempts + 1], ['id' => $record->id]);
            $remaining = self::MAX_ATTEMPTS - $record->attempts - 1;

            wp_send_json_error([
                'message'   => sprintf(__('الرمز غير صحيح. متبقي %d محاولات', 'zooboxi'), max(0, $remaining)),
                'code'      => 'wrong_otp',
                'remaining' => max(0, $remaining),
            ]);
        }

        // OTP is correct — mark as verified
        $wpdb->update($table, ['verified' => 1], ['id' => $record->id]);

        // Find existing user by phone
        $user = self::find_user_by_phone($phone);

        if ($user) {
            // Existing customer — log them in
            wp_set_current_user($user->ID);
            wp_set_auth_cookie($user->ID, true);

            $name = $user->first_name ?: $user->display_name;

            wp_send_json_success([
                'status'    => 'existing',
                'message'   => sprintf(__('مرحباً %s! 🎉', 'zooboxi'), $name),
                'name'      => $name,
                'user_id'   => $user->ID,
                'new_nonce' => wp_create_nonce('zooboxi_nonce'),
            ]);
        } else {
            // New customer — create account
            $username = 'zb_' . substr($phone, -9); // e.g., zb_500141072
            $email = $username . '@zooboxi.local'; // placeholder — user can set later
            $password = wp_generate_password(16, true, true);

            $userId = wp_create_user($username, $password, $email);
            if (is_wp_error($userId)) {
                wp_send_json_error(['message' => __('حدث خطأ في إنشاء الحساب', 'zooboxi')]);
            }

            // Set role and phone
            $user = new WP_User($userId);
            $user->set_role('customer');

            update_user_meta($userId, 'billing_phone', self::format_local_phone($phone));
            update_user_meta($userId, 'zooboxi_phone_verified', 1);
            update_user_meta($userId, 'zooboxi_registered_via', 'otp');

            // Log them in
            wp_set_current_user($userId);
            wp_set_auth_cookie($userId, true);

            wp_send_json_success([
                'status'    => 'new',
                'message'   => __('أهلاً بك في ZooBoxi! 🎉', 'zooboxi'),
                'user_id'   => $userId,
                'new_nonce' => wp_create_nonce('zooboxi_nonce'),
            ]);
        }
    }

    /**
     * AJAX: Complete new customer profile (name + optional email).
     */
    public static function ajax_complete_profile(): void
    {
        // After OTP login, the browser has old cookies but server set new auth.
        // Verify nonce with the new user context, or fall back to user_id check.
        $nonceValid = wp_verify_nonce($_POST['nonce'] ?? '', 'zooboxi_nonce');
        $userId = (int) ($_POST['user_id'] ?? 0);

        // If nonce invalid, verify user exists and was just created via OTP
        if (!$nonceValid) {
            if (!$userId || !get_user_meta($userId, 'zooboxi_registered_via', true)) {
                wp_send_json_error(['message' => __('جلسة غير صالحة. أعد تحميل الصفحة', 'zooboxi')]);
            }
            // Set current user for this request
            wp_set_current_user($userId);
        }

        if (!is_user_logged_in() && !$userId) {
            wp_send_json_error(['message' => __('يرجى تسجيل الدخول أولاً', 'zooboxi')]);
        }

        $firstName = sanitize_text_field($_POST['first_name'] ?? '');
        $email = sanitize_email($_POST['email'] ?? '');

        if (empty($firstName)) {
            wp_send_json_error(['message' => __('الاسم مطلوب', 'zooboxi')]);
        }

        $userId = get_current_user_id();

        // Final guard — if we still don't have a valid user, bail
        if (!$userId) {
            wp_send_json_error(['message' => __('جلسة غير صالحة. أعد تحميل الصفحة', 'zooboxi')]);
        }

        // Update user data
        $updateData = [
            'ID'           => $userId,
            'first_name'   => $firstName,
            'display_name' => $firstName,
        ];

        if (!empty($email) && is_email($email)) {
            // Check if email is already used
            $existing = get_user_by('email', $email);
            if (!$existing || $existing->ID === $userId) {
                $updateData['user_email'] = $email;
                update_user_meta($userId, 'billing_email', $email);
            }
        }

        wp_update_user($updateData);

        // WooCommerce billing fields
        update_user_meta($userId, 'billing_first_name', $firstName);
        update_user_meta($userId, 'billing_country', 'SA');

        wp_send_json_success([
            'message' => sprintf(__('أهلاً %s! 🎉', 'zooboxi'), $firstName),
            'name'    => $firstName,
        ]);
    }

    /* ── Helpers ──────────────────────────────────── */

    /**
     * Format Saudi phone: 05xx → 9665xx
     */
    public static function format_saudi_phone(string $phone): string
    {
        $phone = preg_replace('/[^0-9]/', '', $phone);

        // Remove leading +
        $phone = ltrim($phone, '+');

        // 05xxxxxxxx → 9665xxxxxxxx
        if (preg_match('/^05\d{8}$/', $phone)) {
            return '966' . substr($phone, 1);
        }
        // 5xxxxxxxx → 9665xxxxxxxx
        if (preg_match('/^5\d{8}$/', $phone)) {
            return '966' . $phone;
        }
        // Already international: 9665xxxxxxxx
        if (preg_match('/^9665\d{8}$/', $phone)) {
            return $phone;
        }
        // With 00: 009665xxxxxxxx
        if (preg_match('/^009665\d{8}$/', $phone)) {
            return substr($phone, 2);
        }

        return '';
    }

    /**
     * Format phone for local display: 966500141072 → 0500141072
     */
    private static function format_local_phone(string $intlPhone): string
    {
        if (str_starts_with($intlPhone, '966')) {
            return '0' . substr($intlPhone, 3);
        }
        return $intlPhone;
    }

    /**
     * Mask phone for display: 0500141072 → 05XX XXX XX72
     */
    private static function mask_phone(string $phone): string
    {
        $phone = preg_replace('/[^0-9]/', '', $phone);
        if (strlen($phone) < 10) return $phone;

        // Show first 2 and last 2 digits
        $local = self::format_local_phone(self::format_saudi_phone($phone));
        if (strlen($local) === 10) {
            return substr($local, 0, 2) . 'XX XXX XX' . substr($local, -2);
        }
        return $phone;
    }

    /**
     * Find WordPress user by billing phone.
     */
    private static function find_user_by_phone(string $intlPhone): ?WP_User
    {
        $localPhone = self::format_local_phone($intlPhone);

        // Search by billing_phone meta
        $users = get_users([
            'meta_query' => [
                'relation' => 'OR',
                ['key' => 'billing_phone', 'value' => $localPhone],
                ['key' => 'billing_phone', 'value' => $intlPhone],
                ['key' => 'billing_phone', 'value' => '0' . substr($intlPhone, 3)],
            ],
            'number' => 1,
        ]);

        return $users[0] ?? null;
    }

    /**
     * Check rate limiting.
     */
    private static function is_rate_limited(string $phone, string $ip): bool
    {
        global $wpdb;
        $table = $wpdb->prefix . self::TABLE_NAME;
        $fifteenMinsAgo = gmdate('Y-m-d H:i:s', time() - 900);
        $oneHourAgo = gmdate('Y-m-d H:i:s', time() - 3600);

        // Check phone rate (3 per 15 minutes)
        $phoneCount = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$table} WHERE phone = %s AND created_at > %s",
            $phone, $fifteenMinsAgo
        ));
        if ($phoneCount >= self::MAX_OTP_PER_PHONE_PER_15M) return true;

        // Check IP rate (10 per hour)
        $ipCount = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$table} WHERE ip_address = %s AND created_at > %s",
            $ip, $oneHourAgo
        ));
        if ($ipCount >= self::MAX_OTP_PER_IP_PER_HOUR) return true;

        // Check if phone is blocked (5 wrong attempts recently)
        $lastRecord = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM {$table} WHERE phone = %s AND verified = 0 ORDER BY created_at DESC LIMIT 1",
            $phone
        ));
        if ($lastRecord && (int) $lastRecord->attempts >= self::MAX_ATTEMPTS) {
            $blockUntil = strtotime($lastRecord->created_at) + (self::BLOCK_MINS * 60);
            if (time() < $blockUntil) return true;
        }

        return false;
    }

    /**
     * Get client IP address.
     */
    private static function get_client_ip(): string
    {
        $headers = ['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_REAL_IP', 'REMOTE_ADDR'];
        foreach ($headers as $header) {
            if (!empty($_SERVER[$header])) {
                $ip = explode(',', $_SERVER[$header])[0];
                return sanitize_text_field(trim($ip));
            }
        }
        return '0.0.0.0';
    }
}
