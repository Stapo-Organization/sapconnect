import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/account_models.dart';
import '../../../account/presentation/widgets/address_card.dart';
import 'review_step.dart' show addressBlockedReason;

/// Where the order is going — a sheet, not a page.
///
/// Checkout is one page now, and the address is one line of it. Choosing a
/// different one is a detour, and a detour belongs in a sheet the customer can
/// dismiss rather than a step they have to walk back out of.
///
/// **إكسبريس is the reason this sheet has two halves.** That basket was quoted
/// against ONE branch: its stock, its two-hour clock, its courier. Sending it
/// somewhere that branch does not cover is not a slower delivery — it is a
/// different warehouse, where the quantities the customer chose may not exist.
/// So the addresses that branch serves are the choices, and the rest are shown
/// but cannot be picked. Hiding them outright was the other option and it is
/// worse: a customer whose work address is missing assumes the app lost it.
class AddressPickerResult {
  const AddressPickerResult.select(this.address) : isNew = false;
  const AddressPickerResult.create()
      : address = null,
        isNew = true;

  final Address? address;
  final bool isNew;
}

Future<AddressPickerResult?> showAddressPicker(
  BuildContext context, {
  required List<Address> addresses,
  required Address? draft,
  required String? selectedId,
  required bool draftSelected,
}) {
  final l = L.of(context);
  final servable = [for (final a in addresses) if (a.serves) a];
  final blocked = [for (final a in addresses) if (!a.serves) a];

  return showZbSheet<AddressPickerResult>(
    context,
    builder: (sheet) => BottomSheetScaffold(
      title: l.checkoutAddressTitle,
      subtitle: blocked.isEmpty
          ? null
          : (servable.isEmpty && draft == null
              ? l.checkoutAddressNoneInZone
              : l.checkoutAddressZoneHint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft != null) ...[
            AddressCard(
              address: draft,
              selectable: true,
              selected: draftSelected,
              onTap: () =>
                  Navigator.of(sheet).pop(AddressPickerResult.select(draft)),
            ),
            Gap.h12,
          ],

          for (final address in servable) ...[
            AddressCard(
              address: address,
              selectable: true,
              selected: !draftSelected && selectedId == address.id,
              onTap: () =>
                  Navigator.of(sheet).pop(AddressPickerResult.select(address)),
            ),
            Gap.h12,
          ],

          if (blocked.isNotEmpty) ...[
            Gap.h4,
            Text(
              l.checkoutAddressOutOfZoneTitle,
              style: context.tt.labelMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Gap.h8,
            for (final address in blocked) ...[
              _Blocked(address: address),
              Gap.h12,
            ],
          ],

          Gap.h4,
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(sheet).pop(const AddressPickerResult.create()),
            icon: const Icon(Icons.add_location_alt_outlined, size: 20),
            label: Text(l.checkoutAddressNew),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
          ),
          Gap.h8,
        ],
      ),
    ),
  );
}

/// An address this basket cannot go to: shown, so nobody thinks it was lost,
/// and dimmed with the reason, so nobody wonders why it will not take a tap.
class _Blocked extends StatelessWidget {
  const _Blocked({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Semantics(
      enabled: false,
      label: '${address.name} — ${addressBlockedReason(l, address.servesReason)}',
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(ZbTokens.rLg),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wrong_location_outlined, size: 18, color: cs.onSurfaceVariant),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.name,
                          style: context.tt.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [address.addressLine, address.summary]
                              .where((e) => e.isNotEmpty)
                              .join('، '),
                          style: context.tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Gap.h8,
                  Text(
                    addressBlockedReason(l, address.servesReason),
                    style: context.tt.labelSmall?.copyWith(
                      color: context.zb.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
