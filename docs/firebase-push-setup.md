# إعداد إشعارات Firebase Push — قائمة خطوات المالك

كل الكود جاهز (الباكند + التطبيق). يتبقّى فقط إنشاء مشروع Firebase وربط مفاتيحه —
هذه أشياء تتطلّب الدخول على لوحات تحكم لا أملك الوصول إليها. اتبع الخطوات بالترتيب.

> **الـ identifiers المستخدمة:**
> - iOS bundle id: `sa.muntajat.exhibitionManagerApp`
> - Android package: `sa.muntajat.exhibition_manager_app`

---

## 1) إنشاء مشروع Firebase
1. ادخل https://console.firebase.google.com → **Add project** → سمّه مثلاً `Muntajat`.
2. تجاوز Google Analytics (اختياري).

## 2) إضافة تطبيق iOS (الأساسي — يُختبر على iPhone)
1. داخل المشروع → أيقونة iOS (**Add app → Apple**).
2. **Apple bundle ID** = `sa.muntajat.exhibitionManagerApp` → Register.
3. نزّل **`GoogleService-Info.plist`** وأرسله لي (أو ضعه بنفسك في `exhibition_manager_app/ios/Runner/`
   **عبر Xcode** بسحبه إلى مجلد Runner مع تفعيل "Copy items if needed" و target membership = Runner).
   - مهم: لا تضعه يدويًا بالـ Finder فقط — لازم يُضاف لمشروع Xcode ليُحزَّم مع التطبيق.

## 3) إضافة تطبيق Android
1. (**Add app → Android**) → **package name** = `sa.muntajat.exhibition_manager_app` → Register.
2. نزّل **`google-services.json`** وضعه في `exhibition_manager_app/android/app/`.
   - **مطلوب لبناء Android**: بدونه سيفشل بناء أندرويد (بناء iOS لا يتأثر).

## 4) مفتاح APNs (لإشعارات iOS) — يتطلب حساب Apple Developer مدفوع
1. https://developer.apple.com → Certificates, IDs & Profiles → **Keys** → **+**.
2. فعّل **Apple Push Notifications service (APNs)** → Continue → Register → **نزّل ملف `.p8`** (مرة واحدة فقط!).
3. سجّل **Key ID** و **Team ID** (أعلى يمين الحساب).
4. في Firebase → ⚙️ Project Settings → **Cloud Messaging** → قسم **Apple app configuration** →
   **APNs Authentication Key** → ارفع ملف `.p8` + أدخل Key ID و Team ID.
   - الـ `.p8` لا يدخل المستودع نهائيًا — يبقى عندك + في Firebase فقط.

## 5) صلاحيات Xcode (Push) — مرة واحدة
في Xcode افتح `exhibition_manager_app/ios/Runner.xcworkspace` → اختر هدف **Runner** → **Signing & Capabilities**:
1. **+ Capability → Push Notifications**.
2. **+ Capability → Background Modes** → فعّل **Remote notifications**.
   - هذا يُنشئ ملف `Runner.entitlements` ويربطه تلقائيًا.
3. تأكد أن **Team** (التوقيع) مضبوط على حسابك.

## 6) مفتاح خدمة الباكند (Service Account) — لإرسال الإشعارات من الخادم
1. Firebase → ⚙️ Project Settings → **Service accounts** → **Generate new private key** → نزّل ملف JSON.
2. على الخادم (prod) ضعه في: `storage/app/firebase/firebase-credentials.json`
   (المجلد مُستثنى من git — آمن.)
3. أضف في ملف `.env` على prod:
   ```
   FIREBASE_CREDENTIALS=storage/app/firebase/firebase-credentials.json
   ```

## 7) تفعيل مكتبة Firebase في الباكند (على prod عبر SSH)
```bash
cd /path/to/sapconnect       # نسخة prod
composer require kreait/laravel-firebase
php artisan migrate --force  # يطبّق جداول التفضيلات + سجل الإرسال + قالب الجرد
php artisan config:clear
```
> الكود يعمل بأمان **قبل** هذه الخطوة: دالة الإرسال خاملة (تسجّل وتتجاهل) حتى تُثبَّت المكتبة،
> فلا شيء ينكسر إن نشرت الباكند أولًا.

## 8) بناء التطبيق واختباره
```bash
cd exhibition_manager_app
flutter pub get
cd ios && pod install && cd ..
flutter run --release   # على iPhone فعلي (الإشعارات لا تعمل على المحاكي)
```
- عند أول دخول سيظهر طلب إذن الإشعارات → اقبله.
- تحقق أن صفًا أُضيف في جدول `device_tokens` (platform=ios).

## 9) اختبار شامل
1. من لوحة التحكم: **النظام → إرسال إشعار** → استهدف نفسك → أرسل → يصل للـ iPhone.
2. من التطبيق: **الملف الشخصي → الإشعارات** → اضبط "تحويلات المخزون" على **بريد فقط** ثم **تطبيق فقط** وتأكد أن التوجيه يحترم اختيارك.
3. لوحة التحكم → **الإعدادات → سجل الإشعارات المُرسلة** يسجّل كل إرسال.

---

## استكشاف الأخطاء
- **لا يصل إشعار على iPhone:** غالبًا توكِن APNs لا يصل لـ FCM. تأكد من خطوة 4 و5. إن استمر،
  الحل البديل: في `ios/Runner/Info.plist` اجعل `FirebaseAppDelegateProxyEnabled` = `false`
  وأضف تمرير توكِن APNs يدويًا في `AppDelegate.swift` (أخبرني فأضيفه).
- **يفشل بناء Android:** غالبًا `google-services.json` مفقود (خطوة 3).
- **لا يصل بريد بعد التفعيل:** تأكد أن قالب الحدث مفعّل في **لوحة التحكم → قوالب الإشعارات (Email Notifications)**.
