<?php
/**
 * Taqnyat SMS API Wrapper — sends SMS messages via Taqnyat.sa
 * Based on the existing sapconnect TaqnyatService pattern.
 */
class Zooboxi_Taqnyat
{
    const API_BASE = 'https://api.taqnyat.sa';

    /**
     * Send an SMS message.
     *
     * @param string $phone  Recipient phone in international format (966xxxxxxxxx)
     * @param string $body   Message body
     * @param string $sender Sender name (default: from .env)
     * @return array ['success' => bool, 'message' => string, 'data' => array]
     */
    public static function send(string $phone, string $body, string $sender = ''): array
    {
        $token = self::get_token();
        if (empty($token)) {
            return ['success' => false, 'message' => 'Taqnyat token not configured', 'data' => []];
        }

        if (empty($sender)) {
            $sender = self::get_sender();
        }

        $response = wp_remote_post(self::API_BASE . '/v1/messages', [
            'headers' => [
                'Authorization' => 'Bearer ' . $token,
                'Content-Type'  => 'application/json',
            ],
            'body'    => wp_json_encode([
                'recipients' => [$phone],
                'body'       => $body,
                'sender'     => $sender,
            ]),
            'timeout' => 15,
        ]);

        if (is_wp_error($response)) {
            error_log('[Zooboxi Taqnyat] WP Error: ' . $response->get_error_message());
            return ['success' => false, 'message' => $response->get_error_message(), 'data' => []];
        }

        $code = wp_remote_retrieve_response_code($response);
        $result = json_decode(wp_remote_retrieve_body($response), true) ?: [];

        if ($code === 201 || $code === 200) {
            error_log('[Zooboxi Taqnyat] SMS sent to ' . $phone . ' | messageId=' . ($result['messageId'] ?? 'N/A'));
            return ['success' => true, 'message' => 'sent', 'data' => $result];
        }

        error_log('[Zooboxi Taqnyat] Failed: code=' . $code . ' body=' . wp_json_encode($result));
        return ['success' => false, 'message' => $result['message'] ?? 'Unknown error', 'data' => $result];
    }

    /**
     * Check Taqnyat account balance.
     */
    public static function check_balance(): array
    {
        $token = self::get_token();
        if (empty($token)) {
            return ['success' => false, 'balance' => 0];
        }

        $response = wp_remote_get(self::API_BASE . '/account/balance', [
            'headers' => ['Authorization' => 'Bearer ' . $token],
            'timeout' => 10,
        ]);

        if (is_wp_error($response)) {
            return ['success' => false, 'balance' => 0];
        }

        $result = json_decode(wp_remote_retrieve_body($response), true) ?: [];
        return [
            'success' => ($result['statusCode'] ?? 0) === 200,
            'balance' => (float) ($result['balance'] ?? 0),
            'status'  => $result['accountStatus'] ?? 'unknown',
        ];
    }

    /**
     * Get bearer token from .env file in WP root.
     */
    private static function get_token(): string
    {
        static $token = null;
        if ($token !== null) return $token;

        // Try WP option first
        $token = get_option('zooboxi_taqnyat_token', '');
        if (!empty($token)) return $token;

        // Try .env file in WP root
        $env_file = ABSPATH . '.env';
        if (file_exists($env_file)) {
            $lines = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (str_starts_with(trim($line), '#')) continue;
                if (str_starts_with($line, 'ZOOBOXI_TAQNYAT_TOKEN=')) {
                    $token = trim(substr($line, strlen('ZOOBOXI_TAQNYAT_TOKEN=')));
                    return $token;
                }
            }
        }

        $token = '';
        return $token;
    }

    /**
     * Get sender name from .env or option.
     */
    private static function get_sender(): string
    {
        static $sender = null;
        if ($sender !== null) return $sender;

        $sender = get_option('zooboxi_taqnyat_sender', '');
        if (!empty($sender)) return $sender;

        $env_file = ABSPATH . '.env';
        if (file_exists($env_file)) {
            $lines = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (str_starts_with(trim($line), '#')) continue;
                if (str_starts_with($line, 'ZOOBOXI_TAQNYAT_SENDER=')) {
                    $sender = trim(substr($line, strlen('ZOOBOXI_TAQNYAT_SENDER=')));
                    return $sender;
                }
            }
        }

        $sender = 'PPTCO';
        return $sender;
    }
}
