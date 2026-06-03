<?php

return [
    // Cumulative lifetime-point thresholds; level = count of thresholds passed.
    'levels' => [0, 250, 750, 1500, 3000, 5000, 8000, 12000],
    'level_labels' => ['مبتدئ', 'نشِط', 'متمكّن', 'خبير', 'محترف', 'بطل', 'أسطورة', 'النخبة'],

    'on_time_grace_days' => 2,
    'weekly_goal' => 1, // cycle counts per week

    'points' => [
        'base_flat' => 10,
        'base_per_item' => 1,
        'cycle_bonus' => 50,
        'on_time_bonus' => 25,
        'streak_step' => 5,
        'streak_cap' => 10,
    ],

    // Badge catalogue. Award logic lives in BadgeEvaluator; this drives display.
    'badges' => [
        'first_count'    => ['name_ar' => 'البداية', 'name_en' => 'First Count', 'icon' => 'flag', 'desc_ar' => 'أكملت أول جرد', 'desc_en' => 'Completed your first count'],
        'cycle_starter'  => ['name_ar' => 'منتظم', 'name_en' => 'Cycle Starter', 'icon' => 'autorenew', 'desc_ar' => 'أكملت 3 جرود دورية', 'desc_en' => 'Completed 3 cycle counts'],
        'cycle_champion' => ['name_ar' => 'بطل الجرد الدوري', 'name_en' => 'Cycle Champion', 'icon' => 'military_tech', 'desc_ar' => 'أكملت 10 جرود دورية', 'desc_en' => 'Completed 10 cycle counts'],
        'perfectionist'  => ['name_ar' => 'الإتقان', 'name_en' => 'Perfectionist', 'icon' => 'star', 'desc_ar' => 'جرد بدقة 100%', 'desc_en' => 'A 100% accurate count'],
        'sharp_eye'      => ['name_ar' => 'العين الحادّة', 'name_en' => 'Sharp Eye', 'icon' => 'visibility', 'desc_ar' => '5 جرود بدقة 98%+', 'desc_en' => '5 counts at 98%+ accuracy'],
        'streak_3'       => ['name_ar' => 'سلسلة 3', 'name_en' => '3-Week Streak', 'icon' => 'local_fire_department', 'desc_ar' => '3 أسابيع متتالية', 'desc_en' => '3 weeks in a row'],
        'streak_8'       => ['name_ar' => 'سلسلة 8', 'name_en' => '8-Week Streak', 'icon' => 'whatshot', 'desc_ar' => '8 أسابيع متتالية', 'desc_en' => '8 weeks in a row'],
        'centurion'      => ['name_ar' => 'المئوية', 'name_en' => 'Centurion', 'icon' => 'workspace_premium', 'desc_ar' => '1000 نقطة', 'desc_en' => 'Reached 1000 points'],
    ],
];
