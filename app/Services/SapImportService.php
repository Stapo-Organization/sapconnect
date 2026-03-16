<?php

namespace App\Services;

use App\Models\SapImport;
use App\Models\ApiLog;
use App\Services\SAP\SapClient;
use App\Services\SAP\CsvParserService;
use App\Services\SAP\SapPayloadTransformer;
use Illuminate\Support\Facades\Log;

class SapImportService
{
    protected $sap;
    protected $csvParser;
    protected $payloadTransformer;

    public function __construct(SapClient $sap, CsvParserService $csvParser, SapPayloadTransformer $payloadTransformer)
    {
        $this->sap = $sap;
        $this->csvParser = $csvParser;
        $this->payloadTransformer = $payloadTransformer;
    }

    public function setDatabase($db)
    {
        $this->sap->setCompanyDb($db);
    }

    public function process(SapImport $import, $filePath, array $params = [], $dryRun = false)
    {
        $parsedData = $this->csvParser->parse($filePath);
        $mappedData = $this->csvParser->mapData($parsedData['header'], $parsedData['rows'], $import->mapping);

        if (!empty($mappedData)) {
            Log::info("SapImportService: First Mapped Item", ['item' => $mappedData[0]]);
        }

        if ($import->import_mode === 'Single') {
            return $this->processSingleItems($import, $mappedData, $params, $dryRun);
        } elseif ($import->import_mode === 'Document') {
            return $this->processDocuments($import, $mappedData, $params, $dryRun);
        }

        return ['count' => 0, 'preview' => [], 'skipped' => []];
    }

    protected function processSingleItems(SapImport $import, array $mappedData, array $params, bool $dryRun): array
    {
        $successCount = 0;
        $previewPayloads = [];

        foreach ($mappedData as $payload) {
            foreach ($params as $k => $v) {
                data_set($payload, $k, $v);
            }

            if ($dryRun) {
                $previewPayloads[] = $payload;
                continue;
            }

            try {
                $response = $this->sap->post($import->resource, $payload);
                $this->logActivity($import->resource, $payload, $response, 201);
                $successCount++;
            } catch (\Throwable $e) {
                $this->logActivity($import->resource, $payload, ['error' => $e->getMessage()], 500);
            }
        }

        if ($dryRun) {
            return ['count' => 0, 'preview' => $previewPayloads];
        }

        return ['count' => $successCount, 'skipped' => []];
    }

    protected function processDocuments(SapImport $import, array $mappedData, array $params, bool $dryRun): array
    {
        $groupedDocs = $this->payloadTransformer->groupToDocuments($mappedData);
        
        $count = 0;
        $previewPayloads = [];
        $skippedItems = [];

        foreach ($groupedDocs as $docRows) {
            $payload = $this->payloadTransformer->mergeRowsToDocument($docRows);

            foreach ($params as $k => $v) {
                data_set($payload, $k, $v);
            }

            $this->applyInventoryCountingLogic($import, $payload, $params);

            try {
                $this->enrichBatchData($import, $payload, $skippedItems);

                if (str_contains($import->resource, 'InventoryCountings') && empty($payload['InventoryCountingLines'])) {
                    Log::warning("SapImportService: Skipping Document because all lines were removed due to batch validation.");
                    continue;
                }

                if ($dryRun) {
                    $previewPayloads[] = $payload;
                    continue;
                }

                $response = $this->sap->post($import->resource, $payload);
                $this->logActivity($import->resource, $payload, $response, 201);
                $count++;
            } catch (\Throwable $e) {
                if ($dryRun) {
                    throw $e;
                }
                $this->logActivity($import->resource, $payload, ['error' => $e->getMessage()], 500);
                throw $e;
            }
        }

        if ($dryRun) {
            return ['count' => 0, 'preview' => $previewPayloads];
        }

        return ['count' => $count, 'skipped' => $skippedItems ?? []];
    }

    protected function applyInventoryCountingLogic(SapImport $import, array &$payload, array $params)
    {
        if (str_contains($import->resource, 'InventoryCountings') && isset($payload['InventoryCountingLines'])) {
            $rootCostingCode = $payload['CostingCode'] ?? null;

            if (isset($payload['CostingCode'])) {
                unset($payload['CostingCode']);
            }

            foreach ($payload['InventoryCountingLines'] as &$line) {
                if ($rootCostingCode && !isset($line['CostingCode'])) {
                    $line['CostingCode'] = $rootCostingCode;
                }

                if (isset($line['BatchNumbers']) && is_array($line['BatchNumbers'])) {
                    $sum = 0;
                    foreach ($line['BatchNumbers'] as $batch) {
                        $sum += (float) ($batch['Quantity'] ?? 0);
                    }
                    $line['CountedQuantity'] = $sum;
                }
            }
        }
    }

    protected function isBatchManaged($itemCode)
    {
        try {
            $data = $this->sap->get("Items('$itemCode')", [
                '$select' => 'ManageBatchNumbers'
            ]);
            return ($data['ManageBatchNumbers'] ?? 'tNO') === 'tYES';
        } catch (\Exception $e) {
            return false;
        }
    }

    protected function enrichBatchData(SapImport $import, array &$payload, array &$skippedItems = [])
    {
        if (!$import->auto_batch_enrichment) {
            return;
        }

        if (str_contains($import->resource, 'InventoryCountings') && isset($payload['InventoryCountingLines'])) {
            $linesToRemove = [];

            foreach ($payload['InventoryCountingLines'] as $key => &$line) {
                $batches = $line['InventoryCountingBatchNumbers'] ?? $line['BatchNumbers'] ?? [];

                if (empty($batches)) {
                    $itemCode = $line['ItemCode'] ?? null;
                    if ($itemCode) {
                        try {
                            $countedQty = $line['CountedQuantity'] ?? 0;
                            $bestBatch = $this->fetchBestBatch($itemCode, $countedQty);

                            if ($bestBatch) {
                                $line['InventoryCountingBatchNumbers'] = [
                                    [
                                        'BatchNumber' => $bestBatch['BatchNumber'],
                                        'Quantity' => $countedQty,
                                        'ExpiryDate' => $bestBatch['ExpiryDate'] ?? null,
                                    ]
                                ];
                                if (isset($line['BatchNumbers']))
                                    unset($line['BatchNumbers']);

                                Log::info("SapImportService: Auto-Enriched Item $itemCode with Batch {$bestBatch['BatchNumber']}");
                            } else {
                                if ($this->isBatchManaged($itemCode)) {
                                    $reason = "Insufficient Batch Quantity (Count: $countedQty) or No Batch Found";
                                    Log::warning("SapImportService: Skipping Item $itemCode. Reason: $reason");

                                    $skippedItems[] = [
                                        'ItemCode' => $itemCode,
                                        'Reason' => $reason
                                    ];
                                    $linesToRemove[] = $key;
                                } else {
                                    Log::info("SapImportService: Item $itemCode is not Batch Managed. Proceeding without batch.");
                                }
                            }
                        } catch (\Exception $e) {
                            Log::error("SapImportService: Failed to enrich batch for $itemCode: " . $e->getMessage());
                        }
                    }
                }
            }

            if (!empty($linesToRemove)) {
                foreach ($linesToRemove as $k) {
                    unset($payload['InventoryCountingLines'][$k]);
                }
                $payload['InventoryCountingLines'] = array_values($payload['InventoryCountingLines']);
            }
        }
    }

    protected function fetchBestBatch($itemCode, $minQty = 0)
    {
        $response = $this->sap->get("SQLQueries('batchesitems')/List", [
            'ItemCode' => "'$itemCode'"
        ]);

        $rows = $response['value'] ?? [];

        $candidates = array_filter($rows, function ($row) use ($minQty) {
            $exp = $row['ExpiryDate'] ?? '';
            $qty = (float) ($row['Quantity'] ?? 0);

            return !empty($exp) && $qty >= $minQty;
        });

        if (empty($candidates)) {
            return null;
        }

        usort($candidates, function ($a, $b) {
            return strcmp($a['ExpiryDate'], $b['ExpiryDate']);
        });

        return $candidates[0];
    }

    protected function logActivity($resource, $payload, $response, $status)
    {
        try {
            ApiLog::create([
                'user_id' => auth()->id() ?? null,
                'method' => 'POST (Import)',
                'endpoint' => $resource,
                'status_code' => $status,
                'request_payload' => json_encode($payload),
                'response_body' => json_encode($response),
                'database_name' => $this->sap->getCompanyDb(),
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);
        } catch (\Exception $e) {
            // Logging failed, ignore to not break import
        }
    }
}

