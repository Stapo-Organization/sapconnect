<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

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
}
