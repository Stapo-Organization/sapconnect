import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../data/account_models.dart';
import '../data/addresses_controller.dart';
import 'address_editor_screen.dart';
import 'widgets/address_card.dart';

/// The address book.
///
/// Every write goes through [AddressesController], which replaces the list
/// with the server's answer — so "exactly one default" stays the server's rule
/// and the screen never has to reason about it.
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final addresses = ref.watch(addressesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.addressesTitle)),
      floatingActionButton: addresses.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l.addressAdd),
            )
          : null,
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(addressesControllerProvider.notifier).refresh(),
        child: AsyncView<List<Address>>(
          value: addresses,
          onRetry: () => ref.invalidate(addressesControllerProvider),
          skeleton: const _AddressesSkeleton(),
          builder: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.place_rounded,
                title: l.addressesEmpty,
                message: l.addressesEmptyHint,
                actionLabel: l.addressAdd,
                onAction: () => _edit(context, ref),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => Gap.h12,
              itemBuilder: (context, index) {
                final address = list[index];
                return AddressCard(
                  address: address,
                  onEdit: () => _edit(context, ref, initial: address),
                  onDelete: () => _delete(context, ref, address),
                  onMakeDefault: () => _makeDefault(context, ref, address),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Address? initial,
  }) async {
    final draft = await showAddressEditor(context, initial: initial);
    if (draft == null || !context.mounted) return;
    final l = L.of(context);
    try {
      await ref.read(addressesControllerProvider.notifier).save(draft.address);
      if (!context.mounted) return;
      await Haptics.success();
      if (!context.mounted) return;
      AppToast.success(context, l.addressSaved);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, errorMessage(context, e));
    }
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.addressDeleteConfirm),
        content: Text(address.addressLine),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l.addressDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(addressesControllerProvider.notifier).remove(address.id);
      if (!context.mounted) return;
      AppToast.info(context, l.addressDeleted);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, errorMessage(context, e));
    }
  }

  static Future<void> _makeDefault(
    BuildContext context,
    WidgetRef ref,
    Address address,
  ) async {
    final l = L.of(context);
    Haptics.selection();
    try {
      await ref.read(addressesControllerProvider.notifier).makeDefault(address.id);
      if (!context.mounted) return;
      AppToast.success(context, l.addressDefaultSet);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, errorMessage(context, e));
    }
  }
}

class _AddressesSkeleton extends StatelessWidget {
  const _AddressesSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => Gap.h12,
          itemBuilder: (_, _) => const SkeletonBox(
            width: double.infinity,
            height: 128,
            radius: ZbTokens.rLg,
          ),
        ),
      );
}
