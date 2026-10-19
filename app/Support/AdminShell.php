<?php

namespace App\Support;

use App\Models\AdminSavedView;
use Filament\Navigation\NavigationGroup;
use Filament\Navigation\NavigationItem;
use Illuminate\Support\Facades\Auth;
use Throwable;

/**
 * The admin shell's information architecture: a rail of domains, each with a
 * panel of titled sections. Filament still owns the navigation items (their
 * URLs, permissions, badges, active state); this class only re-files them.
 *
 * Items are matched by their admin path (first segment after /admin), so
 * resource classes never change and new/unknown screens still show up: they
 * fall back to a domain picked from their original navigation group.
 */
class AdminShell
{
    /**
     * domain => [icon, [ar, en], [section [ar, en] => [path => [ar, en]]]]
     * Order here is the order on the rail and in each panel.
     */
    private const DOMAINS = [
        'home' => ['heroicon-o-home', ['الرئيسية', 'Home'], [
            'workspace' => [['مساحتي', 'My workspace'], [
                '' => ['الرئيسية', 'Home'],
                'insights' => ['المؤشرات', 'Insights'],
            ]],
        ]],
        'retail' => ['heroicon-o-presentation-chart-line', ['التجزئة والمبيعات', 'Retail & sales'], [
            'performance' => [['الأداء', 'Performance'], [
                'branches' => ['الفروع', 'Branches'],
                'retail-dashboard' => ['لوحة التجزئة', 'Retail dashboard'],
            ]],
            'customers' => [['العملاء والفواتير', 'Customers & invoices'], [
                'muntajat-customers' => ['عملاء مُنتجات', 'Muntajat customers'],
                'muntajat-invoices' => ['فواتير مُنتجات', 'Muntajat invoices'],
                'customers' => ['العملاء', 'Customers'],
                'alrajhi-transactions' => ['حركات الراجحي', 'AlRajhi transactions'],
            ]],
            'channels' => [['القنوات', 'Channels'], [
                'zid-orders' => ['طلبات زد', 'Zid orders'],
                'zid-stores' => ['متاجر زد', 'Zid stores'],
                'sms-campaigns' => ['حملات الرسائل النصية', 'SMS campaigns'],
            ]],
        ]],
        'supply' => ['heroicon-o-globe-europe-africa', ['سلسلة الإمداد', 'Supply chain'], [
            'flow' => [['الطلبات والشحن', 'Orders & freight'], [
                'purchase-orders' => ['أوامر الشراء', 'Purchase orders'],
                'shipments' => ['الشحنات', 'Shipments'],
                'container-tracking' => ['تتبّع الحاويات', 'Container tracking'],
            ]],
            'money' => [['المدفوعات والتكاليف', 'Payments & costs'], [
                'payment-alerts' => ['تنبيهات الدفع', 'Payment alerts'],
                'payment-policies' => ['سياسات الدفع', 'Payment policies'],
                'landed-costs' => ['التكاليف المضافة', 'Landed costs'],
            ]],
            'parties' => [['الأطراف', 'Parties'], [
                'suppliers' => ['الموردون', 'Suppliers'],
                'forwarders' => ['شركات الشحن', 'Forwarders'],
                'brokers' => ['المخلّصون الجمركيون', 'Customs brokers'],
            ]],
            'sfda' => [['تسجيل الغذاء والدواء', 'SFDA registration'], [
                'product-registrations' => ['تسجيلات المنتجات', 'Product registrations'],
                'registration-priorities' => ['أولويات التسجيل', 'Registration priorities'],
            ]],
        ]],
        'inventory' => ['heroicon-o-cube', ['المخزون والمستودعات', 'Inventory'], [
            'stock' => [['المخزون', 'Stock'], [
                'warehouse-item-stocks' => ['مخزون المستودعات', 'Warehouse stock'],
                'stock-gaps' => ['عجز الفروع', 'Branch gaps'],
                'stock-transfers' => ['طلبات التحويل', 'Transfer requests'],
                'suggested-stock-transfers' => ['التوزيع الذكي', 'Smart distribution'],
            ]],
            'counting' => [['الجرد والتصنيف', 'Counting & classes'], [
                'inventory-countings' => ['الجرد', 'Inventory counts'],
                'inventory-cycle-plans' => ['خطط الجرد الدوري', 'Cycle plans'],
                'product-abc-classifications' => ['تصنيف ABC', 'ABC classification'],
            ]],
            'master' => [['البيانات الرئيسية', 'Master data'], [
                'products' => ['المنتجات', 'Products'],
                'brands' => ['العلامات التجارية', 'Brands'],
                'warehouses' => ['المستودعات', 'Warehouses'],
            ]],
            'quality' => [['الجودة', 'Quality'], [
                'quality-tasks' => ['مهام الجودة', 'Quality tasks'],
                'quality-task-instances' => ['تقارير الجودة', 'Quality submissions'],
            ]],
        ]],
        'zooboxi' => ['heroicon-o-shopping-bag', ['زوبكسي', 'Zooboxi'], [
            'store' => [['المتجر', 'Store'], [
                'zooboxi-orders' => ['الطلبات', 'Orders'],
                'mrsool-deliveries' => ['توصيلات مرسول', 'Mrsool deliveries'],
                'zooboxi-products' => ['المنتجات', 'Products'],
                'zooboxi-gate' => ['بوابة الكتالوج', 'Catalog gate'],
            ]],
            'storefront' => [['الواجهة والذكاء', 'Storefront & intelligence'], [
                'brand-pages' => ['صفحات العلامات', 'Brand pages'],
                'zooboxi-intelligence' => ['ذكاء المخزون والتصريف', 'Stock intelligence'],
                'zooboxi-ranking-settings' => ['أوزان الترتيب', 'Ranking weights'],
            ]],
            'ops' => [['التشغيل', 'Operations'], [
                'zooboxi-warehouses' => ['مستودعات زوبكسي', 'Zooboxi warehouses'],
                'zooboxi-sync-logs' => ['سجل المزامنة', 'Sync log'],
            ]],
        ]],
        'shipgo' => ['heroicon-o-truck', ['ShipGo', 'ShipGo'], [
            'accounts' => [['الحسابات', 'Accounts'], [
                'ship-go-customers' => ['العملاء', 'Customers'],
                'ship-go-invoices' => ['الفواتير', 'Invoices'],
            ]],
        ]],
        'sap' => ['heroicon-o-circle-stack', ['SAP والبيانات', 'SAP & data'], [
            'imported' => [['المستورد من SAP', 'Imported from SAP'], [
                'sap-invoices' => ['الفواتير', 'Invoices'],
                'sap-credit-memos' => ['إشعارات الدائن', 'Credit memos'],
                'sap-purchase-orders' => ['أوامر الشراء', 'Purchase orders'],
            ]],
            'tools' => [['الأدوات', 'Tools'], [
                'sap-imports' => ['مستورد SAP', 'SAP importer'],
                'draft-invoice-imports' => ['مسودات الفواتير', 'Draft invoices'],
                'automations' => ['الأتمتة', 'Automations'],
            ]],
            'developers' => [['المطورون', 'Developers'], [
                'api-logs' => ['سجلات API', 'API logs'],
                'api-transformers' => ['طرق عرض API', 'API views'],
                '@docs/api' => ['وثائق API', 'API docs'],
            ]],
        ]],
        'system' => ['heroicon-o-cog-6-tooth', ['النظام', 'System'], [
            'team' => [['الفريق', 'Team'], [
                'users' => ['المستخدمون', 'Users'],
                'roles' => ['الأدوار', 'Roles'],
                'permissions' => ['الصلاحيات', 'Permissions'],
            ]],
            'comms' => [['التواصل', 'Communication'], [
                'announcements' => ['أخبار الشركة', 'Company news'],
                'send-notification' => ['إرسال إشعار', 'Send notification'],
                'email-notifications' => ['إشعارات البريد', 'Email notifications'],
                'notification-dispatch-logs' => ['سجل الإشعارات', 'Notification log'],
                'email-logs' => ['سجل البريد', 'Email log'],
            ]],
            'app' => [['التطبيق', 'App'], [
                'mobile-app-settings' => ['إعدادات تطبيق الجوال', 'Mobile app settings'],
            ]],
        ]],
    ];

    /** Original Filament group label fragment => domain, for screens not in the map. */
    private const GROUP_FALLBACK = [
        'supply' => 'supply', 'retail' => 'retail', 'muntajat' => 'retail', 'زد' => 'retail', 'zid' => 'retail',
        'sms' => 'retail', 'sap' => 'sap', 'shipgo' => 'shipgo', 'zooboxi' => 'zooboxi', 'المتجر' => 'zooboxi',
        'quality' => 'inventory', 'البيانات' => 'inventory', 'master' => 'inventory',
    ];

    public static function isArabic(): bool
    {
        return app()->getLocale() !== 'en';
    }

    /** @param array{0:string,1:string} $pair */
    public static function t(array $pair): string
    {
        return self::isArabic() ? $pair[0] : $pair[1];
    }

    /** Path key of an item URL: "/admin/shipments?x" => "shipments", "/admin" => "", "/docs/api" => "@docs/api". */
    public static function pathKey(?string $url): ?string
    {
        if (blank($url)) {
            return null;
        }
        $path = trim((string) parse_url($url, PHP_URL_PATH), '/');
        if ($path === 'admin') {
            return '';
        }
        if (str_starts_with($path, 'admin/')) {
            return explode('/', substr($path, 6))[0];
        }

        return '@' . $path;
    }

    /**
     * @param  array<NavigationGroup>  $navigation
     * @return array<int, array<string, mixed>>
     */
    public static function domains(array $navigation): array
    {
        $index = [];
        foreach (self::DOMAINS as $domain => [, , $sections]) {
            foreach ($sections as $section => [, $paths]) {
                foreach ($paths as $path => $label) {
                    $index[$path] = [$domain, $section, $label];
                }
            }
        }

        $placed = [];
        foreach ($navigation as $group) {
            foreach ($group->getItems() as $item) {
                if (! $item->isVisible()) {
                    continue;
                }
                $key = self::pathKey($item->getUrl());
                if ($key !== null && isset($index[$key])) {
                    [$domain, $section, $label] = $index[$key];
                    $placed[$domain][$section][$key] = self::itemData($item, self::t($label), $label[0] . ' ' . $label[1]);

                    continue;
                }
                $domain = self::fallbackDomain((string) $group->getLabel());
                $placed[$domain]['other'][$key ?? spl_object_id($item)] = self::itemData($item, (string) $item->getLabel());
            }
        }

        $out = [];
        $activeDomain = null;
        foreach (self::DOMAINS as $domain => [$icon, $label, $sections]) {
            $blocks = [];
            $alert = false;
            $count = 0;
            foreach ([...array_keys($sections), 'other'] as $section) {
                $items = $placed[$domain][$section] ?? [];
                if (! $items) {
                    continue;
                }
                // keep the map's order, not Filament's sort
                $order = array_flip(array_map('strval', array_keys($sections[$section][1] ?? [])));
                uksort($items, fn ($a, $b) => ($order[(string) $a] ?? 99) <=> ($order[(string) $b] ?? 99));
                foreach ($items as $item) {
                    $count++;
                    $alert = $alert || ($item['badge'] !== null && in_array($item['badgeColor'], ['danger', 'warning'], true));
                    if ($item['active']) {
                        $activeDomain = $domain;
                    }
                }
                $blocks[] = [
                    'label' => $section === 'other' ? self::t(['أخرى', 'Other']) : self::t($sections[$section][0]),
                    'items' => array_values($items),
                ];
            }
            if (! $blocks) {
                continue;
            }
            $out[] = ['key' => $domain, 'icon' => $icon, 'label' => self::t($label), 'sections' => $blocks, 'alert' => $alert, 'count' => $count];
        }

        foreach ($out as &$d) {
            $d['active'] = $d['key'] === ($activeDomain ?? ($out[0]['key'] ?? 'home'));
        }

        return $out;
    }

    /** @return array<string, mixed> */
    private static function itemData(NavigationItem $item, string $label, string $keywords = ''): array
    {
        return [
            'label' => $label,
            'keywords' => trim($keywords . ' ' . $item->getLabel()),
            'url' => $item->getUrl(),
            'icon' => $item->isActive() ? ($item->getActiveIcon() ?? $item->getIcon()) : $item->getIcon(),
            'active' => $item->isActive(),
            'badge' => $item->getBadge(),
            'badgeColor' => is_string($item->getBadgeColor()) ? $item->getBadgeColor() : null,
            'newTab' => $item->shouldOpenUrlInNewTab(),
        ];
    }

    private static function fallbackDomain(string $groupLabel): string
    {
        $g = mb_strtolower($groupLabel);
        foreach (self::GROUP_FALLBACK as $needle => $domain) {
            if ($needle !== '' && str_contains($g, $needle)) {
                return $domain;
            }
        }

        return 'system';
    }

    /**
     * Flat list of screens for the command palette.
     *
     * @param  array<NavigationGroup>  $navigation
     * @return array<int, array<string, string>>
     */
    public static function paletteScreens(array $navigation): array
    {
        $out = [];
        foreach (self::domains($navigation) as $d) {
            foreach ($d['sections'] as $section) {
                foreach ($section['items'] as $item) {
                    $out[] = [
                        'label' => $item['label'],
                        'where' => $d['key'] === 'home' ? $d['label'] : $d['label'] . ' · ' . $section['label'],
                        'keywords' => $item['keywords'] . ' ' . $d['label'] . ' ' . $section['label'],
                        'url' => (string) $item['url'],
                        'newTab' => $item['newTab'] ? '1' : '',
                    ];
                }
            }
        }

        return $out;
    }

    /** URL of a screen the current user can open, by admin path; null when hidden to them. */
    public static function screenUrl(string $path): ?string
    {
        foreach (self::paletteScreens(filament()->getNavigation()) as $screen) {
            if (self::pathKey($screen['url']) === $path) {
                return $screen['url'];
            }
        }

        return null;
    }

    /** Human label for a screen path, used on saved-view cards. */
    public static function screenLabel(?string $path): ?string
    {
        foreach (self::DOMAINS as [, , $sections]) {
            foreach ($sections as [, $paths]) {
                if ($path !== null && isset($paths[$path])) {
                    return self::t($paths[$path]);
                }
            }
        }

        return null;
    }

    /** @return array<int, AdminSavedView> the current user's pinned views */
    public static function pinnedViews(): array
    {
        $user = Auth::user();
        if (! $user) {
            return [];
        }
        try {
            return AdminSavedView::query()->where('user_id', $user->getKey())->where('is_pinned', true)
                ->orderBy('position')->orderBy('id')->limit(12)->get()->all();
        } catch (Throwable) {
            return []; // table not migrated yet
        }
    }
}
