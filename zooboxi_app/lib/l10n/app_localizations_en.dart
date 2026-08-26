// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Zooboxi';

  @override
  String get actionOk => 'OK';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDone => 'Done';

  @override
  String get actionNext => 'Next';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionShare => 'Share';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionOr => 'or';

  @override
  String get navHome => 'Home';

  @override
  String get navCategories => 'Categories';

  @override
  String get navCart => 'Cart';

  @override
  String get navAccount => 'Account';

  @override
  String get errTitle => 'Something went wrong';

  @override
  String get errNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errTimeout => 'That took too long. Please try again.';

  @override
  String get errServer => 'A temporary server issue. Please try again shortly.';

  @override
  String get errNotFound => 'We couldn\'t find what you\'re looking for.';

  @override
  String get errValidation => 'Please check the details you entered.';

  @override
  String get errUnauthorized => 'Your session expired. Sign in to continue.';

  @override
  String get errUnknown => 'An unexpected error occurred.';

  @override
  String get onboardTitle => 'Everything your pet needs';

  @override
  String get onboardSubtitle =>
      'Set your location so we show what\'s actually in stock near you — with real delivery times.';

  @override
  String get onboardUseLocation => 'Use my current location';

  @override
  String get onboardChooseCity => 'Choose a city';

  @override
  String get onboardSkip => 'Browse without setting it';

  @override
  String get onboardLocating => 'Finding your location…';

  @override
  String get onboardLocationDenied =>
      'Location permission wasn\'t granted. You can pick your city instead.';

  @override
  String get onboardLocationFailed =>
      'We couldn\'t detect your location. Pick your city instead.';

  @override
  String get citiesTitle => 'Choose your city';

  @override
  String get citiesSearchHint => 'Search for a city';

  @override
  String get citiesEmpty => 'No matching cities';

  @override
  String get locationSheetTitle => 'Deliver to';

  @override
  String get locationDeliverTo => 'Deliver to';

  @override
  String get locationChoose => 'Set your location';

  @override
  String get locationChange => 'Change';

  @override
  String get locationUnknownCity => 'Not set';

  @override
  String get tierExpress => 'Express';

  @override
  String get tierSameDay => 'Same day';

  @override
  String get tierShipping => 'Shipping';

  @override
  String get tierPickup => 'Store pickup';

  @override
  String get homeAnimalNav => 'Shop by pet';

  @override
  String get homeBrands => 'Featured brands';

  @override
  String get homeGreeting => 'Welcome 👋';

  @override
  String get homeEmpty => 'Nothing to show yet';

  @override
  String get homeEmptyHint =>
      'Pull to refresh in a moment, or browse the categories.';

  @override
  String get homeWishlistRail => 'From your wishlist';

  @override
  String get homeReorderDue => 'Time to reorder';

  @override
  String homeCampaignCoupon(String code) {
    return 'Code: $code';
  }

  @override
  String homeCampaignDiscount(String percent) {
    return '$percent off';
  }

  @override
  String homeCampaignEndsIn(String time) {
    return 'Ends in $time';
  }

  @override
  String homeCampaignEndsInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get homeTrustDelivery => 'Fast delivery';

  @override
  String get homeTrustPayment => 'Secure payment';

  @override
  String get homeTrustGenuine => 'Genuine products';

  @override
  String get homeTrustReturns => 'Easy returns';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmpty => 'No categories yet';

  @override
  String get listingFilters => 'Filter';

  @override
  String get listingSort => 'Sort';

  @override
  String get listingSortTitle => 'Sort results';

  @override
  String get listingFiltersTitle => 'Filter results';

  @override
  String get listingPriceRange => 'Price range';

  @override
  String listingResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get listingEmpty => 'No matching products';

  @override
  String get listingEmptyHint =>
      'Try relaxing your filters or changing the city.';

  @override
  String get listingClearFilters => 'Clear filters';

  @override
  String listingFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters applied',
      one: '1 filter applied',
    );
    return '$_temp0';
  }

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search products, brands or a barcode';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear history';

  @override
  String get searchNoSuggestions => 'No suggestions';

  @override
  String get searchStartHint => 'Type a product name or scan a barcode';

  @override
  String get searchScan => 'Scan barcode';

  @override
  String get scanTitle => 'Scan barcode';

  @override
  String get scanHint => 'Point the camera at the barcode on the pack';

  @override
  String get scanNotFound => 'No product matches that barcode';

  @override
  String get scanPermission => 'We need camera access to scan barcodes';

  @override
  String get pdpAddToCart => 'Add to cart';

  @override
  String get pdpOutOfStock => 'Out of stock';

  @override
  String get pdpQuantity => 'Quantity';

  @override
  String get pdpDelivery => 'Delivery';

  @override
  String get pdpAvailability => 'Availability by warehouse';

  @override
  String get pdpFbt => 'Frequently bought together';

  @override
  String get pdpSubstitutes => 'Similar products';

  @override
  String get pdpDescription => 'Description';

  @override
  String get pdpVariantsHint => 'Choose an option';

  @override
  String get pdpSelectVariant => 'Select an option first';

  @override
  String pdpReachable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units reach you',
      one: '1 unit reaches you',
      zero: 'None reach you',
    );
    return '$_temp0';
  }

  @override
  String pdpStockUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
      zero: 'Out of stock',
    );
    return '$_temp0';
  }

  @override
  String pdpMaxQty(int count) {
    return 'Maximum available: $count';
  }

  @override
  String get pdpAddedToCart => 'Added to cart';

  @override
  String get pdpLangFallback => 'Some details are shown in Arabic';

  @override
  String get priceFrom => 'From';

  @override
  String get priceWas => 'Was';

  @override
  String priceOff(int percent) {
    return '$percent% off';
  }

  @override
  String get cardAdd => 'Add';

  @override
  String get cardChooseOptions => 'Choose options';

  @override
  String get cardOutOfStock => 'Out of stock';

  @override
  String cardStockLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count left',
      one: '1 left',
    );
    return '$_temp0';
  }

  @override
  String get badgeHot => 'Best seller';

  @override
  String get badgeTrending => 'Trending';

  @override
  String get badgeNew => 'New';

  @override
  String get badgeLowStock => 'Low stock';

  @override
  String get badgeBackInStock => 'Back in stock';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartEmptyHint =>
      'Add what your pet needs and we\'ll bring it over.';

  @override
  String get cartStartShopping => 'Start shopping';

  @override
  String get cartSubtotal => 'Subtotal';

  @override
  String get cartDiscount => 'Discount';

  @override
  String get cartShipping => 'Delivery';

  @override
  String get cartTax => 'VAT';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartFree => 'Free';

  @override
  String get cartCoupon => 'Coupon';

  @override
  String get cartCouponHint => 'Enter coupon code';

  @override
  String get cartCouponApply => 'Apply';

  @override
  String get cartCouponRemove => 'Remove coupon';

  @override
  String get cartCheckout => 'Checkout';

  @override
  String get cartShipments => 'Your shipments';

  @override
  String get cartShipmentsHint =>
      'We split your order by the fastest source available per item.';

  @override
  String cartFreeShippingRemaining(String amount) {
    return 'Add $amount for free delivery';
  }

  @override
  String get cartFreeShippingQualified => 'Your delivery is free 🎉';

  @override
  String get cartItemRemoved => 'Item removed from cart';

  @override
  String get cartUpdateFailed => 'Couldn\'t update the cart';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String cartLineQty(int qty) {
    return 'Qty $qty';
  }

  @override
  String cartShortfall(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units ship later',
      one: '1 unit ships later',
    );
    return '$_temp0';
  }

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutStepAddress => 'Address';

  @override
  String get checkoutStepReview => 'Review';

  @override
  String get checkoutStepPayment => 'Payment';

  @override
  String get checkoutAddressTitle => 'Where should we deliver?';

  @override
  String get checkoutAddressNew => 'New address';

  @override
  String get checkoutAddressEmpty => 'No saved addresses';

  @override
  String get checkoutAddressEmptyHint =>
      'Add an address so we know where your order goes.';

  @override
  String get checkoutReviewTitle => 'Review your order';

  @override
  String get checkoutDeliverTo => 'Deliver to';

  @override
  String get checkoutChangeAddress => 'Change';

  @override
  String get checkoutItemsShow => 'Show items';

  @override
  String get checkoutItemsHide => 'Hide items';

  @override
  String get checkoutPromiseTitle => 'Arriving';

  @override
  String get checkoutPromiseSplit =>
      'Your order arrives in more than one delivery';

  @override
  String get checkoutNotesLabel => 'Note for the driver';

  @override
  String get checkoutNotesHint => 'e.g. call before arriving';

  @override
  String get checkoutPaymentTitle => 'How would you like to pay?';

  @override
  String get checkoutPaymentEmpty => 'No payment method is available right now';

  @override
  String get checkoutPaymentEmptyHint => 'Refresh, or try again shortly.';

  @override
  String get checkoutPlaceOrder => 'Place order';

  @override
  String get checkoutPayNow => 'Continue to payment';

  @override
  String get checkoutPlacing => 'Placing your order…';

  @override
  String get checkoutCartChangedTitle => 'Your basket changed for this address';

  @override
  String get checkoutCartChangedHint =>
      'Review what changed, then finish your order.';

  @override
  String get checkoutCartChangedAction => 'Review order';

  @override
  String get checkoutSignInReason => 'Sign in to complete your order';

  @override
  String get successTitle => 'Order received 🎉';

  @override
  String get successSubtitle =>
      'Thank you! We\'ve started preparing your order.';

  @override
  String successOrderNumber(String number) {
    return 'Order #$number';
  }

  @override
  String get successCodNote => 'Pay on delivery';

  @override
  String get successTrack => 'Track order';

  @override
  String get successKeepShopping => 'Keep shopping';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentOpening => 'Opening the payment page…';

  @override
  String get paymentWaiting => 'Finish paying in the window';

  @override
  String get paymentWaitingHint =>
      'We\'ll confirm your order automatically once it completes.';

  @override
  String get paymentConfirming => 'Confirming your payment…';

  @override
  String get paymentReopen => 'Reopen payment page';

  @override
  String get paymentFailedTitle => 'Payment didn\'t complete';

  @override
  String get paymentFailedHint =>
      'We never got the confirmation. Your order is saved — you can try again.';

  @override
  String get paymentSupportHint =>
      'If it keeps failing, contact us and we\'ll finish the order for you.';

  @override
  String get paymentAmountDue => 'Amount due';

  @override
  String get paymentCardTitle => 'Pay by card';

  @override
  String paymentPayAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get paymentSecureNote =>
      'Your details are encrypted — the app never stores your card.';

  @override
  String get paymentPreparingCard => 'Preparing the card form…';

  @override
  String get paymentCardFailed => 'The card payment couldn\'t be completed';

  @override
  String get paymentOtherMethods =>
      'Other payment methods (Apple Pay and more)';

  @override
  String get paymentHostedFallback =>
      'In-app card payment isn\'t available right now — continuing on the secure payment page.';

  @override
  String get paymentSaveCard => 'Save this card for next time';

  @override
  String get paymentUseAnotherCard => 'Use another card';

  @override
  String get payCardHolder => 'Cardholder name';

  @override
  String get payCardHolderHint => 'Name as printed on the card';

  @override
  String get payCardNumber => 'Card number';

  @override
  String get payCardNumberHint => '0000 0000 0000 0000';

  @override
  String get payCardExpiry => 'Expiry date';

  @override
  String get payCardExpiryHint => 'MM / YY';

  @override
  String get payCardCvv => 'Security code';

  @override
  String get payCardCvvHint => 'CVV';

  @override
  String get paymentViewOrder => 'View order';

  @override
  String get ordersTitle => 'My orders';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersEmptyHint =>
      'Your first order will appear here with live tracking.';

  @override
  String get orderDetailTitle => 'Order details';

  @override
  String get orderItemsTitle => 'Items';

  @override
  String get orderTimelineTitle => 'Progress';

  @override
  String get orderAddressTitle => 'Delivery address';

  @override
  String get orderTrackingTitle => 'Shipment';

  @override
  String get orderTrackingNumber => 'Tracking number';

  @override
  String get orderTrackingCopied => 'Tracking number copied';

  @override
  String get orderTrackingOpen => 'Track shipment';

  @override
  String get orderNotesTitle => 'Your note';

  @override
  String get orderPaymentMethod => 'Payment method';

  @override
  String get orderPaymentCod => 'Cash on delivery';

  @override
  String get orderPaymentOnline => 'Paid online';

  @override
  String get orderPaid => 'Paid';

  @override
  String get orderUnpaid => 'Awaiting payment';

  @override
  String get orderPayNow => 'Complete payment';

  @override
  String get orderReorder => 'Order again';

  @override
  String orderReorderAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to your cart',
      one: '1 item added to your cart',
    );
    return '$_temp0';
  }

  @override
  String orderReorderMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are unavailable',
      one: '1 item is unavailable',
    );
    return '$_temp0';
  }

  @override
  String get addressesTitle => 'My addresses';

  @override
  String get addressesEmpty => 'No saved addresses';

  @override
  String get addressesEmptyHint =>
      'Save an address once, and we\'ll deliver there every time.';

  @override
  String get addressAdd => 'Add address';

  @override
  String get addressNewTitle => 'New address';

  @override
  String get addressEditTitle => 'Edit address';

  @override
  String get addressPinTitle => 'Pick the delivery point';

  @override
  String get addressPinHint => 'Move the map until the pin sits on your door.';

  @override
  String get addressPinConfirm => 'Confirm location';

  @override
  String get addressPinChange => 'Change location';

  @override
  String get addressPinUseGps => 'My location';

  @override
  String get addressResolving => 'Finding the district…';

  @override
  String get addressLabelTitle => 'Address name';

  @override
  String get addressLabelHome => 'Home';

  @override
  String get addressLabelWork => 'Work';

  @override
  String get addressLabelOther => 'Other';

  @override
  String get addressNameLabel => 'Recipient name';

  @override
  String get addressPhoneLabel => 'Mobile number';

  @override
  String get addressCityLabel => 'City';

  @override
  String get addressDistrictLabel => 'District';

  @override
  String get addressLineLabel => 'Address details';

  @override
  String get addressLineHint => 'Street, building number, nearest landmark';

  @override
  String get addressSaveToggle => 'Save this address to my addresses';

  @override
  String get addressSetDefault => 'Set as default address';

  @override
  String get addressDefaultBadge => 'Default';

  @override
  String get addressDelete => 'Delete address';

  @override
  String get addressDeleteConfirm => 'Delete this address?';

  @override
  String get addressDeleted => 'Address deleted';

  @override
  String get addressSaved => 'Address saved';

  @override
  String get addressDefaultSet => 'This is now your default address';

  @override
  String get addressNameRequired => 'Enter the recipient\'s name';

  @override
  String get addressLineRequired => 'Enter the address details';

  @override
  String get addressCityRequired => 'Enter the city';

  @override
  String get addressPinRequired => 'Pick the location on the map';

  @override
  String get buyAgainTitle => 'Buy again';

  @override
  String get buyAgainEmpty => 'No past purchases yet';

  @override
  String get buyAgainEmptyHint =>
      'After your first order, what you usually buy lands here in one tap.';

  @override
  String get wishlistTitle => 'Wishlist';

  @override
  String get wishlistEmpty => 'Your wishlist is empty';

  @override
  String get wishlistEmptyHint =>
      'Tap the heart on any product to save it here.';

  @override
  String get wishlistAdded => 'Added to wishlist';

  @override
  String get wishlistRemoved => 'Removed from wishlist';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountGuest => 'Guest';

  @override
  String get accountGuestHint => 'Sign in to keep your orders and wishlist';

  @override
  String get accountLogin => 'Sign in';

  @override
  String get accountLogout => 'Sign out';

  @override
  String get accountLogoutConfirm => 'Sign out of your account?';

  @override
  String get accountOrders => 'My orders';

  @override
  String get accountWishlist => 'Wishlist';

  @override
  String get accountAddresses => 'My addresses';

  @override
  String get accountBuyAgain => 'Buy again';

  @override
  String get accountSupport => 'Help & support';

  @override
  String get accountAbout => 'About Zooboxi';

  @override
  String accountVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accountPreferences => 'Preferences';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguageArabic => 'العربية';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountTheme => 'Appearance';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get accountThemeSystem => 'System';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountSoon => 'Coming soon';

  @override
  String get authTitle => 'Sign in';

  @override
  String get authSubtitle =>
      'Enter your mobile number and we\'ll text you a code.';

  @override
  String get authPhoneLabel => 'Mobile number';

  @override
  String get authPhoneHint => '05XXXXXXXX';

  @override
  String get authPhoneInvalid => 'Enter a valid Saudi mobile number';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authOtpTitle => 'Verification code';

  @override
  String authOtpSubtitle(String phone) {
    return 'We sent a 4-digit code to $phone';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authResend => 'Resend code';

  @override
  String get authChangeNumber => 'Change number';

  @override
  String get authOtpInvalid => 'Wrong code — try again';

  @override
  String get authWelcomeTitle => 'Welcome to Zooboxi 🐾';

  @override
  String get authWelcomeSubtitle =>
      'Tell us your name so we can greet you properly.';

  @override
  String get authNameLabel => 'Name';

  @override
  String get authEmailLabel => 'Email (optional)';

  @override
  String get authFinish => 'Start shopping';

  @override
  String get authRequired => 'Sign in to continue';

  @override
  String get authRequiredWishlist => 'Sign in to save your favourite products';

  @override
  String get authLoggedIn => 'Signed in';

  @override
  String get authCartMerged => 'We merged your previous cart';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonOptional => 'Optional';

  @override
  String get paymentOrCard => 'Or pay by card';

  @override
  String get brandAllCategories => 'All';

  @override
  String brandCurated(String brand) {
    return '$brand picks';
  }

  @override
  String brandSince(String year) {
    return 'Since $year';
  }

  @override
  String brandProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
      zero: 'No products',
    );
    return '$_temp0';
  }

  @override
  String brandShopAll(String brand) {
    return 'All $brand products';
  }
}
