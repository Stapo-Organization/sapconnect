<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;

class TrackUserActivity
{
    /**
     * Handle an incoming request.
     * We don't perform DB updates here to avoid blocking the response.
     */
    public function handle(Request $request, Closure $next): Response
    {
        return $next($request);
    }

    /**
     * Terminate the request.
     * Perform the user activity tracking after the response is sent to the browser.
     */
    public function terminate(Request $request, Response $response): void
    {
        if (Auth::check()) {
            $user = Auth::user();

            $cacheKey = 'user-is-online-' . $user->id;

            // تحقق من الكاش لتفادي الضغط على قاعدة البيانات
            if (!Cache::has($cacheKey)) {
                // Update activity only if > 1 minute passed to reduce DB writes
                if (!$user->last_activity_at || $user->last_activity_at->diffInMinutes(now()) >= 1) {
                    $user->update(['last_activity_at' => now()]);
                }

                // حفظ في الكاش لمدة دقيقة
                Cache::put($cacheKey, true, now()->addMinute());
            }
        }
    }
}
