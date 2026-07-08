<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bearer-token guard for the ShipGo WMS read API (/api/shipgo/*).
 * Mirrors AuthenticateWooToken: a single shared token in config/.env.
 * These endpoints are READ-ONLY (catalog mirror); no SAP write path exists here.
 */
class AuthenticateShipGoToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        $valid = config('services.shipgo.api_token');

        if (! $valid || ! $token || ! hash_equals($valid, $token)) {
            return response()->json([
                'error' => 'Unauthorized',
                'message' => 'Invalid or missing ShipGo API token.',
            ], 401);
        }

        return $next($request);
    }
}
