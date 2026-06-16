<?php

namespace App\Http\Middleware;

use App\Support\AppFeatures;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * يحمي مسارات الـ API بصلاحية خاصية معيّنة (دفاع بعمق).
 *
 * الاستخدام في routes/api.php:
 *   ->middleware('feature:stock_transfer.view')
 *   ->middleware('feature:stock_transfer.confirm_receive')
 *
 * حتى لو أخفى التطبيق الخاصية، لن يتمكن المستخدم من الوصول لها عبر الـ API.
 */
class EnsureFeatureAccess
{
    public function handle(Request $request, Closure $next, string $ability): Response
    {
        $user = $request->user();

        if (! $user || ! AppFeatures::userCan($user, $ability)) {
            return response()->json([
                'message' => 'ليس لديك صلاحية الوصول لهذه الخاصية.',
                'ability' => $ability,
            ], 403);
        }

        return $next($request);
    }
}
