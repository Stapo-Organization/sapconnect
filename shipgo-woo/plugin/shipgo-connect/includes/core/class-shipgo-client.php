<?php
defined('ABSPATH') || exit;

/**
 * Thin HTTP client to the ShipGo /v1 API, authenticated with the store API key
 * (Bearer sk_…). Returns a normalized result so callers can branch on ok/status.
 */
class ShipGo_Client {

    /** @return array{ok:bool,status:int,data:mixed,error:?string} */
    public static function post(string $path, array $body, ?string $idempotencyKey = null): array {
        return self::request('POST', $path, $body, $idempotencyKey);
    }

    /** @return array{ok:bool,status:int,data:mixed,error:?string} */
    public static function get(string $path): array {
        return self::request('GET', $path, null, null);
    }

    private static function request(string $method, string $path, ?array $body, ?string $idem): array {
        $base = ShipGo_Settings::base_url();
        $key  = ShipGo_Settings::api_key();
        if ($base === '' || $key === '') {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'ShipGo غير مُهيّأ (الرابط/المفتاح مفقود).'];
        }

        $headers = [
            'Authorization' => 'Bearer ' . $key,
            'Accept'        => 'application/json',
        ];
        $args = ['method' => $method, 'headers' => $headers, 'timeout' => 15];
        if ($body !== null) {
            $headers['Content-Type'] = 'application/json';
            if ($idem) {
                $headers['Idempotency-Key'] = $idem;
            }
            $args['headers'] = $headers;
            $args['body'] = wp_json_encode($body);
        }

        $res = wp_remote_request($base . $path, $args);
        if (is_wp_error($res)) {
            return ['ok' => false, 'status' => 0, 'data' => null, 'error' => $res->get_error_message()];
        }
        $code = (int) wp_remote_retrieve_response_code($res);
        $raw  = wp_remote_retrieve_body($res);
        $json = json_decode($raw, true);
        // ShipGo wraps success as { data, meta }; errors are RFC 9457 problem docs.
        $data = is_array($json) && array_key_exists('data', $json) ? $json['data'] : $json;
        if ($code >= 200 && $code < 300) {
            return ['ok' => true, 'status' => $code, 'data' => $data, 'error' => null];
        }
        $detail = is_array($json) ? ($json['detail'] ?? $json['title'] ?? null) : null;
        return ['ok' => false, 'status' => $code, 'data' => $data, 'error' => $detail ?: ('HTTP ' . $code)];
    }
}
