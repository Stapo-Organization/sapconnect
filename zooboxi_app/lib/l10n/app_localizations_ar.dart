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
  String get categoriesTitle => 'الأقسام';

  @override
  String get categoriesEmpty => 'لا توجد أقسام حاليًا';

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
  String get addressLineLabel => 'تفاصيل العنوان';

  @override
  String get addressLineHint => 'الشارع، رقم المبنى، أقرب معلم';

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
}
