<?php

use Illuminate\Database\Migrations\Migration;
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
            $newMapping = [];

            // Define fields to move to top
            $topFields = ['CreationDate', 'UpdateDate'];

            // Add top fields first
            foreach ($topFields as $field) {
                // Find existing rule or create new
                $found = false;
                foreach ($mapping as $rule) {
                    if (($rule['source'] ?? '') === $field) {
                        $newMapping[] = $rule;
                        $found = true;
                        break;
                    }
                }
                if (!$found) {
                    $newMapping[] = ['source' => $field, 'target' => $field, 'type' => 'string'];
                }
            }

            // Add remaining fields
            foreach ($mapping as $rule) {
                $source = $rule['source'] ?? '';
                if (!in_array($source, $topFields)) {
                    $newMapping[] = $rule;
                }
            }

            $view->update(['mapping' => $newMapping]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No strict reverse needed for reordering
    }
};
