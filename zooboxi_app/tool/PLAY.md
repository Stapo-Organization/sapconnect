# رفع نسخة إلى Google Play

## مفتاح الرفع (upload key)
- الملف: `~/.zooboxi/upload-keystore.jks` — alias `upload` — كلمة السر في `~/.zooboxi/upload-keystore.txt`
- `android/key.properties` (خارج git) يشير إليه؛ بدونه يوقّع البناء بمفتاح debug ويرفضه Play.
- SHA-256: `92:85:D4:09:6B:92:F8:FC:47:3E:08:98:43:00:40:2E:02:8F:F9:60:61:13:DC:D2:82:7D:2A:6D:69:EF:EB:31`
- **انسخ الملفين إلى مكان آمن خارج الجهاز.** مع Play App Signing (الافتراضي) ضياع مفتاح الرفع قابل للاستبدال عبر الدعم، لكن ببطء.

## الرفع من الطرفية (`tool/play.rb`)
حساب الخدمة `id-play-publisher@zooboxi-play.iam.gserviceaccount.com` (مشروع Cloud `zooboxi-play`، مدعوّ Admin على التطبيق)،
مفتاحه في `~/.zooboxi/play-service-account.json`. الأوامر: `token | get | post | put | patch | upload | delete`.
```sh
E=$(ruby tool/play.rb post applications/com.zooboxi.app/edits /dev/null | grep -o '[0-9]\{10,\}' | head -1)
ruby tool/play.rb upload "applications/com.zooboxi.app/edits/${E}/bundles?uploadType=media" build/app/outputs/bundle/release/app-release.aab application/octet-stream
ruby tool/play.rb put "applications/com.zooboxi.app/edits/${E}/tracks/internal" track.json   # {"track":"internal","releases":[{"versionCodes":["N"],"status":"completed"}]}
ruby tool/play.rb post "applications/com.zooboxi.app/edits/${E}:commit" /dev/null
```
- **اكتب `${E}:commit` بالأقواس**: zsh يقرأ `$E:c` كمعدِّل تاريخ ويشوّه الرابط (HTML 404 مضلل).
- ما لا تصل إليه الواجهة (يدويًا من Console فقط): App content — الخصوصية، الإعلانات، App access، التصنيف، الجمهور، Data safety.
- أول رفع: 2026-09-16، versionCode 34 على Internal testing، مع صفحتي المتجر ar/en-US والصور.

## البناء
1. ارفع `version: 1.0.0+N` في `pubspec.yaml` (Play يرفض versionCode مستعملًا).
2. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
   - تحذير «failed to strip debug symbols» = نقص cmdline-tools على الجهاز فقط؛ الحزمة سليمة (تحقق: `jarsigner -verify -certs`).
3. ارفع الملف في Play Console → Production (أو Internal testing أولًا) → Create release.

## أول مرة (يدويًا من Play Console)
- الحساب: play.google.com/console — حساب المالك الشخصي (ID 8823757611215841782، فيه Stapo Mobile). اسم المطوّر الظاهر يُغيَّر من Developer account → Account details.
- App access للمراجع: رقم `0500000000` ورمز `4471` (خيارا المتجر `zooboxi_review_phone` / `zooboxi_review_otp`).
- إنشاء التطبيق: الاسم «Zooboxi زوبوكسي»، اللغة الافتراضية العربية (ar)، App، Free.
- Store listing: النصوص أدناه + الرسومات من `~/.zooboxi/releases/play-listing/`
  (icon-512.png · feature-graphic.png 1024×500 · screenshot-1..5.png 1242×2208).
- App content: سياسة الخصوصية https://store.zooboxi.com/privacy-policy/ ·
  حذف الحساب https://store.zooboxi.com/delete-account/ · الإعلانات: لا ·
  الجمهور: 18+ (متجر) · التصنيف IARC: تطبيق تسوّق، لا عنف/لا مقامرة · الفئة Shopping.
- Data safety: الجدول أدناه.
- الإصدار الأول يُراجع خلال أيام؛ الأنسب تفعيل Internal testing أولًا ثم Production.

## نصوص المتجر (ar)
- الاسم (30): `Zooboxi زوبوكسي`
- الوصف القصير (80): `كل ما يحتاجه حيوانك الأليف — يوصلك خلال ساعتين في الرياض`
- الوصف الكامل:
```
زوبوكسي متجر مستلزمات الحيوانات الأليفة: طعام، رمل، مكافآت، صيدلية، ألعاب ومستلزمات للقطط والكلاب والطيور والأسماك والقوارض.

⚡ إكسبريس — يوصلك خلال ساعتين
حدّد موقعك وشوف ما هو متوفر فعلًا قريب منك، مع وقت وصول صادق قبل ما تطلب. إكسبريس يعمل يوميًا من 9 صباحًا حتى 1 صباحًا.

🐾 متجر زوبوكسي — كل الكتالوج
آلاف الأصناف من ماركات أصلية: كيت كات، فيلاين قو، أبلاوز، جوسيرا، بيفار، زولكس، فيرسيل لاقا وغيرها، بتوصيل لكل مدن المملكة.

📦 بكجات توفّر عليك
باقات جاهزة بسعر أقل من شراء القطع منفردة، و«اشترِه مجددًا» يذكّرك قبل ما ينتهي الطعام.

💛 عائلة زوبوكسي
سجّل حيوانك واكسب نقاطًا على كل طلب، مكافآت وهدايا بحسب نوع حيوانك.

• دفع آمن: بطاقات، Apple Pay/مدى عبر MyFatoorah، أو الدفع عند الاستلام
• تتبّع الطلب لحظة بلحظة
• عناوين محفوظة ومفضّلة وإعادة طلب بضغطة
```
- Data safety: ينقل: الموقع (تقريبي ودقيق — لعرض المتاح قريبًا ووعد التوصيل، مطلوب) · معلومات شخصية: الاسم، رقم الجوال، العنوان (الحساب والتوصيل) · معلومات مالية: سجل المشتريات (الطلبات) · نشاط التطبيق: التفاعلات (لتخصيص الرئيسية) · معرّفات الجهاز: رمز الإشعارات. الكل مشفّر أثناء النقل، لا يُشارك مع أطراف ثالثة إلا مزوّد الدفع لإتمام العملية، ويمكن طلب حذفه (in-app + الصفحة). لا إعلانات.

## الحالة (2026-09-17)
- Internal testing: 1.0.1 (38) مكتمل (بعده 36 و37)، القوائم ar/en-US + الأيقونة + الرسم الترويجي + 5 لقطات مرفوعة عبر `play.rb`؛ `edits:validate` يمرّ.
- الإشعارات تعمل على أندرويد (google-services.json موجود، التطبيق يرسم الإشعار بنفسه).
- ما يبقى من Play Console يدويًا (لا يوجد له API): قسم **App content** — سياسة الخصوصية، App access (0500000000 / 4471)،
  الإعلانات: لا، التصنيف IARC (Shopping)، الجمهور 18+، Data safety (الجدول أعلاه)، ثم إضافة المالك كمختبر داخلي.
- بعد اكتمال App content: الإصدار للإنتاج من الطرفية —
  `edits` → `tracks/production` بنفس versionCode (38) + `status: completed` → `${E}:commit`.
