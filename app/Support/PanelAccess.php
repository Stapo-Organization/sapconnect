<?php

namespace App\Support;

use App\Filament\Resources\ShipGoCustomerResource;
use App\Models\User;
use Filament\Navigation\NavigationItem;
use Illuminate\Database\Eloquent\Model;

/**
 * "Limited" admin roles: a role listed here can open ONLY the resources mapped
 * to it. Everything else in the panel (other resources, custom pages, the
 * dashboard, API docs) is hidden from navigation and blocked at the gate.
 *
 * A user is limited only when every role they hold is a limited role, so
 * combining a limited role with Operator/Finance/... keeps the wider access.
 */
class PanelAccess
{
    /** role name => resource classes it may use */
    public const LIMITED_ROLES = [
        'Accountant' => [ShipGoCustomerResource::class],
    ];

    public static function isLimited(?User $user): bool
    {
        if (!$user) {
            return false;
        }
        $roles = $user->getRoleNames()->all();
        if (empty($roles)) {
            return false;
        }
        foreach ($roles as $role) {
            if (!array_key_exists($role, self::LIMITED_ROLES)) {
                return false;
            }
        }
        return true;
    }

    /** @return array<class-string> resource classes the limited user may use */
    public static function allowedResources(User $user): array
    {
        $out = [];
        foreach ($user->getRoleNames() as $role) {
            $out = array_merge($out, self::LIMITED_ROLES[$role] ?? []);
        }
        return array_values(array_unique($out));
    }

    /** @return array<class-string<Model>> */
    public static function allowedModels(User $user): array
    {
        return array_map(fn (string $resource) => $resource::getModel(), self::allowedResources($user));
    }

    /**
     * Gate::before hook. Returns null (= let policies decide) for allowed
     * models, false for anything else. Non-limited users are untouched.
     */
    public static function gate(User $user, string $ability, array $arguments): ?bool
    {
        if (!self::isLimited($user)) {
            return null;
        }
        $subject = $arguments[0] ?? null;
        $class   = $subject instanceof Model ? get_class($subject) : (is_string($subject) ? $subject : null);

        return ($class && in_array($class, self::allowedModels($user), true)) ? null : false;
    }

    /** Route-name prefixes a limited user may open, besides their resources. */
    public static function allowedRoutePrefixes(User $user): array
    {
        $prefixes = [
            'filament.admin.auth.',      // logout, profile
            'livewire.',                 // component updates / uploads
            'shipgo.customers.statement',
        ];
        foreach (self::allowedResources($user) as $resource) {
            $prefixes[] = $resource::getRouteBaseName();
        }
        return $prefixes;
    }

    public static function routeAllowed(User $user, ?string $routeName): bool
    {
        if (!$routeName) {
            return false;
        }
        foreach (self::allowedRoutePrefixes($user) as $prefix) {
            if (str_starts_with($routeName, $prefix)) {
                return true;
            }
        }
        return false;
    }

    /** Where a limited user lands (first allowed resource index). */
    public static function homeUrl(User $user): string
    {
        $first = self::allowedResources($user)[0] ?? null;
        return $first ? $first::getUrl() : route('filament.admin.auth.profile');
    }

    /** @return array<NavigationItem> sidebar for a limited user: only their resources */
    public static function navigationItems(User $user): array
    {
        $items = [];
        foreach (self::allowedResources($user) as $resource) {
            foreach ($resource::getNavigationItems() as $item) {
                $items[] = $item;
            }
        }
        return $items;
    }
}
