# التحديث الهوائي (Shorebird Code Push)

التطبيق يفحص عند كل فتح إن كان هناك «رقعة» (patch) لإصداره الحالي، ينزّلها بصمت، وتعمل من الفتحة التالية.
الحساب: shorebird.dev (حساب المالك)، app_id في `shorebird.yaml`، الرمز في `~/.zooboxi/shorebird-token.txt`.

```sh
export PATH="$HOME/.shorebird/bin:$PATH"
export SHOREBIRD_TOKEN=$(cat ~/.zooboxi/shorebird-token.txt)
```

## القاعدة
- **يوصل بالرقعة**: أي كود Dart، الأصول (صور/خطوط/ترجمات)، إصلاحات.
- **يحتاج إصدارًا عبر المتجرين** (`shorebird release`): الأيقونة/الاسم، plugin جديد فيه كود أصلي، صلاحية جديدة، رفع نسخة Flutter، أو تغيير في `android/` و`ios/`.
- نسخة Flutter مثبّتة على **3.41.7** (نفس نسخة الجهاز) — مرّرها دائمًا بـ `--flutter-version 3.41.7`.

## إصدار جديد (مرة لكل رقم بناء)
1. ارفع `version: X.Y.Z+N` في `pubspec.yaml`.
2. Android: `shorebird release android --artifact apk --flutter-version 3.41.7 --no-confirm`
   → `build/app/outputs/bundle/release/app-release.aab` يُرفع إلى Play عبر `tool/play.rb` (انظر PLAY.md)، والـAPK إلى `dl/`.
3. iOS: `shorebird release ios --flutter-version 3.41.7 --export-options-plist ios/ExportOptions.plist --no-confirm`
   → `build/ios/ipa/Zooboxi.ipa` يُرفع بـ `xcrun altool` (انظر RELEASE.md).
4. ابنِ الاثنين من نفس الالتزام (commit) دائمًا.

## رقعة (بعد كل تعديل)
```sh
ZB_LEGACY_R8=1 shorebird patch --platforms android --release-version 1.0.2+39 --no-confirm   # 39 فقط: يطابق إعداد R8 القديم (انظر PLAY.md)
shorebird patch --platforms android --release-version X.Y.Z+N --no-confirm   # من 40 فصاعدًا؛ نسخة Flutter تؤخذ من الإصدار نفسه
shorebird patch --platforms ios --release-version X.Y.Z+N --no-confirm
```
- الرقعة تُبنى من نفس الإصدار؛ إن تغيّر شيء أصلي يرفض الأمر ويطلب إصدارًا.
- التحقق: `shorebird releases list` و`shorebird patches list --release-version X.Y.Z+N`.
- التراجع: من لوحة console.shorebird.dev → الإصدار → Patches → Rollback، أو أرسل رقعة جديدة.
- تصل للعميل عند فتح التطبيق مرتين (تنزيل ثم تطبيق). `shorebird preview` لتجربة الإصدار على محاكٍ.

## ملاحظات
- أول إصدار مدعوم بالرقع: **1.0.2 (39)**؛ ما قبله (≤38) لا يمكن ترقيعه.
- `flutter build appbundle` كان يفشل بـ«failed to strip debug symbols» لأن cmdline-tools ناقصة؛ ثُبّتت في `~/Library/Android/sdk/cmdline-tools/latest` مع قبول التراخيص (2026-09-17).
- **بناء تصحيح على المحاكي يكسر رقعة أندرويد بعده** (2026-09-18): `flutter build apk --debug`
  يعيد توليد `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
  بصيغة التصحيح، فيسجّل `integration_test` (اعتماد تطوير). بناء الإصدار يستبعد اعتمادات
  التطوير من Gradle فيسقط javac بـ«package dev.flutter.plugins.integration_test does not
  exist». العلاج: `flutter pub get` ثم احذف كتلة `integration_test` من ذلك الملف (مولّد
  ومستثنى من git)، وأعد الأمر. اختبِر الرقعة بحزمة الإصدار نفسها، لا ببناء تصحيح.
- عملية مقتولة في منتصف البناء تترك كاشًا فاسدًا: Gradle يسقط بصنف مفقود وXcode بـ«disk I/O
  error» على `build.db`. العلاج: `(cd android && ./gradlew --stop)` و`rm -rf
  ~/Library/Developer/Xcode/DerivedData/Runner-*`.
