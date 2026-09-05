import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// App display name
  ///
  /// In ar, this message translates to:
  /// **'زوبوكسي'**
  String get appName;

  /// No description provided for @actionOk.
  ///
  /// In ar, this message translates to:
  /// **'حسنًا'**
  String get actionOk;

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @actionRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get actionClose;

  /// No description provided for @actionSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get actionSave;

  /// No description provided for @actionDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get actionDone;

  /// No description provided for @actionNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get actionNext;

  /// No description provided for @actionApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get actionApply;

  /// No description provided for @actionClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get actionClear;

  /// No description provided for @actionSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get actionSeeAll;

  /// No description provided for @actionRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get actionRemove;

  /// No description provided for @actionConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get actionConfirm;

  /// No description provided for @actionShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get actionShare;

  /// No description provided for @actionContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get actionContinue;

  /// No description provided for @actionOr.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get actionOr;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navCategories.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get navCategories;

  /// No description provided for @navCart.
  ///
  /// In ar, this message translates to:
  /// **'السلة'**
  String get navCart;

  /// No description provided for @navAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navAccount;

  /// No description provided for @errTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام العملية'**
  String get errTitle;

  /// No description provided for @errNetwork.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة وحاول مجددًا.'**
  String get errNetwork;

  /// No description provided for @errTimeout.
  ///
  /// In ar, this message translates to:
  /// **'استغرق الطلب وقتًا أطول من اللازم. حاول مجددًا.'**
  String get errTimeout;

  /// No description provided for @errServer.
  ///
  /// In ar, this message translates to:
  /// **'خلل مؤقت في الخادم. نعمل على إصلاحه — حاول بعد قليل.'**
  String get errServer;

  /// No description provided for @errNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نعثر على ما تبحث عنه.'**
  String get errNotFound;

  /// No description provided for @errValidation.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من البيانات المُدخلة.'**
  String get errValidation;

  /// No description provided for @errUnauthorized.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة. سجّل الدخول للمتابعة.'**
  String get errUnauthorized;

  /// No description provided for @errUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقّع.'**
  String get errUnknown;

  /// No description provided for @onboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'كل ما يحتاجه صديقك الأليف'**
  String get onboardTitle;

  /// No description provided for @onboardSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقعك لنعرض لك المتوفّر فعليًا قربك ووقت التوصيل الحقيقي.'**
  String get onboardSubtitle;

  /// No description provided for @onboardUseLocation.
  ///
  /// In ar, this message translates to:
  /// **'استخدام موقعي الحالي'**
  String get onboardUseLocation;

  /// No description provided for @onboardChooseCity.
  ///
  /// In ar, this message translates to:
  /// **'اختيار المدينة'**
  String get onboardChooseCity;

  /// No description provided for @onboardSkip.
  ///
  /// In ar, this message translates to:
  /// **'تصفّح بدون تحديد'**
  String get onboardSkip;

  /// No description provided for @onboardLocating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد موقعك…'**
  String get onboardLocating;

  /// No description provided for @onboardLocationDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم نحصل على إذن الموقع. يمكنك اختيار مدينتك يدويًا.'**
  String get onboardLocationDenied;

  /// No description provided for @onboardLocationFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع. اختر مدينتك يدويًا.'**
  String get onboardLocationFailed;

  /// No description provided for @onbStart.
  ///
  /// In ar, this message translates to:
  /// **'يلا نبدأ'**
  String get onbStart;

  /// No description provided for @onbContinue.
  ///
  /// In ar, this message translates to:
  /// **'استمرار'**
  String get onbContinue;

  /// No description provided for @onbLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get onbLater;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'حيّاك الله في زوبوكسي'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'كل اللي يحتاجه حيوانك الأليف — أكل وعناية ولعب — يوصلك لباب البيت بسرعة'**
  String get onbWelcomeBody;

  /// No description provided for @onbLanguageTitle.
  ///
  /// In ar, this message translates to:
  /// **'بأي لغة تحب نخدمك؟'**
  String get onbLanguageTitle;

  /// No description provided for @onbLocTitle.
  ///
  /// In ar, this message translates to:
  /// **'وين نوصّلك؟'**
  String get onbLocTitle;

  /// No description provided for @onbLocBody.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت دبوسك على الخريطة ونوصّل لبابك — مخزون أقرب فرع ووعد توصيل صادق لحيّك'**
  String get onbLocBody;

  /// No description provided for @onbLocPerk1.
  ///
  /// In ar, this message translates to:
  /// **'أسرع توصيل ممكن لحيّك'**
  String get onbLocPerk1;

  /// No description provided for @onbLocPerk2.
  ///
  /// In ar, this message translates to:
  /// **'مخزون حقيقي من أقرب فرع لك'**
  String get onbLocPerk2;

  /// No description provided for @onbLocPerk3.
  ///
  /// In ar, this message translates to:
  /// **'عروض مدينتك أول بأول'**
  String get onbLocPerk3;

  /// No description provided for @onbLocCta.
  ///
  /// In ar, this message translates to:
  /// **'حدد موقعي على الخريطة'**
  String get onbLocCta;

  /// No description provided for @onbLocCity.
  ///
  /// In ar, this message translates to:
  /// **'أختار مدينتي بنفسي'**
  String get onbLocCity;

  /// No description provided for @onbLocSetTitle.
  ///
  /// In ar, this message translates to:
  /// **'وصلناك!'**
  String get onbLocSetTitle;

  /// No description provided for @onbLocFailed.
  ///
  /// In ar, this message translates to:
  /// **'ما قدرنا نحدد موقعك — تقدر تختار مدينتك بنفسك'**
  String get onbLocFailed;

  /// No description provided for @onbNotifTitle.
  ///
  /// In ar, this message translates to:
  /// **'خلّك أول من يعرف'**
  String get onbNotifTitle;

  /// No description provided for @onbNotifBody.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات نوصلك حالة طلبك أولًا بأول وأحلى العروض قبل الكل'**
  String get onbNotifBody;

  /// No description provided for @onbNotifPerk1.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع طلبك خطوة بخطوة'**
  String get onbNotifPerk1;

  /// No description provided for @onbNotifPerk2.
  ///
  /// In ar, this message translates to:
  /// **'عروض وتخفيضات على مقاضي حيوانك'**
  String get onbNotifPerk2;

  /// No description provided for @onbNotifPerk3.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه لحظة وصول طلبك'**
  String get onbNotifPerk3;

  /// No description provided for @onbNotifCta.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات'**
  String get onbNotifCta;

  /// No description provided for @onbNotifMockTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبك في الطريق 🚚'**
  String get onbNotifMockTitle;

  /// No description provided for @onbNotifMockBody.
  ///
  /// In ar, this message translates to:
  /// **'السائق قريب منك — جهّز نفسك!'**
  String get onbNotifMockBody;

  /// Timestamp on the mock notification card in the welcome journey
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get onbNotifNow;

  /// No description provided for @citiesTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر مدينتك'**
  String get citiesTitle;

  /// No description provided for @citiesSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مدينة'**
  String get citiesSearchHint;

  /// No description provided for @citiesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدن مطابقة'**
  String get citiesEmpty;

  /// No description provided for @locationSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل إلى'**
  String get locationSheetTitle;

  /// No description provided for @locationDeliverTo.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل إلى'**
  String get locationDeliverTo;

  /// No description provided for @locationChoose.
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقعك'**
  String get locationChoose;

  /// No description provided for @locationChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get locationChange;

  /// No description provided for @locationUnknownCity.
  ///
  /// In ar, this message translates to:
  /// **'غير محدّد'**
  String get locationUnknownCity;

  /// No description provided for @tierExpress.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سريع'**
  String get tierExpress;

  /// No description provided for @tierSameDay.
  ///
  /// In ar, this message translates to:
  /// **'توصيل اليوم'**
  String get tierSameDay;

  /// No description provided for @tierShipping.
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get tierShipping;

  /// No description provided for @tierPickup.
  ///
  /// In ar, this message translates to:
  /// **'استلام من الفرع'**
  String get tierPickup;

  /// No description provided for @homeAnimalNav.
  ///
  /// In ar, this message translates to:
  /// **'تسوّق حسب حيوانك'**
  String get homeAnimalNav;

  /// No description provided for @homeBrands.
  ///
  /// In ar, this message translates to:
  /// **'أبرز العلامات'**
  String get homeBrands;

  /// No description provided for @homeGreeting.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بك 👋'**
  String get homeGreeting;

  /// No description provided for @homeEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد ما نعرضه الآن'**
  String get homeEmpty;

  /// No description provided for @homeEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للتحديث بعد قليل، أو تصفّح الأقسام.'**
  String get homeEmptyHint;

  /// No description provided for @homeWishlistRail.
  ///
  /// In ar, this message translates to:
  /// **'من مفضّلتك'**
  String get homeWishlistRail;

  /// No description provided for @homeReorderDue.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت إعادة الطلب'**
  String get homeReorderDue;

  /// Coupon chip on a campaign creative
  ///
  /// In ar, this message translates to:
  /// **'كود: {code}'**
  String homeCampaignCoupon(String code);

  /// Discount chip; percent arrives pre-formatted (25٪)
  ///
  /// In ar, this message translates to:
  /// **'خصم {percent}'**
  String homeCampaignDiscount(String percent);

  /// Live countdown chip; time is HH:MM:SS
  ///
  /// In ar, this message translates to:
  /// **'ينتهي خلال {time}'**
  String homeCampaignEndsIn(String time);

  /// No description provided for @homeCampaignEndsInDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{باقي يوم واحد} =2{باقي يومان} few{باقي {days} أيام} other{باقي {days} يومًا}}'**
  String homeCampaignEndsInDays(int days);

  /// No description provided for @homeTrustDelivery.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سريع'**
  String get homeTrustDelivery;

  /// No description provided for @homeTrustPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع آمن'**
  String get homeTrustPayment;

  /// No description provided for @homeTrustGenuine.
  ///
  /// In ar, this message translates to:
  /// **'منتجات أصلية'**
  String get homeTrustGenuine;

  /// No description provided for @homeTrustReturns.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع سهل'**
  String get homeTrustReturns;

  /// No description provided for @categoriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get categoriesTitle;

  /// No description provided for @categoriesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أقسام حاليًا'**
  String get categoriesEmpty;

  /// No description provided for @categoriesShopAll.
  ///
  /// In ar, this message translates to:
  /// **'تسوّق الكل'**
  String get categoriesShopAll;

  /// No description provided for @categoriesProductCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد منتجات} =1{منتج واحد} =2{منتجان} few{{count} منتجات} many{{count} منتجًا} other{{count} منتج}}'**
  String categoriesProductCount(int count);

  /// No description provided for @listingFilters.
  ///
  /// In ar, this message translates to:
  /// **'تصفية'**
  String get listingFilters;

  /// No description provided for @listingSort.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب'**
  String get listingSort;

  /// No description provided for @listingSortTitle.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب النتائج'**
  String get listingSortTitle;

  /// No description provided for @listingFiltersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصفية النتائج'**
  String get listingFiltersTitle;

  /// No description provided for @listingPriceRange.
  ///
  /// In ar, this message translates to:
  /// **'نطاق السعر'**
  String get listingPriceRange;

  /// No description provided for @listingResults.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد نتائج} =1{نتيجة واحدة} =2{نتيجتان} few{{count} نتائج} many{{count} نتيجة} other{{count} نتيجة}}'**
  String listingResults(int count);

  /// No description provided for @listingEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات مطابقة'**
  String get listingEmpty;

  /// No description provided for @listingEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تخفيف عوامل التصفية أو تغيير المدينة.'**
  String get listingEmptyHint;

  /// No description provided for @listingClearFilters.
  ///
  /// In ar, this message translates to:
  /// **'مسح التصفية'**
  String get listingClearFilters;

  /// No description provided for @listingFiltersActive.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مُطبَّق فلتر واحد} =2{مُطبَّق فلتران} few{مُطبَّق {count} فلاتر} other{مُطبَّق {count} فلترًا}}'**
  String listingFiltersActive(int count);

  /// No description provided for @searchTitle.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن منتج أو ماركة أو باركود'**
  String get searchHint;

  /// No description provided for @searchRecent.
  ///
  /// In ar, this message translates to:
  /// **'عمليات بحث سابقة'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل'**
  String get searchClearRecent;

  /// No description provided for @searchNoSuggestions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد اقتراحات'**
  String get searchNoSuggestions;

  /// No description provided for @searchStartHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم منتج أو امسح الباركود'**
  String get searchStartHint;

  /// No description provided for @searchScan.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get searchScan;

  /// No description provided for @scanTitle.
  ///
  /// In ar, this message translates to:
  /// **'امسح الباركود'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الكاميرا نحو الباركود على العبوة'**
  String get scanHint;

  /// No description provided for @scanNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نعثر على منتج بهذا الباركود'**
  String get scanNotFound;

  /// No description provided for @scanPermission.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج إذن الكاميرا لمسح الباركود'**
  String get scanPermission;

  /// No description provided for @pdpAddToCart.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى السلة'**
  String get pdpAddToCart;

  /// No description provided for @pdpOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفّر حاليًا'**
  String get pdpOutOfStock;

  /// No description provided for @pdpQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get pdpQuantity;

  /// No description provided for @pdpDelivery.
  ///
  /// In ar, this message translates to:
  /// **'موعد التوصيل'**
  String get pdpDelivery;

  /// No description provided for @pdpAvailability.
  ///
  /// In ar, this message translates to:
  /// **'التوفّر حسب المستودع'**
  String get pdpAvailability;

  /// No description provided for @pdpFbt.
  ///
  /// In ar, this message translates to:
  /// **'يُشترى عادةً معه'**
  String get pdpFbt;

  /// No description provided for @pdpSubstitutes.
  ///
  /// In ar, this message translates to:
  /// **'بدائل مشابهة'**
  String get pdpSubstitutes;

  /// No description provided for @pdpDescription.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get pdpDescription;

  /// No description provided for @pdpVariantsHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخيار المناسب'**
  String get pdpVariantsHint;

  /// No description provided for @pdpSelectVariant.
  ///
  /// In ar, this message translates to:
  /// **'اختر خيارًا أولًا'**
  String get pdpSelectVariant;

  /// No description provided for @pdpReachable.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تصل إليك قطع} =1{تصلك قطعة واحدة} =2{تصلك قطعتان} few{تصلك {count} قطع} other{تصلك {count} قطعة}}'**
  String pdpReachable(int count);

  /// No description provided for @pdpStockUnits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{نفدت} =1{قطعة واحدة} =2{قطعتان} few{{count} قطع} other{{count} قطعة}}'**
  String pdpStockUnits(int count);

  /// No description provided for @pdpMaxQty.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى المتاح {count}'**
  String pdpMaxQty(int count);

  /// No description provided for @pdpAddedToCart.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى السلة'**
  String get pdpAddedToCart;

  /// No description provided for @pdpLangFallback.
  ///
  /// In ar, this message translates to:
  /// **'بعض التفاصيل معروضة بالعربية'**
  String get pdpLangFallback;

  /// No description provided for @priceFrom.
  ///
  /// In ar, this message translates to:
  /// **'يبدأ من'**
  String get priceFrom;

  /// No description provided for @priceWas.
  ///
  /// In ar, this message translates to:
  /// **'بدلًا من'**
  String get priceWas;

  /// No description provided for @priceOff.
  ///
  /// In ar, this message translates to:
  /// **'خصم {percent}٪'**
  String priceOff(int percent);

  /// No description provided for @cardAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف'**
  String get cardAdd;

  /// No description provided for @cardChooseOptions.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخيارات'**
  String get cardChooseOptions;

  /// No description provided for @cardOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'غير متوفّر'**
  String get cardOutOfStock;

  /// No description provided for @cardStockLeft.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بقيت قطعة واحدة} =2{بقيت قطعتان} few{بقي {count} قطع} other{بقي {count} قطعة}}'**
  String cardStockLeft(int count);

  /// No description provided for @badgeHot.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر طلبًا'**
  String get badgeHot;

  /// No description provided for @badgeTrending.
  ///
  /// In ar, this message translates to:
  /// **'رائج الآن'**
  String get badgeTrending;

  /// No description provided for @badgeNew.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get badgeNew;

  /// No description provided for @badgeLowStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية محدودة'**
  String get badgeLowStock;

  /// No description provided for @badgeBackInStock.
  ///
  /// In ar, this message translates to:
  /// **'عاد للتوفّر'**
  String get badgeBackInStock;

  /// No description provided for @cartTitle.
  ///
  /// In ar, this message translates to:
  /// **'السلة'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'سلتك فارغة'**
  String get cartEmpty;

  /// No description provided for @cartEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف ما يحتاجه صديقك الأليف وسنوصله إليك.'**
  String get cartEmptyHint;

  /// No description provided for @cartStartShopping.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التسوّق'**
  String get cartStartShopping;

  /// No description provided for @cartSubtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع الفرعي'**
  String get cartSubtotal;

  /// No description provided for @cartDiscount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get cartDiscount;

  /// No description provided for @cartShipping.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل'**
  String get cartShipping;

  /// No description provided for @cartTax.
  ///
  /// In ar, this message translates to:
  /// **'الضريبة'**
  String get cartTax;

  /// No description provided for @cartTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get cartTotal;

  /// No description provided for @cartFree.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get cartFree;

  /// No description provided for @cartCoupon.
  ///
  /// In ar, this message translates to:
  /// **'كوبون الخصم'**
  String get cartCoupon;

  /// No description provided for @cartCouponHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز الكوبون'**
  String get cartCouponHint;

  /// No description provided for @cartCouponApply.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get cartCouponApply;

  /// No description provided for @cartCouponRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الكوبون'**
  String get cartCouponRemove;

  /// No description provided for @cartCheckout.
  ///
  /// In ar, this message translates to:
  /// **'إتمام الطلب'**
  String get cartCheckout;

  /// No description provided for @cartShipments.
  ///
  /// In ar, this message translates to:
  /// **'شحنات طلبك'**
  String get cartShipments;

  /// No description provided for @cartShipmentsHint.
  ///
  /// In ar, this message translates to:
  /// **'نقسّم طلبك حسب أسرع مصدر متاح لكل منتج.'**
  String get cartShipmentsHint;

  /// No description provided for @cartFreeShippingRemaining.
  ///
  /// In ar, this message translates to:
  /// **'أضف {amount} لتحصل على توصيل مجاني'**
  String cartFreeShippingRemaining(String amount);

  /// No description provided for @cartFreeShippingQualified.
  ///
  /// In ar, this message translates to:
  /// **'توصيلك مجاني 🎉'**
  String get cartFreeShippingQualified;

  /// No description provided for @cartItemRemoved.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل المنتج من السلة'**
  String get cartItemRemoved;

  /// No description provided for @cartUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديث السلة'**
  String get cartUpdateFailed;

  /// No description provided for @cartItems.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا منتجات} =1{منتج واحد} =2{منتجان} few{{count} منتجات} other{{count} منتجًا}}'**
  String cartItems(int count);

  /// No description provided for @cartLineQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية {qty}'**
  String cartLineQty(int qty);

  /// No description provided for @cartShortfall.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قطعة واحدة تُشحن لاحقًا} =2{قطعتان تُشحنان لاحقًا} few{{count} قطع تُشحن لاحقًا} other{{count} قطعة تُشحن لاحقًا}}'**
  String cartShortfall(int count);

  /// No description provided for @checkoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'إتمام الطلب'**
  String get checkoutTitle;

  /// No description provided for @checkoutStepAddress.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get checkoutStepAddress;

  /// No description provided for @checkoutStepReview.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة'**
  String get checkoutStepReview;

  /// No description provided for @checkoutStepPayment.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get checkoutStepPayment;

  /// No description provided for @checkoutAddressTitle.
  ///
  /// In ar, this message translates to:
  /// **'أين نوصّل طلبك؟'**
  String get checkoutAddressTitle;

  /// No description provided for @checkoutAddressNew.
  ///
  /// In ar, this message translates to:
  /// **'عنوان جديد'**
  String get checkoutAddressNew;

  /// No description provided for @checkoutAddressEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناوين محفوظة'**
  String get checkoutAddressEmpty;

  /// No description provided for @checkoutAddressEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف عنوانك لنعرف أين نوصّل طلبك.'**
  String get checkoutAddressEmptyHint;

  /// No description provided for @checkoutReviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'راجع طلبك'**
  String get checkoutReviewTitle;

  /// No description provided for @checkoutDeliverTo.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل إلى'**
  String get checkoutDeliverTo;

  /// No description provided for @checkoutChangeAddress.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get checkoutChangeAddress;

  /// No description provided for @checkoutItemsShow.
  ///
  /// In ar, this message translates to:
  /// **'عرض المنتجات'**
  String get checkoutItemsShow;

  /// No description provided for @checkoutItemsHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المنتجات'**
  String get checkoutItemsHide;

  /// No description provided for @checkoutPromiseTitle.
  ///
  /// In ar, this message translates to:
  /// **'موعد الوصول'**
  String get checkoutPromiseTitle;

  /// No description provided for @checkoutPromiseSplit.
  ///
  /// In ar, this message translates to:
  /// **'طلبك يصلك على أكثر من شحنة'**
  String get checkoutPromiseSplit;

  /// No description provided for @checkoutNotesLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة للمندوب'**
  String get checkoutNotesLabel;

  /// No description provided for @checkoutNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: اتصل قبل الوصول'**
  String get checkoutNotesHint;

  /// No description provided for @checkoutPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف تحب الدفع؟'**
  String get checkoutPaymentTitle;

  /// No description provided for @checkoutPaymentEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طريقة دفع متاحة الآن'**
  String get checkoutPaymentEmpty;

  /// No description provided for @checkoutPaymentEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'حدّث الصفحة أو حاول بعد قليل.'**
  String get checkoutPaymentEmptyHint;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الطلب'**
  String get checkoutPlaceOrder;

  /// No description provided for @checkoutPayNow.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة للدفع'**
  String get checkoutPayNow;

  /// No description provided for @checkoutPlacing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تأكيد طلبك…'**
  String get checkoutPlacing;

  /// No description provided for @checkoutCartChangedTitle.
  ///
  /// In ar, this message translates to:
  /// **'قائمتك تغيّرت حسب عنوان التوصيل'**
  String get checkoutCartChangedTitle;

  /// No description provided for @checkoutCartChangedHint.
  ///
  /// In ar, this message translates to:
  /// **'راجع ما تغيّر ثم أكمل الطلب.'**
  String get checkoutCartChangedHint;

  /// No description provided for @checkoutCartChangedAction.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الطلب'**
  String get checkoutCartChangedAction;

  /// No description provided for @checkoutSignInReason.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لإتمام طلبك'**
  String get checkoutSignInReason;

  /// No description provided for @successTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام طلبك 🎉'**
  String get successTitle;

  /// No description provided for @successSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'شكرًا لك! بدأنا تجهيز طلبك الآن.'**
  String get successSubtitle;

  /// No description provided for @successOrderNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب #{number}'**
  String successOrderNumber(String number);

  /// No description provided for @successCodNote.
  ///
  /// In ar, this message translates to:
  /// **'ادفع عند الاستلام'**
  String get successCodNote;

  /// No description provided for @successTrack.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع الطلب'**
  String get successTrack;

  /// No description provided for @successKeepShopping.
  ///
  /// In ar, this message translates to:
  /// **'مواصلة التسوّق'**
  String get successKeepShopping;

  /// No description provided for @paymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get paymentTitle;

  /// No description provided for @paymentOpening.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ فتح صفحة الدفع…'**
  String get paymentOpening;

  /// No description provided for @paymentWaiting.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الدفع في النافذة'**
  String get paymentWaiting;

  /// No description provided for @paymentWaitingHint.
  ///
  /// In ar, this message translates to:
  /// **'سنؤكّد طلبك تلقائيًا بمجرد اكتمال العملية.'**
  String get paymentWaitingHint;

  /// No description provided for @paymentConfirming.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تأكيد الدفع…'**
  String get paymentConfirming;

  /// No description provided for @paymentReopen.
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح صفحة الدفع'**
  String get paymentReopen;

  /// No description provided for @paymentFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل الدفع'**
  String get paymentFailedTitle;

  /// No description provided for @paymentFailedHint.
  ///
  /// In ar, this message translates to:
  /// **'لم يصلنا تأكيد الدفع. طلبك محفوظ باسمك ويمكنك المحاولة مجددًا.'**
  String get paymentFailedHint;

  /// No description provided for @paymentSupportHint.
  ///
  /// In ar, this message translates to:
  /// **'إن تكرّر الأمر تواصل معنا وسنكمل طلبك يدويًا.'**
  String get paymentSupportHint;

  /// No description provided for @paymentAmountDue.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق'**
  String get paymentAmountDue;

  /// No description provided for @paymentCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع بالبطاقة'**
  String get paymentCardTitle;

  /// No description provided for @paymentPayAmount.
  ///
  /// In ar, this message translates to:
  /// **'ادفع {amount}'**
  String paymentPayAmount(String amount);

  /// No description provided for @paymentSecureNote.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك مشفّرة، ولا يحتفظ التطبيق ببيانات بطاقتك.'**
  String get paymentSecureNote;

  /// No description provided for @paymentPreparingCard.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز نموذج البطاقة…'**
  String get paymentPreparingCard;

  /// No description provided for @paymentCardFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إتمام الدفع بالبطاقة'**
  String get paymentCardFailed;

  /// No description provided for @paymentOtherMethods.
  ///
  /// In ar, this message translates to:
  /// **'طرق دفع أخرى (Apple Pay وسواها)'**
  String get paymentOtherMethods;

  /// No description provided for @paymentHostedFallback.
  ///
  /// In ar, this message translates to:
  /// **'الدفع بالبطاقة داخل التطبيق غير متاح الآن، سنكمل عبر صفحة الدفع الآمنة.'**
  String get paymentHostedFallback;

  /// No description provided for @paymentSaveCard.
  ///
  /// In ar, this message translates to:
  /// **'احفظ البطاقة لعمليات الدفع القادمة'**
  String get paymentSaveCard;

  /// No description provided for @paymentUseAnotherCard.
  ///
  /// In ar, this message translates to:
  /// **'استخدام بطاقة أخرى'**
  String get paymentUseAnotherCard;

  /// No description provided for @payCardHolder.
  ///
  /// In ar, this message translates to:
  /// **'الاسم على البطاقة'**
  String get payCardHolder;

  /// No description provided for @payCardHolderHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم كما يظهر على البطاقة'**
  String get payCardHolderHint;

  /// No description provided for @payCardNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم البطاقة'**
  String get payCardNumber;

  /// No description provided for @payCardNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'0000 0000 0000 0000'**
  String get payCardNumberHint;

  /// No description provided for @payCardExpiry.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get payCardExpiry;

  /// No description provided for @payCardExpiryHint.
  ///
  /// In ar, this message translates to:
  /// **'شهر / سنة'**
  String get payCardExpiryHint;

  /// No description provided for @payCardCvv.
  ///
  /// In ar, this message translates to:
  /// **'رمز الأمان'**
  String get payCardCvv;

  /// No description provided for @payCardCvvHint.
  ///
  /// In ar, this message translates to:
  /// **'CVV'**
  String get payCardCvvHint;

  /// No description provided for @paymentViewOrder.
  ///
  /// In ar, this message translates to:
  /// **'عرض الطلب'**
  String get paymentViewOrder;

  /// No description provided for @ordersTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get ordersEmpty;

  /// No description provided for @ordersEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'أول طلب لك سيظهر هنا مع تتبّع لحظي.'**
  String get ordersEmptyHint;

  /// No description provided for @orderDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderDetailTitle;

  /// No description provided for @orderItemsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get orderItemsTitle;

  /// No description provided for @orderTimelineTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسار الطلب'**
  String get orderTimelineTitle;

  /// No description provided for @orderAddressTitle.
  ///
  /// In ar, this message translates to:
  /// **'عنوان التوصيل'**
  String get orderAddressTitle;

  /// No description provided for @orderTrackingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشحنة'**
  String get orderTrackingTitle;

  /// No description provided for @orderTrackingNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم التتبّع'**
  String get orderTrackingNumber;

  /// No description provided for @orderTrackingCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ رقم التتبّع'**
  String get orderTrackingCopied;

  /// No description provided for @orderTrackingOpen.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع الشحنة'**
  String get orderTrackingOpen;

  /// No description provided for @orderNotesTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظتك'**
  String get orderNotesTitle;

  /// No description provided for @orderPaymentMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get orderPaymentMethod;

  /// No description provided for @orderPaymentCod.
  ///
  /// In ar, this message translates to:
  /// **'الدفع عند الاستلام'**
  String get orderPaymentCod;

  /// No description provided for @orderPaymentOnline.
  ///
  /// In ar, this message translates to:
  /// **'دفع إلكتروني'**
  String get orderPaymentOnline;

  /// No description provided for @orderPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get orderPaid;

  /// No description provided for @orderUnpaid.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الدفع'**
  String get orderUnpaid;

  /// No description provided for @orderPayNow.
  ///
  /// In ar, this message translates to:
  /// **'إكمال الدفع'**
  String get orderPayNow;

  /// No description provided for @orderReorder.
  ///
  /// In ar, this message translates to:
  /// **'اطلبها مجددًا'**
  String get orderReorder;

  /// No description provided for @orderReorderAdded.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أُضيف منتج واحد إلى السلة} =2{أُضيف منتجان إلى السلة} few{أُضيفت {count} منتجات إلى السلة} other{أُضيف {count} منتجًا إلى السلة}}'**
  String orderReorderAdded(int count);

  /// No description provided for @orderReorderMissing.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منتج واحد غير متوفّر حاليًا} =2{منتجان غير متوفّرين حاليًا} few{{count} منتجات غير متوفّرة حاليًا} other{{count} منتجًا غير متوفّر حاليًا}}'**
  String orderReorderMissing(int count);

  /// No description provided for @addressesTitle.
  ///
  /// In ar, this message translates to:
  /// **'عناويني'**
  String get addressesTitle;

  /// No description provided for @addressesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناوين محفوظة'**
  String get addressesEmpty;

  /// No description provided for @addressesEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'احفظ عنوانك مرة واحدة، ونوصّل إليه في كل مرة.'**
  String get addressesEmptyHint;

  /// No description provided for @addressAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عنوان'**
  String get addressAdd;

  /// No description provided for @addressNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'عنوان جديد'**
  String get addressNewTitle;

  /// No description provided for @addressEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل العنوان'**
  String get addressEditTitle;

  /// No description provided for @addressPinTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقع التوصيل'**
  String get addressPinTitle;

  /// No description provided for @addressPinHint.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة حتى يستقر المؤشّر على باب المنزل.'**
  String get addressPinHint;

  /// No description provided for @addressPinConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الموقع'**
  String get addressPinConfirm;

  /// No description provided for @addressPinChange.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموقع'**
  String get addressPinChange;

  /// No description provided for @addressPinUseGps.
  ///
  /// In ar, this message translates to:
  /// **'موقعي الحالي'**
  String get addressPinUseGps;

  /// No description provided for @addressResolving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد الحي…'**
  String get addressResolving;

  /// No description provided for @addressLabelTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم العنوان'**
  String get addressLabelTitle;

  /// No description provided for @addressLabelHome.
  ///
  /// In ar, this message translates to:
  /// **'المنزل'**
  String get addressLabelHome;

  /// No description provided for @addressLabelWork.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get addressLabelWork;

  /// No description provided for @addressLabelOther.
  ///
  /// In ar, this message translates to:
  /// **'آخر'**
  String get addressLabelOther;

  /// No description provided for @addressNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستلم'**
  String get addressNameLabel;

  /// No description provided for @addressPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get addressPhoneLabel;

  /// No description provided for @addressCityLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get addressCityLabel;

  /// No description provided for @addressDistrictLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحي'**
  String get addressDistrictLabel;

  /// No description provided for @addressBuildingLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم العمارة'**
  String get addressBuildingLabel;

  /// No description provided for @addressFloorLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get addressFloorLabel;

  /// No description provided for @addressApartmentLabel.
  ///
  /// In ar, this message translates to:
  /// **'الشقة'**
  String get addressApartmentLabel;

  /// No description provided for @addressLineLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف العنوان'**
  String get addressLineLabel;

  /// No description provided for @addressLineHint.
  ///
  /// In ar, this message translates to:
  /// **'قريب من؟ معلم مميز؟ بوابة؟'**
  String get addressLineHint;

  /// No description provided for @addressSaveToggle.
  ///
  /// In ar, this message translates to:
  /// **'حفظ هذا العنوان في عناويني'**
  String get addressSaveToggle;

  /// No description provided for @addressSetDefault.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كعنوان افتراضي'**
  String get addressSetDefault;

  /// No description provided for @addressDefaultBadge.
  ///
  /// In ar, this message translates to:
  /// **'الافتراضي'**
  String get addressDefaultBadge;

  /// No description provided for @addressDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف العنوان'**
  String get addressDelete;

  /// No description provided for @addressDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف هذا العنوان؟'**
  String get addressDeleteConfirm;

  /// No description provided for @addressDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف العنوان'**
  String get addressDeleted;

  /// No description provided for @addressSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ العنوان'**
  String get addressSaved;

  /// No description provided for @addressDefaultSet.
  ///
  /// In ar, this message translates to:
  /// **'أصبح هذا عنوانك الافتراضي'**
  String get addressDefaultSet;

  /// No description provided for @addressNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المستلم'**
  String get addressNameRequired;

  /// No description provided for @addressLineRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل تفاصيل العنوان'**
  String get addressLineRequired;

  /// No description provided for @addressCityRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل المدينة'**
  String get addressCityRequired;

  /// No description provided for @addressPinRequired.
  ///
  /// In ar, this message translates to:
  /// **'حدّد الموقع على الخريطة'**
  String get addressPinRequired;

  /// No description provided for @buyAgainTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشترياتي'**
  String get buyAgainTitle;

  /// No description provided for @buyAgainEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مشتريات سابقة'**
  String get buyAgainEmpty;

  /// No description provided for @buyAgainEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'بعد أول طلب ستجد هنا ما تشتريه عادةً بضغطة واحدة.'**
  String get buyAgainEmptyHint;

  /// No description provided for @wishlistTitle.
  ///
  /// In ar, this message translates to:
  /// **'المفضّلة'**
  String get wishlistTitle;

  /// No description provided for @wishlistEmpty.
  ///
  /// In ar, this message translates to:
  /// **'قائمة المفضّلة فارغة'**
  String get wishlistEmpty;

  /// No description provided for @wishlistEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط القلب على أي منتج لحفظه هنا.'**
  String get wishlistEmptyHint;

  /// No description provided for @wishlistAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى المفضّلة'**
  String get wishlistAdded;

  /// No description provided for @wishlistRemoved.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من المفضّلة'**
  String get wishlistRemoved;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get accountTitle;

  /// No description provided for @accountGuest.
  ///
  /// In ar, this message translates to:
  /// **'زائر'**
  String get accountGuest;

  /// No description provided for @accountGuestHint.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لحفظ طلباتك ومفضّلتك'**
  String get accountGuestHint;

  /// No description provided for @accountLogin.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get accountLogin;

  /// No description provided for @accountLogout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get accountLogout;

  /// No description provided for @accountLogoutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج؟'**
  String get accountLogoutConfirm;

  /// No description provided for @accountOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get accountOrders;

  /// No description provided for @accountWishlist.
  ///
  /// In ar, this message translates to:
  /// **'المفضّلة'**
  String get accountWishlist;

  /// No description provided for @accountAddresses.
  ///
  /// In ar, this message translates to:
  /// **'عناويني'**
  String get accountAddresses;

  /// No description provided for @accountBuyAgain.
  ///
  /// In ar, this message translates to:
  /// **'مشترياتي · اطلبها مجددًا'**
  String get accountBuyAgain;

  /// No description provided for @accountSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم والمساعدة'**
  String get accountSupport;

  /// No description provided for @accountAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get accountAbout;

  /// No description provided for @accountVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String accountVersion(String version);

  /// No description provided for @accountPreferences.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get accountPreferences;

  /// No description provided for @accountLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get accountLanguage;

  /// No description provided for @accountLanguageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get accountLanguageArabic;

  /// No description provided for @accountLanguageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get accountLanguageEnglish;

  /// No description provided for @accountTheme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get accountTheme;

  /// No description provided for @accountThemeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get accountThemeLight;

  /// No description provided for @accountThemeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get accountThemeDark;

  /// No description provided for @accountThemeSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب النظام'**
  String get accountThemeSystem;

  /// No description provided for @accountProfile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get accountProfile;

  /// No description provided for @accountSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get accountSoon;

  /// No description provided for @authTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم جوالك وسنرسل لك رمز تحقق.'**
  String get authSubtitle;

  /// No description provided for @authPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'05XXXXXXXX'**
  String get authPhoneHint;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم جوال سعودي صحيح'**
  String get authPhoneInvalid;

  /// No description provided for @authSendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرمز'**
  String get authSendCode;

  /// No description provided for @authOtpTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمزًا مكوّنًا من 4 أرقام إلى {phone}'**
  String authOtpSubtitle(String phone);

  /// No description provided for @authVerify.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get authVerify;

  /// No description provided for @authResendIn.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال خلال {seconds} ثانية'**
  String authResendIn(int seconds);

  /// No description provided for @authResend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get authResend;

  /// No description provided for @authChangeNumber.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرقم'**
  String get authChangeNumber;

  /// No description provided for @authOtpInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رمز غير صحيح، حاول مجددًا'**
  String get authOtpInvalid;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بك في زوبوكسي 🐾'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أخبرنا باسمك لنخاطبك به.'**
  String get authWelcomeSubtitle;

  /// No description provided for @authNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get authNameLabel;

  /// No description provided for @authEmailLabel.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني (اختياري)'**
  String get authEmailLabel;

  /// No description provided for @authFinish.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التسوّق'**
  String get authFinish;

  /// No description provided for @authRequired.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول للمتابعة'**
  String get authRequired;

  /// No description provided for @authRequiredWishlist.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لحفظ منتجاتك المفضّلة'**
  String get authRequiredWishlist;

  /// No description provided for @authLoggedIn.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدخول'**
  String get authLoggedIn;

  /// No description provided for @authCartMerged.
  ///
  /// In ar, this message translates to:
  /// **'دمجنا سلتك السابقة'**
  String get authCartMerged;

  /// No description provided for @commonComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get commonComingSoon;

  /// No description provided for @commonOptional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get commonOptional;

  /// No description provided for @paymentOrCard.
  ///
  /// In ar, this message translates to:
  /// **'أو ادفع بالبطاقة'**
  String get paymentOrCard;

  /// No description provided for @brandAllCategories.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get brandAllCategories;

  /// No description provided for @brandCurated.
  ///
  /// In ar, this message translates to:
  /// **'مختارات {brand}'**
  String brandCurated(String brand);

  /// No description provided for @brandSince.
  ///
  /// In ar, this message translates to:
  /// **'منذ {year}'**
  String brandSince(String year);

  /// No description provided for @brandProductCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد منتجات} =1{منتج واحد} =2{منتجان} few{{count} منتجات} many{{count} منتجًا} other{{count} منتج}}'**
  String brandProductCount(int count);

  /// No description provided for @brandShopAll.
  ///
  /// In ar, this message translates to:
  /// **'كل منتجات {brand}'**
  String brandShopAll(String brand);

  /// No description provided for @brandsTitle.
  ///
  /// In ar, this message translates to:
  /// **'كل الماركات'**
  String get brandsTitle;

  /// No description provided for @cartItemUnreachable.
  ///
  /// In ar, this message translates to:
  /// **'هذا المنتج لا يمكن توصيله إلى موقعك حاليًا'**
  String get cartItemUnreachable;

  /// No description provided for @driftTitle.
  ///
  /// In ar, this message translates to:
  /// **'يبدو أنك في مكان جديد'**
  String get driftTitle;

  /// No description provided for @driftBody.
  ///
  /// In ar, this message translates to:
  /// **'موقعك الحالي: {here}\nعنوان التوصيل المحدد: {saved}'**
  String driftBody(String here, String saved);

  /// No description provided for @driftUseHere.
  ///
  /// In ar, this message translates to:
  /// **'وصّلوا لموقعي الحالي'**
  String get driftUseHere;

  /// No description provided for @driftKeep.
  ///
  /// In ar, this message translates to:
  /// **'إبقاء العنوان المحدد'**
  String get driftKeep;

  /// No description provided for @familyTitle.
  ///
  /// In ar, this message translates to:
  /// **'عائلة زوبوكسي'**
  String get familyTitle;

  /// No description provided for @familyTagline.
  ///
  /// In ar, this message translates to:
  /// **'كل طلب يقرّبك من هدية لصديقك'**
  String get familyTagline;

  /// No description provided for @familyGuestTitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلة زوبوكسي'**
  String get familyGuestTitle;

  /// No description provided for @familyGuestBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف حيوانك وابدأ جمع البصمات — هدايا وتوصيل مجاني، بلا خصومات ولا شروط.'**
  String get familyGuestBody;

  /// No description provided for @familyGuestCta.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get familyGuestCta;

  /// No description provided for @familyAddPet.
  ///
  /// In ar, this message translates to:
  /// **'أضف حيوانك'**
  String get familyAddPet;

  /// No description provided for @familyNoPetTitle.
  ///
  /// In ar, this message translates to:
  /// **'من هو صديقك؟'**
  String get familyNoPetTitle;

  /// No description provided for @familyNoPetBody.
  ///
  /// In ar, this message translates to:
  /// **'عرّفنا على حيوانك واكسب 50 بصمة فورًا'**
  String get familyNoPetBody;

  /// No description provided for @familyDue.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت إعادة طلب {product}'**
  String familyDue(String product);

  /// No description provided for @familyOrderNow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الآن'**
  String get familyOrderNow;

  /// No description provided for @familyMemberSince.
  ///
  /// In ar, this message translates to:
  /// **'عضو منذ {date}'**
  String familyMemberSince(String date);

  /// No description provided for @familyPerksTitle.
  ///
  /// In ar, this message translates to:
  /// **'مزاياك'**
  String get familyPerksTitle;

  /// No description provided for @familyPerkFrom.
  ///
  /// In ar, this message translates to:
  /// **'من مستوى {tier}'**
  String familyPerkFrom(String tier);

  /// No description provided for @familyMyRewards.
  ///
  /// In ar, this message translates to:
  /// **'مكافآتي'**
  String get familyMyRewards;

  /// No description provided for @familyRedeemTitle.
  ///
  /// In ar, this message translates to:
  /// **'استبدل بصماتك'**
  String get familyRedeemTitle;

  /// No description provided for @familySealedTitle.
  ///
  /// In ar, this message translates to:
  /// **'بطاقات تنتظر الخدش'**
  String get familySealedTitle;

  /// No description provided for @familyLedgerLink.
  ///
  /// In ar, this message translates to:
  /// **'سجل البصمات'**
  String get familyLedgerLink;

  /// No description provided for @familyReferralCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة {code}'**
  String familyReferralCode(String code);

  /// No description provided for @familyTierOrders.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا طلبات خلال 12 شهرًا} =1{طلب واحد خلال 12 شهرًا} =2{طلبان خلال 12 شهرًا} few{{count} طلبات خلال 12 شهرًا} many{{count} طلبًا خلال 12 شهرًا} other{{count} طلب خلال 12 شهرًا}}'**
  String familyTierOrders(int count);

  /// No description provided for @familyTierNext.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{طلب واحد يفصلك عن {tier}} =2{طلبان يفصلانك عن {tier}} few{{count} طلبات تفصلك عن {tier}} many{{count} طلبًا يفصلك عن {tier}} other{{count} طلب يفصلك عن {tier}}}'**
  String familyTierNext(int count, String tier);

  /// No description provided for @familyTierTop.
  ///
  /// In ar, this message translates to:
  /// **'أنت في أعلى مستوى — شكرًا لثقتك'**
  String get familyTierTop;

  /// No description provided for @pawsTitle.
  ///
  /// In ar, this message translates to:
  /// **'بصماتك'**
  String get pawsTitle;

  /// No description provided for @pawsUnit.
  ///
  /// In ar, this message translates to:
  /// **'بصمة'**
  String get pawsUnit;

  /// No description provided for @pawsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا بصمات} =1{بصمة واحدة} =2{بصمتان} few{{value} بصمات} many{{value} بصمة} other{{value} بصمة}}'**
  String pawsCount(int count, String value);

  /// No description provided for @pawsPending.
  ///
  /// In ar, this message translates to:
  /// **'{value} بصمة قيد التفعيل'**
  String pawsPending(String value);

  /// No description provided for @pawsPendingHint.
  ///
  /// In ar, this message translates to:
  /// **'تُضاف عند تسليم طلبك'**
  String get pawsPendingHint;

  /// No description provided for @pawsExpires.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي في {date}'**
  String pawsExpires(String date);

  /// No description provided for @pawsHowTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف أكسب البصمات؟'**
  String get pawsHowTitle;

  /// No description provided for @pawsHowOrder.
  ///
  /// In ar, this message translates to:
  /// **'بصمة لكل ريال من قيمة أي طلب يصلك'**
  String get pawsHowOrder;

  /// No description provided for @pawsHowProfile.
  ///
  /// In ar, this message translates to:
  /// **'100 بصمة عند إكمال ملف صديقك بالوزن وتاريخ الميلاد'**
  String get pawsHowProfile;

  /// No description provided for @pawsHowPet.
  ///
  /// In ar, this message translates to:
  /// **'50 بصمة لكل حيوان تضيفه'**
  String get pawsHowPet;

  /// No description provided for @pawsHowPlay.
  ///
  /// In ar, this message translates to:
  /// **'مهمات الشهر وبطاقة «اخدش واربح» مع كل طلب من التطبيق'**
  String get pawsHowPlay;

  /// No description provided for @pawsHowExpiry.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي البصمات بعد 12 شهرًا بلا طلبات'**
  String get pawsHowExpiry;

  /// No description provided for @pawsHowDelivered.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق بعد التسليم — لا شيء يُحتسب قبل أن يصلك الطلب'**
  String get pawsHowDelivered;

  /// No description provided for @pawsToEarn.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لن تكسب بصمات من هذه السلة} =1{ستكسب بصمة واحدة} =2{ستكسب بصمتين} few{ستكسب {value} بصمات} many{ستكسب {value} بصمة} other{ستكسب {value} بصمة}}'**
  String pawsToEarn(int count, String value);

  /// No description provided for @pawsEarned.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{كسبت بصمة واحدة} =2{كسبت بصمتين} few{كسبت {value} بصمات} many{كسبت {value} بصمة} other{كسبت {value} بصمة}}'**
  String pawsEarned(int count, String value);

  /// No description provided for @pawsLedgerTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل البصمات'**
  String get pawsLedgerTitle;

  /// No description provided for @pawsLedgerEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السجل فارغ'**
  String get pawsLedgerEmpty;

  /// No description provided for @pawsLedgerEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'أول طلب يصلك يفتح السجل'**
  String get pawsLedgerEmptyHint;

  /// No description provided for @pawsLedgerMore.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get pawsLedgerMore;

  /// No description provided for @pawsBalanceAfter.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد {value}'**
  String pawsBalanceAfter(String value);

  /// No description provided for @pawsReason.
  ///
  /// In ar, this message translates to:
  /// **'{reason, select, order_earn{طلب مسلَّم} profile_complete{إكمال ملف} pet_added{إضافة حيوان} mission{مهمة الشهر} scratch{اخدش واربح} redeem{استبدال} reverse{عكس قيد} expire{انتهاء صلاحية} adjust{تعديل يدوي} welcome{هدية ترحيب} other{حركة}}'**
  String pawsReason(String reason);

  /// No description provided for @missionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'مهمات الشهر'**
  String get missionsTitle;

  /// No description provided for @missionsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أربع مهمات، تتجدد أول كل شهر'**
  String get missionsSubtitle;

  /// No description provided for @missionProgress.
  ///
  /// In ar, this message translates to:
  /// **'{progress} من {target}'**
  String missionProgress(int progress, int target);

  /// No description provided for @missionDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت'**
  String get missionDone;

  /// No description provided for @missionRewardGift.
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get missionRewardGift;

  /// No description provided for @missionSuggested.
  ///
  /// In ar, this message translates to:
  /// **'يناسب صديقك'**
  String get missionSuggested;

  /// No description provided for @missionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مهمات هذا الشهر'**
  String get missionsEmpty;

  /// No description provided for @missionsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'مهمات جديدة تصلك أول الشهر القادم'**
  String get missionsEmptyHint;

  /// No description provided for @rewardsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المكافآت'**
  String get rewardsTitle;

  /// No description provided for @rewardsMine.
  ///
  /// In ar, this message translates to:
  /// **'مكافآتي'**
  String get rewardsMine;

  /// No description provided for @rewardsCatalog.
  ///
  /// In ar, this message translates to:
  /// **'استبدل بصماتك'**
  String get rewardsCatalog;

  /// No description provided for @rewardsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مكافآت بعد'**
  String get rewardsEmpty;

  /// No description provided for @rewardsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'اجمع البصمات واستبدلها بهدية أو توصيل مجاني'**
  String get rewardsEmptyHint;

  /// No description provided for @rewardsCatalogEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الكتالوج فارغ الآن'**
  String get rewardsCatalogEmpty;

  /// No description provided for @rewardCost.
  ///
  /// In ar, this message translates to:
  /// **'{value} بصمة'**
  String rewardCost(String value);

  /// No description provided for @rewardValue.
  ///
  /// In ar, this message translates to:
  /// **'قيمتها {price}'**
  String rewardValue(String price);

  /// No description provided for @rewardValidity.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{صالحة يومًا واحدًا} =2{صالحة يومين} few{صالحة {count} أيام} many{صالحة {count} يومًا} other{صالحة {count} يوم}}'**
  String rewardValidity(int count);

  /// No description provided for @rewardExpires.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي {date}'**
  String rewardExpires(String date);

  /// No description provided for @rewardRedeem.
  ///
  /// In ar, this message translates to:
  /// **'استبدل'**
  String get rewardRedeem;

  /// No description provided for @rewardRedeemTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الاستبدال'**
  String get rewardRedeemTitle;

  /// No description provided for @rewardRedeemBody.
  ///
  /// In ar, this message translates to:
  /// **'سنخصم {value} بصمة مقابل «{title}». تصبح جاهزة للاستخدام في طلبك القادم.'**
  String rewardRedeemBody(String value, String title);

  /// No description provided for @rewardRedeemDone.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت في مكافآتك'**
  String get rewardRedeemDone;

  /// No description provided for @rewardRedeemFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاستبدال'**
  String get rewardRedeemFailed;

  /// No description provided for @rewardUseInCart.
  ///
  /// In ar, this message translates to:
  /// **'استخدم في السلة'**
  String get rewardUseInCart;

  /// No description provided for @rewardInCart.
  ///
  /// In ar, this message translates to:
  /// **'في سلتك'**
  String get rewardInCart;

  /// No description provided for @rewardRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من السلة'**
  String get rewardRemove;

  /// No description provided for @rewardPendingOrder.
  ///
  /// In ar, this message translates to:
  /// **'تُفعَّل عند تسليم الطلب {number}'**
  String rewardPendingOrder(String number);

  /// No description provided for @rewardPending.
  ///
  /// In ar, this message translates to:
  /// **'تُفعَّل عند تسليم طلبك'**
  String get rewardPending;

  /// No description provided for @rewardKindGift.
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get rewardKindGift;

  /// No description provided for @rewardKindExpress.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سريع مجاني'**
  String get rewardKindExpress;

  /// No description provided for @rewardKindDelivery.
  ///
  /// In ar, this message translates to:
  /// **'توصيل مجاني'**
  String get rewardKindDelivery;

  /// No description provided for @rewardKindPaws.
  ///
  /// In ar, this message translates to:
  /// **'بصمات'**
  String get rewardKindPaws;

  /// No description provided for @rewardUseButton.
  ///
  /// In ar, this message translates to:
  /// **'استخدم مكافأة'**
  String get rewardUseButton;

  /// No description provided for @rewardSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'مكافآتك الجاهزة'**
  String get rewardSheetTitle;

  /// No description provided for @rewardSheetHint.
  ///
  /// In ar, this message translates to:
  /// **'تُضاف إلى هذا الطلب فورًا'**
  String get rewardSheetHint;

  /// No description provided for @rewardSheetEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مكافآت جاهزة الآن'**
  String get rewardSheetEmpty;

  /// No description provided for @rewardGiftChip.
  ///
  /// In ar, this message translates to:
  /// **'هدية'**
  String get rewardGiftChip;

  /// No description provided for @rewardGiftFree.
  ///
  /// In ar, this message translates to:
  /// **'مجانًا'**
  String get rewardGiftFree;

  /// No description provided for @rewardClaimFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر استخدام المكافأة'**
  String get rewardClaimFailed;

  /// No description provided for @rewardGiftUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذه الهدية لا تصل موقعك حاليًا'**
  String get rewardGiftUnavailable;

  /// No description provided for @rewardInsufficientPaws.
  ///
  /// In ar, this message translates to:
  /// **'بصماتك لا تكفي'**
  String get rewardInsufficientPaws;

  /// No description provided for @rewardTierRequired.
  ///
  /// In ar, this message translates to:
  /// **'يتطلب مستوى أعلى'**
  String get rewardTierRequired;

  /// No description provided for @rewardFreeDeliveryTier.
  ///
  /// In ar, this message translates to:
  /// **'توصيل مجاني بفضل مستواك'**
  String get rewardFreeDeliveryTier;

  /// No description provided for @rewardFreeDeliveryReward.
  ///
  /// In ar, this message translates to:
  /// **'توصيل مجاني بمكافأتك'**
  String get rewardFreeDeliveryReward;

  /// No description provided for @rewardExpressFreeTier.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سريع مجاني بفضل مستواك'**
  String get rewardExpressFreeTier;

  /// No description provided for @rewardExpressFreeReward.
  ///
  /// In ar, this message translates to:
  /// **'توصيل سريع مجاني بمكافأتك'**
  String get rewardExpressFreeReward;

  /// No description provided for @scratchTitle.
  ///
  /// In ar, this message translates to:
  /// **'اخدش واربح'**
  String get scratchTitle;

  /// No description provided for @scratchHint.
  ///
  /// In ar, this message translates to:
  /// **'امسح البطاقة بإصبعك'**
  String get scratchHint;

  /// No description provided for @scratchOrder.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة الطلب {number}'**
  String scratchOrder(String number);

  /// No description provided for @scratchPrizePaws.
  ///
  /// In ar, this message translates to:
  /// **'{value} بصمة!'**
  String scratchPrizePaws(String value);

  /// No description provided for @scratchActivation.
  ///
  /// In ar, this message translates to:
  /// **'تُفعَّل عند تسليم الطلب'**
  String get scratchActivation;

  /// No description provided for @scratchSettled.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت في حسابك'**
  String get scratchSettled;

  /// No description provided for @scratchDone.
  ///
  /// In ar, this message translates to:
  /// **'رائع'**
  String get scratchDone;

  /// No description provided for @scratchOpen.
  ///
  /// In ar, this message translates to:
  /// **'اكشف البطاقة'**
  String get scratchOpen;

  /// No description provided for @scratchEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا بطاقات الآن'**
  String get scratchEmpty;

  /// No description provided for @scratchEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'كل طلب من التطبيق يأتي ببطاقة'**
  String get scratchEmptyHint;

  /// No description provided for @petsTitle.
  ///
  /// In ar, this message translates to:
  /// **'عائلتي'**
  String get petsTitle;

  /// No description provided for @petsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا حيوانات بعد'**
  String get petsEmpty;

  /// No description provided for @petsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'عرّفنا على صديقك لنقترح ما يناسبه فعلًا'**
  String get petsEmptyHint;

  /// No description provided for @petsAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف حيوانًا'**
  String get petsAdd;

  /// No description provided for @petsFull.
  ///
  /// In ar, this message translates to:
  /// **'{max, plural, =1{يمكنك إضافة حيوان واحد} =2{يمكنك إضافة حيوانين} few{يمكنك إضافة {max} حيوانات} other{يمكنك إضافة {max} حيوان}}'**
  String petsFull(int max);

  /// No description provided for @petNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'صديق جديد'**
  String get petNewTitle;

  /// No description provided for @petEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملف {name}'**
  String petEditTitle(String name);

  /// No description provided for @petFieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get petFieldName;

  /// No description provided for @petFieldNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مشمش'**
  String get petFieldNameHint;

  /// No description provided for @petFieldSpecies.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get petFieldSpecies;

  /// No description provided for @petFieldBreed.
  ///
  /// In ar, this message translates to:
  /// **'السلالة'**
  String get petFieldBreed;

  /// No description provided for @petFieldBreedHint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get petFieldBreedHint;

  /// No description provided for @petFieldWeight.
  ///
  /// In ar, this message translates to:
  /// **'الوزن'**
  String get petFieldWeight;

  /// No description provided for @petFieldBirthDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد'**
  String get petFieldBirthDate;

  /// No description provided for @petFieldSex.
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get petFieldSex;

  /// No description provided for @petFieldNeutered.
  ///
  /// In ar, this message translates to:
  /// **'معقّم'**
  String get petFieldNeutered;

  /// No description provided for @petWeightUnit.
  ///
  /// In ar, this message translates to:
  /// **'كجم'**
  String get petWeightUnit;

  /// No description provided for @petSexMale.
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get petSexMale;

  /// No description provided for @petSexFemale.
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get petSexFemale;

  /// No description provided for @petSexUnset.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get petSexUnset;

  /// No description provided for @petNotSet.
  ///
  /// In ar, this message translates to:
  /// **'غير مسجّل'**
  String get petNotSet;

  /// No description provided for @petSpeciesCat.
  ///
  /// In ar, this message translates to:
  /// **'قط'**
  String get petSpeciesCat;

  /// No description provided for @petSpeciesDog.
  ///
  /// In ar, this message translates to:
  /// **'كلب'**
  String get petSpeciesDog;

  /// No description provided for @petSpeciesBird.
  ///
  /// In ar, this message translates to:
  /// **'طائر'**
  String get petSpeciesBird;

  /// No description provided for @petSpeciesFish.
  ///
  /// In ar, this message translates to:
  /// **'سمك'**
  String get petSpeciesFish;

  /// No description provided for @petSpeciesSmall.
  ///
  /// In ar, this message translates to:
  /// **'قارض'**
  String get petSpeciesSmall;

  /// No description provided for @petSpeciesReptile.
  ///
  /// In ar, this message translates to:
  /// **'زاحف'**
  String get petSpeciesReptile;

  /// No description provided for @petSpeciesOther.
  ///
  /// In ar, this message translates to:
  /// **'غير ذلك'**
  String get petSpeciesOther;

  /// No description provided for @petNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم صديقك'**
  String get petNameRequired;

  /// No description provided for @petWeightInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل وزنًا بين 0.1 و200 كجم'**
  String get petWeightInvalid;

  /// No description provided for @petBirthDateInvalid.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد لا يمكن أن يكون في المستقبل'**
  String get petBirthDateInvalid;

  /// No description provided for @petSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ'**
  String get petSaveFailed;

  /// No description provided for @petSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get petSaved;

  /// No description provided for @petDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف الملف'**
  String get petDelete;

  /// No description provided for @petDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف ملف {name}؟'**
  String petDeleteConfirm(String name);

  /// No description provided for @petDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الملف'**
  String get petDeleted;

  /// No description provided for @petBirthdaySoon.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{عيد ميلاده اليوم} =1{عيد ميلاده غدًا} =2{عيد ميلاده بعد يومين} few{عيد ميلاده بعد {count} أيام} other{عيد ميلاده بعد {count} يومًا}}'**
  String petBirthdaySoon(int count);

  /// No description provided for @petIncompleteHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف الوزن وتاريخ الميلاد واكسب 100 بصمة'**
  String get petIncompleteHint;

  /// No description provided for @petAgeUnknown.
  ///
  /// In ar, this message translates to:
  /// **'العمر غير مسجّل'**
  String get petAgeUnknown;

  /// No description provided for @petPickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get petPickDate;

  /// No description provided for @petLimitReached.
  ///
  /// In ar, this message translates to:
  /// **'وصلت إلى الحد الأقصى للحيوانات'**
  String get petLimitReached;

  /// No description provided for @familyHubGreeting.
  ///
  /// In ar, this message translates to:
  /// **'عائلة {name}'**
  String familyHubGreeting(String name);

  /// No description provided for @familyHubGreetingNoPet.
  ///
  /// In ar, this message translates to:
  /// **'عائلتك'**
  String get familyHubGreetingNoPet;

  /// No description provided for @familyActionHow.
  ///
  /// In ar, this message translates to:
  /// **'كيف أكسب؟'**
  String get familyActionHow;

  /// No description provided for @familyActionLedger.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get familyActionLedger;

  /// No description provided for @familyActionPets.
  ///
  /// In ar, this message translates to:
  /// **'عائلتي'**
  String get familyActionPets;

  /// No description provided for @familyLadderTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلتك في العائلة'**
  String get familyLadderTitle;

  /// No description provided for @familyPendingOrderTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبك {number} في الطريق'**
  String familyPendingOrderTitle(String number);

  /// No description provided for @familyPendingOrderBody.
  ///
  /// In ar, this message translates to:
  /// **'عند التسليم تُضاف {value} بصمة وتُحتسب مهمّتك تلقائيًا'**
  String familyPendingOrderBody(String value);

  /// No description provided for @familyPendingOrderPaws.
  ///
  /// In ar, this message translates to:
  /// **'عند التسليم تُضاف {value} بصمة إلى محفظتك'**
  String familyPendingOrderPaws(String value);

  /// No description provided for @familyReferralTitle.
  ///
  /// In ar, this message translates to:
  /// **'رمز الدعوة'**
  String get familyReferralTitle;

  /// No description provided for @familyReferralCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ رمز الدعوة'**
  String get familyReferralCopied;

  /// No description provided for @pawsWalletTitle.
  ///
  /// In ar, this message translates to:
  /// **'محفظة البصمات'**
  String get pawsWalletTitle;

  /// No description provided for @missionAwaitingDelivery.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تسليم طلبك'**
  String get missionAwaitingDelivery;

  /// No description provided for @missionsDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} مكتملة'**
  String missionsDoneOf(int done, int total);

  /// No description provided for @rewardComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get rewardComingSoon;

  /// No description provided for @rewardsShelfHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للاستبدال'**
  String get rewardsShelfHint;

  /// No description provided for @cartFreeDeliveryCelebrate.
  ///
  /// In ar, this message translates to:
  /// **'مبروك! التوصيل مجاني'**
  String get cartFreeDeliveryCelebrate;

  /// No description provided for @cartExpressCelebrate.
  ///
  /// In ar, this message translates to:
  /// **'التوصيل السريع مجاني لهذا الطلب'**
  String get cartExpressCelebrate;

  /// No description provided for @successPawsNote.
  ///
  /// In ar, this message translates to:
  /// **'{value} بصمة تُضاف لمحفظتك عند تسليم الطلب'**
  String successPawsNote(String value);

  /// No description provided for @successMissionNote.
  ///
  /// In ar, this message translates to:
  /// **'ومهمات الشهر تُحتسب تلقائيًا بعد التسليم'**
  String get successMissionNote;

  /// No description provided for @scratchKeepGoing.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الخدش…'**
  String get scratchKeepGoing;

  /// No description provided for @missionOfTarget.
  ///
  /// In ar, this message translates to:
  /// **'من {target}'**
  String missionOfTarget(String target);

  /// No description provided for @supplyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مخزون البيت'**
  String get supplyTitle;

  /// No description provided for @supplySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نتعلّم من طلباتك — كل «خلص» أو «عندي كفاية» يجعل التقدير أدق'**
  String get supplySubtitle;

  /// No description provided for @supplyHubSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'متى ينفد أكل عائلتك'**
  String get supplyHubSubtitle;

  /// No description provided for @supplyEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء في العدّاد بعد'**
  String get supplyEmptyTitle;

  /// No description provided for @supplyEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'بعد أول طلب أكل أو رمل من التطبيق نبدأ نحسب متى ينفد ونذكّرك في وقته'**
  String get supplyEmptyBody;

  /// No description provided for @supplyDaysLeft.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{ينفد اليوم} =1{يكفي يومًا} =2{يكفي يومين} few{يكفي {count} أيام} other{يكفي {count} يومًا}}'**
  String supplyDaysLeft(int count);

  /// No description provided for @supplyRunsOutToday.
  ///
  /// In ar, this message translates to:
  /// **'ينفد اليوم'**
  String get supplyRunsOutToday;

  /// No description provided for @supplyOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نفد أمس} =2{نفد قبل يومين} few{نفد قبل {count} أيام} other{نفد قبل {count} يومًا}}'**
  String supplyOverdue(int count);

  /// No description provided for @supplyOrderNow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الآن'**
  String get supplyOrderNow;

  /// No description provided for @supplyOut.
  ///
  /// In ar, this message translates to:
  /// **'خلص'**
  String get supplyOut;

  /// No description provided for @supplySnooze.
  ///
  /// In ar, this message translates to:
  /// **'كفاية'**
  String get supplySnooze;

  /// No description provided for @supplySubscribe.
  ///
  /// In ar, this message translates to:
  /// **'اشترك'**
  String get supplySubscribe;

  /// No description provided for @supplySubscribed.
  ///
  /// In ar, this message translates to:
  /// **'مشترك'**
  String get supplySubscribed;

  /// No description provided for @supplyOnTimeBadge.
  ///
  /// In ar, this message translates to:
  /// **'+{pct}% في وقته'**
  String supplyOnTimeBadge(int pct);

  /// No description provided for @supplyCycle.
  ///
  /// In ar, this message translates to:
  /// **'يكفي {days} يومًا تقريبًا'**
  String supplyCycle(String days);

  /// No description provided for @supplyForPet.
  ///
  /// In ar, this message translates to:
  /// **'لـ{name}'**
  String supplyForPet(String name);

  /// No description provided for @supplyConfidenceLow.
  ///
  /// In ar, this message translates to:
  /// **'تقدير أولي'**
  String get supplyConfidenceLow;

  /// No description provided for @supplyConfidenceMedium.
  ///
  /// In ar, this message translates to:
  /// **'تقدير'**
  String get supplyConfidenceMedium;

  /// No description provided for @supplyConfidenceHigh.
  ///
  /// In ar, this message translates to:
  /// **'مبني على طلباتك'**
  String get supplyConfidenceHigh;

  /// No description provided for @supplyMarkedOut.
  ///
  /// In ar, this message translates to:
  /// **'سجّلنا أن الأكل خلص — حان وقت الطلب'**
  String get supplyMarkedOut;

  /// No description provided for @supplySnoozed.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, other{حسنًا، نذكّرك بعد {count} أيام}}'**
  String supplySnoozed(int count);

  /// No description provided for @supplyKindDry.
  ///
  /// In ar, this message translates to:
  /// **'طعام جاف'**
  String get supplyKindDry;

  /// No description provided for @supplyKindWet.
  ///
  /// In ar, this message translates to:
  /// **'طعام رطب'**
  String get supplyKindWet;

  /// No description provided for @supplyKindLitter.
  ///
  /// In ar, this message translates to:
  /// **'رمل'**
  String get supplyKindLitter;

  /// No description provided for @supplyKindTreat.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت'**
  String get supplyKindTreat;

  /// No description provided for @supplyKindOther.
  ///
  /// In ar, this message translates to:
  /// **'مستلزم'**
  String get supplyKindOther;

  /// No description provided for @supplyWindowHint.
  ///
  /// In ar, this message translates to:
  /// **'اطلب بين {before} أيام قبل النفاد و{after} بعده تكسب +{pct}% بصمات'**
  String supplyWindowHint(int before, int after, int pct);

  /// No description provided for @supplyPack.
  ///
  /// In ar, this message translates to:
  /// **'{kg} كجم'**
  String supplyPack(String kg);

  /// No description provided for @subsTitle.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكاتي'**
  String get subsTitle;

  /// No description provided for @subsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'وصّل لي كل شهر — بلا بطاقة محفوظة ولا التزام، أنت تقرّر كل مرة'**
  String get subsSubtitle;

  /// No description provided for @subsHubSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{اشتراك واحد نشط} =2{اشتراكان نشطان} few{{count} اشتراكات نشطة} other{{count} اشتراكًا نشطًا}}'**
  String subsHubSubtitle(int count);

  /// No description provided for @subsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا اشتراكات بعد'**
  String get subsEmptyTitle;

  /// No description provided for @subsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في أكل عائلتك من مخزون البيت — نذكّرك قبل الموعد وتطلب بضغطة، والتوصيل علينا'**
  String get subsEmptyBody;

  /// No description provided for @subsNextIn.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{التوصيلة غدًا} =2{التوصيلة بعد يومين} few{التوصيلة بعد {count} أيام} other{التوصيلة بعد {count} يومًا}}'**
  String subsNextIn(int count);

  /// No description provided for @subsNextToday.
  ///
  /// In ar, this message translates to:
  /// **'التوصيلة اليوم'**
  String get subsNextToday;

  /// No description provided for @subsOverdue.
  ///
  /// In ar, this message translates to:
  /// **'موعد التوصيلة فات'**
  String get subsOverdue;

  /// No description provided for @subsEvery.
  ///
  /// In ar, this message translates to:
  /// **'كل {days} يومًا'**
  String subsEvery(int days);

  /// No description provided for @subsQty.
  ///
  /// In ar, this message translates to:
  /// **'× {qty}'**
  String subsQty(int qty);

  /// No description provided for @subsPaused.
  ///
  /// In ar, this message translates to:
  /// **'موقوف مؤقتًا'**
  String get subsPaused;

  /// No description provided for @subsOrderNow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الآن'**
  String get subsOrderNow;

  /// No description provided for @subsSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطَّ'**
  String get subsSkip;

  /// No description provided for @subsEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get subsEdit;

  /// No description provided for @subsPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get subsPause;

  /// No description provided for @subsResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get subsResume;

  /// No description provided for @subsCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاشتراك'**
  String get subsCancel;

  /// No description provided for @subsCancelConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تلغي هذا الاشتراك؟ تقدر تشترك مجددًا في أي وقت.'**
  String get subsCancelConfirm;

  /// No description provided for @subsPerks.
  ///
  /// In ar, this message translates to:
  /// **'توصيل مجاني على كل توصيلة · +{pct}% بصمات · هدية كل {every} توصيلات'**
  String subsPerks(int pct, int every);

  /// No description provided for @subsDeliveries.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توصيلات بعد} =1{توصيلة واحدة} =2{توصيلتان} few{{count} توصيلات} other{{count} توصيلة}}'**
  String subsDeliveries(int count);

  /// No description provided for @subsNextGift.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{هدية مع التوصيلة القادمة} =2{هدية بعد توصيلتين} few{هدية بعد {count} توصيلات} other{هدية بعد {count} توصيلة}}'**
  String subsNextGift(int count);

  /// No description provided for @subsEditorTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاشتراك'**
  String get subsEditorTitle;

  /// No description provided for @subsIntervalLabel.
  ///
  /// In ar, this message translates to:
  /// **'كل كم يومًا؟'**
  String get subsIntervalLabel;

  /// No description provided for @subsQtyLabel.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get subsQtyLabel;

  /// No description provided for @subsNextLabel.
  ///
  /// In ar, this message translates to:
  /// **'التوصيلة التالية'**
  String get subsNextLabel;

  /// No description provided for @subsSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get subsSave;

  /// No description provided for @subsCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم الاشتراك — نذكّرك قبل الموعد بثلاثة أيام'**
  String get subsCreated;

  /// No description provided for @subsSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم تخطي هذه التوصيلة'**
  String get subsSkipped;

  /// No description provided for @subsBasketReady.
  ///
  /// In ar, this message translates to:
  /// **'جهّزنا سلتك — التوصيل مجاني'**
  String get subsBasketReady;

  /// No description provided for @subsCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الاشتراك'**
  String get subsCancelled;

  /// No description provided for @subsFreeDeliveryBody.
  ///
  /// In ar, this message translates to:
  /// **'توصيلة اشتراك — الشحن علينا'**
  String get subsFreeDeliveryBody;

  /// No description provided for @successSubscriptionNote.
  ///
  /// In ar, this message translates to:
  /// **'توصيلة اشتراك: بصمات إضافية والتوصيل مجاني'**
  String get successSubscriptionNote;

  /// No description provided for @referralTitle.
  ///
  /// In ar, this message translates to:
  /// **'ادعُ صديقًا'**
  String get referralTitle;

  /// No description provided for @referralHubBody.
  ///
  /// In ar, this message translates to:
  /// **'صديقك يأخذ هدية ترحيب مع أول طلب، وأنت {paws} بصمة بعد تسليمه'**
  String referralHubBody(String paws);

  /// No description provided for @referralShare.
  ///
  /// In ar, this message translates to:
  /// **'شارك الدعوة'**
  String get referralShare;

  /// No description provided for @referralCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الكود'**
  String get referralCopy;

  /// No description provided for @referralCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الكود'**
  String get referralCopied;

  /// No description provided for @referralYourCode.
  ///
  /// In ar, this message translates to:
  /// **'كودك'**
  String get referralYourCode;

  /// No description provided for @referralStatsInvited.
  ///
  /// In ar, this message translates to:
  /// **'دعوات'**
  String get referralStatsInvited;

  /// No description provided for @referralStatsQualified.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التسليم'**
  String get referralStatsQualified;

  /// No description provided for @referralStatsRewarded.
  ///
  /// In ar, this message translates to:
  /// **'مكافآت'**
  String get referralStatsRewarded;

  /// No description provided for @referralHaveCode.
  ///
  /// In ar, this message translates to:
  /// **'عندك كود من صديق؟'**
  String get referralHaveCode;

  /// No description provided for @referralEnterCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كود الدعوة'**
  String get referralEnterCode;

  /// No description provided for @referralApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get referralApply;

  /// No description provided for @referralApplied.
  ///
  /// In ar, this message translates to:
  /// **'تم تطبيق كود {code} — هدية الترحيب في محفظتك'**
  String referralApplied(String code);

  /// No description provided for @referralAppliedBefore.
  ///
  /// In ar, this message translates to:
  /// **'انضممت بدعوة {code}'**
  String referralAppliedBefore(String code);

  /// No description provided for @referralCap.
  ///
  /// In ar, this message translates to:
  /// **'{n} من {cap} دعوات هذا الشهر'**
  String referralCap(int n, int cap);

  /// No description provided for @referralEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تدعُ أحدًا بعد — أول صديق ينتظر'**
  String get referralEmpty;

  /// No description provided for @referralStatePending.
  ///
  /// In ar, this message translates to:
  /// **'انضم — بانتظار أول طلب'**
  String get referralStatePending;

  /// No description provided for @referralStateQualified.
  ///
  /// In ar, this message translates to:
  /// **'أتمّ طلبه — بانتظار الاعتماد'**
  String get referralStateQualified;

  /// No description provided for @referralStateReview.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get referralStateReview;

  /// No description provided for @referralStateRewarded.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة مدفوعة'**
  String get referralStateRewarded;

  /// No description provided for @referralStateRejected.
  ///
  /// In ar, this message translates to:
  /// **'لم تُقبل'**
  String get referralStateRejected;

  /// No description provided for @referralHow.
  ///
  /// In ar, this message translates to:
  /// **'كيف تعمل'**
  String get referralHow;

  /// No description provided for @referralHow1.
  ///
  /// In ar, this message translates to:
  /// **'شارك كودك أو رابطك مع صديق لم يطلب من زوبوكسي من قبل'**
  String get referralHow1;

  /// No description provided for @referralHow2.
  ///
  /// In ar, this message translates to:
  /// **'يطبّق الكود في التطبيق ويأخذ {welcome} مع أول طلب'**
  String referralHow2(String welcome);

  /// No description provided for @referralHow3.
  ///
  /// In ar, this message translates to:
  /// **'بعد تسليم طلبه بأسبوع تصلك {paws} بصمة'**
  String referralHow3(String paws);

  /// No description provided for @momentBirthdayTitle.
  ///
  /// In ar, this message translates to:
  /// **'عيد ميلاد {name} 🎂'**
  String momentBirthdayTitle(String name);

  /// No description provided for @momentBirthdayIn.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{غدًا} =2{بعد يومين} few{بعد {count} أيام} other{بعد {count} يومًا}}'**
  String momentBirthdayIn(int count);

  /// No description provided for @momentBirthdayToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم!'**
  String get momentBirthdayToday;

  /// No description provided for @momentBirthdayPassed.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أمس} =2{قبل يومين} few{قبل {count} أيام} other{قبل {count} يومًا}}'**
  String momentBirthdayPassed(int count);

  /// No description provided for @momentBirthdayGift.
  ///
  /// In ar, this message translates to:
  /// **'هدية باسمه في محفظتك — أضفها لطلبك القادم'**
  String get momentBirthdayGift;

  /// No description provided for @momentBirthdayPaws.
  ///
  /// In ar, this message translates to:
  /// **'{paws} بصمة هدية عيد ميلاد في محفظتك'**
  String momentBirthdayPaws(String paws);

  /// No description provided for @momentBirthdayNoGift.
  ///
  /// In ar, this message translates to:
  /// **'ما رأيك بهدية صغيرة له هذا الأسبوع؟'**
  String get momentBirthdayNoGift;

  /// No description provided for @momentAddToCart.
  ///
  /// In ar, this message translates to:
  /// **'أضف الهدية للسلة'**
  String get momentAddToCart;

  /// No description provided for @momentGiftAdded.
  ///
  /// In ar, this message translates to:
  /// **'أضفنا الهدية لسلتك'**
  String get momentGiftAdded;

  /// No description provided for @tierRiskLine.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{غدًا يهبط مستواك إلى {tier} — طلب واحد يحفظه} =2{بعد يومين يهبط مستواك إلى {tier} — طلب واحد يحفظه} few{خلال {days} أيام يهبط مستواك إلى {tier} — طلب واحد يحفظه} other{خلال {days} يومًا يهبط مستواك إلى {tier} — طلب واحد يحفظه}}'**
  String tierRiskLine(int days, String tier);

  /// No description provided for @stampsTitle.
  ///
  /// In ar, this message translates to:
  /// **'بطاقات الماركات'**
  String get stampsTitle;

  /// No description provided for @stampsRemaining.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بقي واحد} =2{بقي اثنان} few{بقي {count}} other{بقي {count}}}'**
  String stampsRemaining(int count);

  /// No description provided for @stampsDone.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بطاقة مكتملة} =2{بطاقتان مكتملتان} few{{count} بطاقات مكتملة} other{{count} بطاقة مكتملة}}'**
  String stampsDone(int count);

  /// No description provided for @stampsMinPack.
  ///
  /// In ar, this message translates to:
  /// **'عبوات {kg} كجم فأكثر'**
  String stampsMinPack(String kg);

  /// No description provided for @stampsReward.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة'**
  String get stampsReward;

  /// No description provided for @familySupplyLine.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{أكل {name} يكفي يومًا} =2{أكل {name} يكفي يومين} few{أكل {name} يكفي {days} أيام} other{أكل {name} يكفي {days} يومًا}}'**
  String familySupplyLine(int days, String name);

  /// No description provided for @familySupplyDue.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت إعادة طلب أكل {name}'**
  String familySupplyDue(String name);

  /// No description provided for @familySubscriptionLine.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{توصيلة اشتراكك غدًا} =2{توصيلة اشتراكك بعد يومين} few{توصيلة اشتراكك بعد {days} أيام} other{توصيلة اشتراكك بعد {days} يومًا}}'**
  String familySubscriptionLine(int days);

  /// No description provided for @familySubscriptionToday.
  ///
  /// In ar, this message translates to:
  /// **'توصيلة اشتراكك اليوم'**
  String get familySubscriptionToday;

  /// No description provided for @subsEveryWeek.
  ///
  /// In ar, this message translates to:
  /// **'كل أسبوع'**
  String get subsEveryWeek;

  /// No description provided for @subsEveryTwoWeeks.
  ///
  /// In ar, this message translates to:
  /// **'كل أسبوعين'**
  String get subsEveryTwoWeeks;

  /// No description provided for @subsEveryMonth.
  ///
  /// In ar, this message translates to:
  /// **'كل شهر'**
  String get subsEveryMonth;

  /// No description provided for @subsEveryTwoMonths.
  ///
  /// In ar, this message translates to:
  /// **'كل شهرين'**
  String get subsEveryTwoMonths;

  /// No description provided for @petEditFormTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل ملف {name}'**
  String petEditFormTitle(String name);

  /// No description provided for @careEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get careEdit;

  /// No description provided for @careFeedTitle.
  ///
  /// In ar, this message translates to:
  /// **'كم يأكل {name}؟'**
  String careFeedTitle(String name);

  /// No description provided for @careFeedKcal.
  ///
  /// In ar, this message translates to:
  /// **'{kcal} سعرة حرارية في اليوم'**
  String careFeedKcal(String kcal);

  /// No description provided for @careGramsPerDay.
  ///
  /// In ar, this message translates to:
  /// **'{grams} غ/يوم'**
  String careGramsPerDay(String grams);

  /// No description provided for @careFeedDry.
  ///
  /// In ar, this message translates to:
  /// **'جاف'**
  String get careFeedDry;

  /// No description provided for @careFeedWet.
  ///
  /// In ar, this message translates to:
  /// **'رطب'**
  String get careFeedWet;

  /// No description provided for @careFeedMixed.
  ///
  /// In ar, this message translates to:
  /// **'مختلط'**
  String get careFeedMixed;

  /// No description provided for @careFeedMixedHint.
  ///
  /// In ar, this message translates to:
  /// **'نصف السعرات من كل نوع'**
  String get careFeedMixedHint;

  /// No description provided for @careFeedStageKitten.
  ///
  /// In ar, this message translates to:
  /// **'صغير'**
  String get careFeedStageKitten;

  /// No description provided for @careFeedStageJunior.
  ///
  /// In ar, this message translates to:
  /// **'يافع'**
  String get careFeedStageJunior;

  /// No description provided for @careFeedStageAdult.
  ///
  /// In ar, this message translates to:
  /// **'بالغ'**
  String get careFeedStageAdult;

  /// No description provided for @careFeedStageSenior.
  ///
  /// In ar, this message translates to:
  /// **'كبير السن'**
  String get careFeedStageSenior;

  /// No description provided for @careActivity.
  ///
  /// In ar, this message translates to:
  /// **'النشاط'**
  String get careActivity;

  /// No description provided for @careActivityLow.
  ///
  /// In ar, this message translates to:
  /// **'هادئ'**
  String get careActivityLow;

  /// No description provided for @careActivityNormal.
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get careActivityNormal;

  /// No description provided for @careActivityHigh.
  ///
  /// In ar, this message translates to:
  /// **'نشيط'**
  String get careActivityHigh;

  /// No description provided for @careCondition.
  ///
  /// In ar, this message translates to:
  /// **'الجسم'**
  String get careCondition;

  /// No description provided for @careConditionUnder.
  ///
  /// In ar, this message translates to:
  /// **'نحيف'**
  String get careConditionUnder;

  /// No description provided for @careConditionIdeal.
  ///
  /// In ar, this message translates to:
  /// **'مثالي'**
  String get careConditionIdeal;

  /// No description provided for @careConditionOver.
  ///
  /// In ar, this message translates to:
  /// **'ممتلئ'**
  String get careConditionOver;

  /// No description provided for @careOverrideHint.
  ///
  /// In ar, this message translates to:
  /// **'تطعمه كمية مختلفة؟'**
  String get careOverrideHint;

  /// No description provided for @careOverrideTitle.
  ///
  /// In ar, this message translates to:
  /// **'كم تطعم {name} فعلاً؟'**
  String careOverrideTitle(String name);

  /// No description provided for @careOverrideBody.
  ///
  /// In ar, this message translates to:
  /// **'سيحسب عدّاد الأكل على هذه الكمية بدل الخطة'**
  String get careOverrideBody;

  /// No description provided for @careOverrideReset.
  ///
  /// In ar, this message translates to:
  /// **'ارجع للخطة'**
  String get careOverrideReset;

  /// No description provided for @careOverrideActive.
  ///
  /// In ar, this message translates to:
  /// **'تطعمه {grams} غ/يوم بدل الخطة'**
  String careOverrideActive(String grams);

  /// No description provided for @careFeedNoWeight.
  ///
  /// In ar, this message translates to:
  /// **'أضف وزن {name} لنحسب كم يأكل'**
  String careFeedNoWeight(String name);

  /// No description provided for @careFeedAddWeight.
  ///
  /// In ar, this message translates to:
  /// **'أضف الوزن'**
  String get careFeedAddWeight;

  /// No description provided for @careFeedUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'حاسبة التغذية متاحة للقطط والكلاب حالياً'**
  String get careFeedUnsupported;

  /// No description provided for @careFeedGaugeNote.
  ///
  /// In ar, this message translates to:
  /// **'عدّاد الأكل يعتمد على هذا الرقم'**
  String get careFeedGaugeNote;

  /// No description provided for @careWeightTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوزن'**
  String get careWeightTitle;

  /// No description provided for @careWeightLog.
  ///
  /// In ar, this message translates to:
  /// **'سجّل وزن اليوم'**
  String get careWeightLog;

  /// No description provided for @careWeightLogTitle.
  ///
  /// In ar, this message translates to:
  /// **'وزن {name} اليوم'**
  String careWeightLogTitle(String name);

  /// No description provided for @careWeightEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا قراءات بعد. أول قراءة تبدأ الرسم'**
  String get careWeightEmpty;

  /// No description provided for @careWeightTrendUp.
  ///
  /// In ar, this message translates to:
  /// **'زاد {kg} كجم خلال {days} يومًا'**
  String careWeightTrendUp(String kg, String days);

  /// No description provided for @careWeightTrendDown.
  ///
  /// In ar, this message translates to:
  /// **'نقص {kg} كجم خلال {days} يومًا'**
  String careWeightTrendDown(String kg, String days);

  /// No description provided for @careWeightTrendFlat.
  ///
  /// In ar, this message translates to:
  /// **'ثابت خلال {days} يومًا'**
  String careWeightTrendFlat(String days);

  /// No description provided for @careWeightFlagGain.
  ///
  /// In ar, this message translates to:
  /// **'زيادة تتجاوز 10٪. إن استمرت فاستشر الطبيب البيطري'**
  String get careWeightFlagGain;

  /// No description provided for @careWeightFlagLoss.
  ///
  /// In ar, this message translates to:
  /// **'نقص يتجاوز 10٪. يستحق نظرة من الطبيب البيطري'**
  String get careWeightFlagLoss;

  /// No description provided for @careWeightMission.
  ///
  /// In ar, this message translates to:
  /// **'+{paws} بصمة لأول قراءة هذا الشهر'**
  String careWeightMission(String paws);

  /// No description provided for @careWeightDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف قراءة {date}؟'**
  String careWeightDeleteConfirm(String date);

  /// No description provided for @careWeightSaved.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل الوزن'**
  String get careWeightSaved;

  /// No description provided for @careWeightPickDate.
  ///
  /// In ar, this message translates to:
  /// **'بتاريخ'**
  String get careWeightPickDate;

  /// No description provided for @careRemindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات الرعاية'**
  String get careRemindersTitle;

  /// No description provided for @careRemindersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «تم» عند إنجازه وسنذكّرك في الموعد القادم'**
  String get careRemindersSubtitle;

  /// No description provided for @careStateUnset.
  ///
  /// In ar, this message translates to:
  /// **'غير مضبوط'**
  String get careStateUnset;

  /// No description provided for @careStateOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get careStateOff;

  /// No description provided for @careStateIn.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{غدًا} =2{بعد يومين} few{بعد {days} أيام} other{بعد {days} يومًا}}'**
  String careStateIn(int days);

  /// No description provided for @careStateDue.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get careStateDue;

  /// No description provided for @careStateOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{تأخر يومًا} =2{تأخر يومين} few{تأخر {days} أيام} other{تأخر {days} يومًا}}'**
  String careStateOverdue(int days);

  /// No description provided for @careDoneToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل. الموعد القادم {date}'**
  String careDoneToast(String date);

  /// No description provided for @careSetTitle.
  ///
  /// In ar, this message translates to:
  /// **'{label} · {name}'**
  String careSetTitle(String label, String name);

  /// No description provided for @careLastOn.
  ///
  /// In ar, this message translates to:
  /// **'آخر مرة'**
  String get careLastOn;

  /// No description provided for @careNextOn.
  ///
  /// In ar, this message translates to:
  /// **'الموعد القادم'**
  String get careNextOn;

  /// No description provided for @careInterval.
  ///
  /// In ar, this message translates to:
  /// **'يتكرر كل'**
  String get careInterval;

  /// No description provided for @careIntervalDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{كل يوم} =2{كل يومين} few{كل {days} أيام} other{كل {days} يومًا}}'**
  String careIntervalDays(int days);

  /// No description provided for @careEnabled.
  ///
  /// In ar, this message translates to:
  /// **'التذكير مفعّل'**
  String get careEnabled;

  /// No description provided for @careSetHint.
  ///
  /// In ar, this message translates to:
  /// **'حدّد آخر مرة وسنحسب الموعد القادم'**
  String get careSetHint;

  /// No description provided for @careSuggested.
  ///
  /// In ar, this message translates to:
  /// **'قد يفيدك'**
  String get careSuggested;

  /// No description provided for @careSupplyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مخزون {name}'**
  String careSupplyTitle(String name);

  /// No description provided for @careSupplyAll.
  ///
  /// In ar, this message translates to:
  /// **'كل المخزون'**
  String get careSupplyAll;

  /// No description provided for @careSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get careSaved;

  /// No description provided for @familyCareLine.
  ///
  /// In ar, this message translates to:
  /// **'اليوم موعد {label} {name}'**
  String familyCareLine(String label, String name);

  /// No description provided for @familyCareOverdue.
  ///
  /// In ar, this message translates to:
  /// **'تأخر موعد {label} {name}'**
  String familyCareOverdue(String label, String name);

  /// No description provided for @familyCareOpen.
  ///
  /// In ar, this message translates to:
  /// **'افتح الملف'**
  String get familyCareOpen;

  /// No description provided for @careEveryWeek.
  ///
  /// In ar, this message translates to:
  /// **'كل أسبوع'**
  String get careEveryWeek;

  /// No description provided for @careEveryTwoWeeks.
  ///
  /// In ar, this message translates to:
  /// **'كل أسبوعين'**
  String get careEveryTwoWeeks;

  /// No description provided for @careEveryMonth.
  ///
  /// In ar, this message translates to:
  /// **'كل شهر'**
  String get careEveryMonth;

  /// No description provided for @careEveryTwoMonths.
  ///
  /// In ar, this message translates to:
  /// **'كل شهرين'**
  String get careEveryTwoMonths;

  /// No description provided for @careEveryQuarter.
  ///
  /// In ar, this message translates to:
  /// **'كل 3 أشهر'**
  String get careEveryQuarter;

  /// No description provided for @careEveryHalfYear.
  ///
  /// In ar, this message translates to:
  /// **'كل 6 أشهر'**
  String get careEveryHalfYear;

  /// No description provided for @careEveryYear.
  ///
  /// In ar, this message translates to:
  /// **'كل سنة'**
  String get careEveryYear;

  /// No description provided for @actionDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get actionDelete;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
