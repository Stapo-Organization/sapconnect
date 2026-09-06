import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/app_toast.dart';
import '../../account/data/account_models.dart';
import '../../account/data/addresses_controller.dart';
import '../../account/presentation/address_editor_screen.dart';
import '../../auth/presentation/auth_sheet.dart';
import '../../catalog/data/catalog_models.dart';
import 'delivery_when.dart';

/// How this sheet opens the address editor. Indirection exists for one
/// reason: the editor owns a live map, and the paths worth testing here are
/// what the sheet does with what it *returns* — a refused save, a guest's
/// address, a customer who swiped the sheet away mid-request.
typedef AddressEditorOpener = Future<AddressDraft?> Function(
  BuildContext context, {
  Address? initial,
  bool contactOptional,
  bool autoLocate,
});

final addressEditorProvider = Provider<AddressEditorOpener>((ref) => showAddressEditor);

/// Opens the delivery-location sheet — the in-store way to change where we
/// deliver, and the only place in the shop that owns "where does this go?".
Future<void> showLocationSheet(BuildContext context) {
  return showZbSheet<void>(context, builder: (_) => const LocationSheet());
}

/// «التوصيل إلى» — the customer's addresses, and a map.
///
/// There is no city list here any more. A city is not an address: it gets the
/// catalogue roughly right and then fails at the only moment that matters,
/// which is a driver looking for a door. Every point this sheet sets comes
/// from a pin on a map with the details written beside it, and it is **kept** —
/// in the customer's address book when they have an account, on the device
/// when they do not — so the second order never asks the same question again.
class LocationSheet extends ConsumerStatefulWidget {
  const LocationSheet({super.key});

  @override
  ConsumerState<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<LocationSheet> {
  /// The address currently being resolved into a delivery promise, if any.
  /// While one is in flight every row is inert: two taps racing each other
  /// end with the store delivering to whichever request happened to finish
  /// second, and with this sheet popping twice.
  String? _applying;

  /// True while the editor's result is being saved and resolved.
  bool _saving = false;

  bool get _busy => _applying != null || _saving;

  /// Pops this sheet, and only this sheet. After the first pop the state stays
  /// mounted for the length of the exit animation, so a second call would take
  /// the page underneath with it.
  void _close() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  /// Sets a saved address as the delivery point.
  ///
  /// An address saved before the map existed can have no pin. Rather than
  /// silently delivering to its city centre, it opens on the map — the
  /// customer drops the pin once and it is a real address from then on.
  Future<void> _use(Address address) async {
    if (_busy) return;
    if (address.lat == null || address.lng == null) {
      await _openEditor(initial: address);
      return;
    }

    Haptics.selection();
    setState(() => _applying = address.id);
    final ok = await ref.read(locationProvider.notifier).resolve(
          address.lat!,
          address.lng!,
          addressId: address.id,
          label: address.label,
        );
    if (!mounted) return;
    setState(() => _applying = null);
    if (!ok) {
      AppToast.error(context, L.of(context).locationResolveFailed);
      return;
    }
    _close();
  }

  /// The one way in: a pin on a map, the details beside it, and it is kept.
  ///
  /// Every notifier is read *before* the awaits. The customer can swipe this
  /// sheet away while the save is in flight, and an address they just pinned
  /// must survive that — reaching for `ref` through a disposed widget would
  /// throw exactly where the recovery path lives.
  Future<void> _openEditor({Address? initial}) async {
    if (_busy) return;
    Haptics.light();

    final loggedIn = ref.read(sessionProvider).isAuthenticated;
    final book = ref.read(addressesControllerProvider.notifier);
    final store = ref.read(localStoreProvider);
    final location = ref.read(locationProvider.notifier);
    final activeId = ref.read(locationProvider).location.addressId;

    final draft = await ref.read(addressEditorProvider)(
      context,
      initial: initial,
      // A guest has no account to attach a name and a phone to yet; checkout
      // asks for those at the moment they are actually needed.
      contactOptional: !loggedIn,
      autoLocate: initial?.lat == null,
    );
    if (draft == null || !mounted) return;

    setState(() => _saving = true);
    final address = draft.address;
    Address? stored;
    var refused = false;
    if (loggedIn) {
      try {
        stored = await book.save(address);
      } catch (_) {
        refused = true;
      }
    }

    // A refused save must never cost the customer the address they just
    // pinned: the device keeps it and checkout picks it up. It must also
    // never keep the id of the entry the server did NOT update — an order
    // sent with that id would go to the address's OLD pin.
    if (stored == null) {
      await store.setPendingAddress(address.toJson());
    }

    final lat = stored?.lat ?? address.lat;
    final lng = stored?.lng ?? address.lng;
    // Editing the address we are already delivering to is the book's own
    // business — AddressesController.save() moves the point with it, and
    // resolving again here would only spend a second round trip.
    final alreadyMoved = stored != null && stored.id == activeId;
    if (lat != null && lng != null && !alreadyMoved) {
      await location.resolve(
        lat,
        lng,
        addressId: stored?.id,
        label: stored?.label ?? address.label,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (refused) {
      AppToast.error(context, L.of(context).locationAddressNotSaved);
      return;
    }
    _close();
  }

  /// Signing in from here has one promise to keep: the address the guest just
  /// pinned belongs to them now, so it moves from the device into their book
  /// instead of sitting there invisible until checkout.
  Future<void> _signIn() async {
    if (_busy) return;
    final l = L.of(context);
    final ok = await showAuthSheet(context, reason: l.locationSignInReason);
    if (!ok || !mounted) return;

    final store = ref.read(localStoreProvider);
    final pending = store.pendingAddress;
    if (pending == null) return;

    final address = Address.fromJson(pending);
    if (address.lat == null || address.lng == null) return;

    setState(() => _saving = true);
    // Everything the migration needs, read while the widget is certainly
    // alive: it must finish even if the customer swipes the sheet away.
    final user = ref.read(sessionProvider).user;
    final book = ref.read(addressesControllerProvider.notifier);
    final location = ref.read(locationProvider.notifier);
    final current = ref.read(locationProvider).location;
    final settled = ref.read(addressesControllerProvider.future);

    var refused = false;
    try {
      // Signing in rebuilds the book, which fires its own fetch. Let that
      // land first: arriving after the save, it would answer with the list
      // as it was a moment ago and the address would vanish again.
      await settled;
    } catch (_) {
      // An empty or failed book is still a book to save into.
    }

    try {
      final stored = await book.save(address.copyWith(
        name: address.name.isEmpty ? (user?.name ?? '') : address.name,
        phone: address.phone.isEmpty ? (user?.phone ?? '') : address.phone,
      ));
      await store.setPendingAddress(null);
      // If we are already delivering to that very spot, it now has an id — so
      // the sheet can tick it and checkout can name it. Only then: signing in
      // must never move the order somewhere the customer did not choose.
      if (current.addressId == null && _samePoint(stored, current)) {
        await location.resolve(
          stored.lat!,
          stored.lng!,
          addressId: stored.id,
          label: stored.label,
        );
      }
    } catch (_) {
      refused = true;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (refused) AppToast.error(context, l.locationAddressNotSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = ref.watch(locationProvider);
    final loggedIn = ref.watch(sessionProvider.select((s) => s.isAuthenticated));
    final book = loggedIn
        ? ref.watch(addressesControllerProvider)
        : const AsyncValue<List<Address>>.data([]);
    final addresses = book.asData?.value ?? const <Address>[];

    return BottomSheetScaffold(
      title: l.locationSheetTitle,
      subtitle: addresses.isEmpty ? l.locationSheetSubtitle : l.locationSheetSubtitlePick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.location.isSet) ...[
            _CurrentPoint(location: state.location),
            Gap.h16,
          ],
          if (loggedIn) ...[
            if (book.isLoading && addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              )
            else if (book.hasError && addresses.isEmpty) ...[
              _BookError(onRetry: () => ref.invalidate(addressesControllerProvider)),
              Gap.h16,
            ] else if (addresses.isNotEmpty) ...[
              _SectionLabel(l.locationMyAddresses),
              Gap.h8,
              for (final address in addresses) ...[
                _AddressRow(
                  address: address,
                  active: _isActive(address, state.location),
                  busy: _applying == address.id,
                  enabled: !_busy,
                  onTap: () => _use(address),
                  onEdit: () => _openEditor(initial: address),
                ),
                Gap.h8,
              ],
              Gap.h8,
            ],
          ],
          FilledButton.icon(
            onPressed: _busy || state.isBusy ? null : () => _openEditor(),
            icon: const Icon(Icons.map_outlined, size: 20),
            label: Text(addresses.isEmpty ? l.locationSetOnMap : l.locationAddOnMap),
          ),
          if (!loggedIn) ...[
            Gap.h8,
            TextButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.bookmark_border_rounded, size: 18),
              label: Text(l.locationSignInToSave),
            ),
          ],
          Gap.h8,
        ],
      ),
    );
  }

  /// The row the customer is being delivered to. Matched by id, and by the
  /// coordinates for a point set before ids were carried — a returning
  /// customer should still see their home ticked.
  static bool _isActive(Address address, ZbLocation location) {
    if (location.addressId != null && location.addressId!.isNotEmpty) {
      return location.addressId == address.id;
    }
    return _samePoint(address, location);
  }

  /// The same doorstep, within about twenty metres — the width of a villa.
  static bool _samePoint(Address address, ZbLocation location) {
    final lat = address.lat;
    final lng = address.lng;
    if (lat == null || lng == null || !location.hasCoordinates) return false;
    return (lat - location.lat!).abs() < 0.0002 && (lng - location.lng!).abs() < 0.0002;
  }
}

/// Where the order is going right now, and when it lands — the same sentence
/// the header shows, so opening this sheet confirms rather than surprises.
class _CurrentPoint extends ConsumerWidget {
  const _CurrentPoint({required this.location});

  final ZbLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final detail = location.detailLabel(locale) ?? '';
    final when = deliveryWhenLabel(context, location: location);

    return Container(
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
                  [
                    if (location.label?.isNotEmpty == true) location.label!,
                    if (detail.isNotEmpty) detail,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.titleSmall?.copyWith(color: cs.onPrimaryContainer),
                ),
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: context.tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The book refused to load. Saying so — with a way to ask again — is the
/// difference between "the network blinked" and "my addresses are gone".
class _BookError extends StatelessWidget {
  const _BookError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: cs.onErrorContainer),
          Gap.w8,
          Expanded(
            child: Text(
              l.locationAddressesFailed,
              style: context.tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: context.tt.labelLarge?.copyWith(
            color: context.cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// One saved address, as a place rather than as a form: what the customer
/// calls it, the street under it, and a tick when the order is going there.
class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.active,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onEdit,
  });

  final Address address;
  final bool active;

  /// This row is the one being resolved right now.
  final bool busy;

  /// False while any row is resolving — a second choice mid-flight would race
  /// the first and leave the store delivering to the loser.
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  IconData get _icon => switch (address.label) {
        final String label when label.contains('عمل') || label.toLowerCase().contains('work') =>
          Icons.work_outline_rounded,
        final String label when label.isNotEmpty => Icons.home_outlined,
        _ => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final title = address.label?.isNotEmpty == true ? address.label! : address.summary;
    final detail = [
      address.addressLine,
      if (address.label?.isNotEmpty == true) address.summary,
    ].where((e) => e.trim().isNotEmpty).join(locale == 'ar' ? '، ' : ', ');

    return Material(
      color: active ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(ZbTokens.rMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 6, top: 10, bottom: 10),
          child: Row(
            children: [
              Icon(_icon, size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
              Gap.w10,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (address.isDefault) ...[
                          Gap.w6,
                          Text(
                            l.addressDefaultBadge,
                            style: context.tt.labelSmall?.copyWith(color: cs.primary),
                          ),
                        ],
                      ],
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else if (active)
                Icon(Icons.check_circle_rounded, size: 20, color: cs.primary)
              else
                IconButton(
                  onPressed: enabled ? onEdit : null,
                  icon: Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
                  tooltip: l.addressEditTitle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header chip: where this is going, and **when it lands**. Tapping it
/// opens the sheet. On a store where the same product has three different
/// answers depending on where you stand, this is the most important control
/// on Home.
///
/// Two lines, in the order a person asks the questions: «يوصلك في المنزل»,
/// then «حي الملك فهد، الرياض · الساعة 10:30 م». The arrival time is part of
/// the address line rather than a badge beside it, because the address and
/// the hour are one fact — this parcel, at this door, by then.
class LocationChip extends ConsumerWidget {
  const LocationChip({super.key, this.onCanvas = false, this.scope});

  /// Renders the chip for the hero canvas: every stroke turns light, since
  /// the canvas colors are deep by design.
  final bool onCanvas;

  /// The active storefront's promise, so the زوبكسي tab says tomorrow even
  /// while standing inside an express zone.
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final location = ref.watch(currentLocationProvider);
    // The full line a person recognises as *their* address: district, city.
    final detail = location.detailLabel(locale);
    final isSet = detail != null && detail.isNotEmpty;
    final when = isSet
        ? deliveryWhenLabel(context, scope: scope, location: location)
        : '';

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
              // Filled once we know where they are — an empty pin is the
              // app asking, a filled one is the app answering.
              ZbIcon(
                ZbIconKind.pin,
                size: 18,
                fill: isSet ? 1 : 0,
                ink: accent,
              ),
              Gap.w6,
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // What the customer calls the place they saved, when
                      // they named one — «يوصلك في العمل» is a better answer
                      // than a guess, and the guess only stands in for an
                      // address set before labels existed.
                      !isSet
                          ? l.locationDeliverTo
                          : (location.label?.isNotEmpty == true
                              ? l.locationArrivesAtNamed(location.label!)
                              : l.locationArrivesAtPoint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelSmall?.copyWith(
                        color: muted,
                        height: 1.1,
                      ),
                    ),
                    // Address then hour on one line. The address gives way
                    // first: an ellipsised district is still recognisable,
                    // a half-printed time is not.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isSet ? detail : l.locationChoose,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.titleSmall?.copyWith(height: 1.2, color: fg),
                          ),
                        ),
                        if (when.isNotEmpty) ...[
                          Gap.w6,
                          // Flexible too: a shipping date («بحلول الخميس 10
                          // سبتمبر») is long enough to overflow the row on a
                          // small phone at a large text scale.
                          Flexible(
                            child: Text(
                              when,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.titleSmall?.copyWith(
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
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

/// The arrival pill for the compact bar that follows the customer down the
/// page: the same answer the header gives, in one word — «الساعة 10:30 م».
class PromiseLine extends ConsumerWidget {
  const PromiseLine({super.key, this.onCanvas = false, this.scope});

  /// On the hero canvas the pill goes translucent-light instead of tinted —
  /// the tier colors were mixed for surfaces, not for a deep teal.
  final bool onCanvas;

  /// The active storefront's promise; falls back to the saved location's.
  final CatalogScope? scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final when = deliveryWhenLabel(context, scope: scope, location: location);
    if (when.isEmpty) return const SizedBox.shrink();

    final tier = (scope != null && scope!.tier.isNotEmpty)
        ? scope!.tier
        : location.deliveryType;
    final pair = context.zb.tier(tier);
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
          Icon(
            tier == 'express' ? Icons.bolt_rounded : Icons.schedule_rounded,
            size: 13,
            color: fg,
          ),
          Gap.w4,
          Text(
            when,
            style: context.tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
