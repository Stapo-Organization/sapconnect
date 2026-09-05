import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/providers.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';

/// "You seem to be somewhere new" — offered, never imposed. One tap switches
/// delivery to the device's spot; the other keeps the saved address and
/// remembers not to ask about this spot again today.
Future<void> showLocationDriftSheet(BuildContext context, LocationDrift drift) {
  return showZbSheet<void>(
    context,
    builder: (_) => _DriftSheet(drift: drift),
  );
}

class _DriftSheet extends ConsumerStatefulWidget {
  const _DriftSheet({required this.drift});

  final LocationDrift drift;

  @override
  ConsumerState<_DriftSheet> createState() => _DriftSheetState();
}

class _DriftSheetState extends ConsumerState<_DriftSheet> {
  bool _busy = false;

  Future<void> _useHere() async {
    if (_busy) return;
    Haptics.light();
    setState(() => _busy = true);
    final ok = await ref
        .read(locationProvider.notifier)
        .resolve(widget.drift.lat, widget.drift.lng);
    if (!mounted) return;
    if (ok) unawaited(Haptics.success());
    Navigator.of(context).pop();
  }

  Future<void> _keep() async {
    Haptics.selection();
    await ref.read(localStoreProvider).setDriftDismissed({
      'lat': widget.drift.lat,
      'lng': widget.drift.lng,
      'at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final saved = ref.watch(currentLocationProvider);
    final here = widget.drift.label(locale) ?? '';
    final savedLabel = saved.detailLabel(locale) ?? '';

    return BottomSheetScaffold(
      title: l.driftTitle,
      subtitle: l.driftBody(here, savedLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.drift.promiseLabel != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(ZbTokens.rMd),
              ),
              child: Row(
                children: [
                  ZbIcon(ZbIconKind.pin, size: 22, fill: 1, ink: cs.onPrimaryContainer),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      '$here — ${widget.drift.promiseLabel}',
                      style: context.tt.titleSmall?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            Gap.h16,
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _useHere,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location_rounded, size: 20),
            label: Text(l.driftUseHere),
          ),
          Gap.h8,
          OutlinedButton(
            onPressed: _busy ? null : _keep,
            child: Text(l.driftKeep),
          ),
          Gap.h8,
        ],
      ),
    );
  }
}
