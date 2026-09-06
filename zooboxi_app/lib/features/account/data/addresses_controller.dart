import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/location/location_controller.dart';
import '../../../core/session/session_controller.dart';
import 'account_models.dart';
import 'account_repository.dart';

/// The address book, shared by the account tab and the checkout address step.
///
/// Every write returns the whole book, so this controller never splices a
/// local list: it replaces state with the server's answer. That is what keeps
/// "exactly one default" true — a rule the server owns and the app would get
/// subtly wrong the first time two edits raced.
class AddressesController extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    // Signing out must empty the book rather than leave the last customer's
    // addresses on screen behind a guest session.
    if (!ref.watch(sessionProvider.select((s) => s.isAuthenticated))) {
      return const [];
    }
    return ref.read(accountRepositoryProvider).addresses();
  }

  AccountRepository get _repo => ref.read(accountRepositoryProvider);

  Future<void> refresh() async {
    if (!ref.read(sessionProvider).isAuthenticated) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      state = AsyncValue.data(await _repo.addresses());
    } catch (e, st) {
      if (!state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Creates or updates one entry and returns it — the caller needs the
  /// server-issued uuid to reference it at checkout.
  Future<Address> save(Address address) async {
    final result = address.isSaved
        ? await _repo.updateAddress(address.id, address)
        : await _repo.createAddress(address);
    state = AsyncValue.data(result.addresses);

    // Moving the pin of the address we are delivering to moves the delivery
    // point with it. Without this the shop would keep quoting the old street
    // — stock, promise and all — while the book already shows the new one.
    final saved = result.address;
    final current = ref.read(locationProvider).location;
    if (saved.id == current.addressId && saved.lat != null && saved.lng != null) {
      unawaited(ref.read(locationProvider.notifier).resolve(
            saved.lat!,
            saved.lng!,
            addressId: saved.id,
            label: saved.label,
          ));
    }
    return saved;
  }

  Future<void> remove(String id) async {
    state = AsyncValue.data(await _repo.deleteAddress(id));
  }

  Future<void> makeDefault(String id) async {
    state = AsyncValue.data(await _repo.setDefaultAddress(id));
  }
}

final addressesControllerProvider =
    AsyncNotifierProvider<AddressesController, List<Address>>(AddressesController.new);
