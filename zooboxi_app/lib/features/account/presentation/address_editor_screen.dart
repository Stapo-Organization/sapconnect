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
import '../../location/data/location_repository.dart';
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
}) {
  return Navigator.of(context, rootNavigator: true).push<AddressDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddressEditorScreen(initial: initial, showSaveToggle: showSaveToggle),
    ),
  );
}

enum _Stage { pin, details }

class AddressEditorScreen extends ConsumerStatefulWidget {
  const AddressEditorScreen({super.key, this.initial, this.showSaveToggle = false});

  final Address? initial;
  final bool showSaveToggle;

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
  final _customLabel = TextEditingController();

  late _Stage _stage = widget.initial?.lat == null ? _Stage.pin : _Stage.details;
  late AddressLabelChoice _labelChoice = _initialLabelChoice();
  LatLng? _point;
  bool _resolving = false;
  bool _save = true;

  /// True while the city/district on screen are the geocoder's guess rather
  /// than the customer's own words — only then may a new pin overwrite them.
  bool _cityIsAuto = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final user = ref.read(sessionProvider).user;

    _name.text = initial?.name ?? user?.name ?? '';
    _phone.text = _localPhone(initial?.phone ?? user?.phone ?? '');
    _city.text = initial?.city ?? '';
    _district.text = initial?.district ?? '';
    _line.text = initial?.addressLine ?? '';

    if (_labelChoice == AddressLabelChoice.other && (initial?.label ?? '').isNotEmpty) {
      _customLabel.text = initial!.label!;
    }

    if (initial?.lat != null && initial?.lng != null) {
      _point = LatLng(initial!.lat!, initial.lng!);
    } else {
      final current = ref.read(currentLocationProvider);
      if (current.hasCoordinates) _point = LatLng(current.lat!, current.lng!);
      _cityIsAuto = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _district.dispose();
    _line.dispose();
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

  /// `+9665…` / `9665…` → `05…`, so the field shows what people actually type.
  static String _localPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('966') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  /// Asks the server what place the pin landed on. It is the same resolver the
  /// header chip uses, so the city string the order carries is one the store
  /// already knows how to route.
  Future<void> _resolvePoint(LatLng point) async {
    if (!mounted) return;
    setState(() {
      _point = point;
      _resolving = true;
    });
    try {
      final result = await ref
          .read(locationRepositoryProvider)
          .resolve(lat: point.latitude, lng: point.longitude);
      if (!mounted) return;
      setState(() {
        _resolving = false;
        if (_cityIsAuto || _city.text.trim().isEmpty) {
          _city.text = result.city ?? _city.text;
          _district.text = result.district ?? _district.text;
          _cityIsAuto = true;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _confirmPin() {
    Haptics.selection();
    final point = _pinKey.currentState?.value ?? _point;
    if (point == null) return;
    setState(() => _stage = _Stage.details);
    unawaited(_resolvePoint(point));
  }

  void _submit() {
    final l = L.of(context);
    final point = _point;

    if (point == null) {
      AppToast.error(context, l.addressPinRequired);
      setState(() => _stage = _Stage.pin);
      return;
    }
    if (_name.text.trim().isEmpty) {
      AppToast.error(context, l.addressNameRequired);
      return;
    }
    if (normalizeSaudiPhone(_phone.text) == null) {
      AppToast.error(context, l.authPhoneInvalid);
      return;
    }
    if (_city.text.trim().isEmpty) {
      AppToast.error(context, l.addressCityRequired);
      return;
    }
    if (_line.text.trim().isEmpty) {
      AppToast.error(context, l.addressLineRequired);
      return;
    }

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
        lat: point.latitude,
        lng: point.longitude,
        isDefault: widget.initial?.isDefault ?? false,
      ),
      save: widget.showSaveToggle ? _save : true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final editing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stage == _Stage.pin
              ? l.addressPinTitle
              : editing
                  ? l.addressEditTitle
                  : l.addressNewTitle,
        ),
      ),
      body: _stage == _Stage.pin ? _buildPinStage(context) : _buildDetailsStage(context),
    );
  }

  Widget _buildPinStage(BuildContext context) {
    final l = L.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            l.addressPinHint,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: MapPinPicker(
            key: _pinKey,
            initial: _point,
            onSettled: (point) => _point = point,
          ),
        ),
        _BottomBar(
          child: FilledButton.icon(
            onPressed: _confirmPin,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(l.addressPinConfirm),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStage(BuildContext context) {
    final l = L.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _MapPreview(
                point: _point,
                onTap: () => setState(() => _stage = _Stage.pin),
              ),
              Gap.h20,
              AddressForm(
                name: _name,
                phone: _phone,
                city: _city,
                district: _district,
                line: _line,
                customLabel: _customLabel,
                labelChoice: _labelChoice,
                onLabelChoice: (choice) => setState(() => _labelChoice = choice),
                resolving: _resolving,
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
