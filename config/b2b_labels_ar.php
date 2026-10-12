<?php

/*
|--------------------------------------------------------------------------
| B2B storefront — Arabic labels for SAP-only categories
|--------------------------------------------------------------------------
|
| Most products carry a Zooboxi breadcrumb with an Arabic path beside the
| English one, and B2bCatalogController reads the Arabic label straight off it.
| Products Zooboxi never indexed fall back to the SAP user fields, which are
| English-only — this file covers those.
|
| Keys are matched case-insensitively and are the raw SAP values, typos and
| all ("Fruniture", "Bidrs Food", "Vitamines"): correcting them belongs in SAP,
| not here, and silently renaming them would hide the data-entry problem.
|
| Anything not listed falls back to the English label rather than showing an
| empty chip.
|
*/

return [

    // ── departments / categories (U_PROPRT2) ────────────────────────────────
    'Fruniture'             => 'أثاث ومفروشات',      // SAP spelling of "Furniture"
    'Furniture'             => 'أثاث ومفروشات',
    'Supplements & Treats'  => 'مكمّلات ومكافآت',
    'Grooming'              => 'العناية والتجميل',
    'Litter & Accessories'  => 'الرمل والملحقات',
    'Litters & Accessories' => 'الرمل والملحقات',
    'Entertainment'         => 'ألعاب وتسلية',
    'Training & Cleaning'   => 'التدريب والتنظيف',
    'Carriers & Cages'      => 'حقائب وأقفاص',
    'Complementary Food'    => 'غذاء مكمّل',
    'Complete Food'         => 'غذاء متكامل',
    'Collars & Harnesses'   => 'أطواق وأحزمة',
    'Wellness'              => 'الصحة والعافية',
    'Aquariums'             => 'أحواض أسماك',
    'Medical'               => 'مستلزمات طبية',
    'Device'                => 'أجهزة',
    'B2B'                   => 'جملة',
    'Other'                 => 'أخرى',

    // ── sub-categories (U_PROPRT3) ──────────────────────────────────────────
    'Wet Food'            => 'طعام رطب',
    'Dry Food'            => 'طعام جاف',
    'Bird Food'           => 'طعام طيور',
    'Birds Food'          => 'طعام طيور',
    'Bidrs Food'          => 'طعام طيور',            // SAP typo
    'bird food'           => 'طعام طيور',
    'Little Pets Food'    => 'طعام الحيوانات الصغيرة',
    'Wet Treats'          => 'مكافآت رطبة',
    'Dry Treats'          => 'مكافآت جافة',
    'Soup'                => 'شوربة',
    'Puree'               => 'هريس',
    'Milk'                => 'حليب',
    'Chewing'             => 'قطع للمضغ',

    'Beds'                => 'أسرّة',
    'Kennels'             => 'بيوت',
    'Scratchers'          => 'مخالب وخدّاشات',
    'Toys'                => 'ألعاب',
    'Cages'               => 'أقفاص',
    'Carrier'             => 'حقيبة نقل',
    'Transfer'            => 'نقل وترحيل',
    'Displays & Stands'   => 'عروض وحوامل',

    'Litter'              => 'رمل',
    'litter'              => 'رمل',
    'Litter accessories'  => 'ملحقات الرمل',
    'Litter Box-Tray'     => 'صندوق رمل',
    'Litter Box-tray'     => 'صندوق رمل',
    'Waste Bags'          => 'أكياس فضلات',
    'Training Pads'       => 'وسادات تدريب',
    'Training Sprays'     => 'بخاخات تدريب',
    'Cleaners'            => 'منظّفات',
    'Wet Wipes'           => 'مناديل مبلّلة',
    'Air freshener'       => 'معطّر جو',

    'Shampoo'             => 'شامبو',
    'Perfume'             => 'عطر',
    'Combs & Brushes'     => 'أمشاط وفرش',
    'Nail Clippers'       => 'مقصّات أظافر',
    'Gloves'              => 'قفازات',
    'Roller'              => 'أسطوانة إزالة الشعر',
    'Skin & Coat Care'    => 'عناية بالجلد والفرو',
    'Skin & Coat care'    => 'عناية بالجلد والفرو',
    'Paws Care'           => 'عناية بالمخالب',
    'Oral Care'           => 'عناية بالفم والأسنان',
    'ear care'            => 'عناية بالأذن',
    'Eye Care'            => 'عناية بالعين',
    'Bird Care'           => 'عناية بالطيور',

    'Supplements'         => 'مكمّلات غذائية',
    'Vitamines'           => 'فيتامينات',            // SAP spelling of "Vitamins"
    'Vitamins'            => 'فيتامينات',
    'Flea & Tick'         => 'مكافحة البراغيث والقراد',
    'Calming'             => 'مهدّئات',

    'Harnesses'           => 'أحزمة',
    'Leash'               => 'مقاود',
    'Leash Accessories'   => 'ملحقات المقاود',
    'Tags'                => 'أسماء ومعلّقات',

    'Feeders'             => 'مغذّيات',
    'feeders'             => 'مغذّيات',
    'Feeders Accessories' => 'ملحقات المغذّيات',
    'Food Accessories'    => 'ملحقات الطعام',
    'Aquarium'            => 'حوض أسماك',
    'Electronic'          => 'إلكترونيات',

];
