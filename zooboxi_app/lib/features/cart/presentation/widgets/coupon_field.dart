import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/error_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/cart_controller.dart';
import '../../data/cart_models.dart';

/// Coupon entry and the applied-coupon chips.
///
/// Validation lives entirely on the server — an app that pre-judges a code
/// eventually rejects one that would have worked.
class CouponField extends ConsumerStatefulWidget {
  const CouponField({super.key, required this.coupons});

  final List<CartCoupon> coupons;

  @override
  ConsumerState<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends ConsumerState<CouponField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await ref.read(cartControllerProvider.notifier).applyCoupon(code);
      _controller.clear();
      Haptics.light();
    } catch (e) {
      if (!mounted) return;
      Haptics.warning();
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String code) async {
    setState(() => _busy = true);
    try {
      await ref.read(cartControllerProvider.notifier).removeCoupon(code);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final zb = context.zb;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.cartCoupon, style: context.tt.titleSmall),
        Gap.h8,
        if (widget.coupons.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final coupon in widget.coupons)
                Chip(
                  backgroundColor: zb.success.withValues(alpha: 0.12),
                  side: BorderSide(color: zb.success.withValues(alpha: 0.3)),
                  label: Text(
                    coupon.amount > 0
                        ? '${coupon.code} · -${Fmt.price(coupon.amount, locale: locale)}'
                        : coupon.code,
                    style: context.tt.labelMedium?.copyWith(color: zb.success),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteIconColor: zb.success,
                  onDeleted: _busy ? null : () => _remove(coupon.code),
                ),
            ],
          ),
          Gap.h12,
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(
                  hintText: l.cartCouponHint,
                  prefixIcon: Icon(Icons.local_offer_outlined, color: cs.onSurfaceVariant),
                  isDense: true,
                ),
              ),
            ),
            Gap.w8,
            FilledButton.tonal(
              onPressed: _busy ? null : _apply,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(l.cartCouponApply),
            ),
          ],
        ),
      ],
    );
  }
}
