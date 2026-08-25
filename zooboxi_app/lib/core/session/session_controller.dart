import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/envelope.dart';
import '../providers.dart';

/// A signed-in customer. The app never stores more than this — no addresses,
/// no order history, nothing that would need clearing beyond a token drop.
@immutable
class ZbUser {
  const ZbUser({required this.id, required this.name, required this.phone, this.email});

  final int id;
  final String name;
  final String phone;
  final String? email;

  factory ZbUser.fromJson(Map<String, dynamic> json) => ZbUser(
        id: asInt(json['id']),
        name: asString(json['name']),
        phone: asString(json['phone']),
        email: asStringOrNull(json['email']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'email': email};

  ZbUser copyWith({String? name, String? email}) =>
      ZbUser(id: id, name: name ?? this.name, phone: phone, email: email ?? this.email);

  /// First word only — "أهلًا يا محمد" reads better than the full legal name.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

enum AuthStatus {
  /// Before the keychain has been read. The splash holds here.
  unknown,

  /// Browsing without an account. This is a *first-class* state, not an error:
  /// guests can browse, search, and fill a cart.
  guest,

  authenticated,
}

@immutable
class SessionState {
  const SessionState({this.status = AuthStatus.unknown, this.token, this.user, this.guestId});

  final AuthStatus status;
  final String? token;
  final ZbUser? user;

  /// Stable device id sent as `X-ZB-Guest`. Present in every state — it keys
  /// the server-side guest cart, which must survive signing in and out.
  final String? guestId;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isReady => status != AuthStatus.unknown;

  SessionState copyWith({AuthStatus? status, String? token, ZbUser? user, String? guestId}) =>
      SessionState(
        status: status ?? this.status,
        token: token ?? this.token,
        user: user ?? this.user,
        guestId: guestId ?? this.guestId,
      );
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  /// Reads the keychain once at launch. Always resolves to a usable state —
  /// a customer with no account is a `guest`, never a blocked screen.
  Future<void> restore() async {
    final secure = ref.read(secureStoreProvider);

    // iOS keeps Keychain entries across a delete/reinstall; drop any token
    // that outlived its install before we trust it.
    await secure.clearOnFreshInstall();

    final guestId = await secure.guestId();
    final token = await secure.readToken();

    if (token == null || token.isEmpty) {
      state = SessionState(status: AuthStatus.guest, guestId: guestId);
      return;
    }

    state = SessionState(status: AuthStatus.authenticated, token: token, guestId: guestId);
    // Hydrate the profile in the background — a missing display name is not
    // worth blocking the first screen for.
    unawaited(refreshUser());
  }

  /// Called after a successful OTP verification.
  Future<void> establish({required String token, ZbUser? user}) async {
    await ref.read(secureStoreProvider).saveToken(token);
    state = state.copyWith(status: AuthStatus.authenticated, token: token, user: user);
    if (user == null) await refreshUser();
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    try {
      final data = await ref.read(apiClientProvider).get('/me');
      final json = asMap(data);
      final userJson = json.containsKey('user') ? asMap(json['user']) : json;
      if (userJson.isEmpty) return;
      if (state.isAuthenticated) {
        state = state.copyWith(user: ZbUser.fromJson(userJson));
      }
    } catch (_) {
      // Offline or a transient 500: the cached identity keeps working.
    }
  }

  void applyUser(ZbUser user) {
    if (state.isAuthenticated) state = state.copyWith(user: user);
  }

  /// Customer-initiated sign-out. The server call is best-effort — a dead
  /// network must never trap someone in an account they want to leave.
  Future<void> logout() async {
    try {
      await ref.read(apiClientProvider).post('/auth/logout');
    } catch (_) {}
    await _tearDown();
  }

  /// The server rejected our bearer token (revoked, expired, or the account
  /// was deleted). Drop it and fall back to guest — never to a wall.
  Future<void> onServerRejectedToken() async {
    if (!state.isAuthenticated) return;
    await _tearDown();
  }

  Future<void> _tearDown() async {
    final guestId = state.guestId ?? await ref.read(secureStoreProvider).guestId();
    state = SessionState(status: AuthStatus.guest, guestId: guestId);
    await ref.read(secureStoreProvider).clearToken();
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience for the many widgets that only care "is there an account".
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(sessionProvider).isAuthenticated);
