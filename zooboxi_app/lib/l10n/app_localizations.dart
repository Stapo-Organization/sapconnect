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
  /// **'حدد موقعك ونعرض لك مخزون أقرب فرع ووعد توصيل صادق لحيّك'**
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
  /// **'حدد موقعي تلقائيًا'**
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

  /// No description provided for @addressLineLabel.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل العنوان'**
  String get addressLineLabel;

  /// No description provided for @addressLineHint.
  ///
  /// In ar, this message translates to:
  /// **'الشارع، رقم المبنى، أقرب معلم'**
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
