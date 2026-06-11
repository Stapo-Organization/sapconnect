<?php

namespace App\Services\Google;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Minimal, dependency-free Google Sheets client using a service-account JWT
 * (RS256 via openssl) → OAuth2 access token → Sheets REST v4. No google/apiclient
 * package, so nothing to install on the diverged prod checkout.
 *
 * Scope: read + write values. Credentials JSON path lives in config/services.php.
 */
class GoogleSheetsClient
{
    protected array $creds = [];

    public function __construct()
    {
        $path = (string) config('services.google_sheets.credentials');
        if ($path !== '' && !str_starts_with($path, '/')) {
            $path = base_path($path);
        }
        if ($path && is_file($path)) {
            $this->creds = json_decode((string) file_get_contents($path), true) ?: [];
        }
    }

    public function configured(): bool
    {
        return !empty($this->creds['client_email']) && !empty($this->creds['private_key']);
    }

    public function clientEmail(): ?string
    {
        return $this->creds['client_email'] ?? null;
    }

    /** Read a range, e.g. "Sheet1!U1:U500". Returns a 2D array of rows. */
    public function getValues(string $spreadsheetId, string $range): array
    {
        $token = $this->accessToken();
        if (!$token) {
            return [];
        }
        $res = Http::withToken($token)
            ->get("https://sheets.googleapis.com/v4/spreadsheets/{$spreadsheetId}/values/" . rawurlencode($range));
        if (!$res->successful()) {
            Log::warning('GoogleSheets getValues failed', ['range' => $range, 'status' => $res->status(), 'body' => $res->json()]);
            return [];
        }
        return $res->json('values', []);
    }

    /** Write a 2D array into a range (USER_ENTERED so dates are parsed). */
    public function updateValues(string $spreadsheetId, string $range, array $values): bool
    {
        $token = $this->accessToken();
        if (!$token) {
            return false;
        }
        $res = Http::withToken($token)
            ->put(
                "https://sheets.googleapis.com/v4/spreadsheets/{$spreadsheetId}/values/" . rawurlencode($range) . '?valueInputOption=USER_ENTERED',
                ['values' => $values]
            );
        if (!$res->successful()) {
            Log::warning('GoogleSheets updateValues failed', ['range' => $range, 'status' => $res->status(), 'body' => $res->json()]);
            return false;
        }
        return true;
    }

    /**
     * Write many disjoint cell ranges in ONE request (so we touch only matched
     * cells, never whole columns — protecting existing manual data).
     * $data = [ ['range' => "Tab!C5", 'values' => [['2026-07-15']]], ... ]
     */
    public function batchUpdate(string $spreadsheetId, array $data): bool
    {
        if (empty($data)) {
            return true;
        }
        $token = $this->accessToken();
        if (!$token) {
            return false;
        }
        $res = Http::withToken($token)
            ->post("https://sheets.googleapis.com/v4/spreadsheets/{$spreadsheetId}/values:batchUpdate", [
                'valueInputOption' => 'USER_ENTERED',
                'data'             => $data,
            ]);
        if (!$res->successful()) {
            Log::warning('GoogleSheets batchUpdate failed', ['status' => $res->status(), 'body' => $res->json()]);
            return false;
        }
        return true;
    }

    /** Title of the first tab (or the gid-0 tab) — used when no tab configured. */
    public function firstTabTitle(string $spreadsheetId): ?string
    {
        return $this->firstSheetProps($spreadsheetId)['title'] ?? null;
    }

    /** First tab's props: ['title','sheetId','columns','rows']. */
    public function firstSheetProps(string $spreadsheetId): array
    {
        $token = $this->accessToken();
        if (!$token) {
            return [];
        }
        $res = Http::withToken($token)
            ->get("https://sheets.googleapis.com/v4/spreadsheets/{$spreadsheetId}?fields=sheets.properties");
        $p = $res->json('sheets.0.properties');
        if (!$p) {
            return [];
        }
        return [
            'title'   => $p['title'] ?? null,
            'sheetId' => $p['sheetId'] ?? 0,
            'columns' => $p['gridProperties']['columnCount'] ?? 0,
            'rows'    => $p['gridProperties']['rowCount'] ?? 0,
        ];
    }

    /** Append empty columns to the end of the grid (non-destructive). */
    public function appendColumns(string $spreadsheetId, int $sheetId, int $count): bool
    {
        if ($count <= 0) {
            return true;
        }
        $token = $this->accessToken();
        if (!$token) {
            return false;
        }
        $res = Http::withToken($token)
            ->post("https://sheets.googleapis.com/v4/spreadsheets/{$spreadsheetId}:batchUpdate", [
                'requests' => [[
                    'appendDimension' => ['sheetId' => $sheetId, 'dimension' => 'COLUMNS', 'length' => $count],
                ]],
            ]);
        if (!$res->successful()) {
            Log::warning('GoogleSheets appendColumns failed', ['status' => $res->status(), 'body' => $res->json()]);
            return false;
        }
        return true;
    }

    /** Service-account JWT → access token, cached just under its 1h lifetime. */
    protected function accessToken(): ?string
    {
        if (!$this->configured()) {
            Log::warning('GoogleSheetsClient: missing/invalid credentials JSON');
            return null;
        }

        $key = 'google_sheets_token_' . md5($this->creds['client_email']);
        if ($cached = Cache::get($key)) {
            return $cached;
        }

        $now = time();
        $b64 = fn ($d) => rtrim(strtr(base64_encode($d), '+/', '-_'), '=');
        $segments = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']))
            . '.' . $b64(json_encode([
                'iss'   => $this->creds['client_email'],
                'scope' => 'https://www.googleapis.com/auth/spreadsheets',
                'aud'   => $this->creds['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                'iat'   => $now,
                'exp'   => $now + 3600,
            ]));

        if (!openssl_sign($segments, $signature, $this->creds['private_key'], 'sha256WithRSAEncryption')) {
            Log::warning('GoogleSheetsClient: JWT signing failed');
            return null;
        }
        $jwt = $segments . '.' . $b64($signature);

        $res = Http::asForm()->post($this->creds['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]);

        $token = $res->json('access_token');
        if (!$token) {
            Log::warning('GoogleSheetsClient: token exchange failed', ['status' => $res->status(), 'body' => $res->json()]);
            return null;
        }
        Cache::put($key, $token, 3300);
        return $token;
    }
}
