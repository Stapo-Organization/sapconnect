<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Exposes the Zooboxi intelligence (built DB-only from the sapconnect data) to the
 * WooCommerce plugin: ranking snapshot, channel-safe clearance queue, FBT/substitute
 * recommendations, and the capture-only event beacon. Protected by AuthenticateWooToken.
 */
class ZooboxiIntelligenceController extends Controller
{
    /**
     * GET /api/woo/snapshot — per-item ranking/health for the plugin to cache as meta.
     */
    public function snapshot(Request $request): JsonResponse
    {
        $perPage = min(500, max(1, (int) $request->query('per_page', 200)));
        $page = max(1, (int) $request->query('page', 1));

        $rows = DB::table('product_intelligence as pi')
            ->leftJoin('clearance_campaigns as c', function ($j) {
                $j->on('c.item_code', '=', 'pi.item_code')->whereIn('c.status', ['suggested', 'active']);
            })
            ->where('pi.warehouse_code', '')
            ->orderBy('pi.item_code')
            ->forPage($page, $perPage)
            ->get([
                'pi.item_code', 'pi.composite_rank_score', 'pi.health_status', 'pi.days_of_cover',
                'pi.in_stock_rate', 'pi.is_hero', 'pi.demand_class', 'pi.abc_class',
                DB::raw('CASE WHEN c.id IS NULL THEN 0 ELSE 1 END as is_clearance'),
                DB::raw('c.lps as clearance_lps'),
            ]);

        return response()->json([
            'page' => $page,
            'per_page' => $perPage,
            'count' => $rows->count(),
            'data' => $rows,
        ]);
    }

    /**
     * GET /api/woo/clearance — the ranked, channel-safe clearance queue.
     */
    public function clearance(Request $request): JsonResponse
    {
        $perPage = min(500, max(1, (int) $request->query('per_page', 200)));
        $page = max(1, (int) $request->query('page', 1));

        $rows = DB::table('clearance_campaigns as c')
            ->leftJoin('products as p', 'p.item_code', '=', 'c.item_code')
            ->whereIn('c.status', ['suggested', 'active'])
            ->orderByDesc('c.lps')
            ->forPage($page, $perPage)
            ->get([
                'c.item_code', 'c.reason', 'c.lps', 'c.capital_tied_sar', 'c.days_of_cover',
                'c.retail_price', 'c.floor_price', 'c.recommended_discount_pct',
                'c.recommended_sale_price', 'c.status',
                'p.zb_name_ar', 'p.zb_name_en', 'p.woo_product_id',
            ]);

        return response()->json([
            'page' => $page,
            'per_page' => $perPage,
            'count' => $rows->count(),
            'data' => $rows,
        ]);
    }

    /**
     * GET /api/woo/recommendations/{item_code} — FBT partners + in-stock substitutes.
     */
    public function recommendations(string $itemCode): JsonResponse
    {
        // Frequently bought together (directed a→b), prefer in-stock partners.
        $fbt = DB::table('product_associations as a')
            ->join('products as p', 'p.item_code', '=', 'a.item_code_b')
            ->leftJoin('product_intelligence as pi', function ($j) {
                $j->on('pi.item_code', '=', 'a.item_code_b')->where('pi.warehouse_code', '');
            })
            ->where('a.item_code_a', $itemCode)
            ->where('a.rule_type', 'fbt')
            ->orderByRaw('CASE WHEN pi.current_stock > 0 THEN 0 ELSE 1 END')
            ->orderByDesc('a.score')
            ->limit(8)
            ->get([
                'a.item_code_b as item_code', 'a.lift', 'a.confidence',
                'p.zb_name_ar', 'p.woo_product_id', 'pi.composite_rank_score', 'pi.health_status',
            ]);

        // Substitutes: same pet-type + subcategory, in stock, ranked — steer to overstock equivalents.
        $self = DB::table('products')->where('item_code', $itemCode)->first(['u_proprt3', 'u_proprt4']);
        $subs = collect();
        if ($self) {
            $subs = DB::table('products as p')
                ->join('product_intelligence as pi', function ($j) {
                    $j->on('pi.item_code', '=', 'p.item_code')->where('pi.warehouse_code', '');
                })
                ->where('p.zooboxi_active', 1)
                ->where('p.item_code', '!=', $itemCode)
                ->where('p.u_proprt4', $self->u_proprt4)
                ->where('p.u_proprt3', $self->u_proprt3)
                ->where('pi.current_stock', '>', 0)
                ->orderByRaw("CASE WHEN pi.health_status = 'overstock' THEN 0 ELSE 1 END")
                ->orderByDesc('pi.composite_rank_score')
                ->limit(8)
                ->get(['p.item_code', 'p.zb_name_ar', 'p.woo_product_id', 'pi.composite_rank_score', 'pi.health_status']);
        }

        return response()->json([
            'item_code' => $itemCode,
            'frequently_bought_together' => $fbt,
            'substitutes' => $subs,
        ]);
    }

    /**
     * POST /api/woo/events — capture-only B2C event ingestion (the cold-start spine).
     */
    public function storeEvent(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_type' => 'required|in:view,search,add_to_cart,begin_checkout,purchase,impression,click,loyalty_scratch,loyalty_mission,loyalty_redeem,loyalty_claim,pet_added,family_card,supply_action,subscription,referral_share,care_action,weight_logged',
            'anon_id' => 'nullable|string|max:64',
            'customer_ref' => 'nullable|string|max:255',
            'item_code' => 'nullable|string|max:255',
            'query' => 'nullable|string|max:255',
            'position' => 'nullable|integer',
            'zone' => 'nullable|string|max:255',
            'ab_variant' => 'nullable|string|max:255',
            'payload' => 'nullable|array',
            'occurred_at' => 'nullable|date',
        ]);

        DB::table('store_events')->insert([
            'anon_id' => $data['anon_id'] ?? null,
            'customer_ref' => $data['customer_ref'] ?? null,
            'event_type' => $data['event_type'],
            'item_code' => $data['item_code'] ?? null,
            'query' => $data['query'] ?? null,
            'position' => $data['position'] ?? null,
            'zone' => $data['zone'] ?? null,
            'ab_variant' => $data['ab_variant'] ?? null,
            'payload' => isset($data['payload']) ? json_encode($data['payload']) : null,
            'occurred_at' => $data['occurred_at'] ?? now(),
            'created_at' => now(),
        ]);

        return response()->json(['ok' => true], 202);
    }
}
