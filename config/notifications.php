<?php

/*
|--------------------------------------------------------------------------
| كتالوج تنبيهات النظام (Notification Event Catalog)
|--------------------------------------------------------------------------
|
| "مصدر الحقيقة الوحيد" لكل تنبيه يرسله النظام، وما القنوات المتاحة له
| (بريد / تطبيق Push)، ومن جمهوره، وما افتراضه. يقود هذا الملف:
|   1. توجيه الإرسال      →  App\Services\NotificationRouter
|   2. تفضيلات المستخدم    →  App\Support\NotificationPreferences (تطبيق + Filament)
|   3. واجهة التفضيلات     →  GET/PUT /api/profile/notification-preferences
|   4. تجاوز المالك        →  قسم "تفضيلات الإشعارات" في صفحة المستخدم بـ Filament
|
| ملاحظات:
|  - "default_channels": القنوات المفعّلة افتراضياً عند غياب تفضيل صريح للمستخدم.
|  - "audience_roles": الأدوار التي ترى/تتحكم بهذا التنبيه في شاشة التفضيلات.
|  - "user_configurable=false": تنبيه لا يُخصَّص (يُسلَّم دائماً، مثل الإرسال اليدوي).
|  - "email_template": يستخدم قالب email_notifications القابل للتحرير (event_name = المفتاح).
|  - "group": عنوان المجموعة في واجهة التفضيلات (تجميع بصري).
|  - أحداث التنبيه التي لها مُطلِق فعلي فقط مُدرجة هنا — لا توجد مفاتيح ميتة.
*/

return [

    // الـ guard المستخدم لأدوار اللوحة (Spatie). متوافق مع app_features.
    'guard' => 'web',

    'events' => [

        /*
        |--------------------------------------------------------------
        | تحويلات المخزون — المثال المرجعي الذي طلبه المالك
        |--------------------------------------------------------------
        | المُطلِق: StockTransferService::notifyNewTransfers (استيراد SAP).
        | اليوم: بريد (قالب) + إشعار داخل التطبيق. الآن: بريد + Push حسب التفضيل.
        */
        'stock_transfer_created' => [
            'label'            => 'طلب تحويل مخزون جديد',
            'label_en'         => 'New stock transfer',
            'group'            => 'تحويلات المخزون',
            'default_channels' => ['email' => true, 'push' => true],
            'audience_roles'   => ['Super Admin', 'Branch Manager'],
            'user_configurable' => true,
            'email_template'   => true,
        ],

        /*
        |--------------------------------------------------------------
        | الجرد الدوري — تذكير المدير بالجلسات المستحقة/المتأخرة
        |--------------------------------------------------------------
        | المُطلِق: counting:send-cycle-reminders. اليوم: Push فقط (توفير SMS).
        */
        'cycle_count_due' => [
            'label'            => 'تذكير جرد دوري مستحق',
            'label_en'         => 'Cycle count due',
            'group'            => 'الجرد',
            'default_channels' => ['email' => false, 'push' => true],
            'audience_roles'   => ['Super Admin', 'Branch Manager'],
            'user_configurable' => true,
            'email_template'   => true,
        ],

        /*
        |--------------------------------------------------------------
        | سلسلة الإمداد — قرب انتهاء عقد مورّد
        |--------------------------------------------------------------
        | المُطلِق: supply-chain:check-contracts → App\Notifications\ContractExpiryAlert
        | (يبقى جرس Filament عبر قناة database؛ البريد/Push عبر التفضيل).
        */
        'contract_expiry' => [
            'label'            => 'قرب انتهاء عقد مورّد',
            'label_en'         => 'Supplier contract expiring',
            'group'            => 'سلسلة الإمداد',
            'default_channels' => ['email' => true, 'push' => false],
            'audience_roles'   => ['Super Admin'],
            'user_configurable' => true,
            'email_template'   => false, // المحتوى من Notification::toMail
        ],

        /*
        |--------------------------------------------------------------
        | المالية — استحقاق دفعة عند تغيّر حالة الشحنة
        |--------------------------------------------------------------
        | المُطلِق: ShipmentObserver → App\Notifications\FinancePaymentAlert
        | (يبقى جرس Filament عبر قناة database؛ البريد/Push عبر التفضيل).
        */
        'finance_payment_due' => [
            'label'            => 'استحقاق دفعة مورّد',
            'label_en'         => 'Supplier payment due',
            'group'            => 'المالية',
            'default_channels' => ['email' => true, 'push' => false],
            'audience_roles'   => ['Super Admin', 'Finance'],
            'user_configurable' => true,
            'email_template'   => false, // المحتوى من Notification::toMail
        ],

        /*
        |--------------------------------------------------------------
        | النظام — مراقبة مزامنة فواتير SAP (تأخّر / تعافٍ)
        |--------------------------------------------------------------
        | المُطلِق: sap:monitor-invoices. يستخدم Mailable مخصص + قالب DB +
        | حارس تكرار (مرة/ساعة). المستلمون من recipient_roles بالقالب.
        */
        'sap_invoice_delay' => [
            'label'            => 'تأخّر مزامنة فواتير SAP',
            'label_en'         => 'SAP invoice sync delayed',
            'group'            => 'النظام',
            'default_channels' => ['email' => true, 'push' => false],
            'audience_roles'   => ['Super Admin'],
            'user_configurable' => true,
            'email_template'   => true, // عبر Mailable مخصص يقرأ القالب
        ],

        'sap_invoice_recovery' => [
            'label'            => 'تعافي مزامنة فواتير SAP',
            'label_en'         => 'SAP invoice sync recovered',
            'group'            => 'النظام',
            'default_channels' => ['email' => true, 'push' => false],
            'audience_roles'   => ['Super Admin'],
            'user_configurable' => true,
            'email_template'   => true,
        ],

        /*
        |--------------------------------------------------------------
        | الإدارة — إشعار يدوي يُرسله المالك من لوحة التحكم
        |--------------------------------------------------------------
        | المُطلِق: App\Filament\Pages\SendPushNotification.
        | غير قابل للتخصيص: يُسلَّم دائماً Push (إجراء متعمَّد من الإدارة).
        */
        'manual_broadcast' => [
            'label'            => 'إشعار يدوي من الإدارة',
            'label_en'         => 'Manual broadcast',
            'group'            => 'الإدارة',
            'default_channels' => ['email' => false, 'push' => true],
            'audience_roles'   => [],
            'user_configurable' => false,
            'email_template'   => false,
        ],

    ],
];
