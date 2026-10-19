<?php

namespace App\Services\ShipGo;

use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * SapClient that asks the Service Layer for big pages
 * (`Prefer: odata.maxpagesize=N`); the default page is 20 rows, which
 * silently truncated ledger statements. GET-only usage; the shared
 * SapClient is left untouched.
 */
class PagedSapClient extends SapClient
{
    public function __construct(private int $pageSize = 5000)
    {
        parent::__construct();
    }

    protected function request(string $method, string $endpoint, array $data = [])
    {
        $this->ensureSession();

        $send = fn () => Http::withOptions(['verify' => $this->sslVerify])
            ->withHeaders(['Prefer' => "odata.maxpagesize={$this->pageSize}"])
            ->withCookies($this->getSessionCookies(), parse_url($this->baseUrl, PHP_URL_HOST))
            ->timeout(180)
            ->{$method}($this->makeUrl($endpoint), $data);

        $response = $send();

        if ($response->status() === 401) {
            Log::warning("SAP Session expired. Re-authenticating and retrying {$endpoint}...");
            $this->forceLogin();
            $response = $send();
        }

        if ($response->failed()) {
            $this->handleError($response);
        }

        return $response->json();
    }
}
