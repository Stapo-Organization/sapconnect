<?php

namespace App\Console\Commands;

use App\Support\AppFeatures;
use Illuminate\Console\Command;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * يزامن صلاحيات Spatie مع كتالوج config/app_features.php.
 *
 *   php artisan app:sync-feature-permissions
 *
 * - ينشئ أي صلاحية app.{feature}.{action} غير موجودة.
 * - يربط default_roles بالصلاحية مرة واحدة فقط عند إنشائها (لا يدوس تخصيصاتك اللاحقة).
 *   استخدم --reset-defaults لإعادة فرض الافتراضيات على الأدوار (لن يحذف استثناءات المستخدمين).
 *
 * شغّل هذا الأمر بعد كل نشر يضيف خصائص جديدة للكتالوج.
 */
class SyncAppFeaturePermissions extends Command
{
    protected $signature = 'app:sync-feature-permissions {--reset-defaults : إعادة ربط الأدوار الافتراضية بالصلاحيات الموجودة}';

    protected $description = 'مزامنة صلاحيات خصائص تطبيق مدير المعرض من config/app_features.php';

    public function handle(): int
    {
        $guard = AppFeatures::guard();
        $resetDefaults = (bool) $this->option('reset-defaults');

        $created = 0;
        $linked = 0;

        foreach (AppFeatures::all() as $feature => $def) {
            $defaultRoles = $def['default_roles'] ?? [];

            foreach (array_keys($def['actions'] ?? []) as $action) {
                $name = AppFeatures::permissionName($feature, $action);

                $permission = Permission::where('name', $name)->where('guard_name', $guard)->first();
                $isNew = false;

                if (! $permission) {
                    $permission = Permission::create(['name' => $name, 'guard_name' => $guard]);
                    $created++;
                    $isNew = true;
                    $this->line("  + أُنشئت الصلاحية: <info>{$name}</info>");
                }

                // اربط الأدوار الافتراضية فقط عند الإنشاء (أو عند --reset-defaults).
                if ($isNew || $resetDefaults) {
                    foreach ($defaultRoles as $roleName) {
                        $role = Role::where('name', $roleName)->where('guard_name', $guard)->first();
                        if ($role && ! $role->hasPermissionTo($permission)) {
                            $role->givePermissionTo($permission);
                            $linked++;
                        }
                    }
                }
            }
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $this->info("تمت المزامنة: {$created} صلاحية جديدة، {$linked} ربط بأدوار افتراضية.");
        $this->newLine();
        $this->line('إجمالي قدرات الكتالوج: ' . count(AppFeatures::allAbilities()));

        return self::SUCCESS;
    }
}
