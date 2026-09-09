import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/location/location_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/location_models.dart';
import '../../data/location_repository.dart';
import '../delivery_when.dart';

/// What is under the pin, in words — the half of a map screen that a map
/// cannot show.
///
/// A satellite view of a Riyadh block looks like every other Riyadh block. The
/// customer needs the store to say the street back to them («حي الملك فهد،
/// الرياض») and, in the same breath, whether anything actually reaches it and
/// how fast. Both come from the one resolver the header chip uses, so what
/// this card promises is what the order will carry.
class PinPlaceCard extends ConsumerWidget {
  const PinPlaceCard({super.key, required this.point, this.action});

  final LatLng? point;

  /// The confirm button, when the card is the screen's bottom bar. Sits under
  /// a hairline inside the same card, so the address and the button that
  /// accepts it are one object.
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;

    final place = point == null
        ? const AsyncValue<ResolveResult>.loading()
        : ref.watch(pinPlaceProvider(PinPoint(point!.latitude, point!.longitude)));

    final body = place.when(
      loading: () => _Line(
        icon: null,
        leading: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
        title: l.pinPlaceLoading,
      ),
      // The pin is the address; a geocoder that will not answer is a missing
      // label, not a missing delivery point. Say so and let them carry on.
      error: (_, _) => _Line(
        icon: Icons.wifi_tethering_off_rounded,
        title: l.pinPlaceUnnamed,
        subtitle: l.pinPlaceUnnamedHint,
      ),
      data: (result) {
        final label = ZbLocation(city: result.city, district: result.district)
            .detailLabel(locale);
        final best = result.best;
        if (best == null && result.options.isEmpty) {
          return _Line(
            icon: Icons.error_outline_rounded,
            tone: cs.error,
            title: label ?? l.pinPlaceUnnamed,
            subtitle: l.pinPlaceOutOfRange,
          );
        }
        return _Line(
          icon: Icons.place_rounded,
          title: label ?? l.pinPlaceUnnamed,
          trailing: _PromiseChip(result: result),
        );
      },
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: body,
          ),
          if (action != null) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}

/// One state of the card: an icon (or a spinner), what the place is called,
/// and the small print under it.
class _Line extends StatelessWidget {
  const _Line({
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final ink = tone ?? cs.primary;

    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: leading ?? Icon(icon, size: 20, color: ink),
          ),
        ),
        Gap.w8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  style: context.tt.bodySmall?.copyWith(
                    color: tone ?? cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[Gap.w8, trailing!],
      ],
    );
  }
}

/// «الساعة ١٠:٣٠ م» in the tier's own colour — the same sentence the header
/// gives, so a pin two streets away shows its consequence before it is saved.
class _PromiseChip extends StatelessWidget {
  const _PromiseChip({required this.result});

  final ResolveResult result;

  @override
  Widget build(BuildContext context) {
    final best = result.best;
    final tier = best?.deliveryType ?? '';
    final when = deliveryWhenLabel(
      context,
      location: ZbLocation(
        deliveryType: tier,
        promiseLabel: best?.promiseLabel,
      ),
    );
    final text = when.isNotEmpty ? when : (best?.promiseLabel ?? '');
    if (text.isEmpty) return const SizedBox.shrink();

    final pair = context.zb.tier(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pair.bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tier == 'express' ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 13,
            color: pair.fg,
          ),
          Gap.w4,
          Text(
            text,
            style: context.tt.labelSmall?.copyWith(
              color: pair.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
