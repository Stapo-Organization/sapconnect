// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'زوبوكسي';

  @override
  String get actionOk => 'حسنًا';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDone => 'تم';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionApply => 'تطبيق';

  @override
  String get actionClear => 'مسح';

  @override
  String get actionSeeAll => 'الكل';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionOr => 'أو';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCategories => 'الأقسام';

  @override
  String get navCart => 'السلة';

  @override
  String get navAccount => 'حسابي';

  @override
  String get errTitle => 'تعذّر إتمام العملية';

  @override
  String get errNetwork =>
      'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة وحاول مجددًا.';

  @override
  String get errTimeout => 'استغرق الطلب وقتًا أطول من اللازم. حاول مجددًا.';

  @override
  String get errServer =>
      'خلل مؤقت في الخادم. نعمل على إصلاحه — حاول بعد قليل.';

  @override
  String get errNotFound => 'لم نعثر على ما تبحث عنه.';

  @override
  String get errValidation => 'تحقّق من البيانات المُدخلة.';

  @override
  String get errUnauthorized => 'انتهت الجلسة. سجّل الدخول للمتابعة.';

  @override
  String get errUnknown => 'حدث خطأ غير متوقّع.';

  @override
  String get onboardTitle => 'كل ما يحتاجه صديقك الأليف';

  @override
  String get onboardSubtitle =>
      'حدّد موقعك لنعرض لك المتوفّر فعليًا قربك ووقت التوصيل الحقيقي.';

  @override
  String get onboardUseLocation => 'استخدام موقعي الحالي';

  @override
  String get onboardChooseCity => 'اختيار المدينة';

  @override
  String get onboardSkip => 'تصفّح بدون تحديد';

  @override
  String get onboardLocating => 'جارٍ تحديد موقعك…';

  @override
  String get onboardLocationDenied =>
      'لم نحصل على إذن الموقع. يمكنك اختيار مدينتك يدويًا.';

  @override
  String get onboardLocationFailed => 'تعذّر تحديد الموقع. اختر مدينتك يدويًا.';

  @override
  String get onbStart => 'يلا نبدأ';

  @override
  String get onbContinue => 'استمرار';

  @override
  String get onbLater => 'لاحقًا';

  @override
  String get onbWelcomeTitle => 'حيّاك الله في زوبوكسي';

  @override
  String get onbWelcomeBody =>
      'كل اللي يحتاجه حيوانك الأليف — أكل وعناية ولعب — يوصلك لباب البيت بسرعة';

  @override
  String get onbLanguageTitle => 'بأي لغة تحب نخدمك؟';

  @override
  String get onbLocTitle => 'وين نوصّلك؟';

  @override
  String get onbLocBody =>
      'ثبّت دبوسك على الخريطة ونوصّل لبابك — مخزون أقرب فرع ووعد توصيل صادق لحيّك';

  @override
  String get onbLocPerk1 => 'أسرع توصيل ممكن لحيّك';

  @override
  String get onbLocPerk2 => 'مخزون حقيقي من أقرب فرع لك';

  @override
  String get onbLocPerk3 => 'عروض مدينتك أول بأول';

  @override
  String get onbLocCta => 'حدد موقعي على الخريطة';

  @override
  String get onbLocCity => 'أختار مدينتي بنفسي';

  @override
  String get onbLocSetTitle => 'وصلناك!';

  @override
  String get onbLocFailed => 'ما قدرنا نحدد موقعك — تقدر تختار مدينتك بنفسك';

  @override
  String get onbNotifTitle => 'خلّك أول من يعرف';

  @override
  String get onbNotifBody =>
      'فعّل الإشعارات نوصلك حالة طلبك أولًا بأول وأحلى العروض قبل الكل';

  @override
  String get onbNotifPerk1 => 'تتبّع طلبك خطوة بخطوة';

  @override
  String get onbNotifPerk2 => 'عروض وتخفيضات على مقاضي حيوانك';

  @override
  String get onbNotifPerk3 => 'تنبيه لحظة وصول طلبك';

  @override
  String get onbNotifCta => 'فعّل الإشعارات';

  @override
  String get onbNotifMockTitle => 'طلبك في الطريق 🚚';

  @override
  String get onbNotifMockBody => 'السائق قريب منك — جهّز نفسك!';

  @override
  String get onbNotifNow => 'الآن';

  @override
  String get citiesTitle => 'اختر مدينتك';

  @override
  String get citiesSearchHint => 'ابحث عن مدينة';

  @override
  String get citiesEmpty => 'لا توجد مدن مطابقة';

  @override
  String get locationSheetTitle => 'التوصيل إلى';

  @override
  String get locationDeliverTo => 'التوصيل إلى';

  @override
  String get locationSheetSubtitle =>
      'حدّد موقعك على الخريطة ليصل الطلب إلى بابك بالضبط — ونحفظه لك للطلبات القادمة';

  @override
  String get locationMyAddresses => 'عناويني';

  @override
  String get locationSetOnMap => 'حدّد موقعي على الخريطة';

  @override
  String get locationAddOnMap => 'عنوان جديد على الخريطة';

  @override
  String get locationSignInToSave => 'سجّل الدخول لتحفظ عناوينك';

  @override
  String get locationSignInReason =>
      'سجّل الدخول لتحفظ عناوينك وتختار بينها في كل طلب';

  @override
  String get locationResolveFailed => 'تعذّر تحديد الموقع، حاول مرة أخرى';

  @override
  String get locationAddressNotSaved =>
      'تعذّر حفظ العنوان في دفترك — سنوصّل إليه الآن، وتقدر تحفظه لاحقًا';

  @override
  String get locationSheetSubtitlePick =>
      'اختر عنوانًا من عناوينك، أو حدّد موقعًا جديدًا على الخريطة';

  @override
  String get locationArrivesAtPoint => 'يوصلك إلى موقعك';

  @override
  String get locationAddressesFailed => 'تعذّر تحميل عناوينك';

  @override
  String get locationChoose => 'حدّد موقعك';

  @override
  String get locationChange => 'تغيير';

  @override
  String get locationUnknownCity => 'غير محدّد';

  @override
  String get tierExpress => 'توصيل سريع';

  @override
  String get tierSameDay => 'توصيل اليوم';

  @override
  String get tierShipping => 'شحن';

  @override
  String get tierPickup => 'استلام من الفرع';

  @override
  String get homeAnimalNav => 'تسوّق حسب حيوانك';

  @override
  String get homeBrands => 'أبرز العلامات';

  @override
  String get homeGreeting => 'أهلًا بك 👋';

  @override
  String get homeEmpty => 'لا يوجد ما نعرضه الآن';

  @override
  String get homeEmptyHint => 'اسحب للتحديث بعد قليل، أو تصفّح الأقسام.';

  @override
  String get homeWishlistRail => 'من مفضّلتك';

  @override
  String get homeReorderDue => 'حان وقت إعادة الطلب';

  @override
  String homeCampaignCoupon(String code) {
    return 'كود: $code';
  }

  @override
  String homeCampaignDiscount(String percent) {
    return 'خصم $percent';
  }

  @override
  String homeCampaignEndsIn(String time) {
    return 'ينتهي خلال $time';
  }

  @override
  String homeCampaignEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'باقي $days يومًا',
      few: 'باقي $days أيام',
      two: 'باقي يومان',
      one: 'باقي يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get homeTrustDelivery => 'توصيل سريع';

  @override
  String get homeTrustPayment => 'دفع آمن';

  @override
  String get homeTrustGenuine => 'منتجات أصلية';

  @override
  String get homeTrustReturns => 'إرجاع سهل';

  @override
  String get shelfTabsLabel => 'اختيار المتجر';

  @override
  String get shelfExpressTab => 'إكسبريس';

  @override
  String get shelfAllTab => 'زوبكسي';

  @override
  String get shelfExpressClosed => 'التوصيل السريع غير متاح في موقعك الحالي';

  @override
  String get shelfAllSub => 'يصلك غدًا';

  @override
  String get shelfExpressOffSub => 'غير متاح هنا';

  @override
  String get shelfAllSubShipping => 'توصيل لمدينتك';

  @override
  String heroExpressArrives(String time) {
    return 'يوصلك الساعة $time';
  }

  @override
  String get heroExpressWindow => 'خلال ساعتين';

  @override
  String get heroTagNew => 'جديد';

  @override
  String get heroUpTo => 'خصم حتى';

  @override
  String heroExpressArrivesTomorrow(String time) {
    return 'يوصلك غدًا $time';
  }

  @override
  String get heroCutoffToday => 'اطلب الآن ويوصلك اليوم';

  @override
  String get heroCutoffTomorrow => 'اطلب الآن ويوصلك غدًا';

  @override
  String heroCutoffOn(String day) {
    return 'اطلب الآن ويوصلك $day';
  }

  @override
  String heroBranchClosesIn(String time) {
    return 'يغلق بعد $time';
  }

  @override
  String heroCutoffIn(String time) {
    return 'باقي $time على توصيل اليوم';
  }

  @override
  String shelfExpressHours(String open, String close) {
    return '$open – $close';
  }

  @override
  String shelfExpressOpensAt(String time) {
    return 'يفتح $time';
  }

  @override
  String get shelfExpressClosedToday => 'مغلق اليوم';

  @override
  String get shelfExpressOpenNow => 'مفتوح الآن';

  @override
  String locationArrivesAtNamed(String label) {
    return 'يوصلك في $label';
  }

  @override
  String etaAt(String time) {
    return 'الساعة $time';
  }

  @override
  String etaTomorrowAt(String time) {
    return 'غدًا $time';
  }

  @override
  String get etaToday => 'اليوم';

  @override
  String get shelfAllSubToday => 'يصلك اليوم';

  @override
  String shelfAllSubOn(String day) {
    return 'يصلك $day';
  }

  @override
  String get etaTomorrow => 'غدًا';

  @override
  String etaOn(String date) {
    return 'بحلول $date';
  }

  @override
  String get categoriesTitle => 'الأقسام';

  @override
  String get categoriesEmpty => 'لا توجد أقسام حاليًا';

  @override
  String get categoriesShopAll => 'تسوّق الكل';

  @override
  String categoriesProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا توجد منتجات',
    );
    return '$_temp0';
  }

  @override
  String get listingFilters => 'تصفية';

  @override
  String get listingSort => 'ترتيب';

  @override
  String get listingSortTitle => 'ترتيب النتائج';

  @override
  String get listingFiltersTitle => 'تصفية النتائج';

  @override
  String get listingPriceRange => 'نطاق السعر';

  @override
  String listingResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا توجد نتائج',
    );
    return '$_temp0';
  }

  @override
  String bundleSavePercent(int percent) {
    return 'وفّر $percent٪';
  }

  @override
  String get bundleExpressChip => 'خلال ساعتين';

  @override
  String bundlePiecesLine(int count) {
    return '$count قطعة في البكج';
  }

  @override
  String get bundleContentsTitle => 'محتويات البكج';

  @override
  String bundleContentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return '$_temp0';
  }

  @override
  String get bundleGiftTag => 'هدية';

  @override
  String get bundlesTitle => 'البكجات';

  @override
  String get bundlesEmpty => 'لا توجد بكجات معروضة الآن';

  @override
  String get bundlesEmptyHint => 'نجهّز حزماً جديدة باستمرار — عُد قريباً.';

  @override
  String get bundlesEmptyExpress => 'لا توجد بكجات في إكسبريس الآن';

  @override
  String get bundlesEmptyExpressHint =>
      'بكجات متجر زوبكسي جاهزة، وتصلك اليوم أو غداً.';

  @override
  String get bundlesEmptyExpressAction => 'تصفّح بكجات زوبكسي';

  @override
  String get listingEmpty => 'لا توجد منتجات مطابقة';

  @override
  String get listingEmptyHint => 'جرّب تخفيف عوامل التصفية أو تغيير المدينة.';

  @override
  String get listingClearFilters => 'مسح التصفية';

  @override
  String listingFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مُطبَّق $count فلترًا',
      few: 'مُطبَّق $count فلاتر',
      two: 'مُطبَّق فلتران',
      one: 'مُطبَّق فلتر واحد',
    );
    return '$_temp0';
  }

  @override
  String get searchTitle => 'البحث';

  @override
  String get searchHint => 'ابحث عن منتج أو ماركة أو باركود';

  @override
  String get searchRecent => 'عمليات بحث سابقة';

  @override
  String get searchClearRecent => 'مسح السجل';

  @override
  String get searchNoSuggestions => 'لا توجد اقتراحات';

  @override
  String get searchStartHint => 'اكتب اسم منتج أو امسح الباركود';

  @override
  String get searchScan => 'مسح الباركود';

  @override
  String get scanTitle => 'امسح الباركود';

  @override
  String get scanHint => 'وجّه الكاميرا نحو الباركود على العبوة';

  @override
  String get scanNotFound => 'لم نعثر على منتج بهذا الباركود';

  @override
  String get scanPermission => 'نحتاج إذن الكاميرا لمسح الباركود';

  @override
  String get pdpAddToCart => 'أضف إلى السلة';

  @override
  String get pdpOutOfStock => 'غير متوفّر حاليًا';

  @override
  String get pdpQuantity => 'الكمية';

  @override
  String get pdpDelivery => 'موعد التوصيل';

  @override
  String get pdpAvailability => 'التوفّر حسب المستودع';

  @override
  String get pdpFbt => 'يُشترى عادةً معه';

  @override
  String get pdpSubstitutes => 'بدائل مشابهة';

  @override
  String get pdpDescription => 'الوصف';

  @override
  String get pdpVariantsHint => 'اختر الخيار المناسب';

  @override
  String get pdpSelectVariant => 'اختر خيارًا أولًا';

  @override
  String pdpReachable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تصلك $count قطعة',
      few: 'تصلك $count قطع',
      two: 'تصلك قطعتان',
      one: 'تصلك قطعة واحدة',
      zero: 'لا تصل إليك قطع',
    );
    return '$_temp0';
  }

  @override
  String pdpStockUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة',
      few: '$count قطع',
      two: 'قطعتان',
      one: 'قطعة واحدة',
      zero: 'نفدت',
    );
    return '$_temp0';
  }

  @override
  String pdpMaxQty(int count) {
    return 'الحد الأقصى المتاح $count';
  }

  @override
  String get pdpAddedToCart => 'أُضيف إلى السلة';

  @override
  String get pdpLangFallback => 'بعض التفاصيل معروضة بالعربية';

  @override
  String get priceFrom => 'يبدأ من';

  @override
  String get priceWas => 'بدلًا من';

  @override
  String priceOff(int percent) {
    return 'خصم $percent٪';
  }

  @override
  String get cardAdd => 'أضف';

  @override
  String get cardChooseOptions => 'اختر الخيارات';

  @override
  String get cardOutOfStock => 'غير متوفّر';

  @override
  String cardStockLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count قطعة',
      few: 'بقي $count قطع',
      two: 'بقيت قطعتان',
      one: 'بقيت قطعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get badgeHot => 'الأكثر طلبًا';

  @override
  String get badgeTrending => 'رائج الآن';

  @override
  String get badgeNew => 'جديد';

  @override
  String get badgeLowStock => 'الكمية محدودة';

  @override
  String get badgeBackInStock => 'عاد للتوفّر';

  @override
  String cartSwitchTitle(String store) {
    return 'تنتقل إلى سلة $store؟';
  }

  @override
  String cartSwitchBody(String leaving, String entering) {
    return 'سلتك الحالية من متجر $leaving، والطلب الواحد يكون من متجر واحد. نحفظ لك منتجات سلة $leaving وتقدر ترجع لها في أي وقت، وأي هدية مضافة ترجع لمكافآتك.';
  }

  @override
  String cartSwitchBodyWaiting(String leaving, String entering, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return 'سلتك الحالية من متجر $leaving، والطلب الواحد يكون من متجر واحد. نحفظ لك منتجات سلة $leaving، وفي سلة $entering $_temp0 بانتظارك.';
  }

  @override
  String cartSwitchBodyEmpty(String store) {
    return 'هذا المنتج من متجر $store، والطلب الواحد يكون من متجر واحد.';
  }

  @override
  String cartSwitchConfirm(String store) {
    return 'افتح سلة $store';
  }

  @override
  String cartBasketOf(String store) {
    return 'سلة $store';
  }

  @override
  String cartBasketMismatch(String basket, String browsing) {
    return 'سلتك من متجر $basket، وأنت تتصفح $browsing الآن.';
  }

  @override
  String get cartBasketMismatchHint =>
      'الطلب الواحد يكون من متجر واحد. تقدر تكمل سلتك أو تنتقل للمتجر الثاني.';

  @override
  String cartOtherClosed(String store) {
    return '$store مغلق الآن، وسلته محفوظة لك.';
  }

  @override
  String cartOtherWaitingSince(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يومًا',
      few: '$days أيام',
      two: 'يومين',
      one: 'يوم',
      zero: 'اليوم',
    );
    return 'تركتها قبل $_temp0.';
  }

  @override
  String cartOtherBasket(String store, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return 'سلة $store فيها $_temp0';
  }

  @override
  String get cartSwitchAction => 'افتحها';

  @override
  String get cartTitle => 'السلة';

  @override
  String get cartEmpty => 'سلتك فارغة';

  @override
  String get cartEmptyHint => 'أضف ما يحتاجه صديقك الأليف وسنوصله إليك.';

  @override
  String get cartStartShopping => 'ابدأ التسوّق';

  @override
  String get cartSubtotal => 'المجموع الفرعي';

  @override
  String get cartDiscount => 'الخصم';

  @override
  String get cartShipping => 'التوصيل';

  @override
  String get cartTax => 'الضريبة';

  @override
  String get cartTotal => 'الإجمالي';

  @override
  String get cartFree => 'مجاني';

  @override
  String get cartCoupon => 'كوبون الخصم';

  @override
  String get cartCouponHint => 'أدخل رمز الكوبون';

  @override
  String get cartCouponApply => 'تفعيل';

  @override
  String get cartCouponRemove => 'إزالة الكوبون';

  @override
  String get cartCheckout => 'إتمام الطلب';

  @override
  String get cartShipments => 'شحنات طلبك';

  @override
  String get cartShipmentsHint => 'نقسّم طلبك حسب أسرع مصدر متاح لكل منتج.';

  @override
  String cartFreeShippingRemaining(String amount) {
    return 'أضف $amount لتحصل على توصيل مجاني';
  }

  @override
  String get cartFreeShippingQualified => 'توصيلك مجاني 🎉';

  @override
  String get cartItemRemoved => 'أُزيل المنتج من السلة';

  @override
  String get cartUpdateFailed => 'تعذّر تحديث السلة';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا منتجات',
    );
    return '$_temp0';
  }

  @override
  String cartLineQty(int qty) {
    return 'الكمية $qty';
  }

  @override
  String cartShortfall(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة تُشحن لاحقًا',
      few: '$count قطع تُشحن لاحقًا',
      two: 'قطعتان تُشحنان لاحقًا',
      one: 'قطعة واحدة تُشحن لاحقًا',
    );
    return '$_temp0';
  }

  @override
  String get checkoutTitle => 'إتمام الطلب';

  @override
  String get checkoutStepAddress => 'العنوان';

  @override
  String get checkoutStepReview => 'المراجعة';

  @override
  String get checkoutStepPayment => 'الدفع';

  @override
  String get checkoutAddressTitle => 'أين نوصّل طلبك؟';

  @override
  String get checkoutAddressNew => 'عنوان جديد';

  @override
  String get checkoutAddressEmpty => 'لا توجد عناوين محفوظة';

  @override
  String get checkoutAddressEmptyHint => 'أضف عنوانك لنعرف أين نوصّل طلبك.';

  @override
  String get checkoutReviewTitle => 'راجع طلبك';

  @override
  String get checkoutDeliverTo => 'التوصيل إلى';

  @override
  String get checkoutChangeAddress => 'تغيير';

  @override
  String get checkoutItemsShow => 'عرض المنتجات';

  @override
  String get checkoutItemsHide => 'إخفاء المنتجات';

  @override
  String get checkoutPromiseTitle => 'موعد الوصول';

  @override
  String get checkoutPromiseSplit => 'طلبك يصلك على أكثر من شحنة';

  @override
  String get checkoutNotesLabel => 'ملاحظة للمندوب';

  @override
  String get checkoutNotesHint => 'مثال: اتصل قبل الوصول';

  @override
  String get checkoutPaymentTitle => 'كيف تحب الدفع؟';

  @override
  String get checkoutPaymentEmpty => 'لا توجد طريقة دفع متاحة الآن';

  @override
  String get checkoutPaymentEmptyHint => 'حدّث الصفحة أو حاول بعد قليل.';

  @override
  String get checkoutPlaceOrder => 'تأكيد الطلب';

  @override
  String get checkoutPayNow => 'المتابعة للدفع';

  @override
  String get checkoutPlacing => 'جارٍ تأكيد طلبك…';

  @override
  String get checkoutCartChangedTitle => 'قائمتك تغيّرت حسب عنوان التوصيل';

  @override
  String get checkoutCartChangedHint => 'راجع ما تغيّر ثم أكمل الطلب.';

  @override
  String get checkoutCartChangedAction => 'مراجعة الطلب';

  @override
  String get checkoutSignInReason => 'سجّل الدخول لإتمام طلبك';

  @override
  String get successTitle => 'تم استلام طلبك 🎉';

  @override
  String get successSubtitle => 'شكرًا لك! بدأنا تجهيز طلبك الآن.';

  @override
  String successOrderNumber(String number) {
    return 'رقم الطلب #$number';
  }

  @override
  String get successCodNote => 'ادفع عند الاستلام';

  @override
  String get successTrack => 'تتبّع الطلب';

  @override
  String get successKeepShopping => 'مواصلة التسوّق';

  @override
  String get paymentTitle => 'الدفع';

  @override
  String get paymentOpening => 'جارٍ فتح صفحة الدفع…';

  @override
  String get paymentWaiting => 'أكمل الدفع في النافذة';

  @override
  String get paymentWaitingHint => 'سنؤكّد طلبك تلقائيًا بمجرد اكتمال العملية.';

  @override
  String get paymentConfirming => 'جارٍ تأكيد الدفع…';

  @override
  String get paymentReopen => 'إعادة فتح صفحة الدفع';

  @override
  String get paymentFailedTitle => 'لم يكتمل الدفع';

  @override
  String get paymentFailedHint =>
      'لم يصلنا تأكيد الدفع. طلبك محفوظ باسمك ويمكنك المحاولة مجددًا.';

  @override
  String get paymentSupportHint =>
      'إن تكرّر الأمر تواصل معنا وسنكمل طلبك يدويًا.';

  @override
  String get paymentAmountDue => 'المبلغ المستحق';

  @override
  String get paymentCardTitle => 'الدفع بالبطاقة';

  @override
  String paymentPayAmount(String amount) {
    return 'ادفع $amount';
  }

  @override
  String get paymentSecureNote =>
      'بياناتك مشفّرة، ولا يحتفظ التطبيق ببيانات بطاقتك.';

  @override
  String get paymentPreparingCard => 'جارٍ تجهيز نموذج البطاقة…';

  @override
  String get paymentCardFailed => 'تعذّر إتمام الدفع بالبطاقة';

  @override
  String get paymentOtherMethods => 'طرق دفع أخرى (Apple Pay وسواها)';

  @override
  String get paymentHostedFallback =>
      'الدفع بالبطاقة داخل التطبيق غير متاح الآن، سنكمل عبر صفحة الدفع الآمنة.';

  @override
  String get paymentSaveCard => 'احفظ البطاقة لعمليات الدفع القادمة';

  @override
  String get paymentUseAnotherCard => 'استخدام بطاقة أخرى';

  @override
  String get payCardHolder => 'الاسم على البطاقة';

  @override
  String get payCardHolderHint => 'الاسم كما يظهر على البطاقة';

  @override
  String get payCardNumber => 'رقم البطاقة';

  @override
  String get payCardNumberHint => '0000 0000 0000 0000';

  @override
  String get payCardExpiry => 'تاريخ الانتهاء';

  @override
  String get payCardExpiryHint => 'شهر / سنة';

  @override
  String get payCardCvv => 'رمز الأمان';

  @override
  String get payCardCvvHint => 'CVV';

  @override
  String get paymentViewOrder => 'عرض الطلب';

  @override
  String get ordersTitle => 'طلباتي';

  @override
  String get ordersEmpty => 'لا توجد طلبات بعد';

  @override
  String get ordersEmptyHint => 'أول طلب لك سيظهر هنا مع تتبّع لحظي.';

  @override
  String get ordersFilterAll => 'الكل';

  @override
  String get ordersFilterActive => 'جارية';

  @override
  String get ordersFilterCompleted => 'مكتملة';

  @override
  String get ordersFilterCancelled => 'ملغاة';

  @override
  String get ordersEmptyFiltered => 'لا طلبات في هذا القسم';

  @override
  String get ordersEmptyFilteredHint => 'بقية طلباتك موجودة في الأقسام الأخرى.';

  @override
  String get ordersThisMonth => 'هذا الشهر';

  @override
  String ordersMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String ordersMorePhotos(int count) {
    return '+$count';
  }

  @override
  String get orderDetailTitle => 'تفاصيل الطلب';

  @override
  String get orderItemsTitle => 'المنتجات';

  @override
  String get orderTimelineTitle => 'مسار الطلب';

  @override
  String get orderAddressTitle => 'عنوان التوصيل';

  @override
  String get orderTrackingTitle => 'الشحنة';

  @override
  String get orderTrackingNumber => 'رقم التتبّع';

  @override
  String get orderTrackingCopied => 'نُسخ رقم التتبّع';

  @override
  String get orderTrackingOpen => 'تتبّع الشحنة';

  @override
  String get orderNotesTitle => 'ملاحظتك';

  @override
  String get orderPaymentMethod => 'طريقة الدفع';

  @override
  String get orderPaymentCod => 'الدفع عند الاستلام';

  @override
  String get orderPaymentOnline => 'دفع إلكتروني';

  @override
  String get orderPaid => 'مدفوع';

  @override
  String get orderUnpaid => 'بانتظار الدفع';

  @override
  String get orderPayNow => 'إكمال الدفع';

  @override
  String get orderReorder => 'اطلبها مجددًا';

  @override
  String orderReorderAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $count منتجًا إلى السلة',
      few: 'أُضيفت $count منتجات إلى السلة',
      two: 'أُضيف منتجان إلى السلة',
      one: 'أُضيف منتج واحد إلى السلة',
    );
    return '$_temp0';
  }

  @override
  String orderReorderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتجًا غير متوفّر حاليًا',
      few: '$count منتجات غير متوفّرة حاليًا',
      two: 'منتجان غير متوفّرين حاليًا',
      one: 'منتج واحد غير متوفّر حاليًا',
    );
    return '$_temp0';
  }

  @override
  String get addressesTitle => 'عناويني';

  @override
  String get addressesEmpty => 'لا توجد عناوين محفوظة';

  @override
  String get addressesEmptyHint =>
      'احفظ عنوانك مرة واحدة، ونوصّل إليه في كل مرة.';

  @override
  String get addressAdd => 'إضافة عنوان';

  @override
  String get addressNewTitle => 'عنوان جديد';

  @override
  String get addressEditTitle => 'تعديل العنوان';

  @override
  String get addressPinTitle => 'حدّد موقع التوصيل';

  @override
  String get addressPinHint => 'حرّك الخريطة حتى يستقر المؤشّر على باب المنزل.';

  @override
  String get addressPinConfirm => 'تأكيد الموقع';

  @override
  String get addressPinChange => 'تعديل الموقع';

  @override
  String get addressPinUseGps => 'موقعي الحالي';

  @override
  String get mapZoomIn => 'تكبير الخريطة';

  @override
  String get mapStyleSatellite => 'عرض القمر الصناعي';

  @override
  String get mapStyleStreets => 'عرض الخريطة';

  @override
  String get mapZoomOut => 'تصغير الخريطة';

  @override
  String get pinPlaceLoading => 'جارٍ تحديد العنوان…';

  @override
  String get pinPlaceUnnamed => 'موقع بلا اسم';

  @override
  String get pinPlaceUnnamedHint =>
      'لا بأس — المؤشّر نفسه هو العنوان الذي يصل إليه المندوب.';

  @override
  String get pinPlaceOutOfRange => 'خارج نطاق التوصيل حاليًا';

  @override
  String get addressResolving => 'جارٍ تحديد الحي…';

  @override
  String get addressLabelTitle => 'اسم العنوان';

  @override
  String get addressLabelHome => 'المنزل';

  @override
  String get addressLabelWork => 'العمل';

  @override
  String get addressLabelOther => 'آخر';

  @override
  String get addressNameLabel => 'اسم المستلم';

  @override
  String get addressPhoneLabel => 'رقم الجوال';

  @override
  String get addressCityLabel => 'المدينة';

  @override
  String get addressDistrictLabel => 'الحي';

  @override
  String get addressBuildingLabel => 'رقم العمارة';

  @override
  String get addressFloorLabel => 'الدور';

  @override
  String get addressApartmentLabel => 'الشقة';

  @override
  String get addressLineLabel => 'وصف العنوان';

  @override
  String get addressLineHint => 'قريب من؟ معلم مميز؟ بوابة؟';

  @override
  String get addressSaveToggle => 'حفظ هذا العنوان في عناويني';

  @override
  String get addressSetDefault => 'تعيين كعنوان افتراضي';

  @override
  String get addressDefaultBadge => 'الافتراضي';

  @override
  String get addressDelete => 'حذف العنوان';

  @override
  String get addressDeleteConfirm => 'هل تريد حذف هذا العنوان؟';

  @override
  String get addressDeleted => 'حُذف العنوان';

  @override
  String get addressSaved => 'حُفظ العنوان';

  @override
  String get addressDefaultSet => 'أصبح هذا عنوانك الافتراضي';

  @override
  String get addressNameRequired => 'أدخل اسم المستلم';

  @override
  String get addressLineRequired => 'أدخل تفاصيل العنوان';

  @override
  String get addressCityRequired => 'أدخل المدينة';

  @override
  String get addressPinRequired => 'حدّد الموقع على الخريطة';

  @override
  String get buyAgainTitle => 'مشترياتي';

  @override
  String get buyAgainEmpty => 'لا توجد مشتريات سابقة';

  @override
  String get buyAgainEmptyHint =>
      'بعد أول طلب ستجد هنا ما تشتريه عادةً بضغطة واحدة.';

  @override
  String get wishlistTitle => 'المفضّلة';

  @override
  String get wishlistEmpty => 'قائمة المفضّلة فارغة';

  @override
  String get wishlistEmptyHint => 'اضغط القلب على أي منتج لحفظه هنا.';

  @override
  String get wishlistAdded => 'أُضيف إلى المفضّلة';

  @override
  String get wishlistRemoved => 'أُزيل من المفضّلة';

  @override
  String get accountTitle => 'حسابي';

  @override
  String get accountGuest => 'زائر';

  @override
  String get accountGuestHint => 'سجّل الدخول لحفظ طلباتك ومفضّلتك';

  @override
  String get accountLogin => 'تسجيل الدخول';

  @override
  String get accountLogout => 'تسجيل الخروج';

  @override
  String get accountLogoutConfirm => 'هل تريد تسجيل الخروج؟';

  @override
  String get accountOrders => 'طلباتي';

  @override
  String get accountWishlist => 'المفضّلة';

  @override
  String get accountAddresses => 'عناويني';

  @override
  String get accountBuyAgain => 'مشترياتي · اطلبها مجددًا';

  @override
  String get accountSupport => 'الدعم والمساعدة';

  @override
  String get accountAbout => 'عن التطبيق';

  @override
  String accountVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get accountPreferences => 'التفضيلات';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountLanguageArabic => 'العربية';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountTheme => 'المظهر';

  @override
  String get accountThemeLight => 'فاتح';

  @override
  String get accountThemeDark => 'داكن';

  @override
  String get accountThemeSystem => 'حسب النظام';

  @override
  String get accountProfile => 'الملف الشخصي';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsSubtitle => 'اختر ما يستحق أن يقاطعك.';

  @override
  String get notificationsOff => 'الإشعارات موقوفة من إعدادات الجهاز';

  @override
  String get notificationsOffBody =>
      'فعّلها من إعدادات iPhone ← الإشعارات ← Zooboxi لتصلك تحديثات طلبك.';

  @override
  String get notificationsAllow => 'السماح بالإشعارات';

  @override
  String get notificationsOpenSettings => 'فتح الإعدادات';

  @override
  String get notificationsUnavailable =>
      'الإشعارات الفورية غير مفعّلة في هذه النسخة';

  @override
  String get notificationsSilent =>
      'أوقفت كل الإشعارات — لن نرسل لك شيئًا، حتى تحديثات الطلب.';

  @override
  String get notificationsOrders => 'تحديثات الطلب';

  @override
  String get notificationsOrdersBody => 'استلمنا طلبك، جاهز، في الطريق، وصل.';

  @override
  String get notificationsOffers => 'العروض والتخفيضات';

  @override
  String get notificationsOffersBody =>
      'انخفاض أسعار منتجاتك والبكجات الجديدة.';

  @override
  String get notificationsReorder => 'تذكير إعادة الطلب';

  @override
  String get notificationsReorderBody => 'قبل أن ينفد طعام صديقك بأيام.';

  @override
  String get notificationsFamily => 'عائلة زوبوكسي';

  @override
  String get notificationsFamilyBody =>
      'هدية جاهزة، بصمات جديدة، أو عيد ميلاد قريب.';

  @override
  String get notificationsSaveFailed => 'تعذّر حفظ التفضيلات';

  @override
  String get accountStatOrders => 'طلب';

  @override
  String get accountStatPaws => 'بصمة';

  @override
  String get accountStatPets => 'أصدقائي';

  @override
  String accountTierProgress(num count, String tier) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString طلبات تفصلك عن $tier',
      two: 'طلبان يفصلانك عن $tier',
      one: 'طلب واحد يفصلك عن $tier',
    );
    return '$_temp0';
  }

  @override
  String get accountShortcuts => 'اختصارات';

  @override
  String get accountBuyAgainShort => 'مشترياتي';

  @override
  String get accountActiveOrder => 'طلبك في الطريق';

  @override
  String get accountActiveOrderCta => 'تتبّع الطلب';

  @override
  String get accountSoon => 'قريبًا';

  @override
  String get authTitle => 'تسجيل الدخول';

  @override
  String get authSubtitle => 'أدخل رقم جوالك وسنرسل لك رمز تحقق.';

  @override
  String get authPhoneLabel => 'رقم الجوال';

  @override
  String get authPhoneHint => '05XXXXXXXX';

  @override
  String get authPhoneInvalid => 'أدخل رقم جوال سعودي صحيح';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authOtpTitle => 'رمز التحقق';

  @override
  String authOtpSubtitle(String phone) {
    return 'أرسلنا رمزًا مكوّنًا من 4 أرقام إلى $phone';
  }

  @override
  String get authVerify => 'تأكيد';

  @override
  String authResendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get authResend => 'إعادة إرسال الرمز';

  @override
  String get authChangeNumber => 'تعديل الرقم';

  @override
  String get authOtpInvalid => 'رمز غير صحيح، حاول مجددًا';

  @override
  String get authWelcomeTitle => 'أهلًا بك في زوبوكسي 🐾';

  @override
  String get authWelcomeSubtitle => 'أخبرنا باسمك لنخاطبك به.';

  @override
  String get authNameLabel => 'الاسم';

  @override
  String get authEmailLabel => 'البريد الإلكتروني (اختياري)';

  @override
  String get authFinish => 'ابدأ التسوّق';

  @override
  String get authRequired => 'سجّل الدخول للمتابعة';

  @override
  String get authRequiredWishlist => 'سجّل الدخول لحفظ منتجاتك المفضّلة';

  @override
  String get authLoggedIn => 'تم تسجيل الدخول';

  @override
  String get authCartMerged => 'دمجنا سلتك السابقة';

  @override
  String get commonComingSoon => 'قريبًا';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get paymentOrCard => 'أو ادفع بالبطاقة';

  @override
  String get brandAllCategories => 'الكل';

  @override
  String brandCurated(String brand) {
    return 'مختارات $brand';
  }

  @override
  String brandSince(String year) {
    return 'منذ $year';
  }

  @override
  String brandProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا توجد منتجات',
    );
    return '$_temp0';
  }

  @override
  String brandShopAll(String brand) {
    return 'كل منتجات $brand';
  }

  @override
  String get brandsTitle => 'كل الماركات';

  @override
  String get cartItemUnreachable =>
      'هذا المنتج لا يمكن توصيله إلى موقعك حاليًا';

  @override
  String get driftTitle => 'يبدو أنك في مكان جديد';

  @override
  String get driftAdjustHint =>
      'حرّك الخريطة حتى يستقر المؤشّر على مكانك بالضبط.';

  @override
  String driftSavedNow(String saved) {
    return 'نوصّل حاليًا إلى: $saved';
  }

  @override
  String get driftUseHere => 'وصّلوا إلى هذا الموقع';

  @override
  String get driftSaveAsNew => 'حفظه كعنوان جديد';

  @override
  String get driftKeep => 'إبقاء العنوان المحدد';

  @override
  String get familyTitle => 'عائلة زوبوكسي';

  @override
  String get familyTagline => 'كل طلب يقرّبك من هدية لصديقك';

  @override
  String get familyGuestTitle => 'انضم إلى عائلة زوبوكسي';

  @override
  String get familyGuestBody =>
      'أضف حيوانك وابدأ جمع البصمات — هدايا وتوصيل مجاني، بلا خصومات ولا شروط.';

  @override
  String get familyGuestCta => 'ابدأ الآن';

  @override
  String get familyAddPet => 'أضف حيوانك';

  @override
  String get familyNoPetTitle => 'من هو صديقك؟';

  @override
  String get familyNoPetBody => 'عرّفنا على حيوانك واكسب 50 بصمة فورًا';

  @override
  String familyDue(String product) {
    return 'حان وقت إعادة طلب $product';
  }

  @override
  String get familyOrderNow => 'اطلب الآن';

  @override
  String familyMemberSince(String date) {
    return 'عضو منذ $date';
  }

  @override
  String get familyPerksTitle => 'مزاياك';

  @override
  String familyPerkFrom(String tier) {
    return 'من مستوى $tier';
  }

  @override
  String get familyMyRewards => 'مكافآتي';

  @override
  String get familyRedeemTitle => 'استبدل بصماتك';

  @override
  String get familySealedTitle => 'بطاقات تنتظر الخدش';

  @override
  String get familyLedgerLink => 'سجل البصمات';

  @override
  String familyReferralCode(String code) {
    return 'رمز الدعوة $code';
  }

  @override
  String familyTierOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب خلال 12 شهرًا',
      many: '$count طلبًا خلال 12 شهرًا',
      few: '$count طلبات خلال 12 شهرًا',
      two: 'طلبان خلال 12 شهرًا',
      one: 'طلب واحد خلال 12 شهرًا',
      zero: 'لا طلبات خلال 12 شهرًا',
    );
    return '$_temp0';
  }

  @override
  String familyTierNext(int count, String tier) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب يفصلك عن $tier',
      many: '$count طلبًا يفصلك عن $tier',
      few: '$count طلبات تفصلك عن $tier',
      two: 'طلبان يفصلانك عن $tier',
      one: 'طلب واحد يفصلك عن $tier',
    );
    return '$_temp0';
  }

  @override
  String get familyTierTop => 'أنت في أعلى مستوى — شكرًا لثقتك';

  @override
  String get pawsTitle => 'بصماتك';

  @override
  String get pawsUnit => 'بصمة';

  @override
  String pawsCount(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value بصمة',
      many: '$value بصمة',
      few: '$value بصمات',
      two: 'بصمتان',
      one: 'بصمة واحدة',
      zero: 'لا بصمات',
    );
    return '$_temp0';
  }

  @override
  String pawsPending(String value) {
    return '$value بصمة قيد التفعيل';
  }

  @override
  String get pawsPendingHint => 'تُضاف عند تسليم طلبك';

  @override
  String pawsExpires(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get pawsHowTitle => 'كيف أكسب البصمات؟';

  @override
  String get pawsHowOrder => 'بصمة لكل ريال من قيمة أي طلب يصلك';

  @override
  String get pawsHowProfile =>
      '100 بصمة عند إكمال ملف صديقك بالوزن وتاريخ الميلاد';

  @override
  String get pawsHowPet => '50 بصمة لكل حيوان تضيفه';

  @override
  String get pawsHowPlay =>
      'مهمات الشهر وبطاقة «اخدش واربح» مع كل طلب من التطبيق';

  @override
  String get pawsHowExpiry => 'تنتهي البصمات بعد 12 شهرًا بلا طلبات';

  @override
  String get pawsHowDelivered =>
      'الاستحقاق بعد التسليم — لا شيء يُحتسب قبل أن يصلك الطلب';

  @override
  String pawsToEarn(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستكسب $value بصمة',
      many: 'ستكسب $value بصمة',
      few: 'ستكسب $value بصمات',
      two: 'ستكسب بصمتين',
      one: 'ستكسب بصمة واحدة',
      zero: 'لن تكسب بصمات من هذه السلة',
    );
    return '$_temp0';
  }

  @override
  String pawsEarned(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كسبت $value بصمة',
      many: 'كسبت $value بصمة',
      few: 'كسبت $value بصمات',
      two: 'كسبت بصمتين',
      one: 'كسبت بصمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get pawsLedgerTitle => 'سجل البصمات';

  @override
  String get pawsLedgerEmpty => 'السجل فارغ';

  @override
  String get pawsLedgerEmptyHint => 'أول طلب يصلك يفتح السجل';

  @override
  String get pawsLedgerMore => 'عرض المزيد';

  @override
  String pawsBalanceAfter(String value) {
    return 'الرصيد $value';
  }

  @override
  String pawsReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'order_earn': 'طلب مسلَّم',
      'profile_complete': 'إكمال ملف',
      'pet_added': 'إضافة حيوان',
      'mission': 'مهمة الشهر',
      'scratch': 'اخدش واربح',
      'redeem': 'استبدال',
      'reverse': 'عكس قيد',
      'expire': 'انتهاء صلاحية',
      'adjust': 'تعديل يدوي',
      'welcome': 'هدية ترحيب',
      'other': 'حركة',
    });
    return '$_temp0';
  }

  @override
  String get missionsTitle => 'مهمات الشهر';

  @override
  String get missionsSubtitle => 'أربع مهمات، تتجدد أول كل شهر';

  @override
  String missionProgress(int progress, int target) {
    return '$progress من $target';
  }

  @override
  String get missionDone => 'اكتملت';

  @override
  String get missionRewardGift => 'هدية';

  @override
  String get missionSuggested => 'يناسب صديقك';

  @override
  String get missionsAllDone => 'خلّصت مهمات الشهر كلها 🎉';

  @override
  String get missionsEmpty => 'لا مهمات هذا الشهر';

  @override
  String get missionsEmptyHint => 'مهمات جديدة تصلك أول الشهر القادم';

  @override
  String get rewardsTitle => 'المكافآت';

  @override
  String get rewardsMine => 'مكافآتي';

  @override
  String get rewardsCatalog => 'استبدل بصماتك';

  @override
  String get rewardsEmpty => 'لا مكافآت بعد';

  @override
  String get rewardsEmptyHint => 'اجمع البصمات واستبدلها بهدية أو توصيل مجاني';

  @override
  String get rewardsCatalogEmpty => 'الكتالوج فارغ الآن';

  @override
  String rewardCost(String value) {
    return '$value بصمة';
  }

  @override
  String rewardValue(String price) {
    return 'قيمتها $price';
  }

  @override
  String rewardValidity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صالحة $count يوم',
      many: 'صالحة $count يومًا',
      few: 'صالحة $count أيام',
      two: 'صالحة يومين',
      one: 'صالحة يومًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String rewardExpires(String date) {
    return 'تنتهي $date';
  }

  @override
  String get rewardRedeem => 'استبدل';

  @override
  String get rewardRedeemTitle => 'تأكيد الاستبدال';

  @override
  String rewardRedeemBody(String value, String title) {
    return 'سنخصم $value بصمة مقابل «$title». تصبح جاهزة للاستخدام في طلبك القادم.';
  }

  @override
  String get rewardRedeemDone => 'أصبحت في مكافآتك';

  @override
  String get rewardRedeemFailed => 'تعذّر الاستبدال';

  @override
  String get rewardUseInCart => 'استخدم في السلة';

  @override
  String get rewardInCart => 'في سلتك';

  @override
  String get rewardRemove => 'إزالة من السلة';

  @override
  String rewardPendingOrder(String number) {
    return 'تُفعَّل عند تسليم الطلب $number';
  }

  @override
  String get rewardPending => 'تُفعَّل عند تسليم طلبك';

  @override
  String get rewardKindGift => 'هدية';

  @override
  String get rewardKindExpress => 'توصيل سريع مجاني';

  @override
  String get rewardKindDelivery => 'توصيل مجاني';

  @override
  String get rewardKindPaws => 'بصمات';

  @override
  String get rewardUseButton => 'استخدم مكافأة';

  @override
  String get rewardSheetTitle => 'مكافآتك الجاهزة';

  @override
  String get rewardSheetHint => 'تُضاف إلى هذا الطلب فورًا';

  @override
  String get rewardSheetEmpty => 'لا مكافآت جاهزة الآن';

  @override
  String get rewardGiftChip => 'هدية';

  @override
  String get rewardGiftFree => 'مجانًا';

  @override
  String get rewardClaimFailed => 'تعذّر استخدام المكافأة';

  @override
  String get rewardGiftUnavailable => 'هذه الهدية لا تصل موقعك حاليًا';

  @override
  String get rewardInsufficientPaws => 'بصماتك لا تكفي';

  @override
  String get rewardTierRequired => 'يتطلب مستوى أعلى';

  @override
  String get rewardFreeDeliveryTier => 'توصيل مجاني بفضل مستواك';

  @override
  String get rewardFreeDeliveryReward => 'توصيل مجاني بمكافأتك';

  @override
  String get rewardExpressFreeTier => 'توصيل سريع مجاني بفضل مستواك';

  @override
  String get rewardExpressFreeReward => 'توصيل سريع مجاني بمكافأتك';

  @override
  String get scratchTitle => 'اخدش واربح';

  @override
  String get scratchHint => 'امسح البطاقة بإصبعك';

  @override
  String scratchOrder(String number) {
    return 'بطاقة الطلب $number';
  }

  @override
  String scratchPrizePaws(String value) {
    return '$value بصمة!';
  }

  @override
  String get scratchActivation => 'تُفعَّل عند تسليم الطلب';

  @override
  String get scratchSettled => 'أصبحت في حسابك';

  @override
  String get scratchDone => 'رائع';

  @override
  String get scratchOpen => 'اكشف البطاقة';

  @override
  String get scratchEmpty => 'لا بطاقات الآن';

  @override
  String get scratchEmptyHint => 'كل طلب من التطبيق يأتي ببطاقة';

  @override
  String get petsTitle => 'عائلتي';

  @override
  String get petsEmpty => 'لا حيوانات بعد';

  @override
  String get petsEmptyHint => 'عرّفنا على صديقك لنقترح ما يناسبه فعلًا';

  @override
  String get petsAdd => 'أضف حيوانًا';

  @override
  String petsFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'يمكنك إضافة $max حيوان',
      few: 'يمكنك إضافة $max حيوانات',
      two: 'يمكنك إضافة حيوانين',
      one: 'يمكنك إضافة حيوان واحد',
    );
    return '$_temp0';
  }

  @override
  String get petNewTitle => 'صديق جديد';

  @override
  String petEditTitle(String name) {
    return 'ملف $name';
  }

  @override
  String get petFieldName => 'الاسم';

  @override
  String get petFieldNameHint => 'مشمش';

  @override
  String get petFieldSpecies => 'النوع';

  @override
  String get petFieldBreed => 'السلالة';

  @override
  String get petFieldBreedHint => 'اختياري';

  @override
  String get petFieldWeight => 'الوزن';

  @override
  String get petFieldBirthDate => 'تاريخ الميلاد';

  @override
  String get petFieldSex => 'الجنس';

  @override
  String get petFieldNeutered => 'معقّم';

  @override
  String get petWeightUnit => 'كجم';

  @override
  String get petSexMale => 'ذكر';

  @override
  String get petSexFemale => 'أنثى';

  @override
  String get petSexUnset => 'غير محدد';

  @override
  String get petNotSet => 'غير مسجّل';

  @override
  String get petSpeciesCat => 'قط';

  @override
  String get petSpeciesDog => 'كلب';

  @override
  String get petSpeciesBird => 'طائر';

  @override
  String get petSpeciesFish => 'سمك';

  @override
  String get petSpeciesSmall => 'قارض';

  @override
  String get petSpeciesReptile => 'زاحف';

  @override
  String get petSpeciesOther => 'غير ذلك';

  @override
  String get petNameRequired => 'اكتب اسم صديقك';

  @override
  String get petWeightInvalid => 'أدخل وزنًا بين 0.1 و200 كجم';

  @override
  String get petBirthDateInvalid => 'تاريخ الميلاد لا يمكن أن يكون في المستقبل';

  @override
  String get petSaveFailed => 'تعذّر الحفظ';

  @override
  String get petSaved => 'تم الحفظ';

  @override
  String get petDelete => 'حذف الملف';

  @override
  String petDeleteConfirm(String name) {
    return 'حذف ملف $name؟';
  }

  @override
  String get petDeleted => 'تم حذف الملف';

  @override
  String petBirthdaySoon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عيد ميلاده بعد $count يومًا',
      few: 'عيد ميلاده بعد $count أيام',
      two: 'عيد ميلاده بعد يومين',
      one: 'عيد ميلاده غدًا',
      zero: 'عيد ميلاده اليوم',
    );
    return '$_temp0';
  }

  @override
  String get petIncompleteHint => 'أضف الوزن وتاريخ الميلاد واكسب 100 بصمة';

  @override
  String get petAgeUnknown => 'العمر غير مسجّل';

  @override
  String get petPickDate => 'اختر التاريخ';

  @override
  String get petLimitReached => 'وصلت إلى الحد الأقصى للحيوانات';

  @override
  String familyHubGreeting(String name) {
    return 'عائلة $name';
  }

  @override
  String get familyHubGreetingNoPet => 'عائلتك';

  @override
  String get familyActionHow => 'كيف أكسب؟';

  @override
  String get familyActionLedger => 'السجل';

  @override
  String get familyActionPets => 'عائلتي';

  @override
  String get familyLadderTitle => 'رحلتك في العائلة';

  @override
  String familyPendingOrderTitle(String number) {
    return 'طلبك $number في الطريق';
  }

  @override
  String familyPendingOrderBody(String value) {
    return 'عند التسليم تُضاف $value بصمة وتُحتسب مهمّتك تلقائيًا';
  }

  @override
  String familyPendingOrderPaws(String value) {
    return 'عند التسليم تُضاف $value بصمة إلى محفظتك';
  }

  @override
  String get familyReferralTitle => 'رمز الدعوة';

  @override
  String get familyReferralCopied => 'تم نسخ رمز الدعوة';

  @override
  String get pawsWalletTitle => 'محفظة البصمات';

  @override
  String get missionAwaitingDelivery => 'بانتظار تسليم طلبك';

  @override
  String missionsDoneOf(int done, int total) {
    return '$done من $total مكتملة';
  }

  @override
  String get rewardComingSoon => 'قريبًا';

  @override
  String get rewardsShelfHint => 'اضغط للاستبدال';

  @override
  String get cartFreeDeliveryCelebrate => 'مبروك! التوصيل مجاني';

  @override
  String get cartExpressCelebrate => 'التوصيل السريع مجاني لهذا الطلب';

  @override
  String successPawsNote(String value) {
    return '$value بصمة تُضاف لمحفظتك عند تسليم الطلب';
  }

  @override
  String get successMissionNote => 'ومهمات الشهر تُحتسب تلقائيًا بعد التسليم';

  @override
  String get scratchKeepGoing => 'أكمل الخدش…';

  @override
  String get supplyTitle => 'مخزون البيت';

  @override
  String get supplySubtitle =>
      'نتعلّم من طلباتك — كل «خلص» أو «عندي كفاية» يجعل التقدير أدق';

  @override
  String get supplyHubSubtitle => 'متى ينفد أكل عائلتك';

  @override
  String get supplyEmptyTitle => 'لا شيء في العدّاد بعد';

  @override
  String get supplyEmptyBody =>
      'بعد أول طلب أكل أو رمل من التطبيق نبدأ نحسب متى ينفد ونذكّرك في وقته';

  @override
  String supplyDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يكفي $count يومًا',
      few: 'يكفي $count أيام',
      two: 'يكفي يومين',
      one: 'يكفي يومًا',
      zero: 'ينفد اليوم',
    );
    return '$_temp0';
  }

  @override
  String get supplyRunsOutToday => 'ينفد اليوم';

  @override
  String supplyOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نفد قبل $count يومًا',
      few: 'نفد قبل $count أيام',
      two: 'نفد قبل يومين',
      one: 'نفد أمس',
    );
    return '$_temp0';
  }

  @override
  String get supplyOrderNow => 'اطلب الآن';

  @override
  String get supplyOut => 'خلص';

  @override
  String get supplySnooze => 'كفاية';

  @override
  String get supplySubscribe => 'اشترك';

  @override
  String get supplySubscribed => 'مشترك';

  @override
  String supplyOnTimeBadge(int pct) {
    return '+$pct% في وقته';
  }

  @override
  String supplyCycle(String days) {
    return 'يكفي $days يومًا تقريبًا';
  }

  @override
  String supplyForPet(String name) {
    return 'لـ$name';
  }

  @override
  String get supplyConfidenceLow => 'تقدير أولي';

  @override
  String get supplyConfidenceMedium => 'تقدير';

  @override
  String get supplyConfidenceHigh => 'مبني على طلباتك';

  @override
  String get supplyMarkedOut => 'سجّلنا أن الأكل خلص — حان وقت الطلب';

  @override
  String supplySnoozed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حسنًا، نذكّرك بعد $count أيام',
    );
    return '$_temp0';
  }

  @override
  String get supplyKindDry => 'طعام جاف';

  @override
  String get supplyKindWet => 'طعام رطب';

  @override
  String get supplyKindLitter => 'رمل';

  @override
  String get supplyKindTreat => 'مكافآت';

  @override
  String get supplyKindOther => 'مستلزم';

  @override
  String supplyWindowHint(int before, int after, int pct) {
    return 'اطلب بين $before أيام قبل النفاد و$after بعده تكسب +$pct% بصمات';
  }

  @override
  String supplyPack(String kg) {
    return '$kg كجم';
  }

  @override
  String get subsTitle => 'اشتراكاتي';

  @override
  String get subsSubtitle =>
      'وصّل لي كل شهر — بلا بطاقة محفوظة ولا التزام، أنت تقرّر كل مرة';

  @override
  String subsHubSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اشتراكًا نشطًا',
      few: '$count اشتراكات نشطة',
      two: 'اشتراكان نشطان',
      one: 'اشتراك واحد نشط',
    );
    return '$_temp0';
  }

  @override
  String get subsEmptyTitle => 'لا اشتراكات بعد';

  @override
  String get subsEmptyBody =>
      'اشترك في أكل عائلتك من مخزون البيت — نذكّرك قبل الموعد وتطلب بضغطة، والتوصيل علينا';

  @override
  String subsNextIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التوصيلة بعد $count يومًا',
      few: 'التوصيلة بعد $count أيام',
      two: 'التوصيلة بعد يومين',
      one: 'التوصيلة غدًا',
    );
    return '$_temp0';
  }

  @override
  String get subsNextToday => 'التوصيلة اليوم';

  @override
  String get subsOverdue => 'موعد التوصيلة فات';

  @override
  String subsEvery(int days) {
    return 'كل $days يومًا';
  }

  @override
  String subsQty(int qty) {
    return '× $qty';
  }

  @override
  String get subsPaused => 'موقوف مؤقتًا';

  @override
  String get subsOrderNow => 'اطلب الآن';

  @override
  String get subsSkip => 'تخطَّ';

  @override
  String get subsEdit => 'تعديل';

  @override
  String get subsPause => 'إيقاف مؤقت';

  @override
  String get subsResume => 'استئناف';

  @override
  String get subsCancel => 'إلغاء الاشتراك';

  @override
  String get subsCancelConfirm =>
      'تلغي هذا الاشتراك؟ تقدر تشترك مجددًا في أي وقت.';

  @override
  String subsPerks(int pct, int every) {
    return 'توصيل مجاني على كل توصيلة · +$pct% بصمات · هدية كل $every توصيلات';
  }

  @override
  String subsDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count توصيلة',
      few: '$count توصيلات',
      two: 'توصيلتان',
      one: 'توصيلة واحدة',
      zero: 'لا توصيلات بعد',
    );
    return '$_temp0';
  }

  @override
  String subsNextGift(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هدية بعد $count توصيلة',
      few: 'هدية بعد $count توصيلات',
      two: 'هدية بعد توصيلتين',
      one: 'هدية مع التوصيلة القادمة',
    );
    return '$_temp0';
  }

  @override
  String get subsEditorTitle => 'تعديل الاشتراك';

  @override
  String get subsIntervalLabel => 'كل كم يومًا؟';

  @override
  String get subsQtyLabel => 'الكمية';

  @override
  String get subsNextLabel => 'التوصيلة التالية';

  @override
  String get subsSave => 'حفظ';

  @override
  String get subsCreated => 'تم الاشتراك — نذكّرك قبل الموعد بثلاثة أيام';

  @override
  String get subsSkipped => 'تم تخطي هذه التوصيلة';

  @override
  String get subsBasketReady => 'جهّزنا سلتك — التوصيل مجاني';

  @override
  String get subsCancelled => 'تم إلغاء الاشتراك';

  @override
  String get subsFreeDeliveryBody => 'توصيلة اشتراك — الشحن علينا';

  @override
  String get successSubscriptionNote =>
      'توصيلة اشتراك: بصمات إضافية والتوصيل مجاني';

  @override
  String get referralTitle => 'ادعُ صديقًا';

  @override
  String referralHubBody(String paws) {
    return 'صديقك يأخذ هدية ترحيب مع أول طلب، وأنت $paws بصمة بعد تسليمه';
  }

  @override
  String get referralShare => 'شارك الدعوة';

  @override
  String get referralCopy => 'نسخ الكود';

  @override
  String get referralCopied => 'تم نسخ الكود';

  @override
  String get referralYourCode => 'كودك';

  @override
  String get referralStatsInvited => 'دعوات';

  @override
  String get referralStatsQualified => 'بانتظار التسليم';

  @override
  String get referralStatsRewarded => 'مكافآت';

  @override
  String get referralHaveCode => 'عندك كود من صديق؟';

  @override
  String get referralEnterCode => 'أدخل كود الدعوة';

  @override
  String get referralApply => 'تطبيق';

  @override
  String referralApplied(String code) {
    return 'تم تطبيق كود $code — هدية الترحيب في محفظتك';
  }

  @override
  String referralAppliedBefore(String code) {
    return 'انضممت بدعوة $code';
  }

  @override
  String referralCap(int n, int cap) {
    return '$n من $cap دعوات هذا الشهر';
  }

  @override
  String get referralEmpty => 'لم تدعُ أحدًا بعد — أول صديق ينتظر';

  @override
  String get referralStatePending => 'انضم — بانتظار أول طلب';

  @override
  String get referralStateQualified => 'أتمّ طلبه — بانتظار الاعتماد';

  @override
  String get referralStateReview => 'قيد المراجعة';

  @override
  String get referralStateRewarded => 'مكافأة مدفوعة';

  @override
  String get referralStateRejected => 'لم تُقبل';

  @override
  String get referralHow => 'كيف تعمل';

  @override
  String get referralHow1 =>
      'شارك كودك أو رابطك مع صديق لم يطلب من زوبوكسي من قبل';

  @override
  String referralHow2(String welcome) {
    return 'يطبّق الكود في التطبيق ويأخذ $welcome مع أول طلب';
  }

  @override
  String referralHow3(String paws) {
    return 'بعد تسليم طلبه بأسبوع تصلك $paws بصمة';
  }

  @override
  String momentBirthdayTitle(String name) {
    return 'عيد ميلاد $name 🎂';
  }

  @override
  String momentBirthdayIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يومًا',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'غدًا',
    );
    return '$_temp0';
  }

  @override
  String get momentBirthdayToday => 'اليوم!';

  @override
  String momentBirthdayPassed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String get momentBirthdayGift => 'هدية باسمه في محفظتك — أضفها لطلبك القادم';

  @override
  String momentBirthdayPaws(String paws) {
    return '$paws بصمة هدية عيد ميلاد في محفظتك';
  }

  @override
  String get momentBirthdayNoGift => 'ما رأيك بهدية صغيرة له هذا الأسبوع؟';

  @override
  String get momentAddToCart => 'أضف الهدية للسلة';

  @override
  String get momentGiftAdded => 'أضفنا الهدية لسلتك';

  @override
  String tierRiskLine(int days, String tier) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'خلال $days يومًا يهبط مستواك إلى $tier — طلب واحد يحفظه',
      few: 'خلال $days أيام يهبط مستواك إلى $tier — طلب واحد يحفظه',
      two: 'بعد يومين يهبط مستواك إلى $tier — طلب واحد يحفظه',
      one: 'غدًا يهبط مستواك إلى $tier — طلب واحد يحفظه',
    );
    return '$_temp0';
  }

  @override
  String get stampsTitle => 'بطاقات الماركات';

  @override
  String stampsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count',
      few: 'بقي $count',
      two: 'بقي اثنان',
      one: 'بقي واحد',
    );
    return '$_temp0';
  }

  @override
  String stampsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بطاقة مكتملة',
      few: '$count بطاقات مكتملة',
      two: 'بطاقتان مكتملتان',
      one: 'بطاقة مكتملة',
    );
    return '$_temp0';
  }

  @override
  String stampsMinPack(String kg) {
    return 'عبوات $kg كجم فأكثر';
  }

  @override
  String get stampsReward => 'المكافأة';

  @override
  String familySupplyLine(int days, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'أكل $name يكفي $days يومًا',
      few: 'أكل $name يكفي $days أيام',
      two: 'أكل $name يكفي يومين',
      one: 'أكل $name يكفي يومًا',
    );
    return '$_temp0';
  }

  @override
  String familySupplyDue(String name) {
    return 'حان وقت إعادة طلب أكل $name';
  }

  @override
  String familySubscriptionLine(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'توصيلة اشتراكك بعد $days يومًا',
      few: 'توصيلة اشتراكك بعد $days أيام',
      two: 'توصيلة اشتراكك بعد يومين',
      one: 'توصيلة اشتراكك غدًا',
    );
    return '$_temp0';
  }

  @override
  String get familySubscriptionToday => 'توصيلة اشتراكك اليوم';

  @override
  String get subsEveryWeek => 'كل أسبوع';

  @override
  String get subsEveryTwoWeeks => 'كل أسبوعين';

  @override
  String get subsEveryMonth => 'كل شهر';

  @override
  String get subsEveryTwoMonths => 'كل شهرين';

  @override
  String petEditFormTitle(String name) {
    return 'تعديل ملف $name';
  }

  @override
  String get careEdit => 'تعديل';

  @override
  String careFeedTitle(String name) {
    return 'كم يأكل $name؟';
  }

  @override
  String careFeedKcal(String kcal) {
    return '$kcal سعرة حرارية في اليوم';
  }

  @override
  String careGramsPerDay(String grams) {
    return '$grams غ/يوم';
  }

  @override
  String get careFeedDry => 'جاف';

  @override
  String get careFeedWet => 'رطب';

  @override
  String get careFeedMixed => 'مختلط';

  @override
  String get careFeedMixedHint => 'نصف السعرات من كل نوع';

  @override
  String get careFeedStageKitten => 'صغير';

  @override
  String get careFeedStageJunior => 'يافع';

  @override
  String get careFeedStageAdult => 'بالغ';

  @override
  String get careFeedStageSenior => 'كبير السن';

  @override
  String get careActivity => 'النشاط';

  @override
  String get careActivityLow => 'هادئ';

  @override
  String get careActivityNormal => 'عادي';

  @override
  String get careActivityHigh => 'نشيط';

  @override
  String get careCondition => 'الجسم';

  @override
  String get careConditionUnder => 'نحيف';

  @override
  String get careConditionIdeal => 'مثالي';

  @override
  String get careConditionOver => 'ممتلئ';

  @override
  String get careOverrideHint => 'تطعمه كمية مختلفة؟';

  @override
  String careOverrideTitle(String name) {
    return 'كم تطعم $name فعلاً؟';
  }

  @override
  String get careOverrideBody => 'سيحسب عدّاد الأكل على هذه الكمية بدل الخطة';

  @override
  String get careOverrideReset => 'ارجع للخطة';

  @override
  String careOverrideActive(String grams) {
    return 'تطعمه $grams غ/يوم بدل الخطة';
  }

  @override
  String careFeedNoWeight(String name) {
    return 'أضف وزن $name لنحسب كم يأكل';
  }

  @override
  String get careFeedAddWeight => 'أضف الوزن';

  @override
  String get careFeedUnsupported => 'حاسبة التغذية متاحة للقطط والكلاب حالياً';

  @override
  String get careFeedGaugeNote => 'عدّاد الأكل يعتمد على هذا الرقم';

  @override
  String get careWeightTitle => 'الوزن';

  @override
  String get careWeightLog => 'سجّل وزن اليوم';

  @override
  String careWeightLogTitle(String name) {
    return 'وزن $name اليوم';
  }

  @override
  String get careWeightEmpty => 'لا قراءات بعد. أول قراءة تبدأ الرسم';

  @override
  String careWeightTrendUp(String kg, String days) {
    return 'زاد $kg كجم خلال $days يومًا';
  }

  @override
  String careWeightTrendDown(String kg, String days) {
    return 'نقص $kg كجم خلال $days يومًا';
  }

  @override
  String careWeightTrendFlat(String days) {
    return 'ثابت خلال $days يومًا';
  }

  @override
  String get careWeightFlagGain =>
      'زيادة تتجاوز 10٪. إن استمرت فاستشر الطبيب البيطري';

  @override
  String get careWeightFlagLoss =>
      'نقص يتجاوز 10٪. يستحق نظرة من الطبيب البيطري';

  @override
  String careWeightMission(String paws) {
    return '+$paws بصمة لأول قراءة هذا الشهر';
  }

  @override
  String careWeightDeleteConfirm(String date) {
    return 'حذف قراءة $date؟';
  }

  @override
  String get careWeightSaved => 'سُجّل الوزن';

  @override
  String get careWeightPickDate => 'بتاريخ';

  @override
  String get careRemindersTitle => 'تذكيرات الرعاية';

  @override
  String get careRemindersSubtitle =>
      'اضغط «تم» عند إنجازه وسنذكّرك في الموعد القادم';

  @override
  String get careStateUnset => 'غير مضبوط';

  @override
  String get careStateOff => 'متوقف';

  @override
  String careStateIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بعد $days يومًا',
      few: 'بعد $days أيام',
      two: 'بعد يومين',
      one: 'غدًا',
    );
    return '$_temp0';
  }

  @override
  String get careStateDue => 'اليوم';

  @override
  String careStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تأخر $days يومًا',
      few: 'تأخر $days أيام',
      two: 'تأخر يومين',
      one: 'تأخر يومًا',
    );
    return '$_temp0';
  }

  @override
  String careDoneToast(String date) {
    return 'سُجّل. الموعد القادم $date';
  }

  @override
  String careSetTitle(String label, String name) {
    return '$label · $name';
  }

  @override
  String get careLastOn => 'آخر مرة';

  @override
  String get careNextOn => 'الموعد القادم';

  @override
  String get careInterval => 'يتكرر كل';

  @override
  String careIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'كل $days يومًا',
      few: 'كل $days أيام',
      two: 'كل يومين',
      one: 'كل يوم',
    );
    return '$_temp0';
  }

  @override
  String get careEnabled => 'التذكير مفعّل';

  @override
  String get careSetHint => 'حدّد آخر مرة وسنحسب الموعد القادم';

  @override
  String get careSuggested => 'قد يفيدك';

  @override
  String careSupplyTitle(String name) {
    return 'مخزون $name';
  }

  @override
  String get careSupplyAll => 'كل المخزون';

  @override
  String get careSaved => 'تم الحفظ';

  @override
  String familyCareLine(String label, String name) {
    return 'اليوم موعد $label $name';
  }

  @override
  String familyCareOverdue(String label, String name) {
    return 'تأخر موعد $label $name';
  }

  @override
  String get familyCareOpen => 'افتح الملف';

  @override
  String get careEveryWeek => 'كل أسبوع';

  @override
  String get careEveryTwoWeeks => 'كل أسبوعين';

  @override
  String get careEveryMonth => 'كل شهر';

  @override
  String get careEveryTwoMonths => 'كل شهرين';

  @override
  String get careEveryQuarter => 'كل 3 أشهر';

  @override
  String get careEveryHalfYear => 'كل 6 أشهر';

  @override
  String get careEveryYear => 'كل سنة';

  @override
  String get actionDelete => 'حذف';

  @override
  String get liveTrackTitle => 'تتبّع مندوبك';

  @override
  String get liveTrackSearching => 'جارٍ تحديد مندوب توصيل لطلبك';

  @override
  String get liveTrackAssigned => 'مندوبك في طريقه للفرع';

  @override
  String get liveTrackReassigned => 'تم تغيير المندوب';

  @override
  String get liveTrackAtBranch => 'مندوبك وصل الفرع';

  @override
  String get liveTrackCollecting => 'جارٍ تسليم طلبك للمندوب';

  @override
  String get liveTrackPickedUp => 'مندوبك استلم طلبك';

  @override
  String get liveTrackOnTheWay => 'مندوبك في الطريق إليك';

  @override
  String get liveTrackAtDoor => 'مندوبك وصل عندك';

  @override
  String get liveTrackPartial => 'تم تسليم طلبك جزئياً';

  @override
  String get liveTrackDelivered => 'تم تسليم طلبك';

  @override
  String get liveTrackReturned => 'رجع الطلب للفرع';

  @override
  String get liveTrackCanceled => 'أُلغيت مهمة المندوب';

  @override
  String get liveTrackExpired => 'لم نجد مندوباً متاحاً';

  @override
  String get liveTrackStepRequested => 'طلبنا مندوباً';

  @override
  String get liveTrackStepAssigned => 'تم تعيين المندوب';

  @override
  String get liveTrackStepPickedUp => 'استلم طلبك من الفرع';

  @override
  String get liveTrackStepDelivered => 'وصل إليك';

  @override
  String get liveTrackStepFailed => 'تعذّر التوصيل';

  @override
  String liveTrackEta(int minutes) {
    return 'تقريباً $minutes دقيقة';
  }

  @override
  String get liveTrackEtaNow => 'على بابك الآن';

  @override
  String liveTrackDistance(String km) {
    return 'يبعد عنك $km كم';
  }

  @override
  String get liveTrackCall => 'اتصل بالمندوب';

  @override
  String get liveTrackWhatsapp => 'واتساب المندوب';

  @override
  String get liveTrackWhatsappHello =>
      'مرحباً، أنا عميل زوبوكسي بخصوص طلب التوصيل.';

  @override
  String get liveTrackCourier => 'مندوب مرسول';

  @override
  String get liveTrackSearchingHint =>
      'عادةً خلال دقائق. سننبّهك فور تعيين المندوب.';

  @override
  String get liveTrackOpenMap => 'الخريطة كاملة';

  @override
  String get liveTrackProof => 'صورة التسليم';

  @override
  String get liveTrackYou => 'موقعك';

  @override
  String get liveTrackBranch => 'الفرع';

  @override
  String liveTrackUpdatedAt(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String get liveTrackOpenMrsool => 'افتح صفحة مرسول';

  @override
  String liveTrackDeliveredAt(String time) {
    return 'سُلّم $time';
  }

  @override
  String get liveTrackFailedHint => 'تواصل معنا وسنعيد المحاولة.';

  @override
  String get liveBarPreparing => 'جارٍ تجهيز طلبك';

  @override
  String get liveBarReady => 'طلبك جاهز للتوصيل';

  @override
  String liveBarOrderNo(String number) {
    return 'طلب $number';
  }

  @override
  String liveBarItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
    );
    return '$_temp0';
  }

  @override
  String get liveBarOpen => 'تفاصيل الطلب';

  @override
  String get liveBarTitle => 'طلبك الآن';

  @override
  String get liveTrackAssigning => 'جارٍ تحديد مندوب توصيل لطلبك';

  @override
  String get liveTrackStillSearching => 'نواصل البحث عن مندوب لك';

  @override
  String get liveTrackAssignHint =>
      'نبحث بين المندوبين القريبين. ننبّهك فور تحديد المندوب.';

  @override
  String get liveBarSearching => 'جارٍ تحديد مندوب';

  @override
  String get expressSearchHint1 => 'رويال كانين';

  @override
  String get expressSearchHint2 => 'رمل قطط';

  @override
  String get expressSearchHint3 => 'ويسكاس';

  @override
  String get expressSearchHint4 => 'مكافآت';

  @override
  String expressSearchPrefix(String example) {
    return 'ابحث: $example';
  }

  @override
  String get searchBought => 'اشتريته سابقاً';

  @override
  String searchBoughtDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      many: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'أمس',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String cartExpressFreeRemaining(String amount) {
    return 'باقي $amount لتوصيل سريع مجاني';
  }

  @override
  String get cartExpressFreeQualified => 'توصيلك السريع مجاني';

  @override
  String get closingOrderWithin => 'اطلب خلال';

  @override
  String get homeNeedsTitle => 'تحتاج الآن؟';

  @override
  String replenishTitle(String pet) {
    return 'طعام $pet يكفي';
  }

  @override
  String get replenishTitleNoPet => 'يكفي';

  @override
  String replenishDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوماً واحداً',
      zero: 'انتهى',
    );
    return '$_temp0';
  }

  @override
  String replenishOut(String pet) {
    return 'خلص طعام $pet';
  }

  @override
  String get replenishOutNoPet => 'خلص';

  @override
  String get replenishCta => 'أعد الطلب إكسبريس';

  @override
  String get replenishArrives => 'يوصلك خلال ساعتين';

  @override
  String get replenishCtaPlain => 'أعد الطلب';
}
