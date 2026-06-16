<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

use Filament\Models\Contracts\HasAvatar;
use Illuminate\Support\Facades\Storage;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Support\AppFeatures;

class User extends Authenticatable implements HasAvatar
{
    use HasApiTokens, HasFactory, Notifiable, HasRoles;

    protected $fillable = [
        'name',
        'email',
        'mobile_number',
        'otp_code',
        'otp_expires_at',
        'password',
        'avatar_url',
        'last_login_at',
        'last_activity_at',
        'auth_token',
        'fcm_token',
        'receive_sms_on_zid_import',
        'receive_sms_on_stock_transfer_import',
        'warehouse_code',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'last_login_at' => 'datetime',
        'last_activity_at' => 'datetime',
        'warehouse_code' => 'array',
    ];

    public function getFilamentAvatarUrl(): ?string
    {
        return $this->avatar_url ? Storage::url($this->avatar_url) : null;
    }

    /** استثناءات صلاحيات خصائص التطبيق لهذا المستخدم (allow / deny فوق افتراضي الدور). */
    public function featureOverrides(): HasMany
    {
        return $this->hasMany(UserFeatureOverride::class);
    }

    /** تفضيلات قنوات التنبيه (بريد/تطبيق) لكل حدث — غياب السطر = افتراضي الكتالوج. */
    public function notificationPreferences(): HasMany
    {
        return $this->hasMany(NotificationPreference::class);
    }

    /** القدرات الفعّالة لخصائص التطبيق (للتطبيق و middleware). */
    public function appAbilities(): array
    {
        return AppFeatures::resolveForUser($this)['abilities'];
    }

    /** هل يملك المستخدم قدرة خاصية معيّنة؟ مثال: can('stock_transfer.confirm_receive'). */
    public function canFeature(string $ability): bool
    {
        return in_array($ability, $this->appAbilities(), true);
    }

    public function setMobileNumberAttribute($value)
    {
        if (blank($value)) {
            $this->attributes['mobile_number'] = null;
            return;
        }

        $digits = preg_replace('/\D/', '', $value);

        if (strlen($digits) === 12 && str_starts_with($digits, '966')) {
            $this->attributes['mobile_number'] = $digits;
        } elseif (strlen($digits) === 10 && str_starts_with($digits, '05')) {
            $this->attributes['mobile_number'] = '966' . substr($digits, 1);
        } elseif (strlen($digits) === 9 && str_starts_with($digits, '5')) {
            $this->attributes['mobile_number'] = '966' . $digits;
        } else {
            $this->attributes['mobile_number'] = $digits;
        }
    }
}
