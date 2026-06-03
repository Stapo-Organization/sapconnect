
// ═══════════ CONTEXT HELPERS ═══════════

/**
 * Known root category IDs for context detection.
 */
function zooboxi_root_ids(): array {
    return [
        'health_criteria' => 102,
        'brands'          => 8643,
        'brands_en'       => 9061,
        'cat_main'        => 107,
        'dog_main'        => 114,
        'birds_main'      => 202,
        'small_main'      => 194,
        'cat_en'          => 1827,
        'dog_en'          => 1830,
        'cat_health'      => 103,
        'dog_health'      => 110,
        'birds_health'    => 199,
        'small_health'    => 189,
    ];
}

function zooboxi_is_under_health_criteria(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if ($term_id === $roots['health_criteria']) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['health_criteria'], $ancestors);
}

function zooboxi_is_under_brands(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if ($term_id === $roots['brands'] || $term_id === $roots['brands_en']) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['brands'], $ancestors) || in_array($roots['brands_en'], $ancestors);
}

function zooboxi_is_under_en_tree(int $term_id): bool {
    $roots = zooboxi_root_ids();
    if (in_array($term_id, [$roots['cat_en'], $roots['dog_en']])) return true;
    $ancestors = get_ancestors($term_id, 'product_cat', 'taxonomy');
    return in_array($roots['cat_en'], $ancestors) || in_array($roots['dog_en'], $ancestors);
}

/**
 * Structural subcategory IDs under health-criteria animal pages
 * mapped to their main-tree counterparts (for icon reuse).
 */
function zooboxi_health_structural_map(): array {
    return [
        // Health tree ID => Main tree ID
        8649 => 108,   // طعام (health-cat) -> طعام (main-cat)
        8691 => 146,   // مستلزمات القطط
        8685 => 132,   // المكافآت والفيتامينات
        8789 => 141,   // التنظيف والتدريب
        8799 => 148,   // صحة القطط
        8659 => 152,   // مستلزمات الرمل
        8829 => 235,   // رمل القطط
        9083 => 130,   // بكجات متعددة وموفّرة
        // Dog health structural
        8805 => 174,   // المكافات والفيتامينات (health-dog)
        8739 => 162,   // التنظيف والتدريب (health-dog)
        8719 => 166,   // مستلزمات الكلاب (health-dog)
    ];
}


// ═══════════ CATEGORY ICON SYSTEM ═══════════

/**
 * Icon map by term_id — definitive, no collision.
 */
function zooboxi_get_category_icon_map_by_id(): array {
    return [
        // Root main categories
        107 => 'https://gal.holeno.com/category/Cat.png',
        114 => 'https://gal.holeno.com/category/Dog.png',
        202 => 'https://gal.holeno.com/category/Birds.png',
        194 => 'https://gal.holeno.com/category/Small Animals.png',
        // Cat > main subcategories (parent=107)
        108 => 'https://gal.holeno.com/sub_category/Cat/Food/Food.png',
        132 => 'https://gal.holeno.com/sub_category/Cat/Treats %26 Vitamins/Treats_%26_Vitamins.png',
        141 => 'https://gal.holeno.com/sub_category/Cat/Cleaning %26 Training/Cleaning_%26_Training.png',
        146 => 'https://gal.holeno.com/sub_category/Cat/Supplies/Supplies.png',
        148 => 'https://gal.holeno.com/sub_category/Cat/Health/Health.png',
        152 => 'https://gal.holeno.com/sub_category/Cat/Litter Supplies/Litter_Supplies.png',
        235 => 'https://gal.holeno.com/sub_category/Cat/Litter/Litter.png',
        130 => 'https://gal.holeno.com/sub_category/Cat/Multi-Packs %26 Savers/Multi-Packs_%26_Savers.png',
        // Dog > main subcategories (parent=114)
        115 => 'https://gal.holeno.com/sub_category/Dog/Food/Food.png',
        174 => 'https://gal.holeno.com/sub_category/Dog/Treats %26 Vitamins/Treats_%26_Vitamins.png',
        162 => 'https://gal.holeno.com/sub_category/Dog/Cleaning %26 Training/Cleaning_%26_Training.png',
        166 => 'https://gal.holeno.com/sub_category/Dog/Supplies/Supplies.png',
        126 => 'https://gal.holeno.com/sub_category/Dog/Health/Health.png',
        // Health criteria root children (animal types)
        103 => 'https://gal.holeno.com/category/Cat.png',
        110 => 'https://gal.holeno.com/category/Dog.png',
        199 => 'https://gal.holeno.com/category/Birds.png',
        189 => 'https://gal.holeno.com/category/Small Animals.png',
    ];
}

/**
 * Fallback name-based map for categories with unique names only.
 */
function zooboxi_get_category_icon_map_by_name(): array {
    return [
        // Cat > Food sub-sub
        'الطعام الجاف'              => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Dry Food/Dry_Food.png',
        'الطعام الرطب'              => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Wet Food/Wet_Food.png',
        'طعام القطط البالغة'        => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Adult Cat Food/Adult_Cat_Food.png',
        'طعام القطط الصغيرة'        => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Kitten Food/Kitten_Food.png',
        'طعام القطط المسنة'         => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Senior Cat Food/Senior_Cat_Food.png',
        'الحليب والسوائل'           => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Milk %26 Liquids/Milk_%26_Liquids.png',
        'طعام للحساسية الهضمية'     => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Digestive Sensitivity Food/Digestive_Sensitivity_Food.png',
        'طعام التحكم في الوزن'      => 'https://gal.holeno.com/sub_sub_category/Cat/Food/Weight Control Food/Weight_Control_Food.png',
        // Cat > Treats sub-sub
        'الكريمي'                 => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Creamy Treats/Creamy_Treats.png',
        'البسكويت والمقرمشات'    => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Biscuit %26 Crunchy Treats/Biscuit_%26_Crunchy_Treats.png',
        'المكافآت والوجبات الخفيفة' => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Treats %26 Snacks/Treats_%26_Snacks.png',
        'الناعمة والمضغية'       => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Soft %26 Chewy Treats/Soft_%26_Chewy_Treats.png',
        'مكافآت العناية بالأسنان' => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Dental Care Treats/Dental_Care_Treats.png',
        'الفيتامينات والمكملات'  => 'https://gal.holeno.com/sub_sub_category/Cat/Treats %26 Vitamins/Vitamins %26 Supplements/Vitamins_%26_Supplements.png',
        // Cat > Cleaning sub-sub
        'الاستحمام والتنظيف الجاف' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Bathing %26 Dry Cleaning/Bathing_%26_Dry_Cleaning.png',
        'فرش وامشاط ومقصات'     => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Brushes %26 Combs %26 Scissors/Brushes_%26_Combs_%26_Scissors.png',
        'شامبو وبلسم'            => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Shampoo %26 Conditioner/Shampoo_%26_Conditioner.png',
        'العناية بالعين والاذن والاسنان' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Eye %26 Ear %26 Dental Care/Eye_%26_Ear_%26_Dental_Care.png',
        'مزيلات البقع والروائح والشعر' => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Stain %26 Odor %26 Hair Removers/Stain_%26_Odor_%26_Hair_Removers.png',
        'التدريب وتحسين السلوك'  => 'https://gal.holeno.com/sub_sub_category/Cat/Cleaning %26 Training/Training %26 Behavior Improvement/Training_%26_Behavior_Improvement.png',
        // Cat > Supplies sub-sub
        'وسادات وبيوت واقفاص'    => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Cushions %26 Houses %26 Cages/Cushions_%26_Houses_%26_Cages.png',
        'صناديق وشنط التنقل'     => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Carriers/Carriers.png',
        'ادوات الطعام'            => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Feeding Tools/Feeding_Tools.png',
        'العاب وكاتنيب'           => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Toys %26 Catnip/Toys_%26_Catnip.png',
        'اطواق'                   => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Collars/Collars.png',
        'اثاث وخداشات'            => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Furniture %26 Scratchers/Furniture_%26_Scratchers.png',
        'مشدات وصدريات'           => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Harnesses %26 Vests/Harnesses_%26_Vests.png',
        'قلادات قابلة للحفر'      => 'https://gal.holeno.com/sub_sub_category/Cat/Supplies/Engravable Tags/Engravable_Tags.png',
        // Cat > Litter sub-sub
        'صناديق الرمل'            => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Litter Boxes/Litter_Boxes.png',
        'مستلزمات صندوق الرمل'   => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Litter Box Accessories/Litter_Box_Accessories.png',
        'معطرات ومقلل الروائح الكريهة' => 'https://gal.holeno.com/sub_sub_category/Cat/Litter Supplies/Odor Reducers/Odor_Reducers.png',
        // Dog sub-sub (unique)
        'طعام الكلاب البالغة'     => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Adult Dog Food/Adult_Dog_Food.png',
        'طعام الكلاب البوبي'      => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Puppy Food/Puppy_Food.png',
        'طعام الكلاب المسنة'      => 'https://gal.holeno.com/sub_sub_category/Dog/Food/Senior Dog Food/Senior_Dog_Food.png',
        // Birds (unique)
        'طعام ومكافات الطيور'     => 'https://gal.holeno.com/sub_category/Birds/Bird Food %26 Treats/Bird_Food_%26_Treats.png',
        'مستلزمات الطيور'         => 'https://gal.holeno.com/sub_category/Birds/Bird Supplies/Bird_Supplies.png',
        'اقفاص وبيوت'             => 'https://gal.holeno.com/sub_sub_category/Birds/Bird Supplies/Cages %26 Houses/Cages_%26_Houses.png',
        'اغصان'                   => 'https://gal.holeno.com/sub_sub_category/Birds/Bird Supplies/Branches %26 Perches/Branches_%26_Perches.png',
        // Small Animals (unique)
        'مستلزمات الارانب والهماستر' => 'https://gal.holeno.com/sub_category/Small Animals/Rabbit %26 Hamster Supplies/Rabbit_%26_Hamster_Supplies.png',
        'طعام ومكافات القوارض'    => 'https://gal.holeno.com/sub_category/Small Animals/Rodent Food %26 Treats/Rodent_Food_%26_Treats.png',
    ];
}

/**
 * Get icon URL for a category — context-aware, resolves name collisions.
 */
function zooboxi_get_category_icon(object $term): string {
    $id_map = zooboxi_get_category_icon_map_by_id();
    
    // 1. Direct term_id match (highest priority)
    if (isset($id_map[$term->term_id])) {
        return $id_map[$term->term_id];
    }
    
    // 2. Health-criteria structural subcategory -> use main counterpart icon
    $structural = zooboxi_health_structural_map();
    if (isset($structural[$term->term_id])) {
        $main_id = $structural[$term->term_id];
        if (isset($id_map[$main_id])) {
            return $id_map[$main_id];
        }
    }
    
    // 3. Name-based fallback (unique names only)
    $name_map = zooboxi_get_category_icon_map_by_name();
    if (isset($name_map[$term->name])) {
        return $name_map[$term->name];
    }
    
    // 4. WooCommerce thumbnail
    $thumb_id = get_term_meta($term->term_id, 'thumbnail_id', true);
    if ($thumb_id) {
        $img_url = wp_get_attachment_url($thumb_id);
        if ($img_url) return $img_url;
    }
    
    return '';
}


// ═══════════ SUBCATEGORY NAVIGATION BAR ═══════════
add_action('woocommerce_before_shop_loop', 'zooboxi_subcategory_navigation', 5);
add_action('woocommerce_archive_description', 'zooboxi_subcategory_navigation', 20);

function zooboxi_subcat_nav_rendered($set = false) {
    static $rendered = false;
    if ($set) $rendered = true;
    return $rendered;
}

function zooboxi_subcategory_navigation() {
    if (!is_product_category()) return;
    if (zooboxi_subcat_nav_rendered()) return;
    zooboxi_subcat_nav_rendered(true);
    
    $current_cat = get_queried_object();
    if (!$current_cat || !isset($current_cat->term_id)) return;
    
    // Skip brands and EN trees
    if (zooboxi_is_under_brands($current_cat->term_id)) return;
    if (zooboxi_is_under_en_tree($current_cat->term_id)) return;
    
    // Get child categories
    $children = get_terms([
        'taxonomy'   => 'product_cat',
        'parent'     => $current_cat->term_id,
        'hide_empty' => false,
        'orderby'    => 'count',
        'order'      => 'DESC',
    ]);
    
    if (empty($children) || is_wp_error($children)) return;
    
    // ─── Custom Breadcrumb ───
    $ancestors = get_ancestors($current_cat->term_id, 'product_cat', 'taxonomy');
    $ancestors = array_reverse($ancestors);
    
    $breadcrumb_html = '<nav class="zbx-breadcrumb" aria-label="breadcrumb"><a href="' . home_url('/') . '">الرئيسية</a>';
    foreach ($ancestors as $ancestor_id) {
        $ancestor = get_term($ancestor_id, 'product_cat');
        if ($ancestor && !is_wp_error($ancestor)) {
            $breadcrumb_html .= ' <span class="zbx-bc-sep">/</span> <a href="' . esc_url(get_term_link($ancestor)) . '">' . esc_html($ancestor->name) . '</a>';
        }
    }
    $breadcrumb_html .= ' <span class="zbx-bc-sep">/</span> <span class="zbx-bc-current">' . esc_html($current_cat->name) . '</span></nav>';
    
    // ─── Category Header ───
    $cat_icon = zooboxi_get_category_icon($current_cat);
    $cat_desc = $current_cat->description ?: '';
    
    echo '<div class="zbx-cat-header">';
    echo $breadcrumb_html;
    echo '<div class="zbx-cat-title-row">';
    if ($cat_icon) {
        echo '<img src="' . esc_url($cat_icon) . '" alt="' . esc_attr($current_cat->name) . '" class="zbx-cat-header-icon" onerror="this.style.display=\'none\'" />';
    }
    echo '<div class="zbx-cat-title-text">';
    echo '<h1 class="zbx-cat-title">' . esc_html($current_cat->name) . '</h1>';
    if ($cat_desc) {
        echo '<p class="zbx-cat-desc">' . esc_html(wp_strip_all_tags($cat_desc)) . '</p>';
    }
    echo '</div></div></div>';
    
    // ─── Detect: Health criteria animal page? ───
    $roots = zooboxi_root_ids();
    $is_health_animal_page = zooboxi_is_under_health_criteria($current_cat->term_id)
                             && $current_cat->term_id !== $roots['health_criteria'];
    
    if ($is_health_animal_page) {
        // Split children: structural vs health issues
        $structural_ids = array_keys(zooboxi_health_structural_map());
        $structural_children = [];
        $health_children = [];
        
        foreach ($children as $child) {
            if (in_array($child->term_id, $structural_ids)) {
                $structural_children[] = $child;
            } else {
                $health_children[] = $child;
            }
        }
        
        // ─── Structural as icon scrollbar ───
        if (!empty($structural_children)) {
            echo '<div class="zbx-subcat-nav">';
            echo '<div class="zbx-subcat-scroll">';
            foreach ($structural_children as $child) {
                $icon_url = zooboxi_get_category_icon($child);
                $link = get_term_link($child);
                echo '<a href="' . esc_url($link) . '" class="zbx-subcat-item" title="' . esc_attr($child->name) . '">';
                echo '<div class="zbx-subcat-img-wrap">';
                if ($icon_url) {
                    echo '<img src="' . esc_url($icon_url) . '" alt="' . esc_attr($child->name) . '" loading="lazy" onerror="this.parentElement.innerHTML=\'<span class=zbx-subcat-emoji>🐾</span>\'" />';
                } else {
                    echo '<span class="zbx-subcat-emoji">🐾</span>';
                }
                echo '</div>';
                echo '<span class="zbx-subcat-name">' . esc_html($child->name) . '</span>';
                echo '</a>';
            }
            echo '</div></div>';
        }
        
        // ─── Health Issues as Tag Cloud ───
        if (!empty($health_children)) {
            echo '<div class="zbx-health-tags">';
            echo '<h3 class="zbx-health-tags-title"><span class="zbx-health-icon">🩺</span> المشاكل الصحية</h3>';
            echo '<div class="zbx-health-tags-cloud">';
            foreach ($health_children as $child) {
                $link = get_term_link($child);
                $count = $child->count;
                echo '<a href="' . esc_url($link) . '" class="zbx-health-tag" title="' . esc_attr($child->name) . ' (' . $count . ' منتج)">';
                echo esc_html($child->name);
                if ($count > 0) {
                    echo '<span class="zbx-health-tag-count">' . $count . '</span>';
                }
                echo '</a>';
            }
            echo '</div></div>';
        }
        
    } else {
        // ─── Normal subcategory icon scrollbar ───
        echo '<div class="zbx-subcat-nav">';
        echo '<div class="zbx-subcat-scroll">';
        
        foreach ($children as $child) {
            $icon_url = zooboxi_get_category_icon($child);
            $link = get_term_link($child);
            
            echo '<a href="' . esc_url($link) . '" class="zbx-subcat-item" title="' . esc_attr($child->name) . '">';
            echo '<div class="zbx-subcat-img-wrap">';
            if ($icon_url) {
                echo '<img src="' . esc_url($icon_url) . '" alt="' . esc_attr($child->name) . '" loading="lazy" onerror="this.parentElement.innerHTML=\'<span class=zbx-subcat-emoji>🐾</span>\'" />';
            } else {
                echo '<span class="zbx-subcat-emoji">🐾</span>';
            }
            echo '</div>';
            echo '<span class="zbx-subcat-name">' . esc_html($child->name) . '</span>';
            echo '</a>';
        }
        
        echo '</div></div>';
    }
}
