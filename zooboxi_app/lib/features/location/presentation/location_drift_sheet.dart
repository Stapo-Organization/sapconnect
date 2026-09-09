import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/account_models.dart';
import '../../account/presentation/widgets/map_pin_picker.dart';
import '../data/address_intake.dart';
import '../data/location_repository.dart';
import 'location_sheet.dart';
import 'widgets/pin_place_card.dart';

/// "You seem to be somewhere new" — offered, never imposed, and offered **on a
/// map**.
///
/// A device fix is a claim, not an address: it can land on the building behind
/// yours, or on the road outside the compound. Naming the neighbourhood and
/// asking yes/no made the customer accept or reject a point they could not
/// see. So the map opens here, centred on the fix, draggable — the pin is
/// corrected in the same breath as it is offered, and the card underneath says
/// what is under it and when we would arrive there.
///
/// Three answers, in the order a person wants them: deliver here, keep this
/// place as an address of its own, or leave the saved address alone.
Future<void> showLocationDriftSheet(BuildContext context, LocationDrift drift) {
  return showZbSheet<void>(
    context,
    // The map owns vertical drags inside this sheet; the sheet closes by its
    // own buttons and by the backdrop.
    enableDrag: false,
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
  /// Where the pin actually is — the device's fix until the customer nudges
  /// it, and their correction from then on. Every action reads this, never
  /// the raw fix.
  late LatLng _point = LatLng(widget.drift.lat, widget.drift.lng);

  bool _busy = false;

  void _close() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  /// Deliver to the pin as it stands. No address is kept: this is where the
  /// customer *is*, and where they are today is not «المنزل».
  Future<void> _useHere() async {
    if (_busy) return;
    Haptics.light();
    setState(() => _busy = true);
    final ok = await ref
        .read(locationProvider.notifier)
        .resolve(_point.latitude, _point.longitude);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppToast.error(context, L.of(context).locationResolveFailed);
      return;
    }
    unawaited(Haptics.success());
    _close();
  }

  /// Keep this place. The editor opens on the pin the customer just corrected,
  /// with the city and district the store already resolved for it, so the only
  /// thing left to write is what to call it.
  Future<void> _saveAsAddress() async {
    if (_busy) return;
    Haptics.light();
    final loggedIn = ref.read(sessionProvider).isAuthenticated;
    final place = ref
        .read(pinPlaceProvider(PinPoint(_point.latitude, _point.longitude)))
        .asData
        ?.value;

    final draft = await ref.read(addressEditorProvider)(
      context,
      initial: Address(
        id: '',
        name: '',
        phone: '',
        city: place?.city ?? '',
        district: place?.district,
        addressLine: '',
        lat: _point.latitude,
        lng: _point.longitude,
      ),
      contactOptional: !loggedIn,
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final outcome = await adoptAddress(ref, draft.address);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == AddressIntake.refused) {
      AppToast.error(context, L.of(context).locationAddressNotSaved);
      return;
    }
    _close();
  }

  /// Leave the saved address alone — and remember not to ask about this spot
  /// again today. The *fix* is what gets waved away, not the corrected pin:
  /// tomorrow's check compares against where the phone is, not where the
  /// customer dragged to.
  Future<void> _keep() async {
    if (_busy) return;
    Haptics.selection();
    await ref.read(localStoreProvider).setDriftDismissed({
      'lat': widget.drift.lat,
      'lng': widget.drift.lng,
      'at': DateTime.now().toIso8601String(),
    });
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final saved = ref.watch(currentLocationProvider);
    final savedLabel = [
      if (saved.label?.isNotEmpty == true) saved.label!,
      ?saved.detailLabel(locale),
    ].join(' · ');

    // A third of the screen: enough map to recognise a block on, short enough
    // that the three answers are all still above the fold.
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(170.0, 260.0);

    return BottomSheetScaffold(
      title: l.driftTitle,
      subtitle: l.driftAdjustHint,
      trailing: IconButton(
        onPressed: _busy ? null : _close,
        icon: const Icon(Icons.close_rounded),
        tooltip: l.actionClose,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (savedLabel.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.bookmark_rounded, size: 15, color: cs.onSurfaceVariant),
                Gap.w6,
                Expanded(
                  child: Text(
                    l.driftSavedNow(savedLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            Gap.h12,
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            child: MapPinPicker(
              initial: _point,
              height: mapHeight,
              // A sheet this size has no room for a zoom column beside the
              // pin; pinching is the gesture at this scale.
              showZoom: false,
              onSettled: (point) {
                if (mounted) setState(() => _point = point);
              },
            ),
          ),
          Gap.h12,
          PinPlaceCard(point: _point),
          Gap.h16,
          FilledButton.icon(
            onPressed: _busy ? null : _useHere,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.near_me_rounded, size: 20),
            label: Text(l.driftUseHere),
          ),
          Gap.h8,
          OutlinedButton.icon(
            onPressed: _busy ? null : _saveAsAddress,
            icon: const Icon(Icons.bookmark_add_outlined, size: 19),
            label: Text(l.driftSaveAsNew),
          ),
          Gap.h4,
          TextButton(
            onPressed: _busy ? null : _keep,
            child: Text(l.driftKeep),
          ),
        ],
      ),
    );
  }
}
