<?php
/**
 * Zooboxi i18n — Force Arabic translations for key WooCommerce / Theme strings.
 *
 * Runs via gettext filter when site locale is Arabic (ar / ar_SA).
 */
class Zooboxi_I18N
{
    /**
     * Key frontend strings that should always appear in Arabic
     * when the site is running in Arabic locale.
     */
    private static array $translations = [
        // Navigation / Breadcrumb
        'Home'                              => 'الرئيسية',
        'Shop'                              => 'المتجر',
        'Cart'                              => 'سلة التسوق',
        'Checkout'                          => 'إتمام الطلب',
        'My account'                        => 'حسابي',

        // Product buttons
        'Add to cart'                       => 'أضف للسلة',
        'Select options'                    => 'اختر الخيارات',
        'Read more'                         => 'اقرأ المزيد',
        'View cart'                         => 'عرض السلة',

        // Cart / Checkout
        'Proceed to checkout'               => 'الانتقال لإتمام الطلب',
        'Update cart'                       => 'تحديث السلة',
        'Coupon code'                       => 'رمز القسيمة',
        'Apply coupon'                      => 'تطبيق القسيمة',
        'Place order'                       => 'تأكيد الطلب',
        'Your order'                        => 'طلبك',
        'Billing details'                   => 'تفاصيل الفوترة',
        'Shipping details'                  => 'تفاصيل الشحن',
        'Additional information'            => 'معلومات إضافية',
        'Order notes'                       => 'ملاحظات الطلب',

        // Account
        'Dashboard'                         => 'لوحة التحكم',
        'Orders'                            => 'الطلبات',
        'Downloads'                         => 'التحميلات',
        'Addresses'                         => 'العناوين',
        'Account details'                   => 'تفاصيل الحساب',
        'Logout'                            => 'تسجيل الخروج',

        // Misc
        'Search'                            => 'بحث',
        'Search results:'                   => 'نتائج البحث:',
        'Showing all results'               => 'عرض جميع النتائج',
        'No products found'                 => 'لا توجد منتجات',
        'Sale!'                             => 'تخفيض!',
        'Related products'                  => 'منتجات مشابهة',
        'Description'                       => 'الوصف',
        'Reviews'                           => 'التقييمات',
    ];

    public static function register(): void
    {
        add_filter('gettext', [self::class, 'translate'], 20, 3);
        add_filter('ngettext', [self::class, 'translate_plural'], 20, 5);
    }

    /**
     * Translate single strings.
     */
    public static function translate(string $translation, string $text, string $domain): string
    {
        // Only apply when Arabic is active
        if (!self::is_arabic()) {
            return $translation;
        }

        // WooCommerce core strings (and our overrides)
        if (isset(self::$translations[$text])) {
            return self::$translations[$text];
        }

        return $translation;
    }

    /**
     * Translate plural strings.
     */
    public static function translate_plural(string $translation, string $single, string $plural, int $number, string $domain): string
    {
        if (!self::is_arabic()) {
            return $translation;
        }

        // Common WooCommerce plural forms
        $pluralMap = [
            '%s item'   => '%s منتج',
            '%s items'  => '%s منتجات',
        ];

        if (isset($pluralMap[$translation])) {
            return $pluralMap[$translation];
        }

        return $translation;
    }

    /**
     * Check if current locale is Arabic.
     */
    private static function is_arabic(): bool
    {
        $locale = determine_locale();
        return str_starts_with($locale, 'ar');
    }
}

Zooboxi_I18N::register();
