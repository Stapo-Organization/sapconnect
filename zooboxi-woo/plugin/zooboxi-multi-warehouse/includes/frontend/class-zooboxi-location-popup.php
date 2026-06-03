<?php
/**
 * Location Popup — auto-detect GPS then allow map adjustment.
 */
class Zooboxi_Location_Popup
{
    public function __construct()
    {
        add_action('wp_footer', [$this, 'render_popup']);
    }

    public function render_popup(): void
    {
        $has_location = isset($_COOKIE['zooboxi_lat']) || isset($_COOKIE['zooboxi_city']);
        $maps_api_key = get_option('zooboxi_google_maps_api_key', '');
        $saved_lat = isset($_COOKIE['zooboxi_lat']) ? (float) $_COOKIE['zooboxi_lat'] : 0;
        $saved_lng = isset($_COOKIE['zooboxi_lng']) ? (float) $_COOKIE['zooboxi_lng'] : 0;
        $saved_city = isset($_COOKIE['zooboxi_city']) ? sanitize_text_field($_COOKIE['zooboxi_city']) : '';
        $saved_district = isset($_COOKIE['zooboxi_district']) ? sanitize_text_field($_COOKIE['zooboxi_district']) : '';
        ?>
        <div id="zooboxi-location-modal" class="zooboxi-modal" style="display: <?php echo $has_location ? 'none' : 'flex'; ?>;">
            <div class="zooboxi-modal__overlay"></div>
            <div class="zooboxi-modal__content">
                <button id="zbx-loc-close" class="zbx-loc-close-btn" type="button" aria-label="إغلاق">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                </button>
                
                <div class="zbx-loc-icon">📍</div>
                <h2 class="zbx-loc-title"><?php esc_html_e('حدد موقعك', 'zooboxi'); ?></h2>
                <p class="zbx-loc-subtitle"><?php esc_html_e('حرّك الخريطة لتحديد موقعك بدقة', 'zooboxi'); ?></p>
                
                <!-- Map -->
                <div class="zbx-loc-map-wrap">
                    <div id="zooboxi-map" class="zbx-loc-map"></div>
                    <div class="zbx-loc-pin">📍</div>
                    <!-- Detecting overlay -->
                    <div id="zbx-loc-detecting" class="zbx-loc-detecting">
                        <div class="zbx-loc-spinner"></div>
                        <span><?php esc_html_e('جاري تحديد موقعك...', 'zooboxi'); ?></span>
                    </div>
                </div>
                
                <!-- Address display -->
                <div id="zbx-loc-address" class="zbx-loc-address"></div>
                
                <!-- Status -->
                <div id="zooboxi-location-status" class="zooboxi-modal__status" style="display:none;"></div>

                <!-- Confirm -->
                <button id="zooboxi-confirm-location" class="zbx-loc-confirm-btn" type="button">
                    ✅ <?php esc_html_e('تأكيد الموقع', 'zooboxi'); ?>
                </button>
            </div>
        </div>

        <!-- Location Drift Confirmation Popup -->
        <div id="zbx-drift-modal" class="zooboxi-modal" style="display:none;">
            <div class="zooboxi-modal__overlay zbx-drift-overlay"></div>
            <div class="zooboxi-modal__content zbx-drift-content">
                <button id="zbx-drift-close" class="zbx-loc-close-btn" type="button" aria-label="إغلاق">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                </button>
                <div class="zbx-drift-icon">📍</div>
                <h2 class="zbx-drift-title"><?php esc_html_e('يبدو أنك في موقع مختلف', 'zooboxi'); ?></h2>
                <p class="zbx-drift-subtitle">
                    <?php esc_html_e('اكتشفنا أن موقعك الحالي يختلف عن العنوان المحفوظ. هل تريد تحديث موقع التوصيل؟', 'zooboxi'); ?>
                </p>
                <div class="zbx-drift-locations">
                    <div class="zbx-drift-loc-card zbx-drift-saved">
                        <span class="zbx-drift-loc-label"><?php esc_html_e('الموقع المحفوظ', 'zooboxi'); ?></span>
                        <span class="zbx-drift-loc-city" id="zbx-drift-saved-city"><?php echo esc_html($saved_district ?: $saved_city ?: '—'); ?></span>
                    </div>
                    <div class="zbx-drift-arrow">→</div>
                    <div class="zbx-drift-loc-card zbx-drift-new">
                        <span class="zbx-drift-loc-label"><?php esc_html_e('موقعك الحالي', 'zooboxi'); ?></span>
                        <span class="zbx-drift-loc-city" id="zbx-drift-new-city"><?php esc_html_e('جاري التحديد...', 'zooboxi'); ?></span>
                    </div>
                </div>
                <div class="zbx-drift-actions">
                    <button id="zbx-drift-update" class="zbx-drift-btn zbx-drift-btn-primary" type="button">
                        🔄 <?php esc_html_e('تحديث الموقع', 'zooboxi'); ?>
                    </button>
                    <button id="zbx-drift-keep" class="zbx-drift-btn zbx-drift-btn-secondary" type="button">
                        <?php esc_html_e('الإبقاء على الموقع الحالي', 'zooboxi'); ?>
                    </button>
                </div>
            </div>
        </div>
        
        <style>
        .zooboxi-modal {
            position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: 99999;
            display: flex; align-items: center; justify-content: center;
        }
        .zooboxi-modal__overlay {
            position: absolute; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.5); backdrop-filter: blur(6px);
        }
        .zooboxi-modal__content {
            background: #fff; border-radius: 24px; padding: 28px 24px 24px; width: 92%; max-width: 400px;
            position: relative; z-index: 2; text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.25);
            max-height: 90vh; overflow-y: auto;
            animation: zbx-modal-pop 0.35s cubic-bezier(0.16,1,0.3,1);
        }
        @keyframes zbx-modal-pop {
            0% { opacity:0; transform: scale(0.92) translateY(20px); }
            100% { opacity:1; transform: scale(1) translateY(0); }
        }

        /* Close Button */
        .zbx-loc-close-btn {
            position: absolute; top: 14px; right: 14px;
            width: 36px; height: 36px; border-radius: 50%;
            background: #f0f0f0 !important; border: none !important;
            display: flex; align-items: center; justify-content: center;
            cursor: pointer; color: #666; transition: all 0.2s;
            z-index: 10;
        }
        .zbx-loc-close-btn:hover { background: #e0e0e0 !important; color: #333; }

        .zbx-loc-icon { font-size: 32px; margin-bottom: 4px; }
        .zbx-loc-title { font-size: 22px; font-weight: 700; color: #2c3e2d; margin: 0 0 4px; font-family: 'El Messiri', sans-serif; }
        .zbx-loc-subtitle { font-size: 13px; color: #888; margin-bottom: 16px; }

        /* Map */
        .zbx-loc-map-wrap {
            position: relative; width: 100%; height: 240px;
            border-radius: 16px; overflow: hidden; margin-bottom: 12px;
            border: 2px solid #e8ece8;
        }
        .zbx-loc-map { width: 100%; height: 100%; }
        .zbx-loc-pin {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -100%);
            font-size: 36px; pointer-events: none; z-index: 5;
            filter: drop-shadow(0 3px 6px rgba(0,0,0,0.3));
            transition: transform 0.15s;
        }
        .zbx-loc-pin.bounce { animation: zbx-pin-bounce 0.4s ease; }
        @keyframes zbx-pin-bounce {
            0%,100% { transform: translate(-50%, -100%); }
            50% { transform: translate(-50%, -120%); }
        }

        /* Detecting overlay */
        .zbx-loc-detecting {
            position: absolute; top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(255,255,255,0.92); backdrop-filter: blur(4px);
            display: flex; flex-direction: column; align-items: center; justify-content: center;
            gap: 12px; z-index: 10; font-size: 14px; font-weight: 600; color: #429d9c;
        }
        .zbx-loc-detecting.hidden { display: none; }
        .zbx-loc-spinner {
            width: 32px; height: 32px; border: 3px solid #e0e0e0;
            border-top-color: #429d9c; border-radius: 50%;
            animation: zbx-spin 0.7s linear infinite;
        }
        @keyframes zbx-spin { to { transform: rotate(360deg); } }

        /* Address */
        .zbx-loc-address {
            background: #f7f9f7; border-radius: 12px; padding: 10px 14px;
            font-size: 13px; font-weight: 600; color: #333;
            margin-bottom: 12px; min-height: 20px;
            display: none;
        }

        /* Confirm */
        .zbx-loc-confirm-btn {
            width: 100%; padding: 14px; border: none; border-radius: 14px;
            background: #27ae60; color: #fff; font-size: 16px; font-weight: 700;
            cursor: pointer; font-family: inherit; transition: all 0.3s;
        }
        .zbx-loc-confirm-btn:hover { background: #219a52; transform: translateY(-1px); }

        /* Status */
        .zooboxi-modal__status {
            margin-bottom: 10px; padding: 10px; border-radius: 10px; font-size: 13px; font-weight: 600;
        }
        .zooboxi-modal__status.success { background: #e7f2e4; color: #429d9c; }
        .zooboxi-modal__status.error { background: #fdf2f2; color: #e74c3c; }
        .zooboxi-modal__status.loading { background: #fcf6e3; color: #d48644; }

        /* ═══ Drift Confirmation Popup ═══ */
        .zbx-drift-content {
            max-width: 420px;
            padding: 32px 28px 28px;
        }
        .zbx-drift-icon {
            font-size: 40px;
            margin-bottom: 8px;
            animation: zbx-drift-pulse 2s ease-in-out infinite;
        }
        @keyframes zbx-drift-pulse {
            0%,100% { transform: scale(1); }
            50% { transform: scale(1.15); }
        }
        .zbx-drift-title {
            font-size: 20px; font-weight: 700; color: #2c3e2d;
            margin: 0 0 6px; font-family: 'El Messiri', sans-serif;
        }
        .zbx-drift-subtitle {
            font-size: 13px; color: #777; line-height: 1.7;
            margin-bottom: 20px;
        }
        .zbx-drift-locations {
            display: flex; align-items: center; gap: 10px;
            margin-bottom: 20px;
        }
        .zbx-drift-loc-card {
            flex: 1; padding: 12px 10px;
            border-radius: 14px; text-align: center;
        }
        .zbx-drift-saved {
            background: #f5f0f0;
            border: 1.5px solid #e8dede;
        }
        .zbx-drift-new {
            background: #eef7f0;
            border: 1.5px solid #c8e6cc;
        }
        .zbx-drift-loc-label {
            display: block; font-size: 10px; font-weight: 600;
            text-transform: uppercase; letter-spacing: 0.5px;
            color: #999; margin-bottom: 4px;
        }
        .zbx-drift-loc-city {
            display: block; font-size: 15px; font-weight: 700;
            color: #333;
        }
        .zbx-drift-arrow {
            font-size: 20px; color: #aaa;
            flex-shrink: 0;
        }
        [dir=rtl] .zbx-drift-arrow { transform: scaleX(-1); }
        .zbx-drift-actions {
            display: flex; flex-direction: column; gap: 10px;
        }
        .zbx-drift-btn {
            width: 100%; padding: 13px; border: none; border-radius: 14px;
            font-size: 15px; font-weight: 700; cursor: pointer;
            font-family: inherit; transition: all 0.3s;
        }
        .zbx-drift-btn-primary {
            background: linear-gradient(135deg, #27ae60, #2ecc71);
            color: #fff;
            box-shadow: 0 4px 14px rgba(39,174,96,0.3);
        }
        .zbx-drift-btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(39,174,96,0.4);
        }
        .zbx-drift-btn-secondary {
            background: #f0f0f0; color: #555;
        }
        .zbx-drift-btn-secondary:hover {
            background: #e0e0e0;
        }
        </style>

        <?php if (!empty($maps_api_key)): ?>
        <script>
        (function(){
            var zbxMap, zbxSelectedLat = null, zbxSelectedLng = null;
            var geocodeTimer = null;
            var mapReady = false;

            // Called by Google Maps callback
            window.zbxInitMap = function() {
                var mapEl = document.getElementById('zooboxi-map');
                if (!mapEl) return;
                
                zbxMap = new google.maps.Map(mapEl, {
                    center: {lat: 24.7136, lng: 46.6753},
                    zoom: 13,
                    disableDefaultUI: true,
                    zoomControl: true,
                    gestureHandling: 'greedy',
                    styles: [
                        {featureType: "poi", stylers: [{visibility: "off"}]},
                        {featureType: "transit", stylers: [{visibility: "off"}]}
                    ]
                });
                mapReady = true;

                // When map stops moving → update address
                zbxMap.addListener('idle', function() {
                    var center = zbxMap.getCenter();
                    zbxSelectedLat = center.lat();
                    zbxSelectedLng = center.lng();

                    // Bounce pin
                    var pin = document.querySelector('.zbx-loc-pin');
                    if (pin) { pin.classList.remove('bounce'); void pin.offsetWidth; pin.classList.add('bounce'); }

                    // Debounced reverse geocode
                    clearTimeout(geocodeTimer);
                    geocodeTimer = setTimeout(function(){
                        var geocoder = new google.maps.Geocoder();
                        geocoder.geocode({location: {lat: zbxSelectedLat, lng: zbxSelectedLng}}, function(results, status) {
                            var addrEl = document.getElementById('zbx-loc-address');
                            if (status === 'OK' && results[0]) {
                                addrEl.textContent = '📍 ' + results[0].formatted_address;
                                addrEl.style.display = 'block';
                            }
                        });
                    }, 400);
                });

                // Auto-detect GPS immediately
                autoDetectGPS();
            };

            function autoDetectGPS() {
                var detectingEl = document.getElementById('zbx-loc-detecting');
                
                if (!navigator.geolocation) {
                    if (detectingEl) detectingEl.classList.add('hidden');
                    return;
                }

                navigator.geolocation.getCurrentPosition(
                    function(pos) {
                        // Success — center map on user's location
                        if (zbxMap) {
                            zbxMap.setCenter({lat: pos.coords.latitude, lng: pos.coords.longitude});
                            zbxMap.setZoom(16);
                        }
                        if (detectingEl) detectingEl.classList.add('hidden');
                    },
                    function() {
                        // GPS denied/failed — just hide overlay, show default Riyadh
                        if (detectingEl) detectingEl.classList.add('hidden');
                    },
                    { enableHighAccuracy: true, timeout: 8000 }
                );
            }

            // Close button
            document.addEventListener('click', function(e) {
                var closeBtn = e.target.closest('#zbx-loc-close');
                var overlay = e.target.closest('.zooboxi-modal__overlay');
                if (closeBtn || overlay) {
                    document.getElementById('zooboxi-location-modal').style.display = 'none';
                }
            });

            // Confirm button
            document.addEventListener('click', function(e) {
                if (e.target.closest('#zooboxi-confirm-location')) {
                    if (!zbxSelectedLat || !zbxSelectedLng) return;
                    if (typeof jQuery === 'undefined' || typeof zooboxiData === 'undefined') return;

                    var $ = jQuery;
                    var statusEl = $('#zooboxi-location-status');
                    var btn = $('#zooboxi-confirm-location');
                    btn.text('جاري التأكيد...').prop('disabled', true);
                    statusEl.removeClass('success error loading').addClass('loading').text('جاري تحديد منطقة التوصيل...').show();
                    
                    $.post(zooboxiData.ajaxUrl, {
                        action: 'zooboxi_detect_warehouse',
                        nonce: zooboxiData.nonce,
                        lat: zbxSelectedLat,
                        lng: zbxSelectedLng,
                    }).done(function(res) {
                        if (res.success) {
                            statusEl.removeClass('loading').addClass('success').text('✅ تم تحديد موقعك بنجاح!');
                            btn.text('✅ تم!').css('background','#27ae60');
                            setTimeout(function() {
                                $('#zooboxi-location-modal').fadeOut(300, function() { location.reload(); });
                            }, 1000);
                        } else {
                            statusEl.removeClass('loading').addClass('error').text(res.data?.message || 'حدث خطأ في تحديد الموقع');
                            btn.text('✅ تأكيد الموقع').prop('disabled', false);
                        }
                    }).fail(function() {
                        statusEl.removeClass('loading').addClass('error').text('حدث خطأ في الاتصال');
                        btn.text('✅ تأكيد الموقع').prop('disabled', false);
                    });
                }
            });

            /* ═══ Location Drift Detection ═══ */
            (function zbxDriftCheck() {
                var savedLat = <?php echo json_encode($saved_lat); ?>;
                var savedLng = <?php echo json_encode($saved_lng); ?>;
                var savedCity = <?php echo json_encode($saved_city); ?>;
                var DRIFT_KM = 1; // Threshold in kilometers (neighborhood-level)
                var DRIFT_COOLDOWN_KEY = 'zbx_drift_dismissed';
                var DRIFT_COOLDOWN_HOURS = 6;

                // Only run if user already has a saved location
                if (!savedLat || !savedLng) return;

                // Check cooldown — don't bother user repeatedly
                var lastDismissed = localStorage.getItem(DRIFT_COOLDOWN_KEY);
                if (lastDismissed) {
                    var elapsed = (Date.now() - parseInt(lastDismissed, 10)) / (1000 * 60 * 60);
                    if (elapsed < DRIFT_COOLDOWN_HOURS) return;
                }

                // Silent GPS check in background
                if (!navigator.geolocation) return;

                navigator.geolocation.getCurrentPosition(
                    function(pos) {
                        var curLat = pos.coords.latitude;
                        var curLng = pos.coords.longitude;
                        var dist = zbxHaversine(savedLat, savedLng, curLat, curLng);

                        if (dist < DRIFT_KM) return; // Still close — no popup

                        // Reverse geocode current position to show neighborhood
                        zbxReverseGeocode(curLat, curLng, function(result) {
                            var driftModal = document.getElementById('zbx-drift-modal');
                            var newCityEl = document.getElementById('zbx-drift-new-city');
                            if (!driftModal) return;

                            var label = result.district || result.city || (Math.round(dist) + ' كم بعيد');
                            if (newCityEl) newCityEl.textContent = label;
                            driftModal.style.display = 'flex';

                            // "Update" — open the full location modal
                            document.getElementById('zbx-drift-update').addEventListener('click', function() {
                                driftModal.style.display = 'none';
                                // Clear saved cookies so the main modal takes over
                                document.cookie = 'zooboxi_lat=; expires=Thu, 01 Jan 1970; path=/';
                                document.cookie = 'zooboxi_lng=; expires=Thu, 01 Jan 1970; path=/';
                                document.cookie = 'zooboxi_city=; expires=Thu, 01 Jan 1970; path=/';
                                document.cookie = 'zooboxi_district=; expires=Thu, 01 Jan 1970; path=/';
                                document.getElementById('zooboxi-location-modal').style.display = 'flex';
                                // Recenter map if available
                                if (typeof zbxMap !== 'undefined' && zbxMap) {
                                    zbxMap.setCenter({lat: curLat, lng: curLng});
                                    zbxMap.setZoom(16);
                                }
                            });

                            // "Keep" — dismiss and set cooldown
                            document.getElementById('zbx-drift-keep').addEventListener('click', function() {
                                driftModal.style.display = 'none';
                                localStorage.setItem(DRIFT_COOLDOWN_KEY, Date.now().toString());
                            });

                            // Close button / overlay
                            document.getElementById('zbx-drift-close').addEventListener('click', function() {
                                driftModal.style.display = 'none';
                                localStorage.setItem(DRIFT_COOLDOWN_KEY, Date.now().toString());
                            });
                            driftModal.querySelector('.zbx-drift-overlay').addEventListener('click', function() {
                                driftModal.style.display = 'none';
                                localStorage.setItem(DRIFT_COOLDOWN_KEY, Date.now().toString());
                            });
                        });
                    },
                    function() { /* GPS denied — do nothing */ },
                    { enableHighAccuracy: false, timeout: 8000, maximumAge: 300000 }
                );

                function zbxHaversine(lat1, lon1, lat2, lon2) {
                    var R = 6371;
                    var dLat = (lat2 - lat1) * Math.PI / 180;
                    var dLon = (lon2 - lon1) * Math.PI / 180;
                    var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                            Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
                            Math.sin(dLon/2) * Math.sin(dLon/2);
                    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
                }

                function zbxReverseGeocode(lat, lng, callback) {
                    // Use Nominatim with zoom=16 for neighborhood-level
                    var url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=' + lat + '&lon=' + lng + '&zoom=16&addressdetails=1&accept-language=ar';
                    fetch(url, { headers: { 'User-Agent': 'Zooboxi-Store/1.0' } })
                        .then(function(r) { return r.json(); })
                        .then(function(data) {
                            var addr = data.address || {};
                            var city = addr.city || addr.town || addr.village || addr.region || '';
                            var district = addr.suburb || addr.neighbourhood || addr.quarter || addr.subdistrict || '';
                            callback({ city: city, district: district });
                        })
                        .catch(function() { callback({ city: '', district: '' }); });
                }
            })();
        })();
        </script>
        <script src="https://maps.googleapis.com/maps/api/js?key=<?php echo esc_attr($maps_api_key); ?>&callback=zbxInitMap" async defer></script>
        <?php endif; ?>
        <?php
    }
}
