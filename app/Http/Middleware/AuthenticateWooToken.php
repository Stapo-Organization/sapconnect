<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Authenticates WooCommerce API requests using a Bearer token.
 * The token is stored in the .env file as WOO_API_TOKEN.
 */
class AuthenticateWooToken
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (!$token) {
            return response()->json([
                'error' => 'Unauthorized',
                'message' => 'Bearer token is required.',
            ], 401);
        }

        $validToken = config('services.woo.api_token');

        if (!$validToken || $token !== $validToken) {
            return response()->json([
                'error' => 'Unauthorized',
                'message' => 'Invalid API token.',
            ], 401);
        }

        return $next($request);
    }
}
