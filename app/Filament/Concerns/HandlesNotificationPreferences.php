<?php

namespace App\Filament\Concerns;

use App\Models\User;

/**
 * يربط حقل "تفضيلات الإشعارات" في فورم المستخدم بجدول notification_preferences.
 *
 * تمثيل الحالة في الفورم:  notification_prefs[{event_key}] = inherit|email|push|both
 *   - inherit : لا سطر في الجدول (يرث افتراضي الكتالوج).
 *   - email   : سطر (email=1, push=0).
 *   - push    : سطر (email=0, push=1).
 *   - both    : سطر (email=1, push=1).
 */
trait HandlesNotificationPreferences
{
    protected ?array $notificationPrefsInput = null;

    /** يستخرج حالة التفضيلات من بيانات الفورم ويزيلها قبل حفظ موديل المستخدم. */
    protected function extractNotificationPrefs(array $data): array
    {
        $this->notificationPrefsInput = $data['notification_prefs'] ?? [];
        unset($data['notification_prefs']);
        return $data;
    }

    /** يحمّل التفضيلات الحالية للمستخدم إلى حالة الفورم (عند التعديل). */
    protected function loadNotificationPrefs(array $data, User $user): array
    {
        $map = [];
        foreach ($user->notificationPreferences as $pref) {
            $map[$pref->event_key] = $this->stateFromBooleans((bool) $pref->email, (bool) $pref->push);
        }
        $data['notification_prefs'] = $map;
        return $data;
    }

    /** يحفظ التفضيلات في الجدول (sync: استبدال كامل). */
    protected function persistNotificationPrefs(User $user): void
    {
        $input = $this->notificationPrefsInput ?? [];

        $user->notificationPreferences()->delete();

        foreach ($input as $eventKey => $state) {
            $channels = $this->booleansFromState($state);
            if ($channels === null) {
                continue; // inherit → لا سطر
            }
            $user->notificationPreferences()->create([
                'event_key' => $eventKey,
                'email'     => $channels['email'],
                'push'      => $channels['push'],
            ]);
        }
    }

    private function stateFromBooleans(bool $email, bool $push): string
    {
        return match (true) {
            $email && $push => 'both',
            $email          => 'email',
            $push           => 'push',
            default         => 'inherit',
        };
    }

    /** @return array{email: bool, push: bool}|null  null = inherit (لا سطر) */
    private function booleansFromState(?string $state): ?array
    {
        return match ($state) {
            'email' => ['email' => true,  'push' => false],
            'push'  => ['email' => false, 'push' => true],
            'both'  => ['email' => true,  'push' => true],
            default => null,
        };
    }
}
