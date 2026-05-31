<?php
/**
 * Build Zooboxi Homepage
 * Run with: wp eval-file setup_homepage.php
 */

// Create Homepage
$homepage_id = wp_insert_post([
    'post_title'   => 'الرئيسية',
    'post_content' => '<!-- wp:html -->
<div class="zooboxi-hero">
    <div class="zooboxi-hero__content">
        <h1 class="zooboxi-hero__title">🐾 Zooboxi</h1>
        <p class="zooboxi-hero__subtitle">كل ما يحتاجه حيوانك الأليف — توصيل سريع في أنحاء المملكة</p>
        <div class="zooboxi-hero__features">
            <span>🚀 توصيل سريع خلال ساعتين</span>
            <span>📦 شحن مجاني فوق 200 ر.س</span>
            <span>🏪 استلام من الفرع</span>
        </div>
        <a href="/shop/" class="zooboxi-hero__btn">تسوق الآن ←</a>
    </div>
</div>

<style>
.zooboxi-hero {
    background: linear-gradient(135deg, #1a1a2e 0%, #0f3d2e 50%, #1a8a5c 100%);
    border-radius: 24px;
    padding: 60px 40px;
    margin: 0 auto 40px;
    max-width: 1200px;
    text-align: center;
    position: relative;
    overflow: hidden;
}
.zooboxi-hero::before {
    content: "";
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at 30% 50%, rgba(45,184,123,0.2) 0%, transparent 60%),
                radial-gradient(circle at 70% 30%, rgba(255,140,66,0.1) 0%, transparent 50%);
}
.zooboxi-hero__content { position: relative; z-index: 1; }
.zooboxi-hero__title {
    font-size: 56px;
    font-weight: 800;
    color: #fff;
    margin: 0 0 12px;
    letter-spacing: -1px;
}
.zooboxi-hero__subtitle {
    font-size: 20px;
    color: rgba(255,255,255,0.85);
    margin: 0 0 28px;
    line-height: 1.6;
}
.zooboxi-hero__features {
    display: flex;
    justify-content: center;
    gap: 24px;
    flex-wrap: wrap;
    margin-bottom: 32px;
}
.zooboxi-hero__features span {
    background: rgba(255,255,255,0.1);
    backdrop-filter: blur(8px);
    color: #fff;
    padding: 8px 20px;
    border-radius: 30px;
    font-size: 14px;
    font-weight: 600;
    border: 1px solid rgba(255,255,255,0.15);
}
.zooboxi-hero__btn {
    display: inline-block;
    background: linear-gradient(135deg, #2DB87B, #1a8a5c);
    color: #fff !important;
    padding: 16px 48px;
    border-radius: 14px;
    font-size: 18px;
    font-weight: 700;
    text-decoration: none;
    transition: all 0.3s;
    box-shadow: 0 8px 24px rgba(45,184,123,0.3);
}
.zooboxi-hero__btn:hover {
    transform: translateY(-3px);
    box-shadow: 0 12px 32px rgba(45,184,123,0.4);
}
@media (max-width: 768px) {
    .zooboxi-hero { padding: 40px 20px; }
    .zooboxi-hero__title { font-size: 36px; }
    .zooboxi-hero__subtitle { font-size: 16px; }
    .zooboxi-hero__features { gap: 12px; }
    .zooboxi-hero__features span { font-size: 12px; padding: 6px 14px; }
}
</style>
<!-- /wp:html -->

<!-- wp:heading {"level":2,"textAlign":"center","style":{"spacing":{"margin":{"top":"40px","bottom":"24px"}}}} -->
<h2 class="wp-block-heading has-text-align-center" style="margin-top:40px;margin-bottom:24px">🏷️ تصفح حسب الماركة</h2>
<!-- /wp:heading -->

<!-- wp:woocommerce/product-categories {"hasCount":false,"columns":4,"isDropdown":false} /-->

<!-- wp:heading {"level":2,"textAlign":"center","style":{"spacing":{"margin":{"top":"48px","bottom":"24px"}}}} -->
<h2 class="wp-block-heading has-text-align-center" style="margin-top:48px;margin-bottom:24px">⭐ أحدث المنتجات</h2>
<!-- /wp:heading -->

<!-- wp:woocommerce/product-new {"columns":4,"rows":2} /-->

<!-- wp:html -->
<div class="zooboxi-features-section">
    <div class="zooboxi-feature">
        <div class="zooboxi-feature__icon">🚀</div>
        <h3>توصيل سريع</h3>
        <p>توصيل خلال ساعتين من أقرب مستودع في مدينتك</p>
    </div>
    <div class="zooboxi-feature">
        <div class="zooboxi-feature__icon">💯</div>
        <h3>منتجات أصلية</h3>
        <p>جميع منتجاتنا أصلية 100% ومستوردة مباشرة من المصنع</p>
    </div>
    <div class="zooboxi-feature">
        <div class="zooboxi-feature__icon">🔄</div>
        <h3>إرجاع سهل</h3>
        <p>سياسة إرجاع مرنة خلال 14 يوم من تاريخ الشراء</p>
    </div>
    <div class="zooboxi-feature">
        <div class="zooboxi-feature__icon">🏬</div>
        <h3>استلام من الفرع</h3>
        <p>استلم طلبك مجاناً من أقرب فرع لموقعك</p>
    </div>
</div>

<style>
.zooboxi-features-section {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 24px;
    max-width: 1200px;
    margin: 48px auto;
    padding: 0 20px;
}
.zooboxi-feature {
    background: #fff;
    border: 1px solid #e2e8e5;
    border-radius: 16px;
    padding: 32px 24px;
    text-align: center;
    transition: all 0.3s;
}
.zooboxi-feature:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 32px rgba(0,0,0,0.08);
    border-color: #2DB87B;
}
.zooboxi-feature__icon { font-size: 40px; margin-bottom: 12px; }
.zooboxi-feature h3 { font-size: 18px; font-weight: 700; margin: 0 0 8px; color: #1a2420; }
.zooboxi-feature p { font-size: 14px; color: #6b7c72; line-height: 1.6; margin: 0; }
@media (max-width: 768px) {
    .zooboxi-features-section { grid-template-columns: repeat(2, 1fr); gap: 12px; }
    .zooboxi-feature { padding: 20px 16px; }
    .zooboxi-feature__icon { font-size: 30px; }
    .zooboxi-feature h3 { font-size: 15px; }
}
</style>
<!-- /wp:html -->',
    'post_status'  => 'publish',
    'post_type'    => 'page',
    'post_name'    => 'home',
]);

// Set as static homepage
update_option('show_on_front', 'page');
update_option('page_on_front', $homepage_id);

echo "Homepage created: ID {$homepage_id}\n";
echo "Set as static front page.\n";
echo "Done!\n";
