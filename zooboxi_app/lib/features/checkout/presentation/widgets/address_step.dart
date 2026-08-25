import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/data/account_models.dart';
import '../../../account/presentation/widgets/address_card.dart';

/// Step one: where the order is going.
///
/// The chosen address is what the server re-prices the whole basket against —
/// stock, caps and shipping tiers all resolve at the destination, not at the
/// phone — so it is the first question, not the last.
class CheckoutAddressStep extends StatelessWidget {
  const CheckoutAddressStep({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.draft,
    required this.onSelect,
    required this.onSelectDraft,
    required this.onNew,
    required this.onEdit,
  });

  final List<Address> addresses;

  /// The saved address in play, if any.
  final String? selectedId;

  /// A one-off address typed for this order and not saved to the book.
  final Address? draft;

  final ValueChanged<Address> onSelect;
  final VoidCallback onSelectDraft;
  final VoidCallback onNew;
  final ValueChanged<Address> onEdit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final isEmpty = addresses.isEmpty && draft == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Text(l.checkoutAddressTitle, style: context.tt.titleLarge),
        Gap.h4,
        Text(
          isEmpty ? l.checkoutAddressEmptyHint : l.locationDeliverTo,
          style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Gap.h16,

        if (draft != null) ...[
          AddressCard(
            address: draft!,
            selectable: true,
            selected: selectedId == null,
            onTap: onSelectDraft,
            onEdit: () => onEdit(draft!),
          ),
          Gap.h12,
        ],

        for (final address in addresses) ...[
          AddressCard(
            address: address,
            selectable: true,
            selected: selectedId == address.id,
            onTap: () => onSelect(address),
            onEdit: () => onEdit(address),
          ),
          Gap.h12,
        ],

        if (isEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.place_outlined, size: 30, color: cs.onSurfaceVariant),
                Gap.h8,
                Text(l.checkoutAddressEmpty, style: context.tt.titleSmall),
              ],
            ),
          ),
          Gap.h12,
        ],

        OutlinedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add_location_alt_outlined, size: 20),
          label: Text(l.checkoutAddressNew),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
        ),
      ],
    );
  }
}
