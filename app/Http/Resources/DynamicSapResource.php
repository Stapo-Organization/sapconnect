<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\ApiTransformer;

class DynamicSapResource extends JsonResource
{
    protected $transformerConfig;

    public function __construct($resource, ApiTransformer $transformerConfig)
    {
        parent::__construct($resource);
        $this->transformerConfig = $transformerConfig;
    }

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $mapping = $this->transformerConfig->mapping ?? [];
        $result = [];

        foreach ($mapping as $rule) {
            $sourceKey = $rule['source'] ?? null;
            $targetKey = $rule['target'] ?? $sourceKey;
            $type = $rule['type'] ?? 'string';

            if (!$sourceKey)
                continue;

            // Handle Nested properties? Not fully supporting deep dot notation for simplicity unless requested.
            // But we can support basic access.
            $value = $this[$sourceKey] ?? null;

            // Casting
            switch ($type) {
                case 'integer':
                    $value = (int) $value;
                    break;
                case 'float':
                    $value = (float) $value;
                    break;
                case 'boolean':
                    $value = (bool) $value;
                    break;
                case 'array':
                    if (isset($rule['sub_mapping']) && is_array($rule['sub_mapping']) && is_array($value)) {
                        $value = collect($value)->map(function ($item) use ($rule) {
                            $mappedItem = [];
                            foreach ($rule['sub_mapping'] as $subRule) {
                                $subSource = $subRule['source'] ?? null;
                                $subTarget = $subRule['target'] ?? $subSource;
                                // Simple type casting for sub-items
                                if (!$subSource)
                                    continue;
                                $subVal = $item[$subSource] ?? null;
                                $mappedItem[$subTarget] = $subVal;
                            }
                            return $mappedItem;
                        })->toArray();
                    } else {
                        $value = is_array($value) ? $value : [];
                    }
                    break;

                case 'collection_extraction':
                    // Extract a single value from a collection based on a condition
                    // Rule expects: 'source' (the collection), 'filter_key', 'filter_value', 'value_key'
                    if (is_array($value)) {
                        $filterKey = $rule['filter_key'] ?? null;
                        $filterValue = $rule['filter_value'] ?? null;
                        $valueKey = $rule['value_key'] ?? null;

                        $foundItem = collect($value)->first(function ($item) use ($filterKey, $filterValue) {
                            return isset($item[$filterKey]) && $item[$filterKey] == $filterValue;
                        });

                        $value = $foundItem[$valueKey] ?? null;
                    } else {
                        $value = null;
                    }
                    break;
            }

            $result[$targetKey] = $value;
        }

        return $result;
    }
}
