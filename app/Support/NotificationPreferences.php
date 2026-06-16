<?php

namespace App\Support;

use App\Models\User;

/**
 * محرك تفضيلات قنوات التنبيه (بريد / تطبيق Push).
 *
 * يقرأ كتالوج config/notifications.php + جدول notification_preferences ويترجمهما إلى:
 *  - channelsFor(): القنوات الفعّالة لحدث معيّن لمستخدم (تفضيله الصريح أو افتراضي الكتالوج).
 *  - configurableFor(): الأحداث التي يراها/يتحكم بها المستخدم في شاشة التفضيلات.
 *
 * نموذج القرار: سطر تفضيل صريح يحسم؛ وإلا يُستخدم default_channels من الكتالوج.
 */
class NotificationPreferences
{
    /** كل أحداث التنبيه من الكتالوج. */
    public static function all(): array
    {
        return (array) config('notifications.events', []);
    }

    public static function guard(): string
    {
        return (string) config('notifications.guard', config('auth.defaults.guard', 'web'));
    }

    /** تعريف حدث واحد من الكتالوج، أو null. */
    public static function event(string $eventKey): ?array
    {
        return self::all()[$eventKey] ?? null;
    }

    /** افتراضي قنوات الحدث من الكتالوج. */
    public static function defaultChannels(string $eventKey): array
    {
        $def = self::event($eventKey);
        $channels = $def['default_channels'] ?? [];

        return [
            'email' => (bool) ($channels['email'] ?? false),
            'push'  => (bool) ($channels['push'] ?? false),
        ];
    }

    /**
     * القنوات الفعّالة لحدث معيّن لمستخدم: سطر التفضيل الصريح إن وُجد، وإلا افتراضي الكتالوج.
     *
     * @return array{email: bool, push: bool}
     */
    public static function channelsFor(User $user, string $eventKey): array
    {
        // أحداث غير موجودة بالكتالوج: لا تُرسل (حماية).
        if (! self::event($eventKey)) {
            return ['email' => false, 'push' => false];
        }

        $pref = $user->notificationPreferences
            ? $user->notificationPreferences->firstWhere('event_key', $eventKey)
            : $user->notificationPreferences()->where('event_key', $eventKey)->first();

        if ($pref) {
            return ['email' => (bool) $pref->email, 'push' => (bool) $pref->push];
        }

        return self::defaultChannels($eventKey);
    }

    /** هل الحدث قابل لتخصيص المستخدم؟ */
    public static function isConfigurable(string $eventKey): bool
    {
        $def = self::event($eventKey);
        return (bool) ($def['user_configurable'] ?? false);
    }

    /**
     * الأحداث التي يراها هذا المستخدم في شاشة التفضيلات:
     * قابلة للتخصيص + المستخدم ضمن جمهورها (audience_roles).
     *
     * @return array<string, array> map event_key => تعريف الكتالوج
     */
    public static function configurableFor(User $user): array
    {
        $out = [];
        foreach (self::all() as $key => $def) {
            if (! ($def['user_configurable'] ?? false)) {
                continue;
            }
            $roles = $def['audience_roles'] ?? [];
            if (! empty($roles) && ! $user->hasAnyRole($roles)) {
                continue;
            }
            $out[$key] = $def;
        }
        return $out;
    }

    /**
     * تمثيل جاهز للتطبيق/Filament: قائمة الأحداث القابلة للتخصيص لهذا المستخدم
     * مع القنوات الفعّالة الحالية.
     *
     * @return array<int, array{event_key:string,label:string,label_en:string,group:string,email:bool,push:bool}>
     */
    public static function resolveForUser(User $user): array
    {
        $out = [];
        foreach (self::configurableFor($user) as $key => $def) {
            $channels = self::channelsFor($user, $key);
            $out[] = [
                'event_key' => $key,
                'label'     => $def['label'] ?? $key,
                'label_en'  => $def['label_en'] ?? $key,
                'group'     => $def['group'] ?? '',
                'email'     => $channels['email'],
                'push'      => $channels['push'],
            ];
        }
        return $out;
    }
}
