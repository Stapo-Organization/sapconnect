<?php

/*
|--------------------------------------------------------------------------
| كتالوج خصائص تطبيق مدير المعرض (App Feature Catalog)
|--------------------------------------------------------------------------
|
| هذا الملف هو "مصدر الحقيقة الوحيد" لكل خاصية تظهر في تطبيق مدير المعرض،
| وما يقابلها من صلاحيات وإجراءات. يقود هذا الملف:
|   1. صلاحيات Spatie   →  app.{feature}.{action}   (php artisan app:sync-feature-permissions)
|   2. واجهة Filament    →  قسم "صلاحيات التطبيق" في صفحة المستخدم
|   3. حماية الـ API     →  middleware  feature:{feature}.{action}
|   4. رد /profile و /login → قائمة الصلاحيات الفعّالة للتطبيق
|
| لإضافة خاصية جديدة مستقبلاً: أضِف عنصراً هنا ثم نفّذ:
|   php artisan app:sync-feature-permissions
| فتصبح الخاصية قابلة للتحكم بها لكل مستخدم من اللوحة، وتظهر/تختفي في التطبيق.
|
| ملاحظات:
|  - مفتاح "view" هو إجراء الوصول للخاصية (إن لم يملكه المستخدم لا يرى الخاصية إطلاقاً).
|  - "default_roles" تُربط بصلاحيات الأدوار مرة واحدة عند إنشائها (لا تدوس تخصيصاتك اللاحقة).
|  - "tab" يعني أن الخاصية لها تبويب في الشريط السفلي للتطبيق.
|  - "domain" يطابق ألوان الهوية في التطبيق (AppDomain).
*/

return [

    // الـ guard المستخدم لصلاحيات وأدوار اللوحة (Filament/Spatie). الأدوار الحالية على web.
    'guard' => 'web',

    // بادئة أسماء صلاحيات Spatie الخاصة بخصائص التطبيق.
    'prefix' => 'app',

    'features' => [

        /*
        |--------------------------------------------------------------
        | تحويلات المخزون  —  النموذج المرجعي المكتمل
        |--------------------------------------------------------------
        */
        'stock_transfer' => [
            'label'         => 'تحويلات المخزون',
            'label_en'      => 'Stock Transfers',
            'icon'          => 'heroicon-o-arrows-right-left',
            'domain'        => 'transfers',
            'tab'           => true,
            'default_roles' => ['Super Admin', 'Branch Manager'],
            'actions'       => [
                'view'            => 'عرض التحويلات',
                'send'            => 'تجهيز وإرسال البضاعة',
                'confirm_receive' => 'تأكيد الاستلام',
            ],
        ],

        'inventory_counting' => [
            'label'         => 'الجرد',
            'label_en'      => 'Inventory Counting',
            'icon'          => 'heroicon-o-clipboard-document-check',
            'domain'        => 'counting',
            'tab'           => true,
            'default_roles' => ['Super Admin', 'Branch Manager'],
            'actions'       => [
                'view'     => 'عرض جلسات الجرد',
                'create'   => 'بدء عدّة جرد جديدة',
                'complete' => 'إنهاء/اعتماد الجرد',
            ],
        ],

        'quality_control' => [
            'label'         => 'مهام الجودة',
            'label_en'      => 'Quality Control',
            'icon'          => 'heroicon-o-check-badge',
            'domain'        => 'quality',
            'tab'           => false,
            'default_roles' => ['Super Admin', 'Branch Manager'],
            'actions'       => [
                'view'   => 'عرض مهام الجودة',
                'submit' => 'رفع الصور واعتماد المهمة',
            ],
        ],

        'zooboxi_orders' => [
            'label'         => 'طلبات زوبوكسي العاجلة',
            'label_en'      => 'Zooboxi Express Orders',
            'icon'          => 'heroicon-o-bolt',
            'domain'        => 'zooboxi',
            'tab'           => false,
            'default_roles' => ['Super Admin', 'Branch Manager'],
            'actions'       => [
                'view'    => 'عرض الطلبات',
                'prepare' => 'تجهيز الطلب',
            ],
        ],

        'gamification' => [
            'label'         => 'الإنجازات والنقاط',
            'label_en'      => 'Gamification',
            'icon'          => 'heroicon-o-trophy',
            'domain'        => 'achievements',
            'tab'           => true,
            'default_roles' => ['Super Admin', 'Branch Manager', 'Operator'],
            'actions'       => [
                'view' => 'عرض الإنجازات ولوحة الصدارة',
            ],
        ],

        'promotions' => [
            'label'         => 'الإعلانات والعروض',
            'label_en'      => 'Promotions',
            'icon'          => 'heroicon-o-megaphone',
            'domain'        => 'promotions',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view'    => 'عرض الحملات',
                'approve' => 'اعتماد ونشر الحملات',
            ],
        ],

        /*
        |--------------------------------------------------------------
        | نبض المعرض  —  لوحة قرار لكل فرع (per-branch)
        |--------------------------------------------------------------
        */
        'showroom_pulse' => [
            'label'         => 'نبض المعرض',
            'label_en'      => 'Showroom Pulse',
            'icon'          => 'heroicon-o-heart',
            'domain'        => 'showroom_pulse',
            'tab'           => true,
            'default_roles' => ['Super Admin', 'Branch Manager'],
            'actions'       => [
                'view'             => 'عرض نبض المعرض',
                'request_transfer' => 'رفع طلب تحويل للمالك',
                'suggest_discount' => 'اقتراح خصم للمالك',
            ],
        ],

        /*
        |--------------------------------------------------------------
        | خصائص المالك (Super Admin) — لوحة الإدارة
        |--------------------------------------------------------------
        | هذه الخصائص مخصّصة للمالك فقط (default_roles = Super Admin)،
        | وتظهر خلف تبويب "الإدارة" في التطبيق.
        */
        'retail_dashboard' => [
            'label'         => 'لوحة البيع بالتجزئة',
            'label_en'      => 'Retail Dashboard',
            'icon'          => 'heroicon-o-presentation-chart-line',
            'domain'        => 'admin',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view' => 'عرض لوحة المعارض وتفاصيلها',
            ],
        ],

        'quality_admin' => [
            'label'         => 'إدارة مهام الجودة',
            'label_en'      => 'Quality Tasks Admin',
            'icon'          => 'heroicon-o-clipboard-document-list',
            'domain'        => 'quality',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view'   => 'استعراض القوالب والنسخ ومتابعتها',
                'manage' => 'إنشاء وتعديل مهام الجودة',
            ],
        ],

        'stock_distribution' => [
            'label'         => 'التوزيع الذكي للمخزون',
            'label_en'      => 'Smart Stock Distribution',
            'icon'          => 'heroicon-o-sparkles',
            'domain'        => 'admin',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view' => 'عرض التوصيات',
                'run'  => 'تشغيل محرك التوصيات',
            ],
        ],

        'container_tracking' => [
            'label'         => 'تتبّع الحاويات',
            'label_en'      => 'Container Tracking',
            'icon'          => 'heroicon-o-globe-alt',
            'domain'        => 'admin',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view' => 'عرض شحنات الحاويات وتفاصيلها',
            ],
        ],

        'supply_chain' => [
            'label'         => 'العمليات وسلسلة الإمداد',
            'label_en'      => 'Operations & Supply Chain',
            'icon'          => 'heroicon-o-clipboard-document-list',
            'domain'        => 'admin',
            'tab'           => false,
            'default_roles' => ['Super Admin'],
            'actions'       => [
                'view' => 'عرض ملخص أوامر الشراء والشحنات والتسجيلات',
            ],
        ],

    ],
];
