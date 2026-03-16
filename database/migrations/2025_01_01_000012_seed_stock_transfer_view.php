<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use App\Models\ApiTransformer;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        ApiTransformer::create([
            'resource' => 'StockTransfers',
            'name' => 'default',
            'is_active' => true,
            'mapping' => [
                    ['source' => 'DocEntry', 'target' => 'DocEntry', 'type' => 'integer'],
                    ['source' => 'DocNum', 'target' => 'DocNum', 'type' => 'integer'],
                    ['source' => 'FromWarehouse', 'target' => 'FromWarehouse', 'type' => 'string'],
                    ['source' => 'ToWarehouse', 'target' => 'ToWarehouse', 'type' => 'string'],
                    ['source' => 'DocDate', 'target' => 'DocDate', 'type' => 'string'],
                    ['source' => 'DocumentStatus', 'target' => 'DocumentStatus', 'type' => 'string'],
                    [
                        'source' => 'StockTransferLines',
                        'target' => 'StockTransferLines',
                        'type' => 'array',
                        'sub_mapping' => [
                                ['source' => 'ItemCode', 'target' => 'ItemCode', 'type' => 'string'],
                                ['source' => 'ItemDescription', 'target' => 'ItemDescription', 'type' => 'string'],
                                ['source' => 'Quantity', 'target' => 'Quantity', 'type' => 'float'],
                                ['source' => 'FromWarehouseCode', 'target' => 'FromWarehouseCode', 'type' => 'string'],
                                ['source' => 'WarehouseCode', 'target' => 'WarehouseCode', 'type' => 'string'],
                                ['source' => 'LineStatus', 'target' => 'LineStatus', 'type' => 'string'],
                            ]
                    ]
                ]
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        ApiTransformer::where('resource', 'StockTransfers')->where('name', 'default')->delete();
    }
};
