<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\Brand;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

class StoreController extends Controller
{
    /**
     * Get all brands.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function getBrands(Request $request)
    {
        // Limit or paginate if needed. For now, get all.
        // Also order by code or name for consistency.
        $brands = Brand::orderBy('name')->get();

        return response()->json([
            'status' => 'success',
            'data' => $brands
        ]);
    }

    /**
     * Get products, optionally filtered by brand_code.
     *
     * @return \Illuminate\Http\JsonResponse
     */
    public function getProducts(Request $request)
    {
        $query = \App\Models\Product::query();

        if ($request->has('brand_code') && $request->brand_code != null) {
            $query->where('items_group_code', $request->brand_code);
        }

        $products = $query->paginate(20);

        return response()->json([
            'status' => 'success',
            'data' => $products
        ]);
    }

    public function proxyImage(Request $request)
    {
        $url = $request->query('url');
        if (!$url) {
            return response('URL is required', 400);
        }

        try {
            // Using file_get_contents is simpler and allows us to easily get the exact byte length
            $contents = file_get_contents($url);
            
            if ($contents !== false) {
                return response($contents, 200)
                    ->header('Content-Type', 'image/png')
                    ->header('Access-Control-Allow-Origin', '*')
                    ->header('Content-Length', strlen($contents))
                    ->header('Cache-Control', 'public, max-age=604800');
            }
            
            return response('Image not found', 404);
        } catch (\Exception $e) {
            return response('Error proxying image', 500);
        }
    }

    /**
     * Public landing feed for the Muntajat HUB app (pre-login screen):
     * published company news + general company info. No products / no prices
     * (owner decision — protects the wholesale channel).
     */
    public function getLanding(Request $request)
    {
        $lang = $this->resolveLang($request);

        $news = Announcement::published()->get()->map(function (Announcement $a) use ($lang) {
            $title = $lang === 'en'
                ? ($a->title_en ?: $a->title_ar)
                : ($a->title_ar ?: $a->title_en);
            $body = $lang === 'en'
                ? ($a->body_en ?: $a->body_ar)
                : ($a->body_ar ?: $a->body_en);

            return [
                'id' => $a->id,
                'title' => $title,
                'body' => $body,
                'image_url' => $a->image_url,
                'link_url' => $a->link_url,
                'published_at' => optional($a->published_at ?? $a->created_at)->toIso8601String(),
            ];
        })->values();

        $companyInfo = $lang === 'en'
            ? [
                'name' => 'Muntajat HUB',
                'about' => 'Muntajat — a leading wholesale distributor of premium brands across the Kingdom, delivering products from our warehouses to your showrooms and branches with efficiency and reliability.',
            ]
            : [
                'name' => 'Muntajat HUB',
                'about' => 'منتجات — موزّع الجملة الرائد لأبرز العلامات التجارية في المملكة، نوصل المنتجات من مستودعاتنا إلى معارضك وفروعك بكفاءةٍ وموثوقية.',
            ];

        // Brands rarely change (synced from SAP); cache the list. Also resolve
        // every brand logo with ONE grouped query instead of the per-brand
        // products()->first() lookup behind Brand::image_url (was an N+1 → ~7s).
        $brands = Cache::remember('store_app_brands', 1800, function () {
            $itemByBrand = Product::query()
                ->selectRaw('items_group_code, MIN(item_code) as item_code')
                ->groupBy('items_group_code')
                ->pluck('item_code', 'items_group_code');

            return Brand::visibleInApp()
                ->orderBy('name')
                ->get()
                ->map(function (Brand $b) use ($itemByBrand) {
                    $ic = $itemByBrand[$b->code] ?? null;
                    $logo = ($ic && strlen($ic) >= 4)
                        ? 'https://ppte.sa/imghd/brands/' . substr($ic, 0, 4) . '.png'
                        : 'https://ppte.sa/imghd/brands/P' . $b->code . '.png';

                    return [
                        'code' => $b->code,
                        'name' => $b->name,
                        'logo_url' => $logo,
                    ];
                })
                ->values()
                ->all();
        });

        // Public branches (customer-facing showrooms) from the configured
        // Zooboxi warehouses. Localized + cached (rarely change).
        $branches = Cache::remember('store_app_branches_' . $lang, 1800, function () use ($lang) {
            return \App\Models\ZooboxiWarehouse::where('is_active', true)
                ->orderBy('city')
                ->get()
                ->map(function ($w) use ($lang) {
                    $name = $lang === 'en'
                        ? ($w->display_name_en ?: $w->display_name_ar)
                        : $w->display_name_ar;
                    $address = $lang === 'en'
                        ? ($w->address_en ?: $w->address_ar)
                        : ($w->address_ar ?: $w->address_en);

                    return [
                        'name' => $name,
                        'city' => $w->city,
                        'address' => $address,
                        'phone' => $w->phone,
                        'latitude' => $w->latitude !== null ? (float) $w->latitude : null,
                        'longitude' => $w->longitude !== null ? (float) $w->longitude : null,
                    ];
                })
                ->values()
                ->all();
        });

        return response()->json([
            'status' => 'success',
            'data' => [
                'news' => $news,
                'company_info' => $companyInfo,
                'brands' => $brands,
                'branches' => $branches,
            ],
        ]);
    }

    /**
     * Public per-brand intro page: logo, name, an optional read-only tagline
     * (from the marketing brand kit if one exists), and a gallery of the
     * brand's product images. NO prices (channel-safe).
     */
    public function getBrand(Request $request, string $code)
    {
        $lang = $this->resolveLang($request);

        $brand = Brand::where('code', $code)->first();
        if (!$brand || $brand->hidden_in_app) {
            return response()->json(['status' => 'error', 'message' => 'Brand not found'], 404);
        }

        // Optional, read-only enrichment from the existing brand design kit
        // (does NOT touch the Zooboxi store identity). Safe if absent.
        $tagline = null;
        $country = null;
        $founded = null;
        try {
            if (class_exists(\App\Models\BrandDesignKitModel::class)) {
                $kit = \App\Models\BrandDesignKitModel::where('is_active', true)
                    ->where(function ($q) use ($brand) {
                        $q->where('brand_key', $brand->code)
                          ->orWhere('brand_key', $brand->name);
                    })
                    ->first();
                if ($kit) {
                    $tagline = $lang === 'en'
                        ? ($kit->tagline_en ?: $kit->tagline_ar)
                        : ($kit->tagline_ar ?: $kit->tagline_en);
                    $country = $kit->country;
                    $founded = $kit->founded;
                }
            }
        } catch (\Throwable $e) {
            // ignore enrichment errors — brand page still renders
        }

        $products = Product::where('items_group_code', $code)
            ->orderByDesc('zooboxi_active')
            ->limit(40)
            ->get()
            ->map(function (Product $p) use ($lang) {
                // Localized product name: Arabic for AR users, English for EN.
                $name = $lang === 'en'
                    ? ($p->zb_name_en ?: ($p->foreign_name ?: ($p->item_name ?: $p->item_code)))
                    : ($p->zb_name_ar ?: ($p->item_name ?: $p->item_code));

                return [
                    'name' => $name,
                    'image_url' => $p->primary_image,
                ];
            })
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'code' => $brand->code,
                'name' => $brand->name,
                'logo_url' => $brand->image_url,
                'tagline' => $tagline,
                'country' => $country,
                'founded' => $founded,
                'products' => $products,
            ],
        ]);
    }

    /**
     * Serve a stored announcement image through the API so it works regardless
     * of whether `storage:link` exists on the server.
     */
    public function newsImage(Announcement $announcement)
    {
        $path = $announcement->image_path;

        if (!$path || !Storage::disk('public')->exists($path)) {
            return response('Image not found', 404);
        }

        $contents = Storage::disk('public')->get($path);
        $mime = Storage::disk('public')->mimeType($path) ?: 'image/jpeg';

        return response($contents, 200)
            ->header('Content-Type', $mime)
            ->header('Access-Control-Allow-Origin', '*')
            ->header('Cache-Control', 'public, max-age=86400');
    }

    /** Resolve the requested language ('ar' default) from ?lang= or Accept-Language. */
    protected function resolveLang(Request $request): string
    {
        $lang = $request->query('lang');
        if (in_array($lang, ['ar', 'en'], true)) {
            return $lang;
        }

        return str_starts_with(strtolower((string) $request->header('Accept-Language')), 'en') ? 'en' : 'ar';
    }
}
