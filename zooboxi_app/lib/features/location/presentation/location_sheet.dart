import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../data/location_models.dart';
import 'widgets/city_picker.dart';

/// Opens the delivery-location sheet.
///
/// [primer] is the first-run framing — it explains *why* we're asking, and
/// offers a skip, because a store that blocks browsing on a permission prompt
/// loses the customer before it has shown them anything.
Future<void> showLocationSheet(BuildContext context, {bool primer = false}) {
  return showZbSheet<void>(
    context,
    builder: (_) => LocationSheet(primer: primer),
  );
}

class LocationSheet extends ConsumerStatefulWidget {
  const LocationSheet({super.key, this.primer = false});

  final bool primer;

  @override
  ConsumerState<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<LocationSheet> {
  bool _showCities = false;

  Future<void> _useGps() async {
    Haptics.light();
    final ok = await ref.read(locationProvider.notifier).useDeviceLocation();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      // Permission refused or no fix: fall through to the city list rather
      // than leaving them at a dead end.
      setState(() => _showCities = true);
    }
  }

  Future<void> _pickCity(CityEntry city) async {
    Haptics.selection();
    await ref.read(locationProvider.notifier).setCity(city);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = ref.watch(locationProvider);

    if (_showCities) {
      return BottomSheetScaffold(
        title: l.citiesTitle,
        subtitle: switch (state.phase) {
          LocationPhase.denied => l.onboardLocationDenied,
          LocationPhase.failed => l.onboardLocationFailed,
          _ => null,
        },
        bodyPadding: EdgeInsets.zero,
        child: CityPicker(onSelected: _pickCity),
      );
    }

    return BottomSheetScaffold(
      title: widget.primer ? l.onboardTitle : l.locationSheetTitle,
      subtitle: l.onboardSubtitle,
      child: _PrimerBody(
        busy: state.isBusy,
        current: state.location,
        primer: widget.primer,
        onUseGps: _useGps,
        onChooseCity: () => setState(() => _showCities = true),
      ),
    );
  }
}

class _PrimerBody extends StatelessWidget {
  const _PrimerBody({
    required this.busy,
    required this.current,
    required this.primer,
    required this.onUseGps,
    required this.onChooseCity,
  });

  final bool busy;
  final ZbLocation current;
  final bool primer;
  final VoidCallback onUseGps;
  final VoidCallback onChooseCity;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final city = current.cityFor(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (city != null && city.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(ZbTokens.rMd),
            ),
            child: Row(
              children: [
                Icon(Icons.place_rounded, size: 18, color: cs.onPrimaryContainer),
                Gap.w8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city,
                        style: context.tt.titleSmall
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      if (current.promiseLabel != null)
                        Text(
                          current.promiseLabel!,
                          style: context.tt.bodySmall
                              ?.copyWith(color: cs.onPrimaryContainer),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.h16,
        ],
        FilledButton.icon(
          onPressed: busy ? null : onUseGps,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.my_location_rounded, size: 20),
          label: Text(busy ? l.onboardLocating : l.onboardUseLocation),
        ),
        Gap.h8,
        OutlinedButton.icon(
          onPressed: busy ? null : onChooseCity,
          icon: const Icon(Icons.location_city_rounded, size: 20),
          label: Text(l.onboardChooseCity),
        ),
        if (primer) ...[
          Gap.h4,
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l.onboardSkip),
          ),
        ],
        Gap.h8,
      ],
    );
  }
}

/// The header chip: where we're delivering, and how fast. Tapping it opens
/// the sheet. On a store where the same product has three different answers
/// depending on where you stand, this is the most important control on Home.
class LocationChip extends ConsumerWidget {
  const LocationChip({super.key, this.onCanvas = false});

  /// Renders the chip for the hero canvas: every stroke turns light, since
  /// the canvas colors are deep by design.
  final bool onCanvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final location = ref.watch(currentLocationProvider);
    // The full line a person recognises as *their* address: district, city.
    final detail = location.detailLabel(locale);
    final isSet = detail != null && detail.isNotEmpty;

    final fg = onCanvas ? (context.isDark ? ZbTokens.inkDark : Colors.white) : null;
    final accent = fg ?? cs.primary;
    final muted = fg?.withValues(alpha: 0.78) ?? cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        onTap: () {
          Haptics.selection();
          showLocationSheet(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSet ? Icons.place_rounded : Icons.add_location_alt_outlined,
                size: 16,
                color: accent,
              ),
              Gap.w6,
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.locationDeliverTo,
                      style: context.tt.labelSmall?.copyWith(
                        color: muted,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      isSet ? detail : l.locationChoose,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleSmall?.copyWith(height: 1.2, color: fg),
                    ),
                  ],
                ),
              ),
              Gap.w4,
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The promise line under the header, e.g. "خلال ساعتين من فرع النخيل".
class PromiseLine extends ConsumerWidget {
  const PromiseLine({super.key, this.onCanvas = false});

  /// On the hero canvas the pill goes translucent-light instead of tinted —
  /// the tier colors were mixed for surfaces, not for a deep teal.
  final bool onCanvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final promise = location.promiseLabel;
    if (promise == null || promise.isEmpty) return const SizedBox.shrink();

    final pair = context.zb.tier(location.deliveryType);
    final canvasFg = context.isDark ? ZbTokens.inkDark : Colors.white;
    final fg = onCanvas ? canvasFg : pair.fg;
    final bg = onCanvas ? canvasFg.withValues(alpha: 0.16) : pair.bg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 13, color: fg),
          Gap.w4,
          Text(
            promise,
            style: context.tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
