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
        $view = ApiTransformer::where('resource', 'StockTransfers')->where('name', 'default')->first();

        if ($view) {
            $mapping = $view->mapping;

            // Append new fields if they don't exist
            $mapping[] = ['source' => 'CreationDate', 'target' => 'CreationDate', 'type' => 'string'];
            $mapping[] = ['source' => 'UpdateDate', 'target' => 'UpdateDate', 'type' => 'string'];

            $view->update(['mapping' => $mapping]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Ideally remove them, but for quick iteration we can skip strict down here or re-seed
    }
};
