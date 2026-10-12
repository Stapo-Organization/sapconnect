<?php

/*
|--------------------------------------------------------------------------
| B2B storefront — showroom presentation data
|--------------------------------------------------------------------------
|
| SAP knows a warehouse's code and English name and nothing else: no street
| address, no coordinates, no phone. This file supplies the presentation half,
| keyed by SAP warehouse code.
|
| Resolution order in B2bCatalogController::showrooms():
|   1. `zooboxi_warehouses` row (matched on warehouse_code or sap_warehouse_codes)
|      — the operational source of truth, kept by the team in the admin panel
|   2. this file
|   3. name + city only
|
| The entries below were carried over from the published storefront, matched to
| SAP branches by city. The five Riyadh branches have no verified address or
| coordinates — SAP has none and the published site listed two Riyadh districts
| (Suwaidi, Aziziyah) that match none of the five SAP branch names. They are
| left null on purpose: a wrong pin on a map is worse than no map. Fill them in
| `zooboxi_warehouses` (or here) and they light up with no code change.
|
*/

return [

    /*
     | Company-wide contact details. Neither SAP nor zooboxi_warehouses holds a
     | per-branch phone or opening hours — every branch published the same ones.
     | A branch that gets its own values in zooboxi_warehouses overrides these.
     */
    '_contact' => [
        'phone' => '966554698555',
        'hours' => [
            'weekday'    => ['label' => 'Sat–Thu · 8AM–11PM', 'label_ar' => 'السبت–الخميس · ٨ص–١١م',
                             'days' => ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'],
                             'opens' => '08:00', 'closes' => '23:00'],
            'friday'     => ['label' => 'Fri · 2PM–11PM', 'label_ar' => 'الجمعة · ٢م–١١م',
                             'days' => ['Friday'], 'opens' => '14:00', 'closes' => '23:00'],
        ],
    ],

    'JED002' => [
        'name_ar' => 'معرض جدة',
        'city'    => 'Jeddah',
        'city_ar' => 'جدة',
        'region'  => 'Makkah Province',
        'addr'    => 'Jeddah',
        'addr_ar' => 'جدة',
        'map'     => 'https://maps.app.goo.gl/hwnBS33abxJubJyq7',
        'lat'     => 21.582764,
        'lng'     => 39.231219,
    ],

    'DMM001' => [
        'name_ar' => 'معرض الدمام',
        'city'    => 'Dammam',
        'city_ar' => 'الدمام',
        'region'  => 'Eastern Province',
        'addr'    => 'Dammam',
        'addr_ar' => 'الدمام',
        'map'     => 'https://maps.app.goo.gl/xznNrSWzxnULPL1U9',
        'lat'     => 26.422065,
        'lng'     => 50.120995,
    ],

    'MED001' => [
        'name_ar' => 'معرض المدينة المنورة',
        'city'    => 'Madinah',
        'city_ar' => 'المدينة المنورة',
        'region'  => 'Al Madinah Province',
        'addr'    => 'Madinah',
        'addr_ar' => 'المدينة المنورة',
        'map'     => 'https://maps.app.goo.gl/Q9ie2ioGqvqfuWYM6',
        'lat'     => 24.397326,
        'lng'     => 39.639505,
    ],

    'ABH001' => [
        'name_ar' => 'معرض أبها',
        'city'    => 'Abha',
        'city_ar' => 'أبها',
        'region'  => 'Asir Province',
        'addr'    => 'Abha',
        'addr_ar' => 'أبها',
        'map'     => 'https://maps.app.goo.gl/6HGmgzV7dvdrihHZA',
        'lat'     => 18.223703,
        'lng'     => 42.521682,
    ],

    'UZH001' => [
        'name_ar' => 'معرض عنيزة',
        'city'    => 'Unaizah',
        'city_ar' => 'عنيزة',
        'region'  => 'Al-Qassim Province',
        'addr'    => 'Unaizah',
        'addr_ar' => 'عنيزة',
        'map'     => 'https://maps.app.goo.gl/aUm78xgo8R1UqPP46',
        'lat'     => 26.091966,
        'lng'     => 43.991397,
    ],

    'KHO001' => [
        'name_ar' => 'معرض الخبر',
        'city'    => 'Khobar',
        'city_ar' => 'الخبر',
        'region'  => 'Eastern Province',
        'addr'    => 'Al Khobar',
        'addr_ar' => 'الخبر',
        'map'     => 'https://maps.app.goo.gl/LMVjh2Cav7WAsHeHA',
        'lat'     => 26.305072,
        'lng'     => 50.195684,
    ],

    'BRD001' => [
        'name_ar' => 'معرض بريدة',
        'city'    => 'Buraydah',
        'city_ar' => 'بريدة',
        'region'  => 'Al-Qassim Province',
        'addr'    => 'Buraydah',
        'addr_ar' => 'بريدة',
        'map'     => 'https://maps.app.goo.gl/UEP61z6hysNXft437',
        'lat'     => 26.406348,
        'lng'     => 43.929029,
    ],

    'HBT001' => [
        'name_ar' => 'معرض حفر الباطن',
        'city'    => 'Hafar Al Batin',
        'city_ar' => 'حفر الباطن',
        'region'  => 'Eastern Province',
        'addr'    => 'Hafar Al Batin',
        'addr_ar' => 'حفر الباطن',
        'map'     => 'https://maps.app.goo.gl/sK83rjUuC4aqCNdE6',
        'lat'     => 28.424686,
        'lng'     => 45.972684,
    ],

    // ── Riyadh — names verified from SAP, location data still needed ──────────
    'RUH002' => ['name_ar' => 'معرض النصر',       'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH004' => ['name_ar' => 'معرض الربيع',      'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH005' => ['name_ar' => 'معرض قرطبة',       'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH006' => ['name_ar' => 'معرض السليمانية',  'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH007' => ['name_ar' => 'معرض الروابي',     'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH008' => ['name_ar' => 'معرض السويدي',     'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH009' => ['name_ar' => 'معرض سوق الحمام',  'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],
    'RUH010' => ['name_ar' => 'معرض الملك فهد',   'city' => 'Riyadh', 'city_ar' => 'الرياض', 'region' => 'Riyadh Province'],

];
