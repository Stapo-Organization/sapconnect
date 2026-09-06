<?php

namespace Tests\Feature;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * GET /api/woo/prices is streamed in chunks: the catalogue is ~8k products and
 * building the whole payload in memory used to exhaust PHP and 500 the store's
 * price sync. The JSON shape must stay byte-compatible with what the store
 * plugin already parses.
 */
class WooPricesFeedTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.woo.api_token' => 'store-token']);
    }

    private function product(string $code, array $prices, bool $syncable = true, string $source = 'production'): Product
    {
        return Product::create([
            'item_code' => $code,
            'item_name' => 'Item ' . $code,
            'prices'    => $prices,
            'woo_sync'  => $syncable,
            'source'    => $source,
        ]);
    }

    private function fetch(): array
    {
        $response = $this->withHeader('Authorization', 'Bearer store-token')
            ->get('/api/woo/prices');

        $response->assertOk();

        return json_decode($response->streamedContent(), true);
    }

    public function test_it_streams_valid_json_with_the_expected_shape(): void
    {
        $this->product('P001', [['price_list' => 1, 'price' => 25.5]]);
        $this->product('P002', [['price_list' => 1, 'price' => 10]]);

        $body = $this->fetch();

        $this->assertIsArray($body);
        $this->assertArrayHasKey('timestamp', $body);
        $this->assertCount(2, $body['data']);
        $this->assertSame('P001', $body['data'][0]['item_code']);
        $this->assertSame(25.5, $body['data'][0]['prices'][0]['price']);
        $this->assertArrayHasKey('updated_at', $body['data'][0]);
    }

    public function test_it_excludes_non_syncable_and_non_production_products(): void
    {
        $this->product('KEEP', [['price_list' => 1, 'price' => 5]]);
        $this->product('NO_SYNC', [['price_list' => 1, 'price' => 5]], syncable: false);
        $this->product('NOT_PROD', [['price_list' => 1, 'price' => 5]], source: 'test');

        $codes = array_column($this->fetch()['data'], 'item_code');

        $this->assertSame(['KEEP'], $codes);
    }

    public function test_it_stays_valid_json_across_chunk_boundaries(): void
    {
        // The chunk size is 500 — cross it so the comma joining of two chunks
        // is exercised (a bug there yields unparseable JSON, not a wrong value).
        for ($i = 1; $i <= 620; $i++) {
            $this->product(sprintf('P%04d', $i), [['price_list' => 1, 'price' => $i]]);
        }

        $body = $this->fetch();

        $this->assertCount(620, $body['data']);
        $this->assertSame('P0001', $body['data'][0]['item_code']);
        $this->assertSame('P0620', $body['data'][619]['item_code']);
    }

    public function test_an_empty_catalogue_still_returns_valid_json(): void
    {
        $body = $this->fetch();

        $this->assertSame([], $body['data']);
        $this->assertArrayHasKey('timestamp', $body);
    }
}
