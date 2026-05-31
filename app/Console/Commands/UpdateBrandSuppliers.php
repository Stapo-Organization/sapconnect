<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Brand;
use App\Models\Product;
use App\Models\Supplier;

class UpdateBrandSuppliers extends Command
{
    protected $signature = 'sap:update-brand-suppliers';
    protected $description = 'Updates all brands and links them to the correct supplier based on the products Mainsupplier field.';

    public function handle()
    {
        $this->info("Starting brand-supplier linking process based on existing products in the DB...");

        $brands = Brand::all();
        $linkedCount = 0;

        foreach ($brands as $brand) {
            // Find a product with this brand's code that has a mainsupplier
            $product = Product::where('items_group_code', $brand->code)
                              ->whereNotNull('Mainsupplier')
                              ->where('Mainsupplier', '!=', '')
                              ->first();

            if ($product) {
                $supplierCode = $product->Mainsupplier;
                $supplier = Supplier::where('sap_code', $supplierCode)->first();
                if ($supplier) {
                    $exists = \DB::table('brand_supplier')
                                 ->where('brand_id', $brand->id)
                                 ->where('supplier_id', $supplier->id)
                                 ->exists();
                    if (!$exists) {
                        \DB::table('brand_supplier')->insert([
                            'brand_id' => $brand->id,
                            'supplier_id' => $supplier->id,
                        ]);
                        $this->info("Linked Brand {$brand->name} to Supplier {$supplier->name}");
                        $linkedCount++;
                    }
                }
            }
        }

        $this->info("Finished! Successfully linked $linkedCount brand-supplier pairs.");
    }
}
