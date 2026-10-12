<?php

namespace App\Services\SFDA;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * READ-ONLY client for the SFDA developer API (developer.sfda.gov.sa — Apigee
 * gateway on apis.sfda.gov.sa:9002, verified live 2026-07-09).
 *
 * Same discipline as SapClient and the Traqo client: we ONLY issue GETs against
 * the PUBLIC food registry (OAuth2 client_credentials → Bearer). Nothing is ever
 * written to SFDA. Used to cross-check our SAP catalog against the official SFDA
 * food registry BY BARCODE; it does NOT touch the private GHAD workflow.
 *
 *   Token : POST {token_url}?grant_type=client_credentials   (HTTP Basic key:secret)
 *   Lookup: GET  {base_url}/product/barcode/{barcode}         (Bearer; digits only)
 *
 * Quirk: the barcode endpoint returns slightly MALFORMED JSON (some string values
 * are unquoted), so lookupFoodByBarcode() parses tolerantly — it keys off the
 * well-formed leading `code` field (200 = registered, 404 = not found) and pulls
 * the fields it needs by regex when strict json_decode fails.
 */
class SfdaClient
{
    protected string $tokenCacheKey = 'sfda_access_token';

    public function isConfigured(): bool
    {
        return filled(Config::get('services.sfda.key'))
            && filled(Config::get('services.sfda.secret'));
    }

    /**
     * client_credentials access token, cached ~23h (SFDA tokens live ~24h).
     * Consumer Key/Secret go as HTTP Basic; grant_type is a QUERY param.
     */
    public function token(bool $fresh = false): string
    {
        if (!$this->isConfigured()) {
            throw new RuntimeException('SFDA credentials missing: set SFDA_CONSUMER_KEY / SFDA_CONSUMER_SECRET in .env.');
        }
        if ($fresh) {
            Cache::forget($this->tokenCacheKey);
        }

        return Cache::remember($this->tokenCacheKey, now()->addHours(23), function () {
            $url = (string) Config::get('services.sfda.token_url') . '?grant_type=client_credentials';

            $resp = Http::withBasicAuth(
                    (string) Config::get('services.sfda.key'),
                    (string) Config::get('services.sfda.secret'),
                )
                ->withOptions(['verify' => (bool) Config::get('services.sfda.ssl_verify', true)])
                ->timeout((int) Config::get('services.sfda.timeout', 30))
                ->post($url);

            if (!$resp->successful() || blank($resp->json('access_token'))) {
                Log::warning('SFDA token request failed', ['status' => $resp->status(), 'body' => $resp->body()]);
                throw new RuntimeException('SFDA token request failed (HTTP ' . $resp->status() . '): ' . $resp->body());
            }

            return (string) $resp->json('access_token');
        });
    }

    /**
     * Authenticated GET against the gateway. $subPath is relative to base_url.
     * Returns ['status'=>int, 'body'=>string]. Retries once with a fresh token
     * if the gateway reports the token unauthorized/expired.
     */
    public function rawGet(string $subPath): array
    {
        $base = rtrim((string) Config::get('services.sfda.base_url'), '/');
        $url  = $base . '/' . ltrim($subPath, '/');

        $resp = $this->authedGet($url, $this->token());
        if ($resp->status() === 401 || str_contains($resp->body(), '401-02')) {
            $resp = $this->authedGet($url, $this->token(true));
        }

        return ['status' => $resp->status(), 'body' => $resp->body()];
    }

    protected function authedGet(string $url, string $token)
    {
        return Http::withToken($token)
            ->acceptJson()
            ->withOptions(['verify' => (bool) Config::get('services.sfda.ssl_verify', true)])
            ->timeout((int) Config::get('services.sfda.timeout', 30))
            ->get($url);
    }

    /**
     * Look up a food product by barcode and normalize the (often-malformed) result.
     *
     * @return array{
     *   registered:bool, code:?int, reference:?string, status_en:?string,
     *   status_ar:?string, closed:?bool, close_date:?string, brand:?string,
     *   company:?string, error:?string, raw:string
     * }
     */
    public function lookupFoodByBarcode(string $barcode): array
    {
        $barcode = trim($barcode);
        $out = [
            'registered' => false, 'code' => null, 'reference' => null,
            'status_en' => null, 'status_ar' => null, 'closed' => null,
            'close_date' => null, 'brand' => null, 'company' => null,
            'error' => null, 'raw' => '',
        ];

        if ($barcode === '' || !ctype_digit($barcode)) {
            $out['error'] = 'non-numeric barcode (SFDA accepts digits only)';
            return $out;
        }

        $resp = $this->rawGet('product/barcode/' . $barcode);
        $body = $out['raw'] = $resp['body'];

        // The API's own `code` field is authoritative and always well-formed.
        $code = null;
        if (preg_match('/"code"\s*:\s*"?(\d{3})/', $body, $m)) {
            $code = (int) $m[1];
        } elseif ($resp['status']) {
            $code = $resp['status'];
        }
        $out['code'] = $code;

        if ($code === 404) {
            return $out; // legitimately not registered
        }
        if ($code === 429) {
            $out['error'] = 'rate limited (spike arrest)';
            return $out;
        }
        if ($code !== 200) {
            $out['error'] = 'HTTP/code ' . $code . ': ' . mb_substr(trim($body), 0, 120);
            return $out;
        }

        // code 200 → registered. Extract the useful fields tolerantly.
        $out['registered'] = true;
        $out['reference']  = $this->field($body, 'referanceNumber') ?? $this->field($body, 'referenceNumber');
        $out['status_en']  = $this->field($body, 'enStatus');
        $out['status_ar']  = $this->field($body, 'arStatus');
        $out['brand']      = $this->field($body, 'brandName');
        $out['company']    = $this->field($body, 'companyName');
        $out['close_date'] = $this->field($body, 'closeDate');
        $closed            = $this->field($body, 'isClosed');
        $out['closed']     = $closed === null ? null : in_array(strtolower($closed), ['true', '1'], true);

        return $out;
    }

    /**
     * Pull a single field's value out of the (possibly malformed) JSON body.
     * Handles both quoted ("v") and unquoted (v,) values, and empty values.
     */
    protected function field(string $body, string $key): ?string
    {
        // Quoted value: "key": "value"
        if (preg_match('/"' . preg_quote($key, '/') . '"\s*:\s*"([^"]*)"/u', $body, $m)) {
            $v = trim($m[1]);
            return $v === '' ? null : $v;
        }
        // Unquoted value up to the next comma or closing brace: "key": value,
        if (preg_match('/"' . preg_quote($key, '/') . '"\s*:\s*([^",}\r\n]+)/u', $body, $m)) {
            $v = trim($m[1]);
            return ($v === '' || strcasecmp($v, 'null') === 0) ? null : $v;
        }
        return null;
    }
}
