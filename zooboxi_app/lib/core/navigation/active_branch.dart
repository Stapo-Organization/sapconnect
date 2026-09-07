import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tab the customer would return to.
///
/// The shell owns the four branches, but two things outside it need to know
/// which one is on screen: a pushed page drawing the floating bar for itself,
/// and any hero that must only fly while its own branch is visible — go_router
/// keeps every visited branch alive and offstage, and an offstage hero is
/// still a hero as far as a flight is concerned.
class ActiveBranch extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    if (state != index) state = index;
  }
}

final activeBranchProvider = NotifierProvider<ActiveBranch, int>(ActiveBranch.new);
