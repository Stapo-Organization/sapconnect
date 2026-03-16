<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Facades\Auth;
use App\Models\User;

class AuthByAppToken
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if ($token) {
            $user = User::where('auth_token', $token)->first();

            if ($user) {
                Auth::login($user);
                return $next($request);
            }
        }

        // Fallback or fail
        // If we want to allow Sanctum to also work, we could check if user is already logged in?
        // But for this route group, we want strict token access or maybe both.
        // If I return 401, Sanctum won't get a chance if this runs first.
        // But if I put this in a group *instead* of sanctum, it's fine.

        return response()->json(['message' => 'Unauthenticated.'], 401);
    }
}
