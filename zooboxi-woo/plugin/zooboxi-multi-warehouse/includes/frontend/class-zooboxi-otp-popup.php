<?php
/**
 * OTP Login Popup — intercepts add-to-cart and wishlist for guests.
 * Shows a 3-step popup: Phone → OTP → Profile (new users only).
 */
class Zooboxi_OTP_Popup
{
    public function __construct()
    {
        // Only for non-logged-in users
        if (!is_user_logged_in()) {
            add_action('wp_footer', [$this, 'render_popup']);
            add_action('wp_enqueue_scripts', [$this, 'enqueue_interceptor']);
        }
    }

    /**
     * Enqueue a small JS that intercepts add-to-cart clicks.
     */
    public function enqueue_interceptor(): void
    {
        // We inline the interceptor in render_popup for simplicity
    }

    /**
     * Render the OTP popup HTML + CSS + JS.
     */
    public function render_popup(): void
    {
        ?>
        <!-- Zooboxi OTP Login Popup -->
        <div id="zbx-otp-modal" class="zbx-otp-modal" style="display:none;">
            <div class="zbx-otp-overlay"></div>
            <div class="zbx-otp-content">
                <button id="zbx-otp-close" class="zbx-otp-close" type="button" aria-label="إغلاق">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                </button>

                <!-- Step 1: Phone Number -->
                <div id="zbx-otp-step1" class="zbx-otp-step">
                    <div class="zbx-otp-icon">📱</div>
                    <h2 class="zbx-otp-title"><?php esc_html_e('مرحباً بك', 'zooboxi'); ?></h2>
                    <p class="zbx-otp-subtitle"><?php esc_html_e('سجل دخولك برقم جوالك لتتمكن من إضافة المنتجات لسلتك', 'zooboxi'); ?></p>

                    <div class="zbx-otp-phone-wrap">
                        <span class="zbx-otp-phone-prefix">🇸🇦 +966</span>
                        <input type="tel" id="zbx-otp-phone" class="zbx-otp-phone-input"
                               placeholder="5X XXX XXXX" maxlength="10" inputmode="numeric"
                               autocomplete="tel-national" dir="ltr">
                    </div>

                    <div id="zbx-otp-error1" class="zbx-otp-error" style="display:none;"></div>

                    <button id="zbx-otp-send" class="zbx-otp-btn" type="button">
                        <?php esc_html_e('إرسال رمز التحقق', 'zooboxi'); ?>
                    </button>
                </div>

                <!-- Step 2: OTP Verification -->
                <div id="zbx-otp-step2" class="zbx-otp-step" style="display:none;">
                    <div class="zbx-otp-icon">📨</div>
                    <h2 class="zbx-otp-title"><?php esc_html_e('أدخل رمز التحقق', 'zooboxi'); ?></h2>
                    <p class="zbx-otp-subtitle">
                        <?php esc_html_e('تم إرسال رمز مكون من 4 أرقام إلى', 'zooboxi'); ?>
                        <span id="zbx-otp-display-phone" class="zbx-otp-phone-display"></span>
                    </p>

                    <div class="zbx-otp-code-wrap">
                        <input type="text" class="zbx-otp-digit" maxlength="1" inputmode="numeric" data-index="0" dir="ltr">
                        <input type="text" class="zbx-otp-digit" maxlength="1" inputmode="numeric" data-index="1" dir="ltr">
                        <input type="text" class="zbx-otp-digit" maxlength="1" inputmode="numeric" data-index="2" dir="ltr">
                        <input type="text" class="zbx-otp-digit" maxlength="1" inputmode="numeric" data-index="3" dir="ltr">
                    </div>

                    <div id="zbx-otp-error2" class="zbx-otp-error" style="display:none;"></div>

                    <button id="zbx-otp-verify" class="zbx-otp-btn" type="button">
                        <?php esc_html_e('تحقق', 'zooboxi'); ?>
                    </button>

                    <div class="zbx-otp-resend">
                        <button id="zbx-otp-resend-btn" class="zbx-otp-resend-btn" type="button" disabled>
                            <?php esc_html_e('إعادة الإرسال', 'zooboxi'); ?>
                            (<span id="zbx-otp-timer">60</span>)
                        </button>
                    </div>
                </div>

                <!-- Step 3: Profile (New users only) -->
                <div id="zbx-otp-step3" class="zbx-otp-step" style="display:none;">
                    <div class="zbx-otp-icon">🎉</div>
                    <h2 class="zbx-otp-title"><?php esc_html_e('أهلاً بك في ZooBoxi!', 'zooboxi'); ?></h2>
                    <p class="zbx-otp-subtitle"><?php esc_html_e('أكمل بياناتك لبدء التسوق', 'zooboxi'); ?></p>

                    <div class="zbx-otp-field">
                        <label for="zbx-otp-name"><?php esc_html_e('الاسم *', 'zooboxi'); ?></label>
                        <input type="text" id="zbx-otp-name" class="zbx-otp-input" placeholder="<?php esc_attr_e('أدخل اسمك', 'zooboxi'); ?>" autocomplete="given-name">
                    </div>

                    <div class="zbx-otp-field">
                        <label for="zbx-otp-email"><?php esc_html_e('البريد الإلكتروني (اختياري)', 'zooboxi'); ?></label>
                        <input type="email" id="zbx-otp-email" class="zbx-otp-input" placeholder="name@example.com" autocomplete="email" dir="ltr">
                    </div>

                    <div id="zbx-otp-error3" class="zbx-otp-error" style="display:none;"></div>

                    <button id="zbx-otp-complete" class="zbx-otp-btn zbx-otp-btn-success" type="button">
                        🛒 <?php esc_html_e('ابدأ التسوق!', 'zooboxi'); ?>
                    </button>
                </div>

                <!-- Step 4: Success -->
                <div id="zbx-otp-step-success" class="zbx-otp-step" style="display:none;">
                    <div class="zbx-otp-icon zbx-otp-icon-success">✅</div>
                    <h2 class="zbx-otp-title" id="zbx-otp-welcome-msg"></h2>
                    <p class="zbx-otp-subtitle"><?php esc_html_e('جاري إضافة المنتج...', 'zooboxi'); ?></p>
                    <div class="zbx-otp-spinner"></div>
                </div>
            </div>
        </div>

        <style>
        /* ── OTP Modal ── */
        .zbx-otp-modal {
            position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            z-index: 999999; display: flex; align-items: center; justify-content: center;
        }
        .zbx-otp-overlay {
            position: absolute; inset: 0;
            background: rgba(0,0,0,0.55); backdrop-filter: blur(8px);
        }
        .zbx-otp-content {
            background: #fff; border-radius: 24px; padding: 32px 28px 28px;
            width: 92%; max-width: 380px; position: relative; z-index: 2;
            text-align: center; box-shadow: 0 24px 64px rgba(0,0,0,0.25);
            animation: zbx-otp-pop 0.35s cubic-bezier(0.16,1,0.3,1);
        }
        @keyframes zbx-otp-pop {
            0% { opacity:0; transform: scale(0.9) translateY(24px); }
            100% { opacity:1; transform: scale(1) translateY(0); }
        }

        .zbx-otp-close {
            position: absolute; top: 14px; right: 14px;
            width: 34px; height: 34px; border-radius: 50%;
            background: #f3f3f3 !important; border: none !important;
            display: flex; align-items: center; justify-content: center;
            cursor: pointer; color: #888; transition: all 0.2s; z-index: 10;
        }
        .zbx-otp-close:hover { background: #e0e0e0 !important; color: #333; }

        .zbx-otp-icon { font-size: 40px; margin-bottom: 8px; }
        .zbx-otp-icon-success { animation: zbx-otp-bounce 0.6s ease; }
        @keyframes zbx-otp-bounce {
            0%,100% { transform: scale(1); } 50% { transform: scale(1.3); }
        }

        .zbx-otp-title {
            font-size: 22px; font-weight: 700; color: #2c3e2d; margin: 0 0 6px;
            font-family: 'El Messiri', 'Tajawal', sans-serif;
        }
        .zbx-otp-subtitle { font-size: 13px; color: #888; margin: 0 0 20px; line-height: 1.6; }

        /* Phone input */
        .zbx-otp-phone-wrap {
            display: flex; align-items: center; gap: 8px;
            background: #f7f9f7; border: 2px solid #e0e5e0; border-radius: 14px;
            padding: 4px 12px; margin-bottom: 16px; transition: border-color 0.3s;
        }
        .zbx-otp-phone-wrap:focus-within { border-color: #429d9c; }
        .zbx-otp-phone-prefix {
            font-size: 14px; font-weight: 600; color: #555; white-space: nowrap;
            padding: 8px 0;
        }
        .zbx-otp-phone-input {
            flex: 1; border: none !important; background: transparent !important;
            font-size: 18px; font-weight: 600; padding: 10px 0; outline: none;
            color: #333; letter-spacing: 1px; font-family: 'Inter', monospace;
        }
        .zbx-otp-phone-input::placeholder { color: #bbb; font-weight: 400; }

        /* OTP digit inputs */
        .zbx-otp-code-wrap {
            display: flex; gap: 12px; justify-content: center; margin-bottom: 16px;
            direction: ltr;
        }
        .zbx-otp-digit {
            width: 56px; height: 64px; border: 2px solid #e0e5e0; border-radius: 14px;
            font-size: 28px; font-weight: 700; text-align: center;
            background: #f7f9f7; color: #333; outline: none;
            transition: all 0.2s; caret-color: #429d9c;
            font-family: 'Inter', monospace;
        }
        .zbx-otp-digit:focus { border-color: #429d9c; background: #fff; box-shadow: 0 0 0 3px rgba(66,157,156,0.15); }
        .zbx-otp-digit.error { border-color: #e74c3c; animation: zbx-otp-shake 0.4s; }
        @keyframes zbx-otp-shake {
            0%,100% { transform: translateX(0); }
            25% { transform: translateX(-6px); }
            75% { transform: translateX(6px); }
        }

        /* Form fields */
        .zbx-otp-field { text-align: right; margin-bottom: 14px; }
        .zbx-otp-field label { display: block; font-size: 13px; font-weight: 600; color: #555; margin-bottom: 6px; }
        .zbx-otp-input {
            width: 100%; padding: 12px 14px; border: 2px solid #e0e5e0; border-radius: 12px;
            font-size: 15px; background: #f7f9f7; outline: none; transition: border-color 0.3s;
            box-sizing: border-box;
        }
        .zbx-otp-input:focus { border-color: #429d9c; background: #fff; }

        /* Buttons */
        .zbx-otp-btn {
            width: 100%; padding: 14px; border: none; border-radius: 14px;
            background: linear-gradient(135deg, #429d9c, #367d7c); color: #fff;
            font-size: 16px; font-weight: 700; cursor: pointer;
            font-family: inherit; transition: all 0.3s;
        }
        .zbx-otp-btn:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(66,157,156,0.35); }
        .zbx-otp-btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        .zbx-otp-btn-success { background: linear-gradient(135deg, #27ae60, #219a52); }
        .zbx-otp-btn.loading { position: relative; color: transparent; }
        .zbx-otp-btn.loading::after {
            content: ''; position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            width: 20px; height: 20px; border: 3px solid rgba(255,255,255,0.3);
            border-top-color: #fff; border-radius: 50%;
            animation: zbx-otp-spin 0.6s linear infinite;
        }
        @keyframes zbx-otp-spin { to { transform: translate(-50%,-50%) rotate(360deg); } }

        /* Error */
        .zbx-otp-error {
            background: #fdf2f2; color: #e74c3c; padding: 10px 14px;
            border-radius: 10px; font-size: 13px; font-weight: 600;
            margin-bottom: 12px;
        }

        /* Resend */
        .zbx-otp-resend { margin-top: 12px; }
        .zbx-otp-resend-btn {
            background: none !important; border: none !important; color: #429d9c;
            font-size: 13px; font-weight: 600; cursor: pointer; font-family: inherit;
        }
        .zbx-otp-resend-btn:disabled { color: #999; cursor: not-allowed; }

        .zbx-otp-phone-display { font-weight: 700; color: #333; direction: ltr; unicode-bidi: embed; }

        /* Spinner */
        .zbx-otp-spinner {
            width: 36px; height: 36px; margin: 16px auto 0;
            border: 3px solid #e0e0e0; border-top-color: #429d9c;
            border-radius: 50%; animation: zbx-otp-spin 0.7s linear infinite;
        }

        /* Mobile */
        @media (max-width: 480px) {
            .zbx-otp-content { padding: 24px 20px 20px; border-radius: 20px; }
            .zbx-otp-digit { width: 50px; height: 56px; font-size: 24px; }
            .zbx-otp-title { font-size: 20px; }
        }
        </style>

        <script>
        (function(){
            if (document.body.classList.contains('logged-in')) return;

            var $ = jQuery;
            var pendingAction = null; // {type: 'cart'|'wishlist', element: DOM, productId: ..., variationId: ..., quantity: ...}
            var currentPhone = '';
            var resendTimer = null;
            var verifiedUserId = null;
            var verifiedNonce = null;

            // ── Intercept add-to-cart ──
            $(document).on('click', '.add_to_cart_button, .single_add_to_cart_button, .ajax_add_to_cart', function(e) {
                if (document.body.classList.contains('logged-in')) return; // Already logged in

                var btn = $(this);

                // Don't intercept "Select options" buttons for variable products — let user go to product page
                if (btn.hasClass('product_type_variable') || btn.hasClass('product_type_grouped') || btn.hasClass('product_type_external')) {
                    return; // Allow default navigation to product page
                }

                e.preventDefault();
                e.stopImmediatePropagation();

                pendingAction = {
                    type: 'cart',
                    element: btn,
                    productId: btn.data('product_id') || btn.closest('form.cart').find('[name=add-to-cart]').val(),
                    variationId: btn.data('variation_id') || btn.closest('form.cart').find('[name=variation_id]').val() || 0,
                    quantity: btn.data('quantity') || btn.closest('form.cart').find('[name=quantity]').val() || 1,
                };

                showModal();
            });

            // ── Intercept wishlist ──
            $(document).on('click', '.yith-wcwl-add-button a, .tinvwl_add_to_wishlist_button, [class*="wishlist"] a', function(e) {
                if (document.body.classList.contains('logged-in')) return;

                e.preventDefault();
                e.stopImmediatePropagation();

                pendingAction = {
                    type: 'wishlist',
                    element: $(this),
                    productId: $(this).data('product-id') || $(this).closest('[data-product-id]').data('product-id'),
                };

                showModal();
            });

            function showModal() {
                $('#zbx-otp-modal').fadeIn(200);
                // Reset to step 1
                $('.zbx-otp-step').hide();
                $('#zbx-otp-step1').show();
                $('.zbx-otp-error').hide();
                $('#zbx-otp-phone').val('').focus();
            }

            // ── Close ──
            $(document).on('click', '#zbx-otp-close, .zbx-otp-overlay', function() {
                $('#zbx-otp-modal').fadeOut(200);
            });

            // ── External open trigger (homepage gentle login invite) ──
            // Opens the same modal with no pending cart/wishlist action, so a
            // successful verify simply reloads into the personalized homepage.
            document.body.addEventListener('zbx:open-otp', function() {
                pendingAction = null;
                showModal();
            });

            // ── Step 1: Send OTP ──
            $(document).on('click', '#zbx-otp-send', function() {
                var phone = $('#zbx-otp-phone').val().trim();
                if (!phone || !/^(05?\d{8}|5\d{8})$/.test(phone.replace(/\s/g,''))) {
                    showError(1, 'يرجى إدخال رقم جوال سعودي صالح');
                    return;
                }
                currentPhone = phone;
                var btn = $(this);
                btn.addClass('loading').prop('disabled', true);
                hideError(1);

                $.post(zooboxiData.ajaxUrl, {
                    action: 'zooboxi_send_otp',
                    nonce: zooboxiData.nonce,
                    phone: phone
                }).done(function(res) {
                    btn.removeClass('loading').prop('disabled', false);
                    if (res.success) {
                        // Move to step 2
                        $('.zbx-otp-step').hide();
                        $('#zbx-otp-step2').show();
                        $('#zbx-otp-display-phone').text(res.data.display_phone);
                        // Focus first digit
                        $('.zbx-otp-digit').val('');
                        $('.zbx-otp-digit').first().focus();
                        // Start resend timer
                        startResendTimer(res.data.resend_after || 60);
                    } else {
                        showError(1, res.data?.message || 'حدث خطأ');
                    }
                }).fail(function() {
                    btn.removeClass('loading').prop('disabled', false);
                    showError(1, 'حدث خطأ في الاتصال');
                });
            });

            // ── OTP digit input handling ──
            $(document).on('input', '.zbx-otp-digit', function() {
                var val = this.value.replace(/[^0-9]/g, '');
                this.value = val;
                if (val.length === 1) {
                    var next = $(this).next('.zbx-otp-digit');
                    if (next.length) next.focus();
                }
            });
            $(document).on('keydown', '.zbx-otp-digit', function(e) {
                if (e.key === 'Backspace' && !this.value) {
                    var prev = $(this).prev('.zbx-otp-digit');
                    if (prev.length) { prev.focus().val(''); }
                }
            });
            // Paste support
            $(document).on('paste', '.zbx-otp-digit', function(e) {
                e.preventDefault();
                var paste = (e.originalEvent.clipboardData || window.clipboardData).getData('text');
                var digits = paste.replace(/[^0-9]/g, '').split('');
                $('.zbx-otp-digit').each(function(i) {
                    if (digits[i]) $(this).val(digits[i]);
                });
                if (digits.length >= 4) {
                    $('.zbx-otp-digit').last().focus();
                    // Auto-verify
                    setTimeout(function() { $('#zbx-otp-verify').click(); }, 200);
                }
            });

            // ── Step 2: Verify OTP ──
            $(document).on('click', '#zbx-otp-verify', function() {
                var otp = '';
                $('.zbx-otp-digit').each(function() { otp += $(this).val(); });
                if (otp.length !== 4) {
                    showError(2, 'أدخل الرمز المكون من 4 أرقام');
                    $('.zbx-otp-digit').addClass('error');
                    setTimeout(function() { $('.zbx-otp-digit').removeClass('error'); }, 500);
                    return;
                }

                var btn = $(this);
                btn.addClass('loading').prop('disabled', true);
                hideError(2);

                $.post(zooboxiData.ajaxUrl, {
                    action: 'zooboxi_verify_otp',
                    nonce: zooboxiData.nonce,
                    phone: currentPhone,
                    otp: otp
                }).done(function(res) {
                    btn.removeClass('loading').prop('disabled', false);
                    if (res.success) {
                        // Store new nonce and user_id from server
                        if (res.data.new_nonce) {
                            verifiedNonce = res.data.new_nonce;
                            zooboxiData.nonce = res.data.new_nonce;
                        }
                        if (res.data.user_id) {
                            verifiedUserId = res.data.user_id;
                        }

                        if (res.data.status === 'existing') {
                            // Existing user — show success & add product
                            showSuccess(res.data.message);
                        } else {
                            // New user — show profile form
                            $('.zbx-otp-step').hide();
                            $('#zbx-otp-step3').show();
                            $('#zbx-otp-name').focus();
                        }
                    } else {
                        showError(2, res.data?.message || 'الرمز غير صحيح');
                        if (res.data?.code === 'wrong_otp') {
                            $('.zbx-otp-digit').addClass('error').val('');
                            $('.zbx-otp-digit').first().focus();
                            setTimeout(function() { $('.zbx-otp-digit').removeClass('error'); }, 500);
                        }
                    }
                }).fail(function() {
                    btn.removeClass('loading').prop('disabled', false);
                    showError(2, 'حدث خطأ في الاتصال');
                });
            });

            // ── Step 3: Complete Profile ──
            $(document).on('click', '#zbx-otp-complete', function() {
                var name = $('#zbx-otp-name').val().trim();
                var email = $('#zbx-otp-email').val().trim();

                if (!name) {
                    showError(3, 'الاسم مطلوب');
                    return;
                }

                var btn = $(this);
                btn.addClass('loading').prop('disabled', true);
                hideError(3);

                $.post(zooboxiData.ajaxUrl, {
                    action: 'zooboxi_complete_profile',
                    nonce: verifiedNonce || zooboxiData.nonce,
                    user_id: verifiedUserId || 0,
                    first_name: name,
                    email: email
                }).done(function(res) {
                    btn.removeClass('loading').prop('disabled', false);
                    if (res.success) {
                        showSuccess(res.data.message);
                    } else {
                        showError(3, res.data?.message || 'حدث خطأ');
                    }
                }).fail(function() {
                    btn.removeClass('loading').prop('disabled', false);
                    showError(3, 'حدث خطأ في الاتصال');
                });
            });

            // ── Resend OTP ──
            $(document).on('click', '#zbx-otp-resend-btn:not(:disabled)', function() {
                var btn = $(this);
                btn.prop('disabled', true);

                $.post(zooboxiData.ajaxUrl, {
                    action: 'zooboxi_send_otp',
                    nonce: zooboxiData.nonce,
                    phone: currentPhone
                }).done(function(res) {
                    if (res.success) {
                        startResendTimer(res.data.resend_after || 60);
                        $('.zbx-otp-digit').val('');
                        $('.zbx-otp-digit').first().focus();
                        hideError(2);
                    } else {
                        showError(2, res.data?.message || 'حدث خطأ');
                    }
                });
            });

            // ── Auto-verify when 4 digits entered ──
            $(document).on('input', '.zbx-otp-digit:last', function() {
                if (this.value) {
                    var otp = '';
                    $('.zbx-otp-digit').each(function() { otp += $(this).val(); });
                    if (otp.length === 4) {
                        setTimeout(function() { $('#zbx-otp-verify').click(); }, 150);
                    }
                }
            });

            // ── Enter key support ──
            $(document).on('keydown', '#zbx-otp-phone', function(e) {
                if (e.key === 'Enter') { e.preventDefault(); $('#zbx-otp-send').click(); }
            });
            $(document).on('keydown', '#zbx-otp-name', function(e) {
                if (e.key === 'Enter') { e.preventDefault(); $('#zbx-otp-complete').click(); }
            });

            // ── Helpers ──
            function showSuccess(message) {
                $('.zbx-otp-step').hide();
                $('#zbx-otp-step-success').show();
                $('#zbx-otp-welcome-msg').text(message);

                // Mark as logged in
                document.body.classList.add('logged-in');

                // Add the pending product
                setTimeout(function() {
                    if (pendingAction) {
                        executePendingAction();
                    } else {
                        closeAndReload();
                    }
                }, 1200);
            }

            function executePendingAction() {
                if (!pendingAction) return;

                if (pendingAction.type === 'cart') {
                    // Add to cart via AJAX
                    $.post(zooboxiData.ajaxUrl.replace('admin-ajax.php', '') + '?wc-ajax=add_to_cart', {
                        product_id: pendingAction.productId,
                        variation_id: pendingAction.variationId || 0,
                        quantity: pendingAction.quantity || 1,
                    }).done(function() {
                        closeAndReload();
                    }).fail(function() {
                        // Fallback: click the button again
                        closeAndReload();
                    });
                } else if (pendingAction.type === 'wishlist') {
                    closeAndReload();
                }
            }

            function closeAndReload() {
                $('#zbx-otp-modal').fadeOut(300, function() {
                    location.reload();
                });
            }

            function showError(step, msg) {
                $('#zbx-otp-error' + step).text(msg).slideDown(200);
            }
            function hideError(step) {
                $('#zbx-otp-error' + step).slideUp(200);
            }

            function startResendTimer(seconds) {
                clearInterval(resendTimer);
                var remaining = seconds;
                var timerEl = $('#zbx-otp-timer');
                var btnEl = $('#zbx-otp-resend-btn');
                btnEl.prop('disabled', true);
                timerEl.text(remaining);

                resendTimer = setInterval(function() {
                    remaining--;
                    timerEl.text(remaining);
                    if (remaining <= 0) {
                        clearInterval(resendTimer);
                        btnEl.prop('disabled', false);
                        timerEl.text('');
                    }
                }, 1000);
            }
        })();
        </script>
        <?php
    }
}
