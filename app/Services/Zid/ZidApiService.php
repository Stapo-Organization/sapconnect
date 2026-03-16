<?php

namespace App\Services\Zid;

use App\Models\ZidStore;
use Illuminate\Support\Facades\Http;

class ZidApiService
{
    protected string $baseUrl = 'https://api.zid.sa/v1';

    public function getOrders(ZidStore $store, array $params = [])
    {
        // Default params based on user request example
        $queryParams = array_merge([
            'payload_type' => 'default',
            'page' => 1,
            'per_page' => 50,
        ], $params);

        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $store->authorization_token,
            'X-Manager-Token' => $store->x_manager_token,
            'Accept' => 'application/json',
            'Accept-Language' => 'ar',
        ])->get("{$this->baseUrl}/managers/store/orders", $queryParams);

        if ($response->successful()) {
            return $response->json();
        }

        throw new \Exception("Failed to fetch orders from Zid: " . $response->body());
    }
}
