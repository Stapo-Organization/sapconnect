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

  /// No description provided for @checkoutSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get checkoutSoon;

  /// No description provided for @checkoutSoonHint.
  ///
  /// In ar, this message translates to:
  /// **'الدفع وإتمام الطلب داخل التطبيق في الطريق. سلتك محفوظة.'**
  String get checkoutSoonHint;

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
