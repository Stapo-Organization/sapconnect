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
  String get onbStart => 'Let\'s go';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbLater => 'Later';

  @override
  String get onbWelcomeTitle => 'Welcome to Zooboxi';

  @override
  String get onbWelcomeBody =>
      'Everything your pet needs — food, care and toys — delivered fast to your door';

  @override
  String get onbLanguageTitle => 'Which language do you prefer?';

  @override
  String get onbLocTitle => 'Where should we deliver?';

  @override
  String get onbLocBody =>
      'Drop your pin and we deliver to your door — real stock from your nearest branch and an honest promise for your district';

  @override
  String get onbLocPerk1 => 'The fastest delivery for your district';

  @override
  String get onbLocPerk2 => 'Real stock from your nearest branch';

  @override
  String get onbLocPerk3 => 'Your city\'s offers, first';

  @override
  String get onbLocCta => 'Pin my location on the map';

  @override
  String get onbLocCity => 'Choose my city';

  @override
  String get onbLocSetTitle => 'Got you!';

  @override
  String get onbLocFailed =>
      'We couldn\'t get your location — you can pick your city instead';

  @override
  String get onbNotifTitle => 'Be the first to know';

  @override
  String get onbNotifBody =>
      'Turn on notifications for live order updates and the best offers before anyone else';

  @override
  String get onbNotifPerk1 => 'Track your order step by step';

  @override
  String get onbNotifPerk2 => 'Offers and discounts on your pet\'s supplies';

  @override
  String get onbNotifPerk3 => 'A heads-up the moment your order arrives';

  @override
  String get onbNotifCta => 'Allow notifications';

  @override
  String get onbNotifMockTitle => 'Your order is on the way 🚚';

  @override
  String get onbNotifMockBody => 'The driver is close — get ready!';

  @override
  String get onbNotifNow => 'now';

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
  String get categoriesShopAll => 'Shop all';

  @override
  String categoriesProductCount(int count) {
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
  String get addressBuildingLabel => 'Building no.';

  @override
  String get addressFloorLabel => 'Floor';

  @override
  String get addressApartmentLabel => 'Apartment';

  @override
  String get addressLineLabel => 'Address description';

  @override
  String get addressLineHint =>
      'Nearby landmark? gate? anything that helps the driver';

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

  @override
  String get brandsTitle => 'All brands';

  @override
  String get cartItemUnreachable =>
      'This product can\'t be delivered to your location right now';

  @override
  String get driftTitle => 'Looks like you\'re somewhere new';

  @override
  String driftBody(String here, String saved) {
    return 'You are at: $here\nDelivery address: $saved';
  }

  @override
  String get driftUseHere => 'Deliver to where I am';

  @override
  String get driftKeep => 'Keep my saved address';

  @override
  String get familyTitle => 'Zooboxi Family';

  @override
  String get familyTagline => 'Every order brings your friend closer to a gift';

  @override
  String get familyGuestTitle => 'Join the Zooboxi Family';

  @override
  String get familyGuestBody =>
      'Add your pet and start collecting paws — gifts and free delivery, no discounts, no catches.';

  @override
  String get familyGuestCta => 'Get started';

  @override
  String get familyAddPet => 'Add your pet';

  @override
  String get familyNoPetTitle => 'Who is your friend?';

  @override
  String get familyNoPetBody =>
      'Introduce your pet and earn 50 paws right away';

  @override
  String familyDue(String product) {
    return 'Time to reorder $product';
  }

  @override
  String get familyOrderNow => 'Order now';

  @override
  String familyMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get familyPerksTitle => 'Your perks';

  @override
  String familyPerkFrom(String tier) {
    return 'From $tier';
  }

  @override
  String get familyMyRewards => 'My rewards';

  @override
  String get familyRedeemTitle => 'Spend your paws';

  @override
  String get familySealedTitle => 'Cards waiting to be scratched';

  @override
  String get familyLedgerLink => 'Paws history';

  @override
  String familyReferralCode(String code) {
    return 'Invite code $code';
  }

  @override
  String familyTierOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders in 12 months',
      one: '1 order in 12 months',
      zero: 'No orders in 12 months',
    );
    return '$_temp0';
  }

  @override
  String familyTierNext(int count, String tier) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders away from $tier',
      one: '1 order away from $tier',
    );
    return '$_temp0';
  }

  @override
  String get familyTierTop => 'You\'re at the top tier — thank you';

  @override
  String get pawsTitle => 'Your paws';

  @override
  String get pawsUnit => 'paws';

  @override
  String pawsCount(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value paws',
      one: '1 paw',
      zero: 'No paws',
    );
    return '$_temp0';
  }

  @override
  String pawsPending(String value) {
    return '$value paws pending';
  }

  @override
  String get pawsPendingHint => 'They land when your order is delivered';

  @override
  String pawsExpires(String date) {
    return 'Expire on $date';
  }

  @override
  String get pawsHowTitle => 'How do I earn paws?';

  @override
  String get pawsHowOrder =>
      'One paw for every riyal of an order that reaches you';

  @override
  String get pawsHowProfile =>
      '100 paws when your pet\'s profile has a weight and a birth date';

  @override
  String get pawsHowPet => '50 paws for every pet you add';

  @override
  String get pawsHowPlay =>
      'Monthly missions, plus a scratch card with every app order';

  @override
  String get pawsHowExpiry => 'Paws expire after 12 months with no orders';

  @override
  String get pawsHowDelivered =>
      'Everything counts on delivery — nothing before the order is in your hands';

  @override
  String pawsToEarn(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You\'ll earn $value paws',
      one: 'You\'ll earn 1 paw',
      zero: 'No paws from this basket',
    );
    return '$_temp0';
  }

  @override
  String pawsEarned(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You earned $value paws',
      one: 'You earned 1 paw',
    );
    return '$_temp0';
  }

  @override
  String get pawsLedgerTitle => 'Paws history';

  @override
  String get pawsLedgerEmpty => 'Nothing here yet';

  @override
  String get pawsLedgerEmptyHint => 'Your first delivered order opens it';

  @override
  String get pawsLedgerMore => 'Show more';

  @override
  String pawsBalanceAfter(String value) {
    return 'Balance $value';
  }

  @override
  String pawsReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'order_earn': 'Delivered order',
      'profile_complete': 'Profile completed',
      'pet_added': 'Pet added',
      'mission': 'Monthly mission',
      'scratch': 'Scratch card',
      'redeem': 'Redeemed',
      'reverse': 'Reversed',
      'expire': 'Expired',
      'adjust': 'Manual adjustment',
      'welcome': 'Welcome gift',
      'other': 'Entry',
    });
    return '$_temp0';
  }

  @override
  String get missionsTitle => 'This month\'s missions';

  @override
  String get missionsSubtitle =>
      'Four missions, renewed at the start of every month';

  @override
  String missionProgress(int progress, int target) {
    return '$progress of $target';
  }

  @override
  String get missionDone => 'Done';

  @override
  String get missionRewardGift => 'A gift';

  @override
  String get missionSuggested => 'Good picks for your friend';

  @override
  String get missionsEmpty => 'No missions this month';

  @override
  String get missionsEmptyHint => 'New ones arrive at the start of next month';

  @override
  String get rewardsTitle => 'Rewards';

  @override
  String get rewardsMine => 'My rewards';

  @override
  String get rewardsCatalog => 'Spend your paws';

  @override
  String get rewardsEmpty => 'No rewards yet';

  @override
  String get rewardsEmptyHint =>
      'Collect paws and turn them into a gift or free delivery';

  @override
  String get rewardsCatalogEmpty => 'The catalogue is empty right now';

  @override
  String rewardCost(String value) {
    return '$value paws';
  }

  @override
  String rewardValue(String price) {
    return 'Worth $price';
  }

  @override
  String rewardValidity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Valid for $count days',
      one: 'Valid for 1 day',
    );
    return '$_temp0';
  }

  @override
  String rewardExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get rewardRedeem => 'Redeem';

  @override
  String get rewardRedeemTitle => 'Confirm redemption';

  @override
  String rewardRedeemBody(String value, String title) {
    return 'We\'ll take $value paws for “$title”. It will be ready for your next order.';
  }

  @override
  String get rewardRedeemDone => 'It\'s in your rewards now';

  @override
  String get rewardRedeemFailed => 'Couldn\'t redeem that';

  @override
  String get rewardUseInCart => 'Use in cart';

  @override
  String get rewardInCart => 'In your cart';

  @override
  String get rewardRemove => 'Remove from cart';

  @override
  String rewardPendingOrder(String number) {
    return 'Activates when order $number is delivered';
  }

  @override
  String get rewardPending => 'Activates when your order is delivered';

  @override
  String get rewardKindGift => 'Gift';

  @override
  String get rewardKindExpress => 'Free express';

  @override
  String get rewardKindDelivery => 'Free delivery';

  @override
  String get rewardKindPaws => 'Paws';

  @override
  String get rewardUseButton => 'Use a reward';

  @override
  String get rewardSheetTitle => 'Rewards ready to use';

  @override
  String get rewardSheetHint => 'Applied to this order right away';

  @override
  String get rewardSheetEmpty => 'Nothing ready just yet';

  @override
  String get rewardGiftChip => 'Gift';

  @override
  String get rewardGiftFree => 'Free';

  @override
  String get rewardClaimFailed => 'Couldn\'t use that reward';

  @override
  String get rewardGiftUnavailable =>
      'That gift can\'t reach your location right now';

  @override
  String get rewardInsufficientPaws => 'Not enough paws';

  @override
  String get rewardTierRequired => 'Needs a higher tier';

  @override
  String get rewardFreeDeliveryTier => 'Free delivery, thanks to your tier';

  @override
  String get rewardFreeDeliveryReward => 'Free delivery from your reward';

  @override
  String get rewardExpressFreeTier => 'Free express, thanks to your tier';

  @override
  String get rewardExpressFreeReward => 'Free express from your reward';

  @override
  String get scratchTitle => 'Scratch and win';

  @override
  String get scratchHint => 'Scratch it with your finger';

  @override
  String scratchOrder(String number) {
    return 'Card for order $number';
  }

  @override
  String scratchPrizePaws(String value) {
    return '$value paws!';
  }

  @override
  String get scratchActivation => 'Activates when your order is delivered';

  @override
  String get scratchSettled => 'It\'s in your account';

  @override
  String get scratchDone => 'Nice';

  @override
  String get scratchOpen => 'Open the card';

  @override
  String get scratchEmpty => 'No cards right now';

  @override
  String get scratchEmptyHint => 'Every app order comes with one';

  @override
  String get petsTitle => 'My family';

  @override
  String get petsEmpty => 'No pets yet';

  @override
  String get petsEmptyHint =>
      'Introduce your friend and we\'ll suggest what actually suits them';

  @override
  String get petsAdd => 'Add a pet';

  @override
  String petsFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can add up to $max pets',
      one: 'You can add 1 pet',
    );
    return '$_temp0';
  }

  @override
  String get petNewTitle => 'A new friend';

  @override
  String petEditTitle(String name) {
    return '$name\'s profile';
  }

  @override
  String get petFieldName => 'Name';

  @override
  String get petFieldNameHint => 'Mishmish';

  @override
  String get petFieldSpecies => 'Species';

  @override
  String get petFieldBreed => 'Breed';

  @override
  String get petFieldBreedHint => 'Optional';

  @override
  String get petFieldWeight => 'Weight';

  @override
  String get petFieldBirthDate => 'Birth date';

  @override
  String get petFieldSex => 'Sex';

  @override
  String get petFieldNeutered => 'Neutered';

  @override
  String get petWeightUnit => 'kg';

  @override
  String get petSexMale => 'Male';

  @override
  String get petSexFemale => 'Female';

  @override
  String get petSexUnset => 'Not set';

  @override
  String get petNotSet => 'Not set';

  @override
  String get petSpeciesCat => 'Cat';

  @override
  String get petSpeciesDog => 'Dog';

  @override
  String get petSpeciesBird => 'Bird';

  @override
  String get petSpeciesFish => 'Fish';

  @override
  String get petSpeciesSmall => 'Small pet';

  @override
  String get petSpeciesReptile => 'Reptile';

  @override
  String get petSpeciesOther => 'Other';

  @override
  String get petNameRequired => 'Give your friend a name';

  @override
  String get petWeightInvalid => 'Enter a weight between 0.1 and 200 kg';

  @override
  String get petBirthDateInvalid => 'A birth date can\'t be in the future';

  @override
  String get petSaveFailed => 'Couldn\'t save that';

  @override
  String get petSaved => 'Saved';

  @override
  String get petDelete => 'Delete profile';

  @override
  String petDeleteConfirm(String name) {
    return 'Delete $name\'s profile?';
  }

  @override
  String get petDeleted => 'Profile deleted';

  @override
  String petBirthdaySoon(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Birthday in $count days',
      one: 'Birthday tomorrow',
      zero: 'Birthday today',
    );
    return '$_temp0';
  }

  @override
  String get petIncompleteHint =>
      'Add a weight and a birth date to earn 100 paws';

  @override
  String get petAgeUnknown => 'Age not recorded';

  @override
  String get petPickDate => 'Pick a date';

  @override
  String get petLimitReached => 'You\'ve reached the pet limit';

  @override
  String familyHubGreeting(String name) {
    return '$name\'s family';
  }

  @override
  String get familyHubGreetingNoPet => 'Your family';

  @override
  String get familyActionHow => 'How to earn';

  @override
  String get familyActionLedger => 'History';

  @override
  String get familyActionPets => 'My pets';

  @override
  String get familyLadderTitle => 'Your journey';

  @override
  String familyPendingOrderTitle(String number) {
    return 'Order $number is on its way';
  }

  @override
  String familyPendingOrderBody(String value) {
    return 'On delivery, $value paws land and your mission counts automatically';
  }

  @override
  String familyPendingOrderPaws(String value) {
    return 'On delivery, $value paws land in your wallet';
  }

  @override
  String get familyReferralTitle => 'Invite code';

  @override
  String get familyReferralCopied => 'Invite code copied';

  @override
  String get pawsWalletTitle => 'Paws wallet';

  @override
  String get missionAwaitingDelivery => 'Waiting for your delivery';

  @override
  String missionsDoneOf(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get rewardComingSoon => 'Soon';

  @override
  String get rewardsShelfHint => 'Tap to redeem';

  @override
  String get cartFreeDeliveryCelebrate => 'Delivery is on us!';

  @override
  String get cartExpressCelebrate => 'Express delivery is free on this order';

  @override
  String successPawsNote(String value) {
    return '$value paws land in your wallet when the order is delivered';
  }

  @override
  String get successMissionNote =>
      'and this month\'s missions count automatically after delivery';

  @override
  String get scratchKeepGoing => 'Keep scratching…';

  @override
  String missionOfTarget(String target) {
    return 'of $target';
  }

  @override
  String get supplyTitle => 'Pantry';

  @override
  String get supplySubtitle =>
      'We learn from your orders — every \"ran out\" or \"still enough\" makes the estimate sharper';

  @override
  String get supplyHubSubtitle => 'When your family\'s food runs out';

  @override
  String get supplyEmptyTitle => 'Nothing on the gauge yet';

  @override
  String get supplyEmptyBody =>
      'After your first food or litter order from the app we start counting down and remind you on time';

  @override
  String supplyDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Runs out today',
    );
    return '$_temp0';
  }

  @override
  String get supplyRunsOutToday => 'Runs out today';

  @override
  String supplyOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ran out $count days ago',
      one: 'Ran out yesterday',
    );
    return '$_temp0';
  }

  @override
  String get supplyOrderNow => 'Order now';

  @override
  String get supplyOut => 'Ran out';

  @override
  String get supplySnooze => 'Enough';

  @override
  String get supplySubscribe => 'Subscribe';

  @override
  String get supplySubscribed => 'Subscribed';

  @override
  String supplyOnTimeBadge(int pct) {
    return '+$pct% on time';
  }

  @override
  String supplyCycle(String days) {
    return 'Lasts about $days days';
  }

  @override
  String supplyForPet(String name) {
    return 'for $name';
  }

  @override
  String get supplyConfidenceLow => 'first estimate';

  @override
  String get supplyConfidenceMedium => 'estimate';

  @override
  String get supplyConfidenceHigh => 'based on your orders';

  @override
  String get supplyMarkedOut => 'Noted — it ran out. Time to reorder';

  @override
  String supplySnoozed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Okay, we\'ll remind you in $count days',
    );
    return '$_temp0';
  }

  @override
  String get supplyKindDry => 'Dry food';

  @override
  String get supplyKindWet => 'Wet food';

  @override
  String get supplyKindLitter => 'Litter';

  @override
  String get supplyKindTreat => 'Treats';

  @override
  String get supplyKindOther => 'Supply';

  @override
  String supplyWindowHint(int before, int after, int pct) {
    return 'Order between $before days before it runs out and $after after, and earn +$pct% paws';
  }

  @override
  String supplyPack(String kg) {
    return '$kg kg';
  }

  @override
  String get subsTitle => 'My subscriptions';

  @override
  String get subsSubtitle =>
      'Deliver every month — no saved card, no commitment, you decide every time';

  @override
  String subsHubSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active subscriptions',
      one: '1 active subscription',
    );
    return '$_temp0';
  }

  @override
  String get subsEmptyTitle => 'No subscriptions yet';

  @override
  String get subsEmptyBody =>
      'Subscribe to your family\'s food from the pantry — we remind you before the date, you order with one tap, delivery is on us';

  @override
  String subsNextIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delivery in $count days',
      one: 'Delivery tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get subsNextToday => 'Delivery today';

  @override
  String get subsOverdue => 'Delivery date passed';

  @override
  String subsEvery(int days) {
    return 'Every $days days';
  }

  @override
  String subsQty(int qty) {
    return '× $qty';
  }

  @override
  String get subsPaused => 'Paused';

  @override
  String get subsOrderNow => 'Order now';

  @override
  String get subsSkip => 'Skip';

  @override
  String get subsEdit => 'Edit';

  @override
  String get subsPause => 'Pause';

  @override
  String get subsResume => 'Resume';

  @override
  String get subsCancel => 'Cancel subscription';

  @override
  String get subsCancelConfirm =>
      'Cancel this subscription? You can subscribe again any time.';

  @override
  String subsPerks(int pct, int every) {
    return 'Free delivery on every delivery · +$pct% paws · a gift every $every deliveries';
  }

  @override
  String subsDeliveries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deliveries',
      one: '1 delivery',
      zero: 'No deliveries yet',
    );
    return '$_temp0';
  }

  @override
  String subsNextGift(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gift in $count deliveries',
      one: 'Gift with the next delivery',
    );
    return '$_temp0';
  }

  @override
  String get subsEditorTitle => 'Edit subscription';

  @override
  String get subsIntervalLabel => 'How often?';

  @override
  String get subsQtyLabel => 'Quantity';

  @override
  String get subsNextLabel => 'Next delivery';

  @override
  String get subsSave => 'Save';

  @override
  String get subsCreated => 'Subscribed — we\'ll remind you three days before';

  @override
  String get subsSkipped => 'This delivery was skipped';

  @override
  String get subsBasketReady => 'Your basket is ready — delivery is free';

  @override
  String get subsCancelled => 'Subscription cancelled';

  @override
  String get subsFreeDeliveryBody =>
      'Subscription delivery — shipping is on us';

  @override
  String get successSubscriptionNote =>
      'Subscription delivery: bonus paws and free delivery';

  @override
  String get referralTitle => 'Invite a friend';

  @override
  String referralHubBody(String paws) {
    return 'Your friend gets a welcome gift with their first order, and you get $paws paws once it\'s delivered';
  }

  @override
  String get referralShare => 'Share the invite';

  @override
  String get referralCopy => 'Copy code';

  @override
  String get referralCopied => 'Code copied';

  @override
  String get referralYourCode => 'Your code';

  @override
  String get referralStatsInvited => 'Invited';

  @override
  String get referralStatsQualified => 'Awaiting delivery';

  @override
  String get referralStatsRewarded => 'Rewarded';

  @override
  String get referralHaveCode => 'Have a code from a friend?';

  @override
  String get referralEnterCode => 'Enter the invitation code';

  @override
  String get referralApply => 'Apply';

  @override
  String referralApplied(String code) {
    return 'Code $code applied — your welcome gift is in your wallet';
  }

  @override
  String referralAppliedBefore(String code) {
    return 'You joined by invitation $code';
  }

  @override
  String referralCap(int n, int cap) {
    return '$n of $cap invitations this month';
  }

  @override
  String get referralEmpty =>
      'No one invited yet — the first friend is waiting';

  @override
  String get referralStatePending => 'Joined — awaiting first order';

  @override
  String get referralStateQualified => 'Order delivered — awaiting approval';

  @override
  String get referralStateReview => 'Under review';

  @override
  String get referralStateRewarded => 'Reward paid';

  @override
  String get referralStateRejected => 'Not accepted';

  @override
  String get referralHow => 'How it works';

  @override
  String get referralHow1 =>
      'Share your code or link with a friend who has never ordered from Zooboxi';

  @override
  String referralHow2(String welcome) {
    return 'They apply the code in the app and get $welcome with their first order';
  }

  @override
  String referralHow3(String paws) {
    return 'A week after their order is delivered, $paws paws land in your wallet';
  }

  @override
  String momentBirthdayTitle(String name) {
    return '$name\'s birthday 🎂';
  }

  @override
  String momentBirthdayIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get momentBirthdayToday => 'today!';

  @override
  String momentBirthdayPassed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String get momentBirthdayGift =>
      'A gift in their name is in your wallet — add it to your next order';

  @override
  String momentBirthdayPaws(String paws) {
    return '$paws birthday paws are in your wallet';
  }

  @override
  String get momentBirthdayNoGift =>
      'How about a small treat for them this week?';

  @override
  String get momentAddToCart => 'Add the gift to cart';

  @override
  String get momentGiftAdded => 'The gift is in your cart';

  @override
  String tierRiskLine(int days, String tier) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days your level drops to $tier — one order keeps it',
      one: 'Tomorrow your level drops to $tier — one order keeps it',
    );
    return '$_temp0';
  }

  @override
  String get stampsTitle => 'Brand cards';

  @override
  String stampsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to go',
      one: '1 to go',
    );
    return '$_temp0';
  }

  @override
  String stampsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards completed',
      one: '1 card completed',
    );
    return '$_temp0';
  }

  @override
  String stampsMinPack(String kg) {
    return 'packs of $kg kg and up';
  }

  @override
  String get stampsReward => 'Reward';

  @override
  String familySupplyLine(int days, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$name\'s food lasts $days more days',
      one: '$name\'s food lasts 1 more day',
    );
    return '$_temp0';
  }

  @override
  String familySupplyDue(String name) {
    return 'Time to reorder $name\'s food';
  }

  @override
  String familySubscriptionLine(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Your subscription delivery is in $days days',
      one: 'Your subscription delivery is tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get familySubscriptionToday => 'Your subscription delivery is today';

  @override
  String get subsEveryWeek => 'Every week';

  @override
  String get subsEveryTwoWeeks => 'Every two weeks';

  @override
  String get subsEveryMonth => 'Every month';

  @override
  String get subsEveryTwoMonths => 'Every two months';
}
