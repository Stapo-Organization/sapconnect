<?php

namespace App\Services\SAP;

class SapPayloadTransformer
{
    /**
     * Groups flat-mapped rows into complex structured documents based on root keys.
     *
     * @param array $mappedData
     * @return array
     */
    public function groupToDocuments(array $mappedData): array
    {
        $groupedDocs = [];
        
        foreach ($mappedData as $data) {
            $rootKeys = [];
            foreach ($data as $k => $v) {
                if (!is_array($v)) {
                    $rootKeys[$k] = $v;
                }
            }
            ksort($rootKeys);
            $sig = json_encode($rootKeys);
            $groupedDocs[$sig][] = $data;
        }

        return $groupedDocs;
    }

    /**
     * Merges multiple flat-mapped rows into a structured document.
     * Handles 2 levels of nesting (Lines -> Batches).
     *
     * @param array $rows
     * @return array
     */
    public function mergeRowsToDocument(array $rows): array
    {
        if (empty($rows)) {
            return [];
        }

        $root = $this->extractRootFields($rows[0]);

        foreach ($rows[0] as $key => $val) {
            if (is_array($val)) {
                $listKey = $key;
                $groupedItems = $this->groupListItems($rows, $listKey);
                
                $groupedItems = $this->cleanAndFormatNestedLists($groupedItems);
                
                $root[$listKey] = array_values($groupedItems);
            }
        }

        return $this->applyResourceSpecificFixes($root);
    }

    private function extractRootFields(array $firstRow): array
    {
        $root = [];
        foreach ($firstRow as $key => $val) {
            if (!is_array($val)) {
                $root[$key] = $val;
            }
        }
        return $root;
    }

    private function groupListItems(array $rows, string $listKey): array
    {
        $groupedItems = [];

        foreach ($rows as $row) {
            if (!isset($row[$listKey])) {
                continue;
            }

            $lineData = $row[$listKey];
            $groupKey = $lineData['ItemCode'] ?? $lineData['CardCode'] ?? json_encode($lineData);

            if (!isset($groupedItems[$groupKey])) {
                $groupedItems[$groupKey] = $lineData;
                foreach ($lineData as $lk => $lv) {
                    if (is_array($lv)) {
                        $groupedItems[$groupKey][$lk] = [$lv];
                    }
                }
            } else {
                foreach ($lineData as $lk => $lv) {
                    if (is_array($lv)) {
                        $groupedItems[$groupKey][$lk][] = $lv;
                    }
                }
            }
        }

        return $groupedItems;
    }

    private function cleanAndFormatNestedLists(array $groupedItems): array
    {
        foreach ($groupedItems as &$gItem) {
            if (isset($gItem['BatchNumbers']) && is_array($gItem['BatchNumbers'])) {
                $gItem['CountedQuantity'] = $this->calculateBatchQuantitySum($gItem['BatchNumbers']);
                $gItem['BatchNumbers'] = array_values(array_filter($gItem['BatchNumbers'], function ($b) {
                    return !empty($b['BatchNumber']);
                }));

                if (empty($gItem['BatchNumbers'])) {
                    unset($gItem['BatchNumbers']);
                }
            }

            if (isset($gItem['SerialNumbers']) && is_array($gItem['SerialNumbers'])) {
                $gItem['SerialNumbers'] = array_values(array_filter($gItem['SerialNumbers'], function ($s) {
                    return !empty($s['InternalSerialNumber']) || !empty($s['SystemSerialNumber']) || !empty($s['SerialNumber']);
                }));

                if (empty($gItem['SerialNumbers'])) {
                    unset($gItem['SerialNumbers']);
                }
            }
        }
        
        return $groupedItems;
    }

    private function calculateBatchQuantitySum(array $batches): float
    {
        $sum = 0;
        foreach ($batches as $b) {
            $sum += (float) ($b['Quantity'] ?? 0);
        }
        return $sum;
    }

    private function applyResourceSpecificFixes(array $root): array
    {
        if (isset($root['InventoryCountingLines']) && is_array($root['InventoryCountingLines'])) {
            $whsCode = $root['WarehouseCode'] ?? $root['WhsCode'] ?? null;
            $uomCode = $root['UoMCode'] ?? $root['UomCode'] ?? null;

            foreach ($root['InventoryCountingLines'] as &$line) {
                if ($whsCode && !isset($line['WarehouseCode'])) {
                    $line['WarehouseCode'] = $whsCode;
                }
                if (!isset($line['UoMCode'])) {
                    $line['UoMCode'] = $uomCode ?? 'PC';
                }
                
                $line['Counted'] = 'tYES';

                if (isset($line['BatchNumbers'])) {
                    $line['InventoryCountingBatchNumbers'] = $line['BatchNumbers'];
                    unset($line['BatchNumbers']);
                }
            }

            unset($root['WhsCode'], $root['UoMCode'], $root['UomCode']);
        }

        return $root;
    }
}
