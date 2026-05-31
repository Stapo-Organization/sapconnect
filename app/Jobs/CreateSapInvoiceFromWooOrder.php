<?php

namespace App\Jobs;

use App\Models\ZooboxiOrder;
use App\Services\SAP\SapClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Creates a SAP Sales Invoice from a Zooboxi WooCommerce order.
 *
 * This job is dispatched after a new paid order is received from WooCommerce.
 * It creates an invoice in SAP Business One through the SAP Service Layer.
 */
class CreateSapInvoiceFromWooOrder implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * The number of times the job may be attempted.
     */
    public int $tries = 3;

    /**
     * The number of seconds to wait before retrying the job.
     */
    public int $backoff = 60;

    public function __construct(
        private readonly int $orderId,
    ) {}

    /**
     * Execute the job.
     */
    public function handle(SapClient $sapClient): void
    {
        $order = ZooboxiOrder::with('lines')->find($this->orderId);

        if (!$order) {
            Log::warning('CreateSapInvoiceFromWooOrder: Order not found', ['id' => $this->orderId]);
            return;
        }

        if ($order->isSyncedToSap()) {
            Log::info('CreateSapInvoiceFromWooOrder: Order already synced', [
                'id' => $this->orderId,
                'sap_doc_entry' => $order->sap_doc_entry,
            ]);
            return;
        }

        try {
            // Build the SAP Invoice payload
            $payload = $this->buildInvoicePayload($order);

            // Create the invoice in SAP
            $response = $sapClient->post('Invoices', $payload);

            if (isset($response['DocEntry'])) {
                $order->markSyncedToSap($response['DocEntry']);

                Log::info('CreateSapInvoiceFromWooOrder: Invoice created', [
                    'order_id' => $order->id,
                    'woo_order_id' => $order->woo_order_id,
                    'sap_doc_entry' => $response['DocEntry'],
                ]);
            } else {
                throw new \RuntimeException('SAP did not return DocEntry');
            }
        } catch (\Exception $e) {
            Log::error('CreateSapInvoiceFromWooOrder: Failed', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
                'attempt' => $this->attempts(),
            ]);

            throw $e; // Retry
        }
    }

    /**
     * Build the SAP Invoice payload from the Zooboxi order.
     */
    private function buildInvoicePayload(ZooboxiOrder $order): array
    {
        $documentLines = $order->lines->map(function ($line, $index) use ($order) {
            return [
                'LineNum' => $index,
                'ItemCode' => $line->item_code,
                'Quantity' => $line->quantity,
                'UnitPrice' => $line->unit_price,
                'WarehouseCode' => $line->warehouse_code ?: $order->warehouse_code,
            ];
        })->toArray();

        return [
            'DocDate' => now()->format('Y-m-d'),
            'DocDueDate' => now()->format('Y-m-d'),
            'CardCode' => 'C-ZOOBOXI', // Default Zooboxi customer in SAP
            'Comments' => sprintf(
                'Zooboxi Order #%s | %s | %s',
                $order->woo_order_number ?? $order->woo_order_id,
                $order->delivery_type_label,
                $order->customer_name ?? 'Walk-in'
            ),
            'U_DeliveryType' => $order->delivery_type,
            'U_WooOrderID' => (string) $order->woo_order_id,
            'DocumentLines' => $documentLines,
        ];
    }

    /**
     * Handle a job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::error('CreateSapInvoiceFromWooOrder: Job permanently failed', [
            'order_id' => $this->orderId,
            'error' => $exception->getMessage(),
        ]);
    }
}
