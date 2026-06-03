import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/storage/secure_storage.dart';

/// App Translations & Locale Controller
class AppLocalizations {
  AppLocalizations._();

  static const String _localeStorageKey = 'app_selected_locale';

  /// Live notifier for language changes across the entire app
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('ar'));

  /// Current active language code
  static String get currentLanguage => localeNotifier.value.languageCode;

  /// Check if the current locale is Arabic
  static bool get isArabic => currentLanguage == 'ar';

  /// Translations map
  static const Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'app_title': 'مُنتجات',
      'app_subtitle': 'مدير المعرض',
      
      // Auth
      'login': 'تسجيل الدخول',
      'login_subtitle': 'أدخل بيانات الدخول للمتابعة',
      'email': 'البريد الإلكتروني',
      'email_hint': 'example@muntajat.sa',
      'password': 'كلمة المرور',
      'password_required': 'يرجى إدخال كلمة المرور',
      'email_required': 'يرجى إدخال البريد الإلكتروني',
      'email_invalid': 'بريد إلكتروني غير صالح',
      'unexpected_error': 'حدث خطأ غير متوقع',
      
      // Bottom Nav
      'nav_home': 'الرئيسية',
      'nav_transfers': 'التحويلات',
      'nav_counting': 'الجرد',
      'nav_achievements': 'إنجازاتي',
      'nav_profile': 'حسابي',

      // Achievements / Gamification
      'achievements_subtitle': 'نقاطك وأوسمتك وترتيبك',
      'achievements_soon_title': 'إنجازاتك قادمة قريباً',
      'achievements_soon_subtitle': 'أكمل مهام الجرد لتجمع النقاط والأوسمة',

      // Cycle Counting (guided)
      'cycle_count': 'جرد دوري',
      'full_count': 'جرد سنوي',
      'status_filter_title': 'تصفية حسب الحالة',
      'items_to_count': 'الأصناف المطلوب جردها',
      'counted': 'تم العدّ',
      'pending_count': 'بانتظار',
      'remaining_items': 'متبقّي',
      'scan_to_count': 'مسح باركود',
      'complete_count': 'إكمال الجرد',
      'scan_at_least_one': 'امسح صنفاً واحداً على الأقل للإكمال',
      'count_completed': 'تم إكمال الجرد بنجاح 🎉',
      'cycle_auto_generated': 'تُنشأ مهام الجرد الدوري تلقائياً كل أسبوع',
      'no_targets': 'لا توجد أصناف مستهدفة في هذه المهمة',
      'class_label': 'الفئة',
      'overdue_label': 'متأخر',
      'due_label': 'مستحق',

      // Cycle detail — tabs & records
      'cycle_targets_tab': 'المطلوب جرده',
      'cycle_records_tab': 'سجلاتي',
      'counted_records': 'السجلات المُدخلة',
      'no_records_yet': 'لم تُسجّل أي عملية عدّ بعد',
      'no_records_yet_hint': 'امسح الأصناف لتسجيل عمليات العدّ',
      'entry_n': 'تسجيل {n}',
      'counted_products_n': 'المنتجات المجرودة ({n})',
      'edit_quantity': 'تعديل الكمية',
      'delete_record': 'حذف السجل',
      'delete_record_confirm': 'هل تريد حذف هذا السجل من الجرد؟',
      'update': 'تحديث',
      'delete': 'حذف',
      // Off-list scanner gating (cycle)
      'off_list_title': 'صنف خارج قائمة الجرد',
      'product_off_cycle_list': 'هذا المنتج خارج قائمة الجرد الدوري',
      'off_list_cannot_count': 'لا يمكن عدّ صنف خارج القائمة',
      'off_list_scans_n': '{n} مسح خارج القائمة',
      'counted_label': 'مجرود',

      // Quality Control
      'quality_tasks': 'مهام الجودة',
      'quality_section_subtitle': 'مهام مستحقة اليوم',
      'no_quality_tasks': 'لا توجد مهام جودة 🎉',
      'view_all': 'عرض الكل',
      'status_pending': 'قيد التنفيذ',
      'status_submitted': 'مكتملة',
      'proof_acknowledge': 'تأكيد',
      'proof_photo': 'صور',
      'proof_checklist': 'قائمة',
      'mark_done': 'تم الإنجاز',
      'submit_task': 'إرسال',
      'task_submitted': 'تم إكمال المهمة 🎉',
      'add_photo': 'إضافة صورة',
      'take_photo': 'التقاط صورة',
      'choose_from_gallery': 'من المعرض',
      'photos_progress': '{x} / {min} صور',
      'comment_optional': 'تعليق (اختياري)',
      'comment_required_label': 'تعليق (مطلوب)',
      'complete_all_items': 'أكمل جميع البنود للإرسال',
      'photo_required_badge': 'صورة مطلوبة',
      'acknowledge_hint': 'اضغط للتأكيد عند إنجاز المهمة',
      'overdue_badge': 'متأخرة',

      // Gamification detail
      'points': 'نقطة',
      'level': 'المستوى',
      'streak': 'سلسلة',
      'weeks': 'أسبوع',
      'accuracy': 'الدقة',
      'this_month': 'هذا الشهر',
      'weekly_goal': 'الهدف الأسبوعي',
      'leaderboard': 'لوحة الترتيب',
      'rank_branch': 'ترتيب فرعك',
      'rank_in_branch': 'ترتيبك في الفرع',
      'rank_company': 'ترتيبك العام',
      'badges_title': 'الأوسمة',
      'branches': 'الفروع',
      'employees': 'الموظفون',
      'you': 'أنت',
      'anonymous_member': 'موظف',
      'position_of': 'من',
      'cycle_counts': 'جرود دورية',
      'full_counts': 'جرود عادية',
      'to_next_level': 'للمستوى التالي',
      'your_tasks': 'مهامك',
      'no_tasks': 'لا توجد مهام مستحقة 🎉',
      'start_now': 'ابدأ الآن',

      // Home
      'welcome': 'مرحباً 👋',
      'quick_actions': 'الإجراءات السريعة',
      'stock_transfers': 'تحويلات المخزون',
      'start_new_count': 'بدء جرد جديد',
      'quick_look': 'نظرة سريعة',
      'transfers_pending_send': 'تحويلات بانتظار الإرسال',
      'transfers_pending_receive': 'تحويلات بانتظار الاستلام',
      'active_counting_sessions': 'سجلات جرد جارية',
      
      // Transfers
      'all': 'الكل',
      'status_new': 'جديد',
      'status_shipped': 'تم الشحن',
      'status_received': 'تم الاستلام',
      'status_partially_received': 'استلام جزئي',
      'status_completed': 'مكتمل',
      'status_cancelled': 'ملغي',
      'no_transfers': 'لا توجد تحويلات',
      'from': 'من',
      'to': 'إلى',
      'items': 'صنف',
      'sent': 'مرسل',
      // Transfers — tabs, filter & detail
      'tab_send': 'إرسال',
      'tab_receive': 'استلام',
      'transfers_send_empty': 'لا توجد تحويلات للإرسال',
      'transfers_receive_empty': 'لا توجد تحويلات للاستلام',
      'required_qty': 'المطلوب',
      'sent_qty': 'المرسل',
      'received_qty': 'المستلم',
      'items_count_label': 'الأصناف',
      'total_quantity': 'إجمالي الكمية',
      'transfer_date': 'التاريخ',
      'scan_to_confirm_send': 'مسح لتأكيد الإرسال',
      'scan_to_confirm_receive': 'مسح لتأكيد الاستلام',
      'confirm_send': 'تأكيد الإرسال',
      'confirm_receive': 'تأكيد الاستلام',
      'search': 'بحث',
      'search_transfers': 'البحث في التحويلات...',
      'search_counting': 'البحث في سجلات الجرد...',
      'no_results': 'لا توجد نتائج',
      
      // Counting
      'stock_counting': 'جرد المخزون',
      'new_count_btn': 'جرد جديد',
      'counting_in_progress': 'جاري الجرد',
      'no_sessions': 'لا توجد سجلات جرد',
      'click_to_start': 'اضغط على "جرد جديد" للبدء',
      'continue_counting': 'متابعة الجرد',
      'pieces': 'قطعة',
      'choose_warehouse': 'اختر المستودع',
      'cancel': 'إلغاء',
      'retry': 'إعادة المحاولة',
      'error_title': 'حدث خطأ',
      'error_subtitle': 'تعذر تحميل البيانات. تحقق من اتصالك بالإنترنت.',
      'barcode_scanner': 'سكان الباركود',
      'barcode_scanner_send': 'سكان تأكيد الإرسال',
      'barcode_scanner_receive': 'سكان تأكيد الاستلام',
      'quantity': 'الكمية',
      'update_quantity': 'تحديث الكمية',
      'add': 'إضافة',
      'product_not_in_transfer': 'المنتج غير موجود في التحويل',
      'skip_and_scan_next': 'تخطي وسكان التالي',
      'scanned_count': 'تم سكان {count} من {total} منتج',
      'unknown_product': 'منتج غير معروف',
      'product_saved': '✅ {name} — الكمية: {qty}',
      
      // Profile
      'phone': 'رقم الجوال',
      'warehouses': 'المستودعات',
      'roles': 'الأدوار',
      'version': 'الإصدار',
      'logout': 'تسجيل الخروج',
      'logout_confirm': 'هل أنت متأكد من تسجيل الخروج؟',
      'language': 'اللغة / Language',
      'arabic': 'العربية',
      'english': 'English',
      'system_title': 'نظام إدارة المعارض - منتجات',
    },
    'en': {
      'app_title': 'Muntajat',
      'app_subtitle': 'Exhibition Manager',
      
      // Auth
      'login': 'Login',
      'login_subtitle': 'Enter login details to continue',
      'email': 'Email Address',
      'email_hint': 'example@muntajat.sa',
      'password': 'Password',
      'password_required': 'Please enter password',
      'email_required': 'Please enter email address',
      'email_invalid': 'Invalid email address',
      'unexpected_error': 'An unexpected error occurred',
      
      // Bottom Nav
      'nav_home': 'Home',
      'nav_transfers': 'Transfers',
      'nav_counting': 'Counting',
      'nav_achievements': 'Rewards',
      'nav_profile': 'Profile',

      // Achievements / Gamification
      'achievements_subtitle': 'Your points, badges & rank',
      'achievements_soon_title': 'Your rewards are coming soon',
      'achievements_soon_subtitle': 'Complete counting tasks to earn points and badges',

      // Cycle Counting (guided)
      'cycle_count': 'Cycle Count',
      'full_count': 'Annual Count',
      'status_filter_title': 'Filter by status',
      'items_to_count': 'Items to Count',
      'counted': 'Counted',
      'pending_count': 'Pending',
      'remaining_items': 'remaining',
      'scan_to_count': 'Scan',
      'complete_count': 'Complete Count',
      'scan_at_least_one': 'Scan at least one item to complete',
      'count_completed': 'Count completed 🎉',
      'cycle_auto_generated': 'Cycle tasks are generated automatically each week',
      'no_targets': 'No target items in this task',
      'class_label': 'Class',
      'overdue_label': 'Overdue',
      'due_label': 'Due',

      // Cycle detail — tabs & records
      'cycle_targets_tab': 'Targets',
      'cycle_records_tab': 'My Records',
      'counted_records': 'Entered Records',
      'no_records_yet': 'No records entered yet',
      'no_records_yet_hint': 'Scan items to log your counts',
      'entry_n': 'Entry {n}',
      'counted_products_n': 'Counted Products ({n})',
      'edit_quantity': 'Edit Quantity',
      'delete_record': 'Delete Record',
      'delete_record_confirm': 'Delete this record from the count?',
      'update': 'Update',
      'delete': 'Delete',
      // Off-list scanner gating (cycle)
      'off_list_title': 'Off-list item',
      'product_off_cycle_list': 'This product is not in the cycle-count list',
      'off_list_cannot_count': "Off-list items can't be counted",
      'off_list_scans_n': '{n} off-list scan(s)',
      'counted_label': 'counted',

      // Quality Control
      'quality_tasks': 'Quality Tasks',
      'quality_section_subtitle': 'Due today',
      'no_quality_tasks': 'No quality tasks 🎉',
      'view_all': 'View all',
      'status_pending': 'Pending',
      'status_submitted': 'Done',
      'proof_acknowledge': 'Confirm',
      'proof_photo': 'Photos',
      'proof_checklist': 'Checklist',
      'mark_done': 'Mark Done',
      'submit_task': 'Submit',
      'task_submitted': 'Task completed 🎉',
      'add_photo': 'Add photo',
      'take_photo': 'Take photo',
      'choose_from_gallery': 'From gallery',
      'photos_progress': '{x} / {min} photos',
      'comment_optional': 'Comment (optional)',
      'comment_required_label': 'Comment (required)',
      'complete_all_items': 'Complete all items to submit',
      'photo_required_badge': 'Photo required',
      'acknowledge_hint': 'Tap to confirm when the task is done',
      'overdue_badge': 'Overdue',

      // Gamification detail
      'points': 'points',
      'level': 'Level',
      'streak': 'Streak',
      'weeks': 'weeks',
      'accuracy': 'Accuracy',
      'this_month': 'This month',
      'weekly_goal': 'Weekly Goal',
      'leaderboard': 'Leaderboard',
      'rank_branch': 'Branch rank',
      'rank_in_branch': 'Rank in branch',
      'rank_company': 'Company rank',
      'badges_title': 'Badges',
      'branches': 'Branches',
      'employees': 'Employees',
      'you': 'You',
      'anonymous_member': 'Member',
      'position_of': 'of',
      'cycle_counts': 'Cycle counts',
      'full_counts': 'Full counts',
      'to_next_level': 'to next level',
      'your_tasks': 'Your Tasks',
      'no_tasks': 'No due tasks 🎉',
      'start_now': 'Start now',

      // Home
      'welcome': 'Welcome 👋',
      'quick_actions': 'Quick Actions',
      'stock_transfers': 'Stock Transfers',
      'start_new_count': 'New Count',
      'quick_look': 'Quick Look',
      'transfers_pending_send': 'Pending Send',
      'transfers_pending_receive': 'Pending Receive',
      'active_counting_sessions': 'Active Counts',
      
      // Transfers
      'all': 'All',
      'status_new': 'New',
      'status_shipped': 'Shipped',
      'status_received': 'Received',
      'status_partially_received': 'Partially Received',
      'status_completed': 'Completed',
      'status_cancelled': 'Cancelled',
      'no_transfers': 'No transfers found',
      'from': 'From',
      'to': 'To',
      'items': 'Items',
      'sent': 'Sent',
      // Transfers — tabs, filter & detail
      'tab_send': 'Send',
      'tab_receive': 'Receive',
      'transfers_send_empty': 'No transfers to send',
      'transfers_receive_empty': 'No transfers to receive',
      'required_qty': 'Required',
      'sent_qty': 'Sent',
      'received_qty': 'Received',
      'items_count_label': 'Items',
      'total_quantity': 'Total Qty',
      'transfer_date': 'Date',
      'scan_to_confirm_send': 'Scan to confirm send',
      'scan_to_confirm_receive': 'Scan to confirm receive',
      'confirm_send': 'Confirm Send',
      'confirm_receive': 'Confirm Receive',
      'search': 'Search',
      'search_transfers': 'Search transfers...',
      'search_counting': 'Search counting sessions...',
      'no_results': 'No results found',
      
      // Counting
      'stock_counting': 'Stock Counting',
      'new_count_btn': 'New Count',
      'counting_in_progress': 'In Progress',
      'no_sessions': 'No counting sessions',
      'click_to_start': 'Click "New Count" to start',
      'continue_counting': 'Continue Count',
      'pieces': 'Pcs',
      'choose_warehouse': 'Choose Warehouse',
      'cancel': 'Cancel',
      'retry': 'Retry',
      'error_title': 'Something went wrong',
      'error_subtitle': 'Could not load data. Please check your internet connection.',
      'barcode_scanner': 'Barcode Scanner',
      'barcode_scanner_send': 'Send Confirmation Scanner',
      'barcode_scanner_receive': 'Receive Confirmation Scanner',
      'quantity': 'Quantity',
      'update_quantity': 'Update Quantity',
      'add': 'Add',
      'product_not_in_transfer': 'Product not in this transfer',
      'skip_and_scan_next': 'Skip & Scan Next',
      'scanned_count': 'Scanned {count} of {total} items',
      'unknown_product': 'Unknown Product',
      'product_saved': '✅ {name} — Qty: {qty}',
      
      // Profile
      'phone': 'Mobile Number',
      'warehouses': 'Warehouses',
      'roles': 'Roles',
      'version': 'Version',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',
      'language': 'Language / اللغة',
      'arabic': 'العربية',
      'english': 'English',
      'system_title': 'Exhibition Management System',
    }
  };

  /// Translate a key based on current locale
  static String translate(String key) {
    final language = localeNotifier.value.languageCode;
    return _localizedValues[language]?[key] ?? key;
  }

  /// Initialize and load stored locale from SecureStorage
  static Future<void> initialize() async {
    final savedLanguage = await SecureStorage.read(_localeStorageKey);
    if (savedLanguage != null && _localizedValues.containsKey(savedLanguage)) {
      localeNotifier.value = Locale(savedLanguage);
    }
  }

  /// Change active language and persist to SecureStorage
  static Future<void> toggleLanguage() async {
    final nextLang = isArabic ? 'en' : 'ar';
    localeNotifier.value = Locale(nextLang);
    await SecureStorage.write(_localeStorageKey, nextLang);
  }
}

/// Inherited locale boundary placed **above the Navigator** (in `MaterialApp.builder`).
///
/// Reading a string with [BuildContext.tr] registers a dependency on this
/// widget, so when the language changes every screen that shows text — including
/// already-pushed routes — rebuilds and re-translates. Without it, only the
/// global `Directionality` flipped (layout mirrored) while strings stayed stale.
class LocaleScope extends InheritedWidget {
  final Locale locale;
  const LocaleScope({super.key, required this.locale, required super.child});

  static Locale of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.locale ?? AppLocalizations.localeNotifier.value;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => oldWidget.locale != locale;
}

/// Helper context extension for quick translations
extension LocalizationExtension on BuildContext {
  String tr(String key) {
    // Subscribe to locale changes so this widget rebuilds on language switch.
    LocaleScope.of(this);
    return AppLocalizations.translate(key);
  }
}
