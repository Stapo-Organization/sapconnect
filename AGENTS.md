# AGENTS.md — Muntajat Automation Platform (sapconnect)

## 📌 نظرة عامة

هذا المشروع هو **النواة المركزية** لمنصة مُنتجات للأتمتة. يتكون من:
- **Backend:** Laravel 11 + Filament 3 (لوحة التحكم الإدارية)
- **Database:** SQLite (قاعدة بيانات محلية)
- **API:** REST API للتكامل مع WooCommerce وتطبيق Flutter
- **ERP Integration:** SAP Business One Service Layer

## 🏗️ الهيكل المعماري

```
sapconnect/
├── app/
│   ├── Console/Commands/       # أوامر Artisan (مزامنة SAP)
│   ├── Filament/
│   │   ├── Resources/          # 30+ Resource لـ Filament Admin
│   │   ├── Pages/              # Dashboard Pages
│   │   ├── Widgets/            # Dashboard Widgets
│   │   └── RetailWidgets/      # Custom Livewire Widgets
│   ├── Http/
│   │   ├── Controllers/Api/    # API Controllers
│   │   └── Middleware/         # Auth, SAP Environment, Logging
│   ├── Models/                 # Eloquent Models (40+)
│   ├── Services/
│   │   ├── SAP/                # SapClient, CsvParser, PayloadTransformer
│   │   ├── Woo/                # WooDeliveryService, WooStockService
│   │   ├── Sms/                # SMS Services
│   │   └── Zid/                # Zid Integration
│   ├── Jobs/                   # Background Jobs
│   ├── Observers/              # Model Observers (ShipmentObserver)
│   └── Policies/               # Authorization Policies
├── config/
│   ├── sap.php                 # SAP Service Layer Configuration
│   ├── scramble.php            # API Documentation (Scramble)
│   └── services.php            # Third-party Services
├── database/migrations/        # 84 Migration
├── routes/
│   ├── api.php                 # API Routes (Store, SAP, Woo, Mobile)
│   ├── web.php                 # Web Routes
│   └── console.php             # Console Routes
└── docs/
    └── supply_chain_user_guide.md
```

## 🔧 التقنيات المستخدمة

| التقنية | الإصدار | الاستخدام |
|---------|---------|-----------|
| PHP | ^8.2 | Backend |
| Laravel | ^11.0 | Framework |
| Filament | ^3.2 | Admin Panel |
| Laravel Sanctum | ^4.0 | API Authentication |
| Spatie Permission | ^6.0 | RBAC |
| Dedoc Scramble | ^0.11.1 | API Documentation |
| GuzzleHTTP | ^7.8 | HTTP Client |
| SQLite | — | Database |

## 🧑‍💼 أنماط التطوير

### 1. Model Naming
- نماذج Eloquent: PascalCase مفرد (`Supplier`, `PurchaseOrder`)
- الجداول: snake_case جمع (`suppliers`, `purchase_orders`)
- الـ fillable: يشمل كل الحقول القابلة للتعديل
- الـ casts: دائماً نحدد الأنواع (`array`, `boolean`, `decimal`, `datetime`)

### 2. Filament Resources
- كل Resource يحتوي على Form Schema + Table Columns + Actions
- استخدام `->disabled()` للحقول القادمة من SAP (للقراءة فقط)
- استخدام `->hidden()` حسب صلاحيات المستخدم
- كل Resource له مجلد خاص يحتوي على Pages (`List`, `Create`, `Edit`, `View`)

### 3. API Endpoints
- **Public:** `/api/store/*` — لا يحتاج مصادقة (للعميل)
- **Mobile:** `/api/*` مع `auth:sanctum` — للتطبيق
- **SAP:** `/api/sap/*` مع `auth.app_token` — للتكامل مع SAP
- **Woo:** `/api/woo/*` مع `auth.woo_token` — للتكامل مع WooCommerce

### 4. Services
- كل Service Class مسؤول عن وظيفة واحدة
- Dependency Injection عبر Constructor
- استخدام `DB::transaction()` للعمليات المالية

## 🔐 الصلاحيات والأدوار (RBAC)

| الدور | الصلاحيات |
|-------|-----------|
| Super Admin | كامل الصلاحيات |
| Finance | قراءة + إدارة Payment Alerts |
| Operator | إنشاء/تعديل Shipments, POs, Suppliers |
| Stakeholder | قراءة فقط (ReadOnlyStakeholder) |

## 🔄 سير المزامنة مع SAP

### Commands:
```bash
php artisan sap:sync-suppliers    # يومياً
php artisan sap:sync-products     # يومياً
php artisan sap:sync-brands       # يومياً
php artisan sap:sync-stock        # كل 10 دقائق
```

### Configuration (`config/sap.php`):
- `url` — SAP Service Layer URL
- `company_db` — اسم قاعدة البيانات
- `username/password` — بيانات الاعتماد
- `session_timeout` — 29 دقيقة

## 📝 اصطلاحات الكود

### إنشاء Resource جديد:
```bash
php artisan make:filament-resource ResourceName
```

### إنشاء Migration:
```bash
php artisan make:migration create_table_name_table
```

### إنشاء Service:
```php
// app/Services/Feature/ServiceName.php
namespace App\Services\Feature;

class ServiceName
{
    public function __construct(private Dependency $dep) {}
    // ...
}
```

## 🧪 الاختبارات

- PHPUnit مُهيأ في `phpunit.xml`
- اختبارات في مجلد `tests/`

## 🚀 Deploy

- لا تقم بتشغيل `git commit` أو `git push` إلا بعد طلب صريح
- استخدم `.env.example` كقالب
- بعد أي تغيير في migrations شغّل: `php artisan migrate`

## 🌐 اللغة

- الواجهة الإدارية: عربي + إنجليزي (ملفات في `lang/ar.json` و `lang/en.json`)
- الكود: إنجليزي
- التعليقات: عربي أو إنجليزي حسب السياق

## ⚠️ ملاحظات مهمة

1. **SAP Read-Only:** النظام يقرأ من SAP فقط — لا يكتب فيه
2. **Stock Management:** المخزون يُدار في SAP، نسخته المحلية للقراءة فقط
3. **Woo Sync:** منتجات `woo_sync = true` فقط تُزامن مع WooCommerce
4. **Zooboxi:** منتجات `zooboxi_active = true` فقط تظهر في المتجر
5. **Payment Alerts:** تُنشأ تلقائياً — لا تُنشأ يدوياً

## 📞 Contact

- المنصة: Muntajat Automation Platform
- API Base: `https://sapapi.muntajat.sa/api`
- Admin Panel: `https://sapapi.muntajat.sa/admin`
