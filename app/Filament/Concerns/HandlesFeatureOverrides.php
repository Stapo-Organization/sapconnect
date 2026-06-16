<?php

namespace App\Filament\Concerns;

use App\Models\User;

/**
 * يربط حقل "صلاحيات التطبيق" في فورم المستخدم بجدول user_feature_overrides.
 *
 * تمثيل الحالة في الفورم:  feature_overrides[{feature}][{action}] = inherit|allow|deny
 *   - inherit : لا سطر في الجدول (يرث افتراضي الدور).
 *   - allow   : سطر effect=allow (منح استثنائي).
 *   - deny    : سطر effect=deny (منع استثنائي).
 */
trait HandlesFeatureOverrides
{
    protected ?array $featureOverridesInput = null;

    /** يستخرج حالة الاستثناءات من بيانات الفورم ويزيلها قبل حفظ موديل المستخدم. */
    protected function extractFeatureOverrides(array $data): array
    {
        $this->featureOverridesInput = $data['feature_overrides'] ?? [];
        unset($data['feature_overrides']);
        return $data;
    }

    /** يحمّل الاستثناءات الحالية للمستخدم إلى حالة الفورم (عند التعديل). */
    protected function loadFeatureOverrides(array $data, User $user): array
    {
        $map = [];
        foreach ($user->featureOverrides as $ov) {
            [$feature, $action] = array_pad(explode('.', $ov->ability, 2), 2, null);
            if ($action !== null) {
                $map[$feature][$action] = $ov->effect;
            }
        }
        $data['feature_overrides'] = $map;
        return $data;
    }

    /** يحفظ الاستثناءات في الجدول (sync: استبدال كامل). */
    protected function persistFeatureOverrides(User $user): void
    {
        $input = $this->featureOverridesInput ?? [];

        $user->featureOverrides()->delete();

        foreach ($input as $feature => $actions) {
            foreach ((array) $actions as $action => $state) {
                if ($state === 'allow' || $state === 'deny') {
                    $user->featureOverrides()->create([
                        'ability' => "{$feature}.{$action}",
                        'effect'  => $state,
                    ]);
                }
            }
        }
    }
}
