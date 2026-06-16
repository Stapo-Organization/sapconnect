<?php

namespace App\Support;

use App\Models\User;

/**
 * محرك صلاحيات خصائص تطبيق مدير المعرض.
 *
 * يقرأ كتالوج config/app_features.php ويترجمه إلى:
 *  - أسماء صلاحيات Spatie:  app.{feature}.{action}
 *  - "قدرات" (abilities) يفهمها التطبيق:  {feature}.{action}
 *
 * نموذج القرار (أدوار + استثناءات لكل مستخدم):
 *   الفعّال = (صلاحيات أدوار المستخدم) + (مسموح استثناءً) − (ممنوع استثناءً)
 */
class AppFeatures
{
    /** كل الخصائص من الكتالوج. */
    public static function all(): array
    {
        return (array) config('app_features.features', []);
    }

    public static function guard(): string
    {
        return (string) config('app_features.guard', config('auth.defaults.guard', 'web'));
    }

    public static function prefix(): string
    {
        return (string) config('app_features.prefix', 'app');
    }

    /** القدرة (ability) كما يفهمها التطبيق: stock_transfer.view */
    public static function ability(string $feature, string $action): string
    {
        return "{$feature}.{$action}";
    }

    /** اسم صلاحية Spatie المقابل: app.stock_transfer.view */
    public static function permissionName(string $feature, string $action): string
    {
        return self::prefix() . '.' . self::ability($feature, $action);
    }

    /** تحويل اسم صلاحية Spatie إلى قدرة التطبيق، أو null إن لم تكن من خصائص التطبيق. */
    public static function abilityFromPermission(string $permission): ?string
    {
        $prefix = self::prefix() . '.';
        if (! str_starts_with($permission, $prefix)) {
            return null;
        }
        return substr($permission, strlen($prefix));
    }

    /** كل أسماء صلاحيات Spatie التي يفرضها الكتالوج. */
    public static function allPermissionNames(): array
    {
        $names = [];
        foreach (self::all() as $feature => $def) {
            foreach (array_keys($def['actions'] ?? []) as $action) {
                $names[] = self::permissionName($feature, $action);
            }
        }
        return $names;
    }

    /** كل القدرات (abilities) في الكتالوج. */
    public static function allAbilities(): array
    {
        $abilities = [];
        foreach (self::all() as $feature => $def) {
            foreach (array_keys($def['actions'] ?? []) as $action) {
                $abilities[] = self::ability($feature, $action);
            }
        }
        return $abilities;
    }

    /**
     * يحسب الصلاحيات الفعّالة للمستخدم.
     *
     * @return array{
     *   abilities: string[],                       قائمة القدرات الممنوحة (للتطبيق و middleware)
     *   features: array<string, array<string,bool>> خريطة feature => action => bool (للوحة)
     * }
     */
    public static function resolveForUser(User $user): array
    {
        // 1) الافتراضي من الأدوار: صلاحيات app.* الواصلة عبر أدوار المستخدم.
        $viaRoles = [];
        foreach ($user->getPermissionsViaRoles() as $perm) {
            $ability = self::abilityFromPermission($perm->name);
            if ($ability !== null) {
                $viaRoles[$ability] = true;
            }
        }

        // 2) استثناءات المستخدم (allow / deny) — تُطبَّق فوق افتراضي الأدوار.
        $overrides = [];
        if (method_exists($user, 'featureOverrides')) {
            foreach ($user->featureOverrides as $ov) {
                $overrides[$ov->ability] = $ov->effect === 'allow';
            }
        }

        // 3) الدمج عبر الكتالوج فقط (نتجاهل أي صلاحية خارج الكتالوج).
        $abilities = [];
        $features  = [];
        foreach (self::all() as $feature => $def) {
            foreach (array_keys($def['actions'] ?? []) as $action) {
                $ability = self::ability($feature, $action);
                $granted = $viaRoles[$ability] ?? false;
                if (array_key_exists($ability, $overrides)) {
                    $granted = $overrides[$ability]; // الاستثناء يحسم
                }
                $features[$feature][$action] = $granted;
                if ($granted) {
                    $abilities[] = $ability;
                }
            }
        }

        return ['abilities' => $abilities, 'features' => $features];
    }

    /** هل يملك المستخدم القدرة المحددة فعلياً؟ (يُستخدم في الـ middleware). */
    public static function userCan(User $user, string $ability): bool
    {
        return in_array($ability, self::resolveForUser($user)['abilities'], true);
    }
}
