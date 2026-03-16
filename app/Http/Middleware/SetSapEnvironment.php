<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SetSapEnvironment
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Force Production
        $db = 'PPTC_V5_PROD';

        // Set into config for this request lifecycle
        config(['sap.company_db' => $db]);

        // Also update session if we are using session state
        if ($request->hasSession()) {
            session(['sap_company_db' => $db]);
        }

        return $next($request);
    }
}
