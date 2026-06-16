<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Collection;

/**
 * يحلّ جمهور المستلمين (User models) لتنبيه معيّن.
 *
 * نعمل دائماً على نماذج User (لا بريد مجرّد) حتى يتمكّن الموجِّه من تطبيق
 * تفضيل القناة لكل مستلم. الحالات المعقّدة (مثل مدير حساب مورّد بعينه)
 * تُحلّ في موضع النداء وتُمرَّر مباشرة للموجِّه.
 */
class NotificationAudience
{
    /**
     * مستخدمو مستودع/مستودعات معيّنة (warehouse_code قد يكون مصفوفة JSON أو نصاً).
     *
     * @param string|array $codes
     * @return Collection<int, User>
     */
    public static function warehouseUsers($codes): Collection
    {
        $codes = array_values(array_filter((array) $codes));
        if (empty($codes)) {
            return collect();
        }

        return User::where(function ($q) use ($codes) {
            foreach ($codes as $code) {
                $q->orWhereJsonContains('warehouse_code', $code)
                  ->orWhere('warehouse_code', $code);
            }
        })->get();
    }

    /**
     * مستخدمو أدوار معيّنة (Spatie).
     *
     * @return Collection<int, User>
     */
    public static function byRoles(array $roles): Collection
    {
        $roles = array_values(array_filter($roles));
        if (empty($roles)) {
            return collect();
        }

        return User::role($roles)->get();
    }

    /**
     * حلّ افتراضي حسب audience_roles من الكتالوج (للأحداث ذات الجمهور القائم على الأدوار).
     *
     * @return Collection<int, User>
     */
    public static function resolve(string $eventKey): Collection
    {
        $def = NotificationPreferences::event($eventKey);
        return self::byRoles($def['audience_roles'] ?? []);
    }
}
