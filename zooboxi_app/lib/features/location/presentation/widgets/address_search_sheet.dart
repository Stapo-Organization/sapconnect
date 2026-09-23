import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/account_models.dart';
import '../../../account/data/addresses_controller.dart';
import '../../data/location_models.dart';
import '../../data/location_repository.dart';

/// What the search hands back to the map: a point to fly to, or «use my
/// location».
sealed class AddressSearchPick {
  const AddressSearchPick();
}

class PickPoint extends AddressSearchPick {
  const PickPoint(this.point);
  final LatLng point;
}

class PickMyLocation extends AddressSearchPick {
  const PickMyLocation();
}

/// Opens the address search over the map. [near] biases the suggestions to
/// where the map is looking.
Future<AddressSearchPick?> showAddressSearch(BuildContext context, {LatLng? near}) =>
    showModalBottomSheet<AddressSearchPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: _AddressSearch(near: near)),
    );

class _AddressSearch extends ConsumerStatefulWidget {
  const _AddressSearch({this.near});

  final LatLng? near;

  @override
  ConsumerState<_AddressSearch> createState() => _AddressSearchState();
}

class _AddressSearchState extends ConsumerState<_AddressSearch> {
  final _query = TextEditingController();

  /// One search, one session: Google bills a typed search and the place it
  /// ends on as a single session when they carry the same token.
  final String _session = const Uuid().v4();
  Timer? _debounce;
  int _ticket = 0;
  bool _loading = false;
  bool _failed = false;
  List<PlaceSuggestion> _results = const [];
  bool _opening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() => _loading = true);
    // A quarter second after the last key: fast enough to feel live, slow
    // enough that «النرجس» is one request and not six.
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _search(String q) async {
    final ticket = ++_ticket;
    try {
      final results = await ref.read(locationRepositoryProvider).search(
            q,
            lat: widget.near?.latitude,
            lng: widget.near?.longitude,
            session: _session,
          );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _results = results;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _open(PlaceSuggestion s) async {
    if (_opening) return;
    Haptics.selection();
    setState(() => _opening = true);
    try {
      final place = await ref.read(locationRepositoryProvider).place(s.id, session: _session);
      if (!mounted) return;
      Navigator.of(context).pop(PickPoint(LatLng(place.lat, place.lng)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final q = _query.text.trim();
    final authed = ref.watch(isAuthenticatedProvider);
    final saved = authed
        ? (ref.watch(addressesControllerProvider).value ?? const <Address>[])
            .where((a) => a.lat != null && a.lng != null)
            .toList()
        : const <Address>[];

    final rows = <Widget>[
      _Row(
        icon: Icons.my_location_rounded,
        solid: true,
        title: l.addressSearchUseLocation,
        onTap: () {
          Haptics.selection();
          Navigator.of(context).pop(const PickMyLocation());
        },
      ),
      if (q.length < 2 && saved.isNotEmpty) ...[
        _Heading(l.addressSearchSaved),
        for (final a in saved)
          _Row(
            icon: Icons.home_rounded,
            title: (a.label ?? '').isNotEmpty ? a.label! : a.addressLine,
            subtitle: a.summaryFor(Localizations.localeOf(context).languageCode),
            onTap: () {
              Haptics.selection();
              Navigator.of(context).pop(PickPoint(LatLng(a.lat!, a.lng!)));
            },
          ),
      ],
      if (q.length >= 2) ...[
        _Heading(l.addressSearchResults),
        if (_results.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              _failed ? l.addressSearchFailed : l.addressSearchEmpty,
              style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        for (final s in _results)
          _Row(
            icon: _iconFor(s.kind),
            title: s.main,
            highlight: q,
            subtitle: s.secondary,
            trailing: _distance(l, context, s.distanceM),
            onTap: () => _open(s),
          ),
        if (_results.isNotEmpty) const _PoweredByGoogle(),
      ],
    ];

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(ZbTokens.rXl)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    style: context.tt.titleMedium,
                    decoration: InputDecoration(
                      hintText: l.addressSearchHint,
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      prefixIcon: Icon(Icons.search_rounded, color: cs.primary),
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                _query.clear();
                                _onChanged('');
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZbTokens.rMd),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZbTokens.rMd),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZbTokens.rMd),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.actionCancel)),
              ],
            ),
          ),
          if (_loading || _opening) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'area' => Icons.map_outlined,
        'street' => Icons.signpost_outlined,
        'park' => Icons.park_outlined,
        'food' => Icons.restaurant_outlined,
        'mosque' => Icons.mosque_outlined,
        'school' => Icons.school_outlined,
        'health' => Icons.local_hospital_outlined,
        _ => Icons.storefront_outlined,
      };

  static String? _distance(L l, BuildContext context, int? metres) {
    if (metres == null) return null;
    final locale = Localizations.localeOf(context).languageCode;
    if (metres < 1000) return l.distanceM(Fmt.number(metres, locale: locale, decimals: 0));
    return l.distanceKm(Fmt.number(metres / 1000, locale: locale, decimals: 1));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(
          text,
          style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w800),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.highlight,
    this.solid = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? highlight;
  final bool solid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final titleStyle = context.tt.titleSmall?.copyWith(fontWeight: solid ? FontWeight.w800 : FontWeight.w700, color: solid ? cs.primary : null);
    final h = highlight;
    final at = h == null || h.isEmpty ? -1 : title.indexOf(h);
    final titleWidget = at < 0
        ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: title.substring(0, at)),
              TextSpan(
                text: title.substring(at, at + h!.length),
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900),
              ),
              TextSpan(text: title.substring(at + h.length)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          );
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: solid ? cs.primary : (context.isDark ? cs.surfaceContainerHigh : ZbTokens.tealTintSoft),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: solid ? cs.onPrimary : cs.primary),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget,
                  if ((subtitle ?? '').isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              Gap.w8,
              Text(trailing!, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Google's terms: a list of its places not drawn on its map carries its name.
class _PoweredByGoogle extends StatelessWidget {
  const _PoweredByGoogle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text.rich(
              const TextSpan(text: 'powered by ', children: [
                TextSpan(text: 'Google', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
        ),
      );
}
