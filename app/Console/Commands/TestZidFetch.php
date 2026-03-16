<?php

namespace App\Console\Commands;

use App\Models\ZidStore;
use App\Services\Zid\ZidApiService;
use Illuminate\Console\Command;

class TestZidFetch extends Command
{
    protected $signature = 'oms:test-fetch';
    protected $description = 'Test fetching orders from Zid for Zuboxy store';

    public function handle()
    {
        $this->info("Looking for Zuboxy store...");
        $store = ZidStore::where('name', 'like', '%Zuboxy%')
            ->orWhere('name', 'like', '%زوبوكسي%')
            ->orWhere('store_id', '1852894')
            ->first();

        if (!$store) {
            $this->error("Zuboxy store not found in DB!");
            // Try to create it if missing? No, seeder should have run.
            return;
        }

        $this->info("Found Store: {$store->name} (ID: {$store->store_id})");

        $this->info("Fetching orders...");
        try {
            $service = new ZidApiService();
            $data = $service->getOrders($store, ['per_page' => 10]);

            $orders = $data['orders'] ?? [];
            $count = count($orders);
            $total = $data['pagination']['total'] ?? 'Unknown';

            $this->info("Success! Fetched {$count} orders. Total available: {$total}");

            foreach ($orders as $order) {
                $this->line("- Order #{$order['id']} | Status: " . ($order['order_status']['name'] ?? 'N/A') . " | Total: " . ($order['order_total'] ?? 0));
            }

        } catch (\Exception $e) {
            $this->error("API Error: " . $e->getMessage());
        }
    }
}
