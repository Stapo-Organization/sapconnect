<?php

namespace Tests\Unit;

use App\Services\Zooboxi\PriceBook;
use Tests\TestCase;

class PriceBookTest extends TestCase
{
    private function sap(array $lists): array
    {
        return array_map(fn ($list, $price) => ['PriceList' => $list, 'Price' => $price, 'Currency' => 'SAR'], array_keys($lists), $lists);
    }

    public function test_retail_is_list_2_with_vat_and_express_adds_five_percent_first(): void
    {
        $q = PriceBook::quote($this->sap([1 => 32.00, 2 => 51.00, 9 => 51.00]));

        $this->assertSame(PriceBook::STATUS_OK, $q['status']);
        $this->assertSame(51.0, $q['base']);
        $this->assertSame(58.65, $q['shelves']['all']);      // 51 × 1.15
        $this->assertSame(61.58, $q['shelves']['express']);  // 51 × 1.05 × 1.15
    }

    public function test_missing_retail_floors_to_wholesale_and_is_flagged(): void
    {
        $q = PriceBook::quote($this->sap([1 => 48.00]));

        $this->assertSame(PriceBook::STATUS_NO_RETAIL, $q['status']);
        $this->assertSame(48.0, $q['base']);
        $this->assertSame(55.2, $q['shelves']['all']);
    }

    public function test_retail_below_wholesale_never_undercuts_the_reseller(): void
    {
        $q = PriceBook::quote($this->sap([1 => 168.00, 2 => 64.97]));

        $this->assertSame(PriceBook::STATUS_BELOW_WHOLESALE, $q['status']);
        $this->assertSame(168.0, $q['base']);
        $this->assertSame(193.2, $q['shelves']['all']);
    }

    public function test_no_usable_price_yields_null_shelves(): void
    {
        $q = PriceBook::quote($this->sap([1 => 0, 2 => 0]));

        $this->assertSame(PriceBook::STATUS_NO_PRICE, $q['status']);
        $this->assertNull($q['shelves']['all']);
        $this->assertNull($q['shelves']['express']);
    }

    public function test_list_price_tolerates_snake_case_and_numeric_keys(): void
    {
        $this->assertSame(4.5, PriceBook::listPrice([['price_list' => 2, 'price' => 4.5]], 2));
        $this->assertSame(4.5, PriceBook::listPrice([2 => ['Price' => 4.5]], 2));
        $this->assertNull(PriceBook::listPrice([['PriceList' => 2, 'Price' => 0]], 2));
        $this->assertNull(PriceBook::listPrice(null, 2));
    }
}
