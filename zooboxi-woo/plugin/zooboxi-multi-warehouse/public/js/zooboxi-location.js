/**
 * Zooboxi Location Detection JS
 * Handles GPS detection and manual city selection.
 */
(function ($) {
    'use strict';

    const modal = $('#zooboxi-location-modal');
    const statusEl = $('#zooboxi-location-status');

    // Show modal on page load if no cookie
    $(document).ready(function () {
        if (!getCookie('zooboxi_lat') && !getCookie('zooboxi_city')) {
            setTimeout(() => modal.fadeIn(300), 1000);
        }
    });

    // GPS detection button
    $('#zooboxi-gps-btn').on('click', function () {
        if (!navigator.geolocation) {
            showStatus('error', zooboxiData.i18n.locationError);
            return;
        }

        showStatus('loading', zooboxiData.i18n.detectingLocation);

        navigator.geolocation.getCurrentPosition(
            function (pos) {
                sendLocation(pos.coords.latitude, pos.coords.longitude);
            },
            function () {
                showStatus('error', zooboxiData.i18n.locationError);
            },
            { enableHighAccuracy: true, timeout: 10000 }
        );
    });

    // Manual city selection
    $('#zooboxi-city-select').on('change', function () {
        const city = $(this).val();
        if (!city) return;

        showStatus('loading', zooboxiData.i18n.detectingLocation);

        $.post(zooboxiData.ajaxUrl, {
            action: 'zooboxi_set_city',
            nonce: zooboxiData.nonce,
            city: city,
        })
        .done(function (res) {
            if (res.success) {
                showStatus('success', zooboxiData.i18n.locationDetected);
                closeModal();
            } else {
                showStatus('error', res.data?.message || zooboxiData.i18n.locationError);
            }
        })
        .fail(function () {
            showStatus('error', zooboxiData.i18n.locationError);
        });
    });

    // Change location link
    $(document).on('click', '.zooboxi-change-location', function (e) {
        e.preventDefault();
        document.cookie = 'zooboxi_lat=; expires=Thu, 01 Jan 1970; path=/';
        document.cookie = 'zooboxi_lng=; expires=Thu, 01 Jan 1970; path=/';
        modal.fadeIn(300);
    });

    function sendLocation(lat, lng) {
        $.post(zooboxiData.ajaxUrl, {
            action: 'zooboxi_detect_warehouse',
            nonce: zooboxiData.nonce,
            lat: lat,
            lng: lng,
        })
        .done(function (res) {
            if (res.success) {
                showStatus('success', zooboxiData.i18n.locationDetected);
                closeModal();
            } else {
                showStatus('error', res.data?.message || zooboxiData.i18n.locationError);
            }
        })
        .fail(function () {
            showStatus('error', zooboxiData.i18n.locationError);
        });
    }

    function closeModal() {
        setTimeout(() => {
            modal.fadeOut(300, () => location.reload());
        }, 1200);
    }

    function showStatus(type, msg) {
        statusEl.removeClass('success error loading').addClass(type).text(msg).show();
    }

    function getCookie(name) {
        const v = document.cookie.match('(^|;)\\s*' + name + '\\s*=\\s*([^;]+)');
        return v ? v.pop() : '';
    }
})(jQuery);
