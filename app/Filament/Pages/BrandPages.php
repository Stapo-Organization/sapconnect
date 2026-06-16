<?php

namespace App\Filament\Pages;

use App\Models\Brand;
use App\Models\BrandDesignKitModel;
use App\Models\MarketingCampaign;
use App\Services\Marketing\AdPlacements;
use App\Services\Marketing\BrandDesignKit;
use App\Services\Marketing\BrandPageManager;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Str;

/**
 * Owner control surface for the per-brand boutique pages (/brand/<slug>/).
 * Pick a brand → see its resolved identity → generate the AI hero + promo tiles in
 * the brand's look → preview / edit Arabic copy / regenerate → publish. Reuses the
 * MarketingCampaign creative pipeline via App\Services\Marketing\BrandPageManager.
 *
 * Channel-safe: brand banners are visibility-only and nothing is served to the
 * store until the owner publishes here.
 */
class BrandPages extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-swatch';

    protected static ?string $slug = 'brand-pages';

    protected static string $view = 'filament.pages.brand-pages';

    /** The four brand-page slots, in display order. */
    public const PLACEMENTS = ['brand_hero', 'brand_tile_1', 'brand_tile_2', 'brand_tile_3'];

    public ?string $brandCode = null;

    /** copy[placement][headline_ar|subheadline_ar|cta_ar|refinement_note] */
    public array $copy = [];

    public static function canAccess(): bool
    {
        return auth()->user()?->hasRole('Super Admin') ?? false;
    }

    public static function getNavigationLabel(): string
    {
        return 'صفحات العلامات';
    }

    public function getTitle(): string|\Illuminate\Contracts\Support\Htmlable
    {
        return 'صفحات العلامات التجارية';
    }

    public static function getNavigationGroup(): ?string
    {
        return 'المتجر';
    }

    /** Brands that have an active design kit → themable & generatable. code => name. */
    public function getBrandsProperty(): array
    {
        $keys = BrandDesignKitModel::query()
            ->where('is_active', true)
            ->where('brand_key', '!=', BrandDesignKit::STORE_KEY)
            ->pluck('brand_key')
            ->map(fn ($k) => (string) $k);

        $out = [];
        foreach (Brand::all() as $b) {
            if ($keys->contains((string) $b->code) || $keys->contains((string) $b->name)) {
                $out[(string) $b->code] = $b->name;
            }
        }
        asort($out);

        return $out;
    }

    public function getSelectedBrandProperty(): ?Brand
    {
        return $this->brandCode ? Brand::where('code', $this->brandCode)->first() : null;
    }

    /** Resolved identity for the selected brand (colors/fonts/story/logo). */
    public function getKitProperty(): ?array
    {
        $b = $this->selectedBrand;

        return $b ? app(BrandDesignKit::class)->forBrand($b) : null;
    }

    /** Best-effort public brand-page URL (store slug ≈ slugified brand name). */
    public function getBrandUrlProperty(): ?string
    {
        $b = $this->selectedBrand;
        if (! $b) {
            return null;
        }
        $base = rtrim((string) config('services.woo.store_url', 'https://store.zooboxi.com'), '/');

        return $base.'/brand/'.Str::slug((string) $b->name).'/';
    }

    /** Per-placement state: current campaign + latest creative preview/status. */
    public function getSlotsProperty(): array
    {
        if (! $this->brandCode) {
            return [];
        }

        $campaigns = MarketingCampaign::with('creatives')
            ->where('brand_code', $this->brandCode)
            ->whereIn('placement', self::PLACEMENTS)
            ->get()->keyBy('placement');

        $slots = [];
        foreach (self::PLACEMENTS as $p) {
            $c = $campaigns->get($p);
            $cr = $c ? $c->creatives->sortByDesc('id')->first() : null;
            $slots[$p] = [
                'placement' => $p,
                'label' => AdPlacements::PLACEMENTS[$p]['label_ar'] ?? $p,
                'format' => AdPlacements::formatFor($p),
                'campaign_id' => $c?->id,
                'status' => $c?->status,
                'live' => $c && $c->status === 'active',
                'preview' => $cr?->final_url ?: $cr?->thumb_url,
                'creative_status' => $cr?->status,
                'busy' => $cr && in_array($cr->status, ['queued', 'generating'], true),
            ];
        }

        return $slots;
    }

    /** True while any slot is rendering — drives the auto-refresh poll in the view. */
    public function getBusyProperty(): bool
    {
        foreach ($this->slots as $s) {
            if ($s['busy']) {
                return true;
            }
        }

        return false;
    }

    public function updatedBrandCode($value): void
    {
        $this->prefillCopy((string) $value);
    }

    private function prefillCopy(string $code): void
    {
        $this->copy = [];
        $b = $code ? Brand::where('code', $code)->first() : null;
        $kit = $b ? app(BrandDesignKit::class)->forBrand($b) : [];
        $existing = MarketingCampaign::where('brand_code', $code)
            ->whereIn('placement', self::PLACEMENTS)->get()->keyBy('placement');

        foreach (self::PLACEMENTS as $p) {
            $c = $existing->get($p);
            $isHero = $p === 'brand_hero';
            $this->copy[$p] = [
                'headline_ar' => $c->headline_ar ?? ($isHero ? (string) ($kit['tagline_ar'] ?? '') : ''),
                'subheadline_ar' => $c->subheadline_ar ?? '',
                'cta_ar' => $c->cta_ar ?? ($isHero ? 'تسوّق المجموعة' : ''),
                'refinement_note' => '',
            ];
        }
    }

    public function generate(string $placement): void
    {
        if (! $this->brandCode || ! in_array($placement, self::PLACEMENTS, true)) {
            return;
        }
        try {
            app(BrandPageManager::class)->generate($this->brandCode, $placement, $this->copy[$placement] ?? []);
            Notification::make()
                ->title('جارٍ توليد التصميم…')
                ->body('قد يستغرق دقيقة أو دقيقتين. ستتحدّث المعاينة تلقائيًا.')
                ->success()->send();
        } catch (\Throwable $e) {
            Notification::make()->title('تعذّر التوليد')->body($e->getMessage())->danger()->send();
        }
    }

    public function publish(string $placement): void
    {
        $c = MarketingCampaign::where('brand_code', $this->brandCode)->where('placement', $placement)->first();
        if (! $c) {
            return;
        }
        try {
            app(BrandPageManager::class)->publish($c, 'A', auth()->id());
            Notification::make()
                ->title('تم النشر ✅')
                ->body('سيظهر على صفحة العلامة خلال ساعة، أو فورًا عبر «مزامنة الآن» في المتجر.')
                ->success()->send();
        } catch (\Throwable $e) {
            Notification::make()->title('تعذّر النشر')->body($e->getMessage())->danger()->send();
        }
    }

    public function unpublish(string $placement): void
    {
        $c = MarketingCampaign::where('brand_code', $this->brandCode)->where('placement', $placement)->first();
        if ($c) {
            app(BrandPageManager::class)->unpublish($c);
            Notification::make()->title('تم الإيقاف')->body('عاد التصميم إلى وضع المعاينة.')->success()->send();
        }
    }
}
