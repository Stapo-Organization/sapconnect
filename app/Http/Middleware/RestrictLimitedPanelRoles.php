<?php

namespace App\Http\Middleware;

use App\Support\PanelAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Users whose only roles are "limited" (see PanelAccess) may open just their
 * resources; every other panel URL (dashboard, pages, other resources) sends
 * them to their home resource.
 */
class RestrictLimitedPanelRoles
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && PanelAccess::isLimited($user) && !PanelAccess::routeAllowed($user, $request->route()?->getName())) {
            return redirect()->to(PanelAccess::homeUrl($user));
        }

        return $next($request);
    }
}
