<?php

namespace App\Services\Marketing;

use App\Jobs\GenerateAdCreative;
use App\Models\CampaignCreative;
use App\Models\MarketingCampaign;
use Illuminate\Support\Facades\DB;

/**
 * Orchestrates the per-brand boutique-page banners on top of the existing
 * MarketingCampaign / CampaignCreative / GenerateAdCreative pipeline. One campaign
 * per (brand_code, placement); always scope='visibility' (channel-safe — never
 * touches price) and design_identity='brand' (the brand's own look).
 *
 * Mirrors PromotionController::approve/publish so the Filament control surface and
 * the (future) API share one code path. Used by App\Filament\Pages\BrandPages.
 */
class BrandPageManager
{
    /**
     * Find-or-create the brand campaign for a placement and (re)generate its single
     * creative in the brand's identity. Returns it in 'approved' status = a PREVIEW
     * (served to the store only after publish()).
     *
     * @param array<string,string|null> $copy headline_ar|subheadline_ar|cta_ar|badge_ar|refinement_note
     */
    public function generate(string $brandCode, string $placement, array $copy = []): MarketingCampaign
    {
        abort_unless(AdPlacements::isBrand($placement), 422, 'موقع علامة غير معروف.');

        $c = MarketingCampaign::firstOrNew([
            'brand_code' => $brandCode,
            'placement' => $placement,
        ]);
        $c->campaign_type = 'brand';
        $c->source = 'manual';
        $c->scope = 'visibility';        // channel-safe: brand pages never touch price
        $c->design_identity = 'brand';   // force the brand's own identity
        $c->item_code = null;
        $c->zones = array_values(array_filter([AdPlacements::zoneFor($placement)]));

        foreach (['headline_ar', 'subheadline_ar', 'cta_ar', 'badge_ar'] as $k) {
            if (array_key_exists($k, $copy)) {
                $c->{$k} = ($copy[$k] ?? '') !== '' ? $copy[$k] : null;
            }
        }
        if (array_key_exists('refinement_note', $copy)) {
            $c->refinement_note = ($copy['refinement_note'] ?? '') !== '' ? trim((string) $copy['refinement_note']) : null;
        }

        $c->status = 'approved'; // preview, not live
        $c->save();

        // Fresh single-format creative sized for this placement.
        CampaignCreative::where('campaign_id', $c->id)->delete();
        GenerateAdCreative::dispatchAfterResponse($c->id);

        return $c;
    }

    /** Re-render the creative (optionally to an owner revision note), same placement/copy. */
    public function regenerate(MarketingCampaign $c, ?string $note = null): void
    {
        if ($note !== null && trim($note) !== '') {
            $c->update(['refinement_note' => trim($note)]);
        }
        CampaignCreative::where('campaign_id', $c->id)->update(['content_hash' => null, 'status' => 'generating']);
        GenerateAdCreative::dispatchAfterResponse($c->id);
    }

    /**
     * Publish the previewed creative live for the brand page. Enforces one active
     * campaign per (placement, brand_code); open-ended (brand pages are long-lived).
     */
    public function publish(MarketingCampaign $c, string $variant = 'A', ?int $ownerId = null): MarketingCampaign
    {
        $hasReady = CampaignCreative::where('campaign_id', $c->id)
            ->where('variant', $variant)
            ->whereIn('status', ['ready', 'approved', 'selected'])
            ->exists();
        abort_unless($hasReady, 422, 'لا يوجد تصميم جاهز للنشر.');

        return DB::transaction(function () use ($c, $variant, $ownerId) {
            // One live campaign per slot, per brand (Applaws & Beaphar heroes coexist).
            MarketingCampaign::where('placement', $c->placement)
                ->where('brand_code', $c->brand_code)
                ->where('id', '!=', $c->id)
                ->whereIn('status', ['active', 'scheduled'])
                ->update(['status' => 'ended']);

            CampaignCreative::where('campaign_id', $c->id)
                ->where('variant', $variant)
                ->whereIn('status', ['ready', 'selected', 'approved'])
                ->update(['status' => 'approved']);

            $c->scope = 'visibility';
            $c->starts_at = now();
            $c->ends_at = null;               // open-ended brand page
            $c->status = 'active';
            $c->owner_approved_by = $ownerId;
            $c->owner_approved_at = now();
            $c->published_at = now();
            $c->save();

            return $c;
        });
    }

    /** Take a brand placement back offline (returns to preview/draft). */
    public function unpublish(MarketingCampaign $c): void
    {
        $c->update(['status' => 'ended']);
    }
}
