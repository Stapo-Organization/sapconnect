<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SAP\SapClient;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class UniversalSapController extends Controller
{
    protected $sap;

    public function __construct(SapClient $sap)
    {
        $this->sap = $sap;
    }

    /**
     * Generic GET endpoint for SAP resources.
     * 
     * @queryParam view string optional The view mode (e.g. Minimal). Example: Minimal
     */
    public function index(Request $request, $resource)
    {
        try {

            // Permission Check (Example)
            // if (!$request->user()->can("view_{$resource}")) {
            //    abort(403, 'Unauthorized access to this SAP Entity.');
            // }

            // Inject Custom Filters based on User Role if needed
            $queryParams = $request->except(['view']);

            // Example: Force Sales Person Filter for Sales Employees
            // if ($request->user()->hasRole('SalesPerson')) {
            //     $slpCode = $request->user()->sap_slp_code;
            //     $queryParams['$filter'] = ($queryParams['$filter'] ?? '') . " and SalesPersonCode eq {$slpCode}";
            // }

            $data = $this->sap->get($resource, $queryParams);

            // Dynamic Resource Transformation
            // e.g. ?view=Minimal -> ItemMinimalResource (DB or File)
            $view = $request->query('view');

            // 1. Check Database Transformer first
            if ($view) {
                $transformer = \App\Models\ApiTransformer::findByResourceAndView($resource, $view);
                if ($transformer) {
                    // DEBUG: Log the mapping
                    $mapping = $transformer->mapping ?? [];
                    Log::info("UniversalSapController: Found transformer for {$resource}/{$view}. Mapping rules: " . count($mapping));
                    Log::info("UniversalSapController: First rule: " . json_encode($mapping[0] ?? []));
                    Log::info("UniversalSapController: Last rule: " . json_encode(end($mapping) ?? []));

                    $resourceClass = \App\Http\Resources\DynamicSapResource::class;

                    if (isset($data['value']) && is_array($data['value'])) {
                        // Collection: map each item to DynamicSapResource with config
                        return $resourceClass::collection(
                            collect($data['value'])->map(fn($item) => new $resourceClass($item, $transformer))
                        );
                    }
                    return new $resourceClass($data, $transformer);
                }
            }

            // 2. Fallback to PHP File Resource
            $resourceClass = $this->resolveResourceClass($resource, $view);

            if ($resourceClass) {
                // If response has 'value' key, it is a collection (OData)
                if (isset($data['value']) && is_array($data['value'])) {
                    return $resourceClass::collection($data['value']);
                }
                // Otherwise treat as single resource
                return new $resourceClass($data);
            }

            return response()->json($data);
        } catch (\Exception $e) {
            return $this->errorResponse($e);
        }
    }

    /**
     * Generic POST endpoint for SAP resources.
     */
    public function store(Request $request, $resource)
    {
        try {

            // Validation Logic here...

            $data = $this->sap->post($resource, $request->all());
            return response()->json($data, 201);
        } catch (\Exception $e) {
            return $this->errorResponse($e);
        }
    }

    /**
     * Generic PATCH/UPDATE endpoint.
     */
    public function update(Request $request, $resource, $id)
    {
        try {

            $this->sap->patch($resource, $id, $request->all());
            return response()->json(['message' => 'Updated successfully']);
        } catch (\Exception $e) {
            return $this->errorResponse($e);
        }
    }

    protected function errorResponse($e)
    {
        $status = $e->getCode() ?: 500;
        // If code is 0 (generic), default to 500. But if HTTP client returns 4xx, use that.
        if ($status < 100 || $status > 599) {
            $status = 500;
        }

        return response()->json([
            'error' => true,
            'message' => $e->getMessage(),
            'sap_details' => method_exists($e, 'getSapError') ? $e->getSapError() : null,
        ], $status);
    }

    protected function resolveResourceClass($resource, $view = null)
    {
        if (!$view) {
            return null;
        }

        // Items -> Item
        $singular = \Illuminate\Support\Str::singular($resource);
        // App\Http\Resources\Sap\ItemResource
        $className = "App\\Http\\Resources\\Sap\\{$singular}{$view}Resource";

        if (class_exists($className)) {
            return $className;
        }

        return null;
    }


}
