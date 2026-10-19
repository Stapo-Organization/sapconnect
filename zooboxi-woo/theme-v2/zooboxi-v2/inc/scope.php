<?php
/**
 * Where the customer is, and what can reach them.
 *
 * The website browses the WHOLE reachable store — the nearest open express
 * branch, the city's central warehouse and the national hub together — and
 * every card carries its own honest promise. (The app splits the same
 * warehouses into two tabs; the website has no tabs.) Pickup-only stock is
 * left out on purpose: a product the customer cannot have delivered must not
 * look buyable and then be refused by the cart.
 */

defined('ABSPATH') || exit;

final class Zv_Scope
{
    private static ?array $memo = null;

    /** @return array{0:float,1:float} */
    public static function latlng(): array
    {
        if (class_exists('Zooboxi_Fulfillment')) {
            return Zooboxi_Fulfillment::customer_location();
        }
        $lat = isset($_COOKIE['zooboxi_lat']) ? (float) $_COOKIE['zooboxi_lat'] : 0.0;
        $lng = isset($_COOKIE['zooboxi_lng']) ? (float) $_COOKIE['zooboxi_lng'] : 0.0;
        return [$lat, $lng];
    }

    public static function has_location(): bool
    {
        [$lat, $lng] = self::latlng();
        return (bool) ($lat || $lng);
    }

    /**
     * Everything the header, cards and listings need to know, resolved once.
     *
     * @return array{
     *   located:bool, city:string, district:string, label:string,
     *   express_code:string, express_open:bool, express_zone:bool, opens_at:string,
     *   central_code:string, hub_code:string, codes:string[],
     *   tier:string, free_min:float
     * }
     */
    public static function get(): array
    {
        if (self::$memo !== null) {
            return self::$memo;
        }

        [$lat, $lng] = self::latlng();
        $s = [
            'located' => (bool) ($lat || $lng),
            'city' => '', 'district' => '', 'label' => '',
            'express_code' => '', 'express_open' => false, 'express_zone' => false, 'opens_at' => '',
            'central_code' => '', 'hub_code' => '', 'codes' => [],
            'tier' => 'shipping', 'free_min' => self::free_min_standard(),
        ];

        $s['city']     = self::city_ar(isset($_COOKIE['zooboxi_city']) ? sanitize_text_field(wp_unslash($_COOKIE['zooboxi_city'])) : '');
        $s['district'] = isset($_COOKIE['zooboxi_district']) ? sanitize_text_field(wp_unslash($_COOKIE['zooboxi_district'])) : '';
        $s['label']    = trim(implode('، ', array_filter([$s['district'], $s['city']])));

        if (!$s['located'] || !class_exists('Zooboxi_Warehouse_Manager')) {
            return self::$memo = $s;
        }

        // 1. The express branch serving this point right now (open + in zone).
        $open = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        if (!empty($open[0]['warehouse']['warehouse_code'])) {
            $s['express_code'] = (string) $open[0]['warehouse']['warehouse_code'];
            $s['express_open'] = true;
            $s['express_zone'] = true;
        } else {
            // In a zone but closed: the header can still say when it opens.
            foreach (Zooboxi_Warehouse_Manager::get_active() as $wh) {
                if (empty($wh['is_express_enabled']) || empty($wh['latitude'])) {
                    continue;
                }
                if (Zooboxi_Warehouse_Manager::is_within_express_zone($wh, $lat, $lng)) {
                    $s['express_zone'] = true;
                    $s['opens_at'] = self::next_open($wh);
                    break;
                }
            }
        }

        // 2. The city's central warehouse.
        $city = isset($_COOKIE['zooboxi_city']) ? sanitize_text_field(wp_unslash($_COOKIE['zooboxi_city'])) : '';
        if ($city === '' && class_exists('Zooboxi_Fulfillment')) {
            $city = (string) Zooboxi_Fulfillment::detect_city($lat, $lng);
        }
        if ($city !== '') {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if (!empty($central['warehouse_code'])) {
                $s['central_code'] = (string) $central['warehouse_code'];
            }
        }

        // 3. The national hub.
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if (!empty($hub['warehouse_code'])) {
            $s['hub_code'] = (string) $hub['warehouse_code'];
        }

        $s['codes'] = array_values(array_unique(array_filter([$s['express_code'], $s['central_code'], $s['hub_code']])));
        $s['tier']  = $s['express_open'] ? 'express' : ($s['central_code'] ? 'same_day' : 'shipping');
        if ($s['express_open'] && class_exists('Zooboxi_Delivery_Engine')) {
            $s['free_min'] = Zooboxi_Delivery_Engine::express_free_min();
        }

        return self::$memo = $s;
    }

    /** A REGEXP for `_zb_avail_branches`, anchored per code (RUH01 never matches RUH010). */
    public static function regexp(): string
    {
        $codes = self::get()['codes'];
        if (empty($codes)) {
            return '';
        }
        return '(^|,)(' . implode('|', array_map(static fn($c) => preg_quote($c, '/'), $codes)) . ')(,|$)';
    }

    /** A cache-key fragment naming the reachable set. */
    public static function key(): string
    {
        $codes = self::get()['codes'];
        return empty($codes) ? 'all' : implode('-', $codes);
    }

    public static function free_min_standard(): float
    {
        return (float) apply_filters('zooboxi_free_shipping_min', (float) get_option('zooboxi_free_shipping_min', 200));
    }

    /** The headline promise for the top bar, in plain words. */
    public static function promise(): array
    {
        $s = self::get();
        if (!$s['located']) {
            return ['tone' => 'ask', 'text' => zv_t('حدّد موقعك لنعرض لك أسرع توصيل وما يتوفر عندك', 'Set your location to see the fastest delivery')];
        }
        if ($s['express_open']) {
            return ['tone' => 'express', 'text' => zv_t('إكسبريس متاح الآن — يوصلك خلال ساعتين', 'Express is on — delivered within 2 hours')];
        }
        if ($s['central_code']) {
            $day = class_exists('Zooboxi_Fulfillment') ? Zooboxi_Fulfillment::standard_day_label() : zv_t('غدًا', 'tomorrow');
            $text = sprintf(zv_t('يوصلك %s', 'Arrives %s'), $day);
            if ($s['express_zone'] && $s['opens_at'] !== '') {
                $text .= ' · ' . sprintf(zv_t('وإكسبريس يفتح %s', 'Express opens %s'), $s['opens_at']);
            }
            return ['tone' => 'standard', 'text' => $text];
        }
        return ['tone' => 'shipping', 'text' => zv_t('نشحن لك لكل مدن المملكة', 'We ship across Saudi Arabia')];
    }

    /** «9:00 ص» today if still ahead, else tomorrow's opening, read from the branch schedule. */
    private static function next_open(array $wh): string
    {
        $raw = $wh['express_working_hours'] ?? null;
        $hours = is_string($raw) ? json_decode($raw, true) : $raw;
        if (!is_array($hours) || empty($hours)) {
            return '';
        }
        try {
            $now = new DateTime('now', new DateTimeZone('Asia/Riyadh'));
        } catch (Exception $e) {
            return '';
        }
        for ($i = 0; $i < 7; $i++) {
            $day = (clone $now)->modify("+{$i} day");
            $h = $hours[strtolower($day->format('l'))] ?? null;
            if (!$h || !empty($h['closed']) || empty($h['open'])) {
                continue;
            }
            if ($i === 0 && $now->format('H:i') >= $h['open']) {
                continue;
            }
            [$hh, $mm] = array_map('intval', explode(':', (string) $h['open']) + [0, 0]);
            $time = sprintf('%d:%02d %s', ($hh % 12) ?: 12, $mm, $hh < 12 ? zv_t('ص', 'am') : zv_t('م', 'pm'));
            return $i === 0 ? $time : ($i === 1 ? sprintf(zv_t('غدًا %s', 'tomorrow %s'), $time) : date_i18n('l', $day->getTimestamp()) . ' ' . $time);
        }
        return '';
    }

    /** Google stores English city names in the cookie; show them in Arabic. */
    public static function city_ar(string $city): string
    {
        if ($city === '' || zv_lang() === 'en') {
            return $city;
        }
        static $map = [
            'riyadh' => 'الرياض', 'jeddah' => 'جدة', 'jiddah' => 'جدة', 'makkah' => 'مكة المكرمة', 'mecca' => 'مكة المكرمة',
            'medina' => 'المدينة المنورة', 'madinah' => 'المدينة المنورة', 'al madinah' => 'المدينة المنورة',
            'dammam' => 'الدمام', 'ad dammam' => 'الدمام', 'khobar' => 'الخبر', 'al khobar' => 'الخبر', 'dhahran' => 'الظهران',
            'jubail' => 'الجبيل', 'al jubail' => 'الجبيل', 'qatif' => 'القطيف', 'hofuf' => 'الهفوف', 'al hofuf' => 'الهفوف',
            'al ahsa' => 'الأحساء', 'hafar al batin' => 'حفر الباطن', 'taif' => 'الطائف', 'at taif' => 'الطائف', 'tabuk' => 'تبوك',
            'buraydah' => 'بريدة', 'buraidah' => 'بريدة', 'unaizah' => 'عنيزة', 'unayzah' => 'عنيزة', 'hail' => 'حائل', "ha'il" => 'حائل',
            'abha' => 'أبها', 'khamis mushait' => 'خميس مشيط', 'khamis mushayt' => 'خميس مشيط', 'najran' => 'نجران',
            'jazan' => 'جازان', 'jizan' => 'جازان', 'yanbu' => 'ينبع', 'al kharj' => 'الخرج', 'al qassim' => 'القصيم',
            'sakaka' => 'سكاكا', 'arar' => 'عرعر', 'al baha' => 'الباحة', 'al bahah' => 'الباحة',
            'riyadh principality' => 'الرياض', 'riyadh province' => 'الرياض', 'riyadh region' => 'الرياض',
            'makkah province' => 'مكة المكرمة', 'makkah region' => 'مكة المكرمة', 'eastern province' => 'المنطقة الشرقية',
        ];
        $k = strtolower(trim($city));
        if (isset($map[$k])) {
            return $map[$k];
        }
        if (function_exists('zooboxi_city_ar')) {
            return zooboxi_city_ar($city);
        }
        return $city;
    }
}
