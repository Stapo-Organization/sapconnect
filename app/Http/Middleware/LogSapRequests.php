<?php

namespace App\Http\Middleware;

use App\Models\ApiLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class LogSapRequests
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Proceed with the request
        $response = $next($request);

        // Terminate: Log after response is sent (if using FPM/Octane) or just normally
        // In standard Laravel request lifecycle, we do it here.

        try {
            ApiLog::create([
                'user_id' => $request->user() ? $request->user()->id : null,
                'method' => $request->method(),
                'endpoint' => $request->fullUrl(),
                'database_name' => session('sap_company_db', config('sap.company_db')),
                'status_code' => $response->getStatusCode(),
                'request_payload' => json_encode($request->all()), // Be careful with passwords
                'response_body' => $this->truncate($response->getContent()),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        } catch (\Exception $e) {
            // Do not fail the request if logging fails
            // Log::error('Failed to log API request: ' . $e->getMessage());
        }

        return $response;
    }

    protected function truncate($string, $length = 10000)
    {
        if (strlen($string) > $length) {
            return substr($string, 0, $length) . '... [TRUNCATED]';
        }
        return $string;
    }
}
