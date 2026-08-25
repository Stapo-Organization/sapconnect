import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/account_models.dart';
import '../../data/order_models.dart';

/// A titled card. The order screen is a stack of these, so the sections read
/// as one document rather than as a settings list.
class OrderSection extends StatelessWidget {
  const OrderSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: cs.primary),
                Gap.w8,
              ],
              Expanded(child: Text(title, style: context.tt.titleSmall)),
              ?trailing,
            ],
          ),
          Gap.h12,
          child,
        ],
      ),
    );
  }
}

/// The lines that were bought, at the prices that were charged.
class OrderItemsList extends StatelessWidget {
  const OrderItemsList({super.key, required this.items});

  final List<OrderLine> items;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: cs.outlineVariant),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ZbImage(
                  url: item.image,
                  radius: BorderRadius.circular(ZbTokens.rSm),
                  padding: const EdgeInsets.all(4),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodyMedium,
                    ),
                    Gap.h4,
                    Text(
                      L.of(context).cartLineQty(item.qty),
                      style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Gap.w8,
              Text(
                Fmt.price(item.total, locale: locale),
                style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Where it went, and who signs for it.
class OrderAddressBlock extends StatelessWidget {
  const OrderAddressBlock({super.key, required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final line = [address.addressLine, address.summary]
        .where((e) => e.isNotEmpty)
        .join('، ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address.name.isNotEmpty) Text(address.name, style: context.tt.bodyMedium),
        if (line.isNotEmpty) ...[
          Gap.h4,
          Text(
            line,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (address.phone.isNotEmpty) ...[
          Gap.h4,
          Text(
            Fmt.phone(address.phone),
            textDirection: TextDirection.ltr,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// The carrier's number — copyable, because the one thing anyone does with a
/// tracking number is paste it somewhere else.
class OrderTrackingBlock extends StatelessWidget {
  const OrderTrackingBlock({super.key, required this.tracking});

  final OrderTracking tracking;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final number = tracking.number;
    final url = tracking.url;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((tracking.carrier ?? '').isNotEmpty)
          Text(tracking.carrier!, style: context.tt.bodyMedium),
        if (number != null && number.isNotEmpty) ...[
          Gap.h8,
          InkWell(
            borderRadius: BorderRadius.circular(ZbTokens.rSm),
            onTap: () => _copy(context, number),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(ZbTokens.rSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.orderTrackingNumber,
                          style: context.tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Text(
                          number,
                          textDirection: TextDirection.ltr,
                          style: context.tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 17, color: cs.primary),
                ],
              ),
            ),
          ),
        ],
        if ((tracking.status ?? '').isNotEmpty) ...[
          Gap.h8,
          Text(
            tracking.status!,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if (url != null && url.isNotEmpty) ...[
          Gap.h12,
          OutlinedButton.icon(
            onPressed: () => _open(context, url),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: Text(l.orderTrackingOpen),
          ),
        ],
      ],
    );
  }

  static Future<void> _copy(BuildContext context, String number) async {
    Haptics.selection();
    await Clipboard.setData(ClipboardData(text: number));
    if (!context.mounted) return;
    AppToast.success(context, L.of(context).orderTrackingCopied);
  }

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    final cs = context.cs;
    try {
      await launchUrl(
        uri,
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(toolbarColor: cs.surface),
          showTitle: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: cs.surface,
          preferredControlTintColor: cs.primary,
          barCollapsingEnabled: true,
        ),
      );
    } catch (_) {
      // No browser available — the number is still copyable, which is the
      // part that actually matters.
    }
  }
}
