<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentAlert;
use App\Models\ProductRegistration;
use App\Models\PurchaseOrder;
use App\Models\Shipment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Owner-facing READ-ONLY supply-chain / operations summary for the app.
 *
 * A pure read from local tables (mirrors ContainerTrackingController): it exposes
 * the operational overlay the ops team maintains in Filament so the owner sees, at
 * a glance, open POs, arriving shipments, expiring SFDA registrations, and payments
 * due. NO writes and NO SAP calls.
 *
 *   GET /supply-chain/overview          → KPI tiles + attention counts
 *   GET /supply-chain/po-summary        → open purchase orders (operational view)
 *   GET /supply-chain/arrived-shipments → shipments with clearance/pricing status
 *   GET /supply-chain/registrations     → SFDA registrations expiring soon
 */
class SupplyChainSummaryController extends Controller
{
    public function overview(): JsonResponse
    {
        $openPos = PurchaseOrder::where('doc_status', 'Open');

        $duePayments = PaymentAlert::whereIn('status', ['pending', 'overdue']);

        $expiringSoon = ProductRegistration::whereNotNull('expiry_date')
            ->whereBetween('expiry_date', [now(), now()->addDays(ProductRegistration::EXPIRING_SOON_DAYS)]);

        return response()->json([
            'kpis' => [
                'open_pos'                 => (clone $openPos)->count(),
                'open_pos_value'           => round((float) (clone $openPos)->sum('po_value'), 2),
                'shipments_active'         => Shipment::whereNotIn('status', ['delivered'])->count(),
                'shipments_arriving_7d'    => Shipment::whereNotNull('eta')
                    ->whereBetween('eta', [now(), now()->addDays(7)])->count(),
                'registrations_total'      => ProductRegistration::count(),
                'registrations_expiring'   => (clone $expiringSoon)->count(),
                'registrations_expired'    => ProductRegistration::whereNotNull('expiry_date')
                    ->where('expiry_date', '<', now())->count(),
                'payments_due_count'       => (clone $duePayments)->count(),
                'payments_due_amount'      => round((float) (clone $duePayments)->sum('due_amount'), 2),
            ],
        ]);
    }

    public function poSummary(Request $request): JsonResponse
    {
        $rows = PurchaseOrder::with(['supplier:id,name', 'brand:id,name'])
            ->where('doc_status', 'Open')
            ->orderByRaw('est_departure is null, est_departure asc')
            ->limit((int) $request->query('limit', 100))
            ->get();

        return response()->json([
            'purchase_orders' => $rows->map(fn (PurchaseOrder $po) => [
                'id'            => $po->id,
                'po_number'     => $po->po_number,
                'sap_doc_num'   => $po->sap_doc_num,
                'pq_ref'        => $po->pq_ref,
                'supplier'      => $po->supplier?->name,
                'brands'        => $po->computed_brands,
                'currency'      => $po->currency,
                'po_value'      => (float) $po->po_value,
                'status'        => $po->doc_status,
                'est_departure' => $po->est_departure?->toDateString(),
                'factory_name'  => $po->factory_name,
                'shipment_count'=> $po->shipments()->count(),
            ])->values(),
        ]);
    }

    public function arrivedShipments(Request $request): JsonResponse
    {
        $rows = Shipment::with(['purchaseOrder.supplier:id,name', 'landedCost:id,shipment_id,pricing_status'])
            ->orderByRaw('eta is null, eta asc')
            ->limit((int) $request->query('limit', 100))
            ->get();

        return response()->json([
            'shipments' => $rows->map(fn (Shipment $s) => [
                'id'                    => $s->id,
                'supplier'              => $s->purchaseOrder?->supplier?->name,
                'description'           => $s->order_description,
                'status'                => $s->status,
                'is_announced'          => (bool) $s->is_announced,
                'announcement_no'       => $s->announcement_no,
                'customs_manifest_no'   => $s->customs_manifest_no,
                'commercial_invoice_no' => $s->commercial_invoice_no,
                'eta'                   => $s->eta?->toDateString(),
                'received_date'         => $s->received_date?->toDateString(),
                'days_until_arrival'    => $s->days_until_arrival,
                'pricing_status'        => $s->landedCost?->pricing_status,
            ])->values(),
        ]);
    }

    public function registrations(Request $request): JsonResponse
    {
        $rows = ProductRegistration::whereNotNull('expiry_date')
            ->where('expiry_date', '<=', now()->addDays(ProductRegistration::EXPIRING_SOON_DAYS))
            ->orderBy('expiry_date', 'asc')
            ->limit((int) $request->query('limit', 100))
            ->get();

        return response()->json([
            'registrations' => $rows->map(fn (ProductRegistration $r) => [
                'id'                 => $r->id,
                'item_code'          => $r->item_code,
                'name_ar'            => $r->name_ar,
                'item_name'          => $r->item_name,
                'brand_code'         => $r->brand_code,
                'status'             => $r->status,
                'status_label'       => $r->statusLabel(),
                'certificate_number' => $r->certificate_number,
                'expiry_date'        => $r->expiry_date?->toDateString(),
                'is_expired'         => $r->isExpired(),
            ])->values(),
        ]);
    }
}
