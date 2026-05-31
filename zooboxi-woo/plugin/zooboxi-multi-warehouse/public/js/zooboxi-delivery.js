/**
 * Zooboxi Delivery Info JS
 * Handles delivery badge updates and checkout enhancements.
 */
(function ($) {
    'use strict';

    // Refresh shipping when delivery options change
    $(document.body).on('updated_checkout', function () {
        // Shipping rates are dynamically loaded — badges auto-update
    });

    // Trigger shipping recalculation after location change
    $(document).on('zooboxi:location_changed', function () {
        $(document.body).trigger('update_checkout');
        $('body').trigger('wc_update_cart');
    });
})(jQuery);
