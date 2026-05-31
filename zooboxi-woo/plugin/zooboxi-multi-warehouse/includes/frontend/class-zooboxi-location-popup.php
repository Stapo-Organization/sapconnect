<?php
/**
 * Location Popup — first-visit popup asking customer to share location.
 */
class Zooboxi_Location_Popup
{
    public function __construct()
    {
        add_action('wp_footer', [$this, 'render_popup']);
    }

    public function render_popup(): void
    {
        // Don't show if already detected
        if (isset($_COOKIE['zooboxi_lat'])) return;
        ?>
        <div id="zooboxi-location-modal" class="zooboxi-modal" style="display:none;">
            <div class="zooboxi-modal__overlay"></div>
            <div class="zooboxi-modal__content">
                <div class="zooboxi-modal__icon">🐾</div>
                <h2 class="zooboxi-modal__title"><?php esc_html_e('مرحباً في Zooboxi!', 'zooboxi'); ?></h2>
                <p class="zooboxi-modal__text"><?php esc_html_e('عشان نعرض لك المنتجات المتاحة والوقت المتوقع للتوصيل:', 'zooboxi'); ?></p>
                <button id="zooboxi-gps-btn" class="zooboxi-btn zooboxi-btn--primary">
                    📍 <?php esc_html_e('السماح بتحديد موقعك', 'zooboxi'); ?>
                </button>
                <div class="zooboxi-modal__divider"><span><?php esc_html_e('أو', 'zooboxi'); ?></span></div>
                <select id="zooboxi-city-select" class="zooboxi-select">
                    <option value=""><?php esc_html_e('اختر مدينتك يدوياً', 'zooboxi'); ?></option>
                    <?php foreach (Zooboxi_Location_Detector::get_available_cities() as $city): ?>
                        <option value="<?php echo esc_attr($city); ?>"><?php echo esc_html($city); ?></option>
                    <?php endforeach; ?>
                </select>
                <div id="zooboxi-location-status" class="zooboxi-modal__status" style="display:none;"></div>
            </div>
        </div>
        <?php
    }
}
