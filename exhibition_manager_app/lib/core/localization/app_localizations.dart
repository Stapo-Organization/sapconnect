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
      'full_count': 'جرد عادي',
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
      'full_count': 'Full Count',
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

/// Helper context extension for quick translations
extension LocalizationExtension on BuildContext {
  String tr(String key) => AppLocalizations.translate(key);
}
