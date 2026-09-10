# رفع نسخة إلى TestFlight

كل شي يتم من الطرفية — لا يحتاج تسجيل دخول Xcode ولا واجهة.

## المتغيرات
```sh
export ASC_KEY_ID=7MK7Y3F4F7
export ASC_ISSUER_ID=6828f241-957e-434e-b02e-11aac4addc98
export ASC_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_7MK7Y3F4F7.p8
```

## الخطوات
1. ارفع رقم البناء في `pubspec.yaml` (`version: 1.0.0+N`) — أبل ترفض رقمًا مستعملًا.
2. `flutter build ipa --export-options-plist=ios/ExportOptions.plist`
3. `xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey $ASC_KEY_ID --apiIssuer $ASC_ISSUER_ID`
4. تابع المعالجة (تأخذ ٥–١٥ دقيقة قبل أن يظهر البناء أصلًا):
   `ruby tool/asc.rb get "/v1/builds?filter%5Bapp%5D=6810280873&fields%5Bbuilds%5D=version,processingState"`

## ثوابت الحساب
| | |
|---|---|
| فريق | `3GSZ27MT3C` — COMPANY AL-UFUG AL-MUTAADDID |
| معرّف التطبيق | `com.zooboxi.app` (+ الامتداد `.LiveActivity`) |
| معرّف السجل في ASC | `6810280873` |
| شهادة التوزيع | `2N8652LDX6` · تنتهي 2027-09-10 |
| ملفا التعريف | «Zooboxi App Store» · «Zooboxi LiveActivity App Store» |
| مجموعة الاختبار الداخلي | `alofq` — تستلم كل بناء تلقائيًا |

## مطبّات دفعنا ثمنها
- **الشهادة والمفتاح لازم يدخلان الكيتشين معًا** كملف PKCS#12، وبخوارزميات قديمة:
  `-keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1`. بدونها يفشل الاستيراد
  بـ«MAC verification failed» لأن OpenSSL 3 يشفّر بما لا يقرؤه الكيتشين.
- **لا تربط بناءً بمجموعة داخلية** — أبل ترد 422. الداخلية تستلم كل شي تلقائيًا.
- الأقواس في مسارات الـAPI لازم تكون `%5B` و`%5D`، وإلا 404 PATH_ERROR.

## تقديم للمراجعة (App Store) — ما تم ضبطه مرة واحدة عبر الـAPI
- الإصدار 1.0 `500a3384-…`، الترجمة ar-SA `49da5bfe-…`، appInfo `ede671d4-…`
- التصنيف SHOPPING · التصنيف العمري كامل (كل الأسئلة الجديدة: advertising/messagingAndChat/… = false)
- السعر: مجاني، الإقليم الأساسي SAU (`POST /v1/appPriceSchedules` بـ included appPrices)
- التوفّر: كل الأقاليم (`POST /v2/appAvailabilities` — v1 غير موجود)
- الإصدار يدوي (`releaseType: MANUAL`) — بعد الموافقة المالك يضغط نشر
- اللقطات: `ruby tool/asc_screenshots.rb <locId> build/appstore` — الحجم 1320×2868 = APP_IPHONE_67
- حساب المراجع: 0500000000 / 4471 (خيارات المتجر `zooboxi_review_phone` / `zooboxi_review_otp`)
- استبيان App Privacy لا API له — من الواجهة فقط
- التقديم: `POST /v1/reviewSubmissions` ثم `reviewSubmissionItems` ثم PATCH `submitted: true`
