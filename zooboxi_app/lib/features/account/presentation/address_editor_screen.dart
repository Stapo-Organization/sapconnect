import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';
import '../../location/data/location_models.dart';
import '../../location/data/location_repository.dart';
import '../../location/presentation/widgets/pin_place_card.dart';
import '../data/account_models.dart';
import 'widgets/address_form.dart';
import 'widgets/map_pin_picker.dart';

/// What the editor hands back: the address as typed, and whether the customer
/// wants it kept. Persisting is the caller's job — the address book always
/// saves, checkout only saves when the toggle is on.
typedef AddressDraft = ({Address address, bool save});

/// Opens the address editor. One widget, two entry points: the address book
/// and the checkout address step.
Future<AddressDraft?> showAddressEditor(
  BuildContext context, {
  Address? initial,
  bool showSaveToggle = false,
  bool contactOptional = false,
  bool autoLocate = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<AddressDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddressEditorScreen(
        initial: initial,
        showSaveToggle: showSaveToggle,
        contactOptional: contactOptional,
        autoLocate: autoLocate,
      ),
    ),
  );
}

enum _Stage { pin, details }

class AddressEditorScreen extends ConsumerStatefulWidget {
  const AddressEditorScreen({
    super.key,
    this.initial,
    this.showSaveToggle = false,
    this.contactOptional = false,
    this.autoLocate = false,
  });

  final Address? initial;
  final bool showSaveToggle;

  /// Drops the recipient name/phone from the form and from validation — the
  /// welcome journey asks a customer who has no account yet where they live,
  /// and checkout collects who is receiving it later.
  final bool contactOptional;

  /// Centres the map on the device's own fix as soon as it opens, so the
  /// customer nudges a pin that is already near their street instead of
  /// dragging one across the country.
  final bool autoLocate;

  @override
  ConsumerState<AddressEditorScreen> createState() => _AddressEditorScreenState();
}

class _AddressEditorScreenState extends ConsumerState<AddressEditorScreen> {
  final _pinKey = GlobalKey<MapPinPickerState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _line = TextEditingController();
  final _building = TextEditingController();
  final _floor = TextEditingController();
  final _apartment = TextEditingController();
  final _customLabel = TextEditingController();

  late _Stage _stage = widget.initial?.lat == null ? _Stage.pin : _Stage.details;
  late AddressLabelChoice _labelChoice = _initialLabelChoice();
  LatLng? _point;
  bool _save = true;

  /// True once this screen has owned a live map in this session — the pin
  /// stage was opened, so the point under the pin is worth resolving and
  /// showing. An address opened straight onto its details is left alone: it
  /// was resolved the day it was pinned, and re-asking would only spend a
  /// request to overwrite the customer's own words with the geocoder's.
  bool _pinLive = false;

  /// True while the city/district on screen are the geocoder's guess rather
  /// than the customer's own words — only then may a new pin overwrite them.
  bool _cityIsAuto = false;

  /// The point whose answer has already been written into the form.
  PinPoint? _adopted;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final user = ref.read(sessionProvider).user;

    // `??` isn't enough: an address pinned during the welcome journey arrives
    // here with *empty* contact strings, not absent ones, and the account we
    // now have is exactly what should fill them.
    _name.text = _firstFilled([initial?.name, user?.name]);
    _phone.text = _localPhone(_firstFilled([initial?.phone, user?.phone]));
    _city.text = initial?.city ?? '';
    _district.text = initial?.district ?? '';
    _line.text = initial?.addressLine ?? '';
    _building.text = initial?.building ?? '';
    _floor.text = initial?.floor ?? '';
    _apartment.text = initial?.apartment ?? '';

    if (_labelChoice == AddressLabelChoice.other && (initial?.label ?? '').isNotEmpty) {
      _customLabel.text = initial!.label!;
    }

    _pinLive = _stage == _Stage.pin;

    if (initial?.lat != null && initial?.lng != null) {
      _point = LatLng(initial!.lat!, initial.lng!);
    } else {
      final current = ref.read(currentLocationProvider);
      if (current.hasCoordinates) _point = LatLng(current.lat!, current.lng!);
      _cityIsAuto = true;
      if (widget.autoLocate) {
        // After the first frame: the picker has to exist before it can be told
        // to centre itself.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final picker = _pinKey.currentState;
          if (mounted && picker != null) unawaited(picker.locate());
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _line.dispose();
    _building.dispose();
    _floor.dispose();
    _apartment.dispose();
    _customLabel.dispose();
    super.dispose();
  }

  AddressLabelChoice _initialLabelChoice() {
    final label = widget.initial?.label?.trim() ?? '';
    if (label.isEmpty) return AddressLabelChoice.home;
    const home = {'المنزل', 'منزل', 'البيت', 'home', 'Home'};
    const work = {'العمل', 'عمل', 'المكتب', 'work', 'Work'};
    if (home.contains(label)) return AddressLabelChoice.home;
    if (work.contains(label)) return AddressLabelChoice.work;
    return AddressLabelChoice.other;
  }

  static String _firstFilled(List<String?> candidates) =>
      candidates.firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => '')!;

  /// `+9665…` / `9665…` → `05…`, so the field shows what people actually type.
  static String _localPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('966') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  /// Adopts the geocoder's answer for the point under the pin — once per
  /// point.
  ///
  /// Once, because the customer types over these fields: «حي الياسمين» where
  /// the geocoder said «النرجس» is a correction, and re-adopting on the next
  /// rebuild would quietly take it back. A *new* pin is a new question, and
  /// that one may answer again.
  ///
  /// Never over words that were the customer's to begin with — an address
  /// opened with a city already in it keeps it.
  void _adoptPlace(PinPoint point, ResolveResult result) {
    if (!mounted || _adopted == point) return;
    _adopted = point;
    if (!_cityIsAuto && _city.text.trim().isNotEmpty) return;
    // The controllers notify their own fields; there is no rebuild to ask for.
    _city.text = result.city ?? _city.text;
    _district.text = result.district ?? _district.text;
    _cityIsAuto = true;
  }

  void _confirmPin() {
    Haptics.selection();
    final point = _pinKey.currentState?.value ?? _point;
    if (point == null) return;
    setState(() {
      _point = point;
      _stage = _Stage.details;
    });
  }

  void _reopenMap() {
    setState(() {
      _stage = _Stage.pin;
      _pinLive = true;
    });
  }

  void _submit() {
    final l = L.of(context);
    final point = _point;

    if (point == null) {
      AppToast.error(context, l.addressPinRequired);
      _reopenMap();
      return;
    }
    if (!widget.contactOptional) {
      if (_name.text.trim().isEmpty) {
        AppToast.error(context, l.addressNameRequired);
        return;
      }
      if (normalizeSaudiPhone(_phone.text) == null) {
        AppToast.error(context, l.authPhoneInvalid);
        return;
      }
    }
    if (_city.text.trim().isEmpty) {
      AppToast.error(context, l.addressCityRequired);
      return;
    }
    // Everything written is optional — the pin and its coordinates are the
    // address; building, flat and description only make the driver faster.

    Haptics.light();
    final label = switch (_labelChoice) {
      AddressLabelChoice.home => l.addressLabelHome,
      AddressLabelChoice.work => l.addressLabelWork,
      AddressLabelChoice.other => _customLabel.text.trim(),
    };

    Navigator.of(context).pop((
      address: Address(
        id: widget.initial?.id ?? '',
        label: label.isEmpty ? null : label,
        name: _name.text.trim(),
        phone: normalizeSaudiPhone(_phone.text) ?? _phone.text.trim(),
        city: _city.text.trim(),
        district: _district.text.trim().isEmpty ? null : _district.text.trim(),
        addressLine: _line.text.trim(),
        building: _trimmedOrNull(_building),
        floor: _trimmedOrNull(_floor),
        apartment: _trimmedOrNull(_apartment),
        lat: point.latitude,
        lng: point.longitude,
        isDefault: widget.initial?.isDefault ?? false,
      ),
      save: widget.showSaveToggle ? _save : true,
    ));
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // A prefilled draft that was never persisted is still a *new* address —
    // the onboarding pin arrives at checkout with everything typed and no id.
    final editing = widget.initial?.isSaved ?? false;

    // The point under the pin, as the store reads it. Watched only once this
    // screen has owned a live map, so opening a saved address to fix a flat
    // number costs nothing.
    final point = _point;
    final pin = _pinLive && point != null
        ? PinPoint(point.latitude, point.longitude)
        : null;
    final place = pin == null ? null : ref.watch(pinPlaceProvider(pin));
    final resolved = place?.asData?.value;
    if (pin != null && resolved != null && _adopted != pin) {
      // After the frame: the form fields being filled are on screen right now.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _adoptPlace(pin, resolved));
    }

    return Scaffold(
      // The map runs to the very top of the screen, under a transparent bar:
      // a pin stage is a *place*, and a header bar drawn across it makes it a
      // form with a picture on it.
      extendBodyBehindAppBar: _stage == _Stage.pin,
      appBar: AppBar(
        backgroundColor: _stage == _Stage.pin ? Colors.transparent : null,
        surfaceTintColor: _stage == _Stage.pin ? Colors.transparent : null,
        elevation: 0,
        title: Text(
          _stage == _Stage.pin
              ? l.addressPinTitle
              : editing
                  ? l.addressEditTitle
                  : l.addressNewTitle,
        ),
      ),
      body: _stage == _Stage.pin
          ? _buildPinStage(context)
          : _buildDetailsStage(context, place),
    );
  }

  /// The map, and nothing between the customer and it.
  ///
  /// The hint floats over the top of the tiles and the answer floats over the
  /// bottom — «حي الملك فهد، الرياض · الساعة ١٠:٣٠ م» — so the whole screen is
  /// the map, and the two things a person needs to read are on top of it.
  Widget _buildPinStage(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: MapPinPicker(
            key: _pinKey,
            initial: _point,
            // Every settle is a fresh question to the store, and the card at
            // the bottom answers it while the customer is still deciding.
            onSettled: (point) {
              if (!mounted) return;
              setState(() => _point = point);
            },
            controlsPadding: EdgeInsets.only(bottom: 150 + bottomInset),
          ),
        ),
        PositionedDirectional(
          top: topInset + 4,
          start: 16,
          end: 16,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(ZbTokens.rPill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  l.addressPinHint,
                  textAlign: TextAlign.center,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 12,
          end: 12,
          bottom: 12 + bottomInset,
          child: PinPlaceCard(
            point: _point,
            action: FilledButton.icon(
              onPressed: _confirmPin,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(l.addressPinConfirm),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStage(BuildContext context, AsyncValue<ResolveResult>? place) {
    final l = L.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _MapPreview(point: _point, onTap: _reopenMap),
              Gap.h20,
              AddressForm(
                name: _name,
                phone: _phone,
                city: _city,
                district: _district,
                line: _line,
                building: _building,
                floor: _floor,
                apartment: _apartment,
                customLabel: _customLabel,
                labelChoice: _labelChoice,
                onLabelChoice: (choice) => setState(() => _labelChoice = choice),
                resolving: place?.isLoading ?? false,
                contactHidden: widget.contactOptional,
              ),
              if (widget.showSaveToggle) ...[
                Gap.h8,
                SwitchListTile.adaptive(
                  value: _save,
                  onChanged: (value) => setState(() => _save = value),
                  title: Text(l.addressSaveToggle, style: context.tt.bodyMedium),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        _BottomBar(
          child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            child: Text(l.actionSave),
          ),
        ),
      ],
    );
  }
}

/// The chosen point, still and un-draggable, with the way back to the map.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.point, required this.onTap});

  final LatLng? point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return PressScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            child: MapPinPicker(initial: point, height: 150, interactive: false),
          ),
          PositionedDirectional(
            end: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(ZbTokens.rPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_location_alt_rounded, size: 15, color: cs.primary),
                  Gap.w4,
                  Text(
                    l.addressPinChange,
                    style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: child,
        ),
      ),
    );
  }
}
