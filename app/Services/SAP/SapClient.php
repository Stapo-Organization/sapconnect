<?php

namespace App\Services\SAP;

use App\Exceptions\SapException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SapClient
{
    protected $baseUrl;
    protected $companyDb;
    protected $username;
    protected $password;
    protected $sslVerify;
    protected $sessionTimeout;

    protected $sessionCacheKey;
    protected $routeIdCacheKey;

    public function __construct()
    {
        $this->baseUrl = Config::get('sap.url');

        // Priority: Session -> Config -> .env
        $this->companyDb = session('sap_company_db', Config::get('sap.company_db'));

        $this->resolveCredentials();

        $this->sslVerify = Config::get('sap.ssl_verify', false);
        $this->sessionTimeout = Config::get('sap.session_timeout', 29) * 60; // Convert to seconds

        // Dynamic Cache Keys based on DB
        $dbHash = md5($this->companyDb);
        $this->sessionCacheKey = 'sap_b1_session_' . $dbHash;
        $this->routeIdCacheKey = 'sap_route_id_' . $dbHash;
    }

    public function setCompanyDb(string $db)
    {
        $this->companyDb = $db;
        $this->resolveCredentials();

        // Re-generate cache keys
        $dbHash = md5($this->companyDb);
        $this->sessionCacheKey = 'sap_b1_session_' . $dbHash;
        $this->routeIdCacheKey = 'sap_route_id_' . $dbHash;
    }

    protected function resolveCredentials()
    {
        $dbSpecificConfigs = Config::get('sap.databases', []);

        if (array_key_exists($this->companyDb, $dbSpecificConfigs)) {
            $this->username = $dbSpecificConfigs[$this->companyDb]['username'];
            $this->password = $dbSpecificConfigs[$this->companyDb]['password'];

            // Allow URL override
            if (isset($dbSpecificConfigs[$this->companyDb]['url'])) {
                $this->baseUrl = $dbSpecificConfigs[$this->companyDb]['url'];
            }
        } else {
            $this->username = Config::get('sap.username');
            $this->password = Config::get('sap.password');
        }
    }

    public function getCompanyDb()
    {
        return $this->companyDb;
    }

    /**
     * Send a GET request to SAP Service Layer.
     */
    public function get(string $resource, array $queryParams = [])
    {
        return $this->request('get', $resource, $queryParams);
    }

    /**
     * Send a POST request to SAP Service Layer.
     */
    public function post(string $resource, array $data = [])
    {
        return $this->request('post', $resource, $data);
    }

    /**
     * Send a PATCH request to SAP Service Layer.
     */
    public function patch(string $resource, string $id, array $data = [])
    {
        // For SAP, the ID is usually part of the URL, e.g., Orders(123)
        // If passing standard resource/ID, we append.
        // If the resource already contains permission, handle accordingly.

        // Example: patch('Orders', 123, [...]) -> Orders(123)
        // Or if $resource is "Orders(123)", $id can be ignored or null.

        $url = str_contains($resource, '(') ? $resource : "{$resource}('{$id}')";
        return $this->request('patch', $url, $data);
    }

    /**
     * Core request handler with Session Management.
     */
    protected function request(string $method, string $endpoint, array $data = [])
    {
        $this->ensureSession();

        $cookies = $this->getSessionCookies();

        $response = Http::withOptions(['verify' => $this->sslVerify])
                    ->withCookies($cookies, parse_url($this->baseUrl, PHP_URL_HOST))
                    ->timeout(60)
            ->{$method}($this->makeUrl($endpoint), $data);

        // Handle Session Expiry (401)
        if ($response->status() === 401) {
            Log::warning("SAP Session expired. Re-authenticating and retrying {$endpoint}...");
            $this->forceLogin();

            // Retry once
            $cookies = $this->getSessionCookies();
            $response = Http::withOptions(['verify' => $this->sslVerify])
                        ->withCookies($cookies, parse_url($this->baseUrl, PHP_URL_HOST))
                        ->timeout(60)
                ->{$method}($this->makeUrl($endpoint), $data);
        }

        if ($response->failed()) {
            $this->handleError($response);
        }

        return $response->json();
    }

    /**
     * Check if valid session exists, if not, login.
     */
    protected function ensureSession()
    {
        if (!Cache::has($this->sessionCacheKey)) {
            $this->login();
        }
    }

    /**
     * Force a fresh login.
     */
    protected function forceLogin()
    {
        Cache::forget($this->sessionCacheKey);
        Cache::forget($this->routeIdCacheKey);
        $this->login();
    }

    /**
     * Perform Login to SAP Service Layer.
     */
    protected function login()
    {
        Log::info("Attempting login to SAP Service Layer ({$this->companyDb}) at {$this->baseUrl}...");

        $loginData = [
            'CompanyDB' => $this->companyDb,
            'UserName' => $this->username,
            'Password' => $this->password,
        ];

        // Log masked credentials for debugging
        Log::info("SAP Login Payload: " . json_encode([
            'CompanyDB' => $loginData['CompanyDB'],
            'UserName' => $loginData['UserName'],
            'Password' => '********'
        ]));

        $response = Http::withOptions(['verify' => $this->sslVerify])
            ->timeout(30)
            ->post($this->makeUrl('Login'), $loginData);

        if ($response->failed()) {
            Log::error("SAP Login Failed: " . $response->body());
            throw new SapException("Failed to connect to SAP Service Layer [{$this->companyDb}].", $response->status(), $response->json());
        }

        $body = $response->json();
        $sessionId = $body['SessionId'] ?? null;

        // Important: Get ROUTEID and B1SESSION from cookies if available, or body.
        // SAP SL usually returns B1SESSION in body, but specifically requests cookies for subsequent calls.

        // Capture Cookies
        $cookies = $response->cookies();
        $cookieJar = [];

        foreach ($cookies as $cookie) {
            $cookieJar[$cookie->getName()] = $cookie->getValue();
        }

        // Fallback if cookies not in jar but in body (rare but possible in some SL versions)
        if (empty($cookieJar['B1SESSION']) && $sessionId) {
            $cookieJar['B1SESSION'] = $sessionId;
        }

        if (empty($cookieJar['B1SESSION'])) {
            throw new SapException("No B1SESSION received from SAP.");
        }

        // Store Session & RouteID in Redis
        // We store the whole array of cookies to pass back to Guzzle
        Cache::put($this->sessionCacheKey, $cookieJar, $this->sessionTimeout);

        Log::info("SAP Login Successful [{$this->companyDb}]. Session cached.");
    }

    /**
     * format cookies for Guzzle
     */
    protected function getSessionCookies()
    {
        return Cache::get($this->sessionCacheKey, []);
    }

    protected function makeUrl($endpoint)
    {
        // Remove leading slash if present to avoid double slash
        $endpoint = ltrim($endpoint, '/');
        return "{$this->baseUrl}/{$endpoint}";
    }

    protected function handleError($response)
    {
        $body = $response->json();
        $error = $body['error'] ?? [];
        $message = $error['message']['value'] ?? 'Unknown SAP Error';

        Log::error("SAP Error [{$response->status()}]: {$message}", ['details' => $body]);

        throw new SapException($message, $response->status(), $body);
    }
}
