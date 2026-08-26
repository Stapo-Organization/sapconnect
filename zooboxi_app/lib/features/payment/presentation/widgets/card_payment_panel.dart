import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myfatoorah_flutter/MFUtils.dart' show getColorHexFromStr;
import 'package:myfatoorah_flutter/myfatoorah_flutter.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/payment_service.dart';

/// What the card view came back with.
///
/// An invoice can exist alongside an error: MyFatoorah mints the invoice
/// *before* the 3-D Secure challenge, so a failure after that point is still
/// worth one question to the server rather than an outright "declined".
@immutable
class CardPaymentResult {
  const CardPaymentResult({this.invoiceId, this.error});

  final String? invoiceId;

  /// The SDK's own wording when it refused. Null on a clean success.
  final String? error;
}

/// The embedded MyFatoorah card form, its pay button, and nothing else.
///
/// The card fields are a native platform view owned by the gateway's SDK — no
/// card number ever crosses into Dart, which is what keeps this build out of
/// PCI scope while still looking like part of the app. 3-D Secure runs inside
/// the SDK, so the customer never leaves the screen.
///
/// The panel handles its own session; the *verdict* belongs to the screen,
/// because only the server can say whether money actually moved.
class CardPaymentPanel extends StatefulWidget {
  const CardPaymentPanel({
    super.key,
    required this.config,
    required this.onResult,
    this.onAttempt,
    this.errorText,
    this.busy = false,
  });

  final PaymentConfig config;

  /// Fired once the SDK has finished with the card, successfully or not.
  final void Function(CardPaymentResult result) onResult;

  /// Fired the moment a new attempt begins, so the screen can clear whatever
  /// it was saying about the last one.
  final VoidCallback? onAttempt;

  /// Set by the screen when *its* step failed — a verification that came back
  /// unpaid. The panel's own failures are held internally.
  final String? errorText;

  /// True while the screen is confirming with the server.
  final bool busy;

  @override
  State<CardPaymentPanel> createState() => _CardPaymentPanelState();
}

class _CardPaymentPanelState extends State<CardPaymentPanel> {
  /// Tall enough for the icons row, three field rows and their labels. The
  /// native view lays itself out inside this; the same number goes to the SDK
  /// so its content and its box agree.
  static const int _cardHeight = 250;

  MFCardPaymentView? _cardView;
  MFInitiateSessionResponse? _session;

  /// The native Apple Pay button — created once, armed per session. Each
  /// arm's future resolves only after the customer acts on the sheet.
  MFApplePayButton? _applePayButton;
  int _applePayArmFailures = 0;
  bool _applePayBroken = false;

  /// Arms the sheet after the SAME sequence of arm calls it was created for —
  /// a stale arm (superseded by a newer session) must not deliver results.
  int _applePayArmSerial = 0;

  bool _loading = true;
  bool _paying = false;
  String? _sessionError;
  String? _payError;

  /// The invoice the SDK announced before running 3-D Secure. Kept so a
  /// failure *after* the card cleared can still be checked with the server.
  String? _pendingInvoice;

  /// Apple Pay renders only behind the server's flag and on iOS. The button
  /// is MyFatoorah's embedded flow — their Apple Pay page in a WKWebView,
  /// their certificates — so the flag is the *only* switch; there is no
  /// merchant id or entitlement on our side. WKWebView Apple Pay needs
  /// iOS 16+; older devices fail the arm and the button hides itself.
  bool get _applePayEnabled =>
      widget.config.applePay &&
      !_applePayBroken &&
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once: the platform view reads its style at creation, so rebuilding
    // it on a theme change would only churn the native side for nothing.
    if (_cardView != null) return;
    _cardView = MFCardPaymentView(cardViewStyle: _style(context));
    if (_applePayEnabled) {
      _applePayButton = MFApplePayButton(
        applePayStyle: MFApplePayStyle()
          ..height = 46
          ..borderRadius = 14
          ..vendorName = 'Zooboxi',
      );
    }
    unawaited(_openSession());
  }

  String get _lang => Localizations.localeOf(context).languageCode == 'ar'
      ? MFLanguage.ARABIC
      : MFLanguage.ENGLISH;

  Future<void> _openSession() async {
    setState(() {
      _loading = true;
      _sessionError = null;
    });
    try {
      // One session per payment — MyFatoorah will not accept it twice. Passing
      // no customer identifier keeps saved cards off, which is deliberate: the
      // app holds no card reference of any kind.
      final session = await MFSDK.initSession(MFInitiateSessionRequest(), _lang);
      if (!mounted) return;
      // Null for the BIN callback on purpose. The SDK multiplexes BIN changes
      // and invoice ids over one event channel, so subscribing here would also
      // hand card BINs to the payment listener.
      _cardView?.load(session, null);
      setState(() {
        _session = session;
        _loading = false;
      });
      _armApplePay(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sessionError = _sdkMessage(context, e);
      });
    }
  }

  Future<void> _pay() async {
    final view = _cardView;
    final session = _session;
    if (view == null || session == null || _paying || widget.busy) return;

    Haptics.light();
    widget.onAttempt?.call();
    setState(() {
      _paying = true;
      _payError = null;
      _pendingInvoice = null;
    });

    final request = _executeRequest(session);

    try {
      final response = await view.pay(
        request,
        _lang,
        (invoiceId) => _pendingInvoice = invoiceId,
        currency: widget.config.currency,
      );
      if (!mounted) return;
      setState(() => _paying = false);
      final invoice = response.invoiceId?.toString() ?? _pendingInvoice;
      _refreshSessionAfterAttempt(invoice);
      widget.onResult(CardPaymentResult(invoiceId: invoice));
    } catch (e) {
      if (!mounted) return;
      final message = _sdkMessage(context, e);
      setState(() {
        _paying = false;
        // Only shown when there is no invoice to ask about; otherwise the
        // screen decides, after the server has answered.
        _payError = _pendingInvoice == null ? message : null;
      });
      _refreshSessionAfterAttempt(_pendingInvoice);
      if (_pendingInvoice != null) {
        widget.onResult(
          CardPaymentResult(invoiceId: _pendingInvoice, error: message),
        );
      }
    }
  }

  /// A session that produced an invoice is spent — executing it again would be
  /// refused by the gateway. Quietly mint a fresh one so a retry after a
  /// declined verification starts from a valid session instead of a dead one.
  void _refreshSessionAfterAttempt(String? invoiceId) {
    if (invoiceId == null || !mounted) return;
    unawaited(_openSession());
  }

  /// One request shape for both forms. The server verifies the resulting
  /// invoice by `customerReference`, so a tampered amount or a foreign
  /// invoice simply fails to confirm.
  MFExecutePaymentRequest _executeRequest(MFInitiateSessionResponse session) {
    final config = widget.config;
    return MFExecutePaymentRequest(
      sessionId: session.sessionId,
      invoiceValue: config.amount,
      displayCurrencyIso: config.currency,
      customerReference:
          config.reference.isEmpty ? '${config.orderId}' : config.reference,
      language: _lang,
    );
  }

  /// Arms the Apple Pay sheet with [session]. The load future resolves only
  /// after the customer acts — pays, cancels, or the SDK refuses outright.
  /// A cancel (slow) re-arms the same session; a payment hands its invoice to
  /// the screen and mints a fresh session; an *immediate* failure counts
  /// toward hiding the button, because a vendor account without Apple Pay
  /// configured would otherwise refuse in a loop forever.
  void _armApplePay(MFInitiateSessionResponse session) {
    final btn = _applePayButton;
    if (btn == null || !_applePayEnabled) return;
    final serial = ++_applePayArmSerial;
    final clock = Stopwatch()..start();

    unawaited(() async {
      try {
        final response = await btn.load(session, _executeRequest(session), _lang);
        if (!mounted || serial != _applePayArmSerial) return;
        _applePayArmFailures = 0;
        final invoice = response.invoiceId?.toString();
        if (invoice == null || invoice.isEmpty) {
          _armApplePay(session);
          return;
        }
        widget.onAttempt?.call();
        widget.onResult(CardPaymentResult(invoiceId: invoice));
        // The session is spent; a fresh one re-arms both forms.
        unawaited(_openSession());
      } catch (_) {
        if (!mounted || serial != _applePayArmSerial) return;
        final immediate = clock.elapsed < const Duration(seconds: 2);
        if (immediate) {
          _applePayArmFailures += 1;
          if (_applePayArmFailures >= 2) {
            // Not wired on the vendor side (or the entitlement is missing) —
            // hide quietly. The card form is still right there.
            setState(() => _applePayBroken = true);
            return;
          }
        } else {
          _applePayArmFailures = 0;
        }
        _armApplePay(session);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final error = widget.errorText ?? _payError ?? _sessionError;
    final ready = _session != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_applePayEnabled && _applePayButton != null && ready) ...[
          SizedBox(height: 46, child: _applePayButton),
          Gap.h16,
          Row(
            children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l.paymentOrCard,
                  style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ],
          ),
          Gap.h12,
        ],
        Text(l.paymentCardTitle, style: context.tt.titleMedium),
        Gap.h12,
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: _cardHeight.toDouble(),
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        Gap.h12,
                        Text(
                          l.paymentPreparingCard,
                          style: context.tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : (ready ? _cardView : const SizedBox.shrink()),
          ),
        ),
        if (error != null) ...[
          Gap.h12,
          _ErrorNote(message: error),
        ],
        Gap.h16,
        FilledButton(
          onPressed: (ready && !_paying && !widget.busy) ? _pay : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: (_paying || widget.busy)
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: cs.onPrimary,
                  ),
                )
              : Text(
                  l.paymentPayAmount(
                    Fmt.price(widget.config.amount, locale: locale),
                  ),
                ),
        ),
        if (!ready && !_loading) ...[
          Gap.h8,
          TextButton.icon(
            onPressed: _openSession,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.actionRetry),
          ),
        ],
        if (widget.busy) ...[
          Gap.h8,
          Text(
            l.paymentConfirming,
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        Gap.h12,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: cs.onSurfaceVariant),
            Gap.w6,
            Flexible(
              child: Text(
                l.paymentSecureNote,
                textAlign: TextAlign.center,
                style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── SDK plumbing ─────────────────────────────────────────────────────

  /// Dresses the gateway's native form in the app's palette and language. Only
  /// what the SDK actually exposes is set — everything else keeps its default
  /// rather than being faked with a value that does nothing.
  MFCardViewStyle _style(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    final style = MFCardViewStyle()
      ..hideCardIcons = false
      ..direction = context.isRtl ? 'rtl' : 'ltr'
      ..backgroundColor = getColorHexFromStr(_hex(cs.surface))
      ..cardHeight = _cardHeight;

    style.input
      ?..color = getColorHexFromStr(_hex(cs.onSurface))
      ..fontSize = 14
      ..inputHeight = 42
      ..inputMargin = 6
      // Teal-leaning rather than pure neutral, so the fields read as part of
      // the app instead of as an embedded stranger.
      ..borderColor = getColorHexFromStr(
        _hex(Color.lerp(cs.outlineVariant, cs.primary, 0.4)!),
      )
      ..borderWidth = 1.2
      ..borderRadius = ZbTokens.rSm;

    style.input?.placeHolder
      ?..holderName = l.payCardHolderHint
      ..cardNumber = l.payCardNumberHint
      ..expiryDate = l.payCardExpiryHint
      ..securityCode = l.payCardCvvHint;

    style.label
      ?..display = true
      ..color = getColorHexFromStr(_hex(cs.onSurfaceVariant))
      ..fontSize = 12
      ..fontWeight = MFFontWeight.SemiBold;

    style.label?.text
      ?..holderName = l.payCardHolder
      ..cardNumber = l.payCardNumber
      ..expiryDate = l.payCardExpiry
      ..securityCode = l.payCardCvv;

    style.error
      ?..borderColor = getColorHexFromStr(_hex(cs.error))
      ..borderRadius = ZbTokens.rSm;

    // Saved cards are not enabled (no customer identifier is sent), but the
    // SDK ships these strings in English — localize them so nothing can
    // surface untranslated.
    style.savedCardText
      ?..saveCardText = l.paymentSaveCard
      ..addCardText = l.paymentUseAnotherCard;

    return style;
  }

  /// `#RRGGBB` — the only colour form the SDK's `getColorHexFromStr` accepts.
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// The SDK throws a bare [MFError] (not an `Exception`), and the platform
  /// channel throws [PlatformException]. Prefer their own wording — it names
  /// the actual field or decline reason — and fall back to ours.
  static String _sdkMessage(BuildContext context, Object error) {
    final String? message = switch (error) {
      MFError(:final message) => message,
      PlatformException(:final message) => message,
      _ => null,
    };
    final trimmed = message?.trim();
    return (trimmed == null || trimmed.isEmpty)
        ? L.of(context).paymentCardFailed
        : trimmed;
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
          Gap.w8,
          Expanded(
            child: Text(
              message,
              style: context.tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
