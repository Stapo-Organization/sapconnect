/**
 * Zooboxi Express Zones — Google Maps with polygon drawing + draggable markers.
 * Each zone gets a unique color and branch name label on the map.
 */
(function($) {
    'use strict';

    // State
    let map;
    let markers = {};
    let polygons = {};
    let circles = {};
    let labels = {};
    let drawingManager = null;
    let drawingMode = null;

    // Zone colors palette — distinct vibrant colors for each warehouse
    const ZONE_COLORS = [
        '#e74c3c', // Red
        '#3498db', // Blue
        '#2ecc71', // Green
        '#9b59b6', // Purple
        '#f39c12', // Orange
        '#1abc9c', // Teal
        '#e91e63', // Pink
        '#00bcd4', // Cyan
        '#ff9800', // Amber
        '#8bc34a', // Light Green
        '#673ab7', // Deep Purple
        '#795548', // Brown
    ];

    // KSA center
    const KSA_CENTER = { lat: 24.7136, lng: 46.6753 };
    const KSA_ZOOM = 6;

    function init() {
        if (!document.getElementById('zooboxi-zones-map')) return;

        // Initialize Google Map
        map = new google.maps.Map(document.getElementById('zooboxi-zones-map'), {
            center: KSA_CENTER,
            zoom: KSA_ZOOM,
            mapTypeId: 'roadmap',
            styles: getMapStyle(),
            gestureHandling: 'greedy',
            zoomControl: true,
            mapTypeControl: true,
            mapTypeControlOptions: {
                style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
                position: google.maps.ControlPosition.TOP_LEFT
            },
            streetViewControl: false,
            fullscreenControl: true,
        });

        // Load all warehouses onto map
        loadWarehouses();

        // Bind events
        bindEvents();
    }

    function getZoneColor(index) {
        return ZONE_COLORS[index % ZONE_COLORS.length];
    }

    function getMapStyle() {
        return [
            { featureType: 'poi', elementType: 'all', stylers: [{ visibility: 'off' }] },
            { featureType: 'transit', elementType: 'all', stylers: [{ visibility: 'off' }] },
            { featureType: 'water', elementType: 'geometry', stylers: [{ color: '#ddeef7' }] },
            { featureType: 'landscape', elementType: 'geometry', stylers: [{ color: '#f7f7f7' }] },
            { featureType: 'road.highway', elementType: 'geometry.fill', stylers: [{ color: '#e0e0e0' }] },
            { featureType: 'road.highway', elementType: 'geometry.stroke', stylers: [{ color: '#c0c0c0' }] },
            { featureType: 'road.highway', elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },
            { featureType: 'road.arterial', elementType: 'geometry', stylers: [{ color: '#eeeeee' }] },
            { featureType: 'road.local', elementType: 'geometry', stylers: [{ color: '#f5f5f5' }] },
            { featureType: 'administrative', elementType: 'geometry.stroke', stylers: [{ color: '#c9c9c9' }] },
            { featureType: 'administrative.neighborhood', elementType: 'labels', stylers: [{ visibility: 'simplified' }] },
        ];
    }

    function loadWarehouses() {
        const cards = document.querySelectorAll('.zooboxi-wh-card');
        const bounds = new google.maps.LatLngBounds();
        let colorIdx = 0;

        cards.forEach(card => {
            const code = card.dataset.code;
            const lat = parseFloat(card.dataset.lat);
            const lng = parseFloat(card.dataset.lng);
            const radius = parseFloat(card.dataset.radius) || 10;
            const isExpress = card.dataset.express === '1';
            const polygonData = card.dataset.polygon ? JSON.parse(card.dataset.polygon) : null;
            const name = card.querySelector('.zooboxi-wh-card__name strong').textContent;
            const color = getZoneColor(colorIdx);

            // Store color on card for reference
            card.dataset.color = color;
            colorIdx++;

            if (!lat || !lng) return;

            bounds.extend({ lat, lng });

            // Create marker with custom label
            const markerIcon = {
                path: google.maps.SymbolPath.CIRCLE,
                scale: 10,
                fillColor: color,
                fillOpacity: 1,
                strokeColor: '#fff',
                strokeWeight: 3,
            };

            markers[code] = new google.maps.Marker({
                position: { lat, lng },
                map: map,
                icon: markerIcon,
                draggable: true,
                title: name,
                zIndex: 10,
            });

            // Add branch name label on the map
            labels[code] = new google.maps.Marker({
                position: { lat: lat + 0.005, lng },
                map: map,
                icon: {
                    path: 'M 0 0',
                    scale: 0,
                },
                label: {
                    text: name,
                    color: color,
                    fontSize: '12px',
                    fontWeight: '700',
                    fontFamily: 'El Messiri, sans-serif',
                    className: 'zbx-map-label',
                },
                clickable: false,
                zIndex: 5,
            });

            // Add color indicator to the card header
            const header = card.querySelector('.zooboxi-wh-card__header');
            if (header) {
                const dot = document.createElement('span');
                dot.style.cssText = `display:inline-block;width:14px;height:14px;border-radius:50%;background:${color};margin-left:8px;vertical-align:middle;box-shadow:0 2px 4px rgba(0,0,0,0.2);`;
                header.prepend(dot);
            }

            // Info window
            const infoWindow = new google.maps.InfoWindow({
                content: createInfoContent(name, code, lat, lng, color),
            });
            markers[code].addListener('click', () => {
                infoWindow.open(map, markers[code]);
            });

            // Drag end — sync lat/lng
            markers[code].addListener('dragend', (e) => {
                const newLat = e.latLng.lat().toFixed(8);
                const newLng = e.latLng.lng().toFixed(8);

                card.dataset.lat = newLat;
                card.dataset.lng = newLng;

                const latInput = card.querySelector('.zooboxi-lat-input');
                const lngInput = card.querySelector('.zooboxi-lng-input');
                if (latInput) latInput.value = newLat;
                if (lngInput) lngInput.value = newLng;

                // Move label too
                if (labels[code]) {
                    labels[code].setPosition({ lat: parseFloat(newLat) + 0.005, lng: parseFloat(newLng) });
                }

                infoWindow.setContent(createInfoContent(name, code, newLat, newLng, color));
                showMapMessage(`📍 تم تحديث موقع ${name} — اضغط حفظ لتأكيد`);
                setTimeout(hideMapMessage, 3000);
                card.classList.add('zooboxi-wh-card--changed');
            });

            // Show zone
            if (polygonData && polygonData.coordinates) {
                showPolygonZone(code, polygonData, color);
            } else if (isExpress) {
                showCircleZone(code, lat, lng, radius, color);
            }
        });

        // Fit map to all markers
        if (!bounds.isEmpty()) {
            map.fitBounds(bounds, { top: 30, right: 30, bottom: 30, left: 30 });
            // Don't zoom in too much
            google.maps.event.addListenerOnce(map, 'idle', () => {
                if (map.getZoom() > 12) map.setZoom(12);
            });
        }
    }

    function createInfoContent(name, code, lat, lng, color) {
        return `<div style="text-align:center;min-width:160px;padding:4px;font-family:'El Messiri',sans-serif;">
            <div style="width:24px;height:24px;border-radius:50%;background:${color};margin:0 auto 8px;"></div>
            <strong style="font-size:14px;">${name}</strong><br>
            <code style="font-size:11px;color:#666;">${code}</code><br>
            <span style="font-size:11px;color:#888;">📍 ${parseFloat(lat).toFixed(6)}, ${parseFloat(lng).toFixed(6)}</span><br>
            <span style="font-size:10px;color:${color};">اسحب الدبوس لتعديل الموقع</span>
        </div>`;
    }

    function showPolygonZone(code, geojson, color) {
        removeZone(code);
        const coords = geojson.coordinates[0].map(c => ({ lat: c[1], lng: c[0] }));

        polygons[code] = new google.maps.Polygon({
            paths: coords,
            strokeColor: color,
            strokeWeight: 2,
            strokeOpacity: 0.8,
            fillColor: color,
            fillOpacity: 0.15,
            map: map,
            editable: false,
            zIndex: 1,
        });
    }

    function showCircleZone(code, lat, lng, radiusKm, color) {
        removeZone(code);
        circles[code] = new google.maps.Circle({
            center: { lat, lng },
            radius: radiusKm * 1000,
            strokeColor: color,
            strokeWeight: 2,
            strokeOpacity: 0.6,
            fillColor: color,
            fillOpacity: 0.08,
            map: map,
            zIndex: 1,
        });
    }

    function removeZone(code) {
        if (polygons[code]) {
            polygons[code].setMap(null);
            delete polygons[code];
        }
        if (circles[code]) {
            circles[code].setMap(null);
            delete circles[code];
        }
    }

    // ── Polygon Drawing ─────────────────────────────

    function startDrawing(code) {
        if (drawingManager) {
            drawingManager.setMap(null);
            drawingManager = null;
        }

        drawingMode = code;

        // Disable marker dragging while drawing
        Object.values(markers).forEach(m => m.setDraggable(false));

        // Zoom to warehouse
        const card = document.querySelector(`.zooboxi-wh-card[data-code="${code}"]`);
        const lat = parseFloat(card.dataset.lat);
        const lng = parseFloat(card.dataset.lng);
        const color = card.dataset.color || '#3498db';

        if (lat && lng) {
            map.setCenter({ lat, lng });
            map.setZoom(13);
        }

        // Initialize Drawing Manager
        drawingManager = new google.maps.drawing.DrawingManager({
            drawingMode: google.maps.drawing.OverlayType.POLYGON,
            drawingControl: false,
            polygonOptions: {
                strokeColor: color,
                strokeWeight: 2,
                fillColor: color,
                fillOpacity: 0.2,
                editable: true,
                clickable: true,
            },
        });
        drawingManager.setMap(map);

        // When polygon complete
        google.maps.event.addListener(drawingManager, 'polygoncomplete', (polygon) => {
            const path = polygon.getPath();
            const coords = [];
            for (let i = 0; i < path.getLength(); i++) {
                const pt = path.getAt(i);
                coords.push([pt.lng(), pt.lat()]);
            }
            // Close polygon
            coords.push(coords[0].slice());

            const geojson = {
                type: 'Polygon',
                coordinates: [coords],
            };

            // Remove the drawn polygon (we'll show our own)
            polygon.setMap(null);

            // Save to card
            if (card) {
                card.dataset.polygon = JSON.stringify(geojson);
            }

            showPolygonZone(code, geojson, color);

            const statusEl = card.querySelector('.zooboxi-zone-status');
            if (statusEl) {
                statusEl.className = 'zooboxi-zone-status zooboxi-zone-status--set';
                statusEl.innerHTML = '✅ منطقة مرسومة';
            }

            stopDrawing();
            showMapMessage(`✅ تم رسم منطقة التغطية — اضغط حفظ لتأكيد`);
            setTimeout(hideMapMessage, 3000);
        });

        showMapMessage('🖊️ ارسم منطقة التغطية على الخريطة بالنقر لإضافة نقاط.');
    }

    function stopDrawing() {
        drawingMode = null;
        if (drawingManager) {
            drawingManager.setMap(null);
            drawingManager = null;
        }
        // Re-enable marker dragging
        Object.values(markers).forEach(m => m.setDraggable(true));
        hideMapMessage();
    }

    // ── Map Messages ────────────────────────────────

    function showMapMessage(msg) {
        let el = document.getElementById('zooboxi-map-message');
        if (!el) {
            el = document.createElement('div');
            el.id = 'zooboxi-map-message';
            el.style.cssText = 'position:absolute;top:10px;left:50%;transform:translateX(-50%);z-index:1000;background:rgba(0,0,0,0.85);color:#fff;padding:10px 20px;border-radius:10px;font-size:13px;pointer-events:none;backdrop-filter:blur(8px);box-shadow:0 4px 16px rgba(0,0,0,0.2);font-family:"El Messiri",sans-serif;';
            document.querySelector('.zooboxi-zones-map-container').style.position = 'relative';
            document.querySelector('.zooboxi-zones-map-container').appendChild(el);
        }
        el.textContent = msg;
        el.style.display = 'block';
    }

    function hideMapMessage() {
        const el = document.getElementById('zooboxi-map-message');
        if (el) el.style.display = 'none';
    }

    // ── Event Bindings ──────────────────────────────

    function bindEvents() {
        // Draw zone button
        $(document).on('click', '.zooboxi-draw-zone', function() {
            const code = $(this).data('code');
            startDrawing(code);
        });

        // Clear zone button
        $(document).on('click', '.zooboxi-clear-zone', function() {
            const code = $(this).data('code');
            removeZone(code);
            const card = document.querySelector(`.zooboxi-wh-card[data-code="${code}"]`);
            if (card) {
                card.dataset.polygon = '';
                const statusEl = card.querySelector('.zooboxi-zone-status');
                if (statusEl) {
                    statusEl.className = 'zooboxi-zone-status';
                    statusEl.innerHTML = '❌ لا توجد منطقة';
                }
            }
        });

        // Save warehouse settings
        $(document).on('click', '.zooboxi-save-wh', function() {
            const code = $(this).data('code');
            saveWarehouse(code);
        });

        // Express toggle
        $(document).on('change', '.zooboxi-express-toggle', function() {
            const code = $(this).data('code');
            const card = document.querySelector(`.zooboxi-wh-card[data-code="${code}"]`);
            if (card) {
                card.classList.toggle('zooboxi-wh-card--active', this.checked);
            }
        });

        // Closed day toggle
        $(document).on('change', '.zooboxi-hours-closed-toggle', function() {
            const row = $(this).closest('.zooboxi-hours-row');
            row.find('.zooboxi-hours-open, .zooboxi-hours-close').prop('disabled', this.checked);
        });

        // Click on card header → zoom to warehouse
        $(document).on('click', '.zooboxi-wh-card__header', function() {
            const card = $(this).closest('.zooboxi-wh-card');
            const lat = parseFloat(card.data('lat'));
            const lng = parseFloat(card.data('lng'));
            const code = card.data('code');
            if (lat && lng && map) {
                map.setCenter({ lat, lng });
                map.setZoom(15);
                if (markers[code]) {
                    google.maps.event.trigger(markers[code], 'click');
                }
            }
        });

        // Lat/Lng manual input → reposition marker
        $(document).on('change', '.zooboxi-lat-input, .zooboxi-lng-input', function() {
            const card = $(this).closest('.zooboxi-wh-card');
            const code = card.data('code');
            const lat = parseFloat(card.find('.zooboxi-lat-input').val());
            const lng = parseFloat(card.find('.zooboxi-lng-input').val());

            if (!lat || !lng || !markers[code]) return;

            markers[code].setPosition({ lat, lng });
            card[0].dataset.lat = lat;
            card[0].dataset.lng = lng;

            if (labels[code]) {
                labels[code].setPosition({ lat: lat + 0.005, lng });
            }

            map.setCenter({ lat, lng });
            map.setZoom(15);
            card[0].classList.add('zooboxi-wh-card--changed');
        });

        // Locate on map button → zoom + open info
        $(document).on('click', '.zooboxi-locate-btn', function() {
            const code = $(this).data('code');
            const card = document.querySelector(`.zooboxi-wh-card[data-code="${code}"]`);
            const lat = parseFloat(card.dataset.lat);
            const lng = parseFloat(card.dataset.lng);
            if (lat && lng && markers[code]) {
                map.setCenter({ lat, lng });
                map.setZoom(16);
                google.maps.event.trigger(markers[code], 'click');
            }
        });
    }

    // ── Save Warehouse Settings ─────────────────────

    function saveWarehouse(code) {
        const card = document.querySelector(`.zooboxi-wh-card[data-code="${code}"]`);
        if (!card) return;

        const $btn = $(`.zooboxi-save-wh[data-code="${code}"]`);
        const $status = $(`.zooboxi-save-status[data-code="${code}"]`);

        $btn.prop('disabled', true).text('⏳ جاري الحفظ...');
        $status.text('');

        // Collect working hours
        const hours = {};
        const hoursGrid = card.querySelector(`.zooboxi-hours-grid[data-code="${code}"]`);
        const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

        hoursGrid.querySelectorAll('.zooboxi-hours-row').forEach((row, idx) => {
            const closed = row.querySelector('.zooboxi-hours-closed-toggle').checked;
            hours[days[idx]] = {
                open: row.querySelector('.zooboxi-hours-open').value || '09:00',
                close: row.querySelector('.zooboxi-hours-close').value || '22:00',
                closed: closed
            };
        });

        const lat = card.querySelector('.zooboxi-lat-input')?.value || card.dataset.lat || '';
        const lng = card.querySelector('.zooboxi-lng-input')?.value || card.dataset.lng || '';

        const data = {
            action: 'zooboxi_save_warehouse_settings',
            nonce: zooboxiAdmin.nonce,
            warehouse_code: code,
            latitude: lat,
            longitude: lng,
            is_express_enabled: card.querySelector('.zooboxi-express-toggle').checked ? 1 : 0,
            express_radius_km: card.querySelector('.zooboxi-radius-input').value || 10,
            warehouse_type: card.querySelector('.zooboxi-wh-type').value || 'showroom',
            is_central: card.querySelector('.zooboxi-central-toggle').checked ? 1 : 0,
            is_main_hub: card.querySelector('.zooboxi-hub-toggle').checked ? 1 : 0,
            express_zone_polygon: card.dataset.polygon || 'null',
            express_working_hours: JSON.stringify(hours),
        };

        $.post(zooboxiAdmin.ajaxUrl, data, function(response) {
            $btn.prop('disabled', false).html('💾 حفظ الإعدادات');
            if (response.success) {
                $status.text('✅ ' + response.data.message).css('color', '#27ae60');
                card.classList.remove('zooboxi-wh-card--changed');
                setTimeout(() => $status.text(''), 3000);
            } else {
                $status.text('❌ ' + (response.data?.message || 'خطأ')).css('color', '#e74c3c');
            }
        }).fail(function() {
            $btn.prop('disabled', false).html('💾 حفظ الإعدادات');
            $status.text('❌ خطأ في الاتصال').css('color', '#e74c3c');
        });
    }

    // Init — exposed as global for Google Maps callback
    window.initZoboxiMap = init;

})(jQuery);
