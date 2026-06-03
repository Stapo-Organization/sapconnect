<?php
/**
 * Zooboxi Brands Slider Shortcode
 * Generates a premium, responsive infinite scrolling brands slider with expandable grid.
 */
class Zooboxi_Brands_Slider
{
    public function __construct()
    {
        add_shortcode('zooboxi_brands_slider', [$this, 'render_slider']);
    }

    /**
     * Render the brands slider HTML & styles.
     */
    public function render_slider($atts = []): string
    {
        // Get all product brand terms (fetch all brands, including empty ones)
        $terms = get_terms([
            'taxonomy'   => 'product_brand',
            'hide_empty' => false,
        ]);

        if (empty($terms) || is_wp_error($terms)) {
            return '';
        }

        $brands = [];
        foreach ($terms as $term) {
            // Get brand logo from term meta
            $thumb_id = get_term_meta($term->term_id, 'thumbnail_id', true);
            $logo_url = '';

            if ($thumb_id) {
                $logo_url = wp_get_attachment_image_url($thumb_id, 'medium');
            }

            $brands[] = [
                'name' => $term->name,
                'slug' => $term->slug,
                'link' => get_term_link($term),
                'logo' => $logo_url,
                'count'=> (int) $term->count
            ];
        }

        if (empty($brands)) {
            return '';
        }

        // Sort all brands by product count DESC for selecting top 30
        $brands_by_count = $brands;
        usort($brands_by_count, function ($a, $b) {
            return $b['count'] <=> $a['count'];
        });

        // Top 30 brands for the sliding track
        $slider_brands = array_slice($brands_by_count, 0, 30);
        
        // Double the list for seamless infinite loop
        $slides = array_merge($slider_brands, $slider_brands);

        // Sort alphabetically for the expandable directory grid
        $grid_brands = $brands;
        usort($grid_brands, function ($a, $b) {
            return strcasecmp($a['name'], $b['name']);
        });

        // Determine localized texts
        $is_ar = (strpos(get_locale(), 'ar') === 0);
        $title = $is_ar ? '🏷️ تسوق حسب الماركة' : '🏷️ Shop by Brand';
        $btn_text = $is_ar ? '🔍 عرض جميع الماركات (' . count($brands) . ')' : '🔍 View All Brands (' . count($brands) . ')';
        $btn_hide_text = $is_ar ? '▲ إخفاء الماركات' : '▲ Hide Brands';

        ob_start();
        ?>
        <div class="zbx-brands-slider-container">
            <h2 class="zbx-brands-slider-title"><?php echo esc_html($title); ?></h2>
            
            <!-- Sliding Track wrapper (Forced LTR for robust seamless looping) -->
            <div class="zbx-brands-slider-wrap">
                <div class="zbx-brands-slider-fade-left"></div>
                <div class="zbx-brands-slider-fade-right"></div>
                <div class="zbx-brands-slider-track">
                    <?php foreach ($slides as $brand): ?>
                        <a href="<?php echo esc_url($brand['link']); ?>" class="zbx-brand-slide <?php echo empty($brand['logo']) ? 'zbx-brand-text-card' : ''; ?>" title="<?php echo esc_attr($brand['name']); ?>">
                            <div class="zbx-brand-logo-wrap">
                                <?php if (!empty($brand['logo'])): ?>
                                    <img src="<?php echo esc_url($brand['logo']); ?>" alt="<?php echo esc_attr($brand['name']); ?>" loading="lazy">
                                <?php else: ?>
                                    <div class="zbx-brand-text-placeholder">
                                        <?php 
                                        $first_letter = mb_substr($brand['name'], 0, 1, 'utf-8');
                                        echo esc_html(mb_strtoupper($first_letter, 'utf-8')); 
                                        ?>
                                    </div>
                                <?php endif; ?>
                            </div>
                            <span class="zbx-brand-name"><?php echo esc_html($brand['name']); ?></span>
                        </a>
                    <?php endforeach; ?>
                </div>
            </div>

            <!-- "Show All" Button Trigger -->
            <div class="zbx-brands-action-wrap">
                <button id="zbx-toggle-brands-btn" class="zbx-brands-toggle-btn">
                    <?php echo esc_html($btn_text); ?>
                </button>
            </div>

            <!-- Expandable Directory Grid -->
            <div id="zbx-brands-grid-wrap" class="zbx-brands-grid-wrap">
                <div class="zbx-brands-grid">
                    <?php foreach ($grid_brands as $brand): ?>
                        <a href="<?php echo esc_url($brand['link']); ?>" class="zbx-brand-slide <?php echo empty($brand['logo']) ? 'zbx-brand-text-card' : ''; ?>" title="<?php echo esc_attr($brand['name']); ?>">
                            <div class="zbx-brand-logo-wrap">
                                <?php if (!empty($brand['logo'])): ?>
                                    <img src="<?php echo esc_url($brand['logo']); ?>" alt="<?php echo esc_attr($brand['name']); ?>" loading="lazy">
                                <?php else: ?>
                                    <div class="zbx-brand-text-placeholder">
                                        <?php 
                                        $first_letter = mb_substr($brand['name'], 0, 1, 'utf-8');
                                        echo esc_html(mb_strtoupper($first_letter, 'utf-8')); 
                                        ?>
                                    </div>
                                <?php endif; ?>
                            </div>
                            <span class="zbx-brand-name"><?php echo esc_html($brand['name']); ?></span>
                        </a>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>

        <style>
        .zbx-brands-slider-container {
            width: 100%;
            max-width: 1200px;
            margin: 48px auto;
            padding: 0 20px;
            overflow: hidden;
            box-sizing: border-box;
        }

        .zbx-brands-slider-title {
            text-align: center;
            font-size: 28px;
            font-weight: 700;
            color: #2c3e2d;
            margin-bottom: 28px;
            font-family: 'El Messiri', sans-serif !important;
        }

        .zbx-brands-slider-wrap {
            position: relative;
            width: 100%;
            overflow: hidden;
            padding: 16px 0;
            background: rgba(255, 255, 255, 0.45);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border-radius: 24px;
            border: 1px solid rgba(226, 232, 224, 0.7);
            box-shadow: 0 8px 32px 0 rgba(66, 157, 156, 0.04);
            box-sizing: border-box;
            direction: ltr !important; /* Force LTR for browser-agnostic seamless loop */
        }

        /* Smooth visual mask at boundaries using pure modern CSS gradient overlay */
        .zbx-brands-slider-fade-left,
        .zbx-brands-slider-fade-right {
            position: absolute;
            top: 0;
            bottom: 0;
            width: 100px;
            z-index: 2;
            pointer-events: none;
        }
        .zbx-brands-slider-fade-left {
            left: 0;
            background: linear-gradient(to right, rgba(255, 255, 255, 1) 0%, rgba(255, 255, 255, 0) 100%);
        }
        .zbx-brands-slider-fade-right {
            right: 0;
            background: linear-gradient(to left, rgba(255, 255, 255, 1) 0%, rgba(255, 255, 255, 0) 100%);
        }

        /* Slide Track: continuous flow animation slowed down to a perfect 50s */
        .zbx-brands-slider-track {
            display: flex;
            width: max-content;
            gap: 20px;
            animation: zbx-scroll-brands 50s linear infinite;
            direction: ltr !important;
        }

        /* Hover pauses the movement */
        .zbx-brands-slider-wrap:hover .zbx-brands-slider-track {
            animation-play-state: paused;
        }

        /* Slide Card item */
        .zbx-brand-slide {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            width: 140px;
            padding: 14px;
            text-decoration: none !important;
            box-sizing: border-box;
            background: #ffffff;
            border: 1px solid #eef2ed;
            border-radius: 20px;
            transition: all 0.4s cubic-bezier(0.165, 0.84, 0.44, 1);
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.015);
        }

        /* Styling for cards that don't have images (typographical cards) */
        .zbx-brand-text-card {
            background: linear-gradient(180deg, #ffffff 0%, #fcfdfe 100%);
        }

        .zbx-brand-logo-wrap {
            width: 100%;
            height: 60px;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            margin-bottom: 8px;
            transition: transform 0.4s cubic-bezier(0.165, 0.84, 0.44, 1);
        }

        .zbx-brand-logo-wrap img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
            display: block;
            filter: grayscale(10%) contrast(95%);
            transition: all 0.4s ease;
        }

        /* Typographical Logo circle styling */
        .zbx-brand-text-placeholder {
            width: 46px;
            height: 46px;
            border-radius: 50%;
            background: linear-gradient(135deg, #429d9c 0%, #2d7a79 100%);
            color: #ffffff;
            font-size: 20px;
            font-weight: 800;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 12px rgba(66, 157, 156, 0.15);
            font-family: 'El Messiri', sans-serif !important;
            transition: transform 0.3s ease;
        }

        .zbx-brand-name {
            font-size: 13px;
            font-weight: 700;
            color: #4a5d4e;
            text-align: center;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            width: 100%;
            transition: color 0.3s;
        }

        /* Modern Premium Hover states */
        .zbx-brand-slide:hover {
            transform: translateY(-6px);
            border-color: #429d9c;
            background: #fdfefe;
            box-shadow: 0 12px 28px rgba(66, 157, 156, 0.15);
        }

        .zbx-brand-slide:hover .zbx-brand-logo-wrap {
            transform: scale(1.08);
        }

        .zbx-brand-slide:hover .zbx-brand-logo-wrap img {
            filter: grayscale(0%) contrast(100%);
        }

        .zbx-brand-slide:hover .zbx-brand-text-placeholder {
            transform: scale(1.05);
            box-shadow: 0 6px 16px rgba(66, 157, 156, 0.3);
        }

        .zbx-brand-slide:hover .zbx-brand-name {
            color: #2d7a79;
        }

        /* Show All Button Container */
        .zbx-brands-action-wrap {
            display: flex;
            justify-content: center;
            margin-top: 24px;
        }

        .zbx-brands-toggle-btn {
            background: linear-gradient(135deg, #429d9c 0%, #2d7a79 100%);
            color: #ffffff !important;
            border: none;
            padding: 12px 36px;
            font-size: 15px;
            font-weight: 700;
            border-radius: 30px;
            cursor: pointer;
            box-shadow: 0 6px 20px rgba(66, 157, 156, 0.22);
            transition: all 0.3s cubic-bezier(0.165, 0.84, 0.44, 1);
            font-family: 'El Messiri', sans-serif !important;
            outline: none;
        }

        .zbx-brands-toggle-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 28px rgba(66, 157, 156, 0.38);
            filter: brightness(105%);
        }

        .zbx-brands-toggle-btn:active {
            transform: translateY(1px);
        }

        /* Active styling when expanded */
        .zbx-brands-toggle-btn.zbx-btn-active {
            background: #ffffff;
            color: #2d7a79 !important;
            border: 2px solid #429d9c;
            box-shadow: 0 4px 14px rgba(66, 157, 156, 0.1);
        }

        /* Directory Grid Container */
        .zbx-brands-grid-wrap {
            max-height: 0;
            overflow: hidden;
            opacity: 0;
            transition: max-height 0.8s cubic-bezier(0.165, 0.84, 0.44, 1), opacity 0.5s ease;
            margin-top: 0;
            box-sizing: border-box;
        }

        .zbx-brands-grid-wrap.zbx-active {
            max-height: 2500px; /* High enough to fully expand all cards */
            opacity: 1;
            margin-top: 32px;
            padding-bottom: 24px;
            border-top: 1px dashed #e2e8e0;
            padding-top: 32px;
        }

        .zbx-brands-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
            gap: 16px;
            justify-content: center;
        }

        .zbx-brands-grid .zbx-brand-slide {
            width: 100%;
        }

        /* Seamless layout keyframes: translate by exactly -50% for 100% perfect endless loop */
        @keyframes zbx-scroll-brands {
            0% {
                transform: translate3d(0, 0, 0);
            }
            100% {
                transform: translate3d(-50%, 0, 0);
            }
        }

        /* Responsive customisations */
        @media (max-width: 768px) {
            .zbx-brands-slider-container {
                margin: 32px auto;
                padding: 0 16px;
            }
            .zbx-brands-slider-title {
                font-size: 22px;
                margin-bottom: 20px;
            }
            .zbx-brand-slide {
                width: 110px;
                padding: 10px;
                border-radius: 16px;
            }
            .zbx-brand-logo-wrap {
                height: 45px;
            }
            .zbx-brand-text-placeholder {
                width: 36px;
                height: 36px;
                font-size: 16px;
            }
            .zbx-brand-name {
                font-size: 11px;
            }
            .zbx-brands-slider-fade-left,
            .zbx-brands-slider-fade-right {
                width: 50px;
            }
            .zbx-brands-grid {
                grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
                gap: 10px;
            }
            .zbx-brands-toggle-btn {
                padding: 10px 24px;
                font-size: 13px;
            }
        }
        </style>

        <script>
        document.addEventListener('DOMContentLoaded', function() {
            var btn = document.getElementById('zbx-toggle-brands-btn');
            var gridWrap = document.getElementById('zbx-brands-grid-wrap');
            if (btn && gridWrap) {
                btn.addEventListener('click', function() {
                    gridWrap.classList.toggle('zbx-active');
                    if (gridWrap.classList.contains('zbx-active')) {
                        btn.innerHTML = '<?php echo esc_js($btn_hide_text); ?>';
                        btn.classList.add('zbx-btn-active');
                        
                        // Smoothly scroll to the newly expanded grid
                        setTimeout(function() {
                            gridWrap.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                        }, 100);
                    } else {
                        btn.innerHTML = '<?php echo esc_js($btn_text); ?>';
                        btn.classList.remove('zbx-btn-active');
                    }
                });
            }
        });
        </script>
        <?php
        return ob_get_clean();
    }
}
