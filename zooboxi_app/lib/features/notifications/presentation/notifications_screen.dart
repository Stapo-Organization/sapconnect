import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/notifications/notify_permission.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../data/push_repository.dart';

/// «الإشعارات» — what the store may interrupt this customer for.
///
/// The screen answers to two authorities and has to be honest about both: the
/// OS permission, which the app cannot grant itself, and the customer's own
/// four switches, which the store keeps. When the first is missing the second
/// is meaningless, so the switches go quiet and the screen says exactly what
/// to do about it instead of pretending to save.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  PushPreferences _prefs = PushPreferences.all;
  String _permission = 'undetermined';
  bool _loading = true;
  bool _saving = false;

  bool get _granted => _permission == 'granted';

  @override
  void initState() {
    super.initState();
    // The customer may leave for iOS Settings and come back having granted it;
    // the screen has to be right when they return, without a pull-to-refresh.
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final permission = await NotifyPermission.status();
    PushPreferences? prefs;
    try {
      prefs = await ref.read(pushRepositoryProvider).preferences(
            token: ref.read(pushServiceProvider).token,
          );
    } catch (_) {
      // An unreachable store is not a reason to show an empty screen: the
      // defaults are what a new device has anyway.
    }
    if (!mounted) return;
    setState(() {
      _permission = permission;
      if (prefs != null) _prefs = prefs;
      _loading = false;
    });
    if (permission == 'granted') {
      // Coming back from Settings with a fresh yes: the store still has no
      // token for this device until we hand it one.
      unawaited(ref.read(pushServiceProvider).refreshRegistration());
    }
  }

  Future<void> _ask() async {
    Haptics.light();
    final granted = await NotifyPermission.request();
    if (!mounted) return;
    if (granted) {
      await ref.read(pushServiceProvider).refreshRegistration();
      await _load(silent: true);
      return;
    }
    // iOS only ever shows that prompt once. After a refusal the only way back
    // is the Settings app, so that is what the button becomes.
    setState(() => _permission = 'denied');
  }

  Future<void> _openSettings() async {
    Haptics.selection();
    final uri = Uri.parse('app-settings:');
    if (!await launchUrl(uri)) {
      if (mounted) AppToast.info(context, L.of(context).notificationsOffBody);
    }
  }

  Future<void> _set(PushPreferences next) async {
    final previous = _prefs;
    Haptics.selection();
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      final saved = await ref.read(pushRepositoryProvider).save(next);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A switch that snaps back is the truth: nothing was saved.
      setState(() {
        _prefs = previous;
        _saving = false;
      });
      AppToast.error(context, L.of(context).notificationsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final available = ref.read(pushServiceProvider).available;

    return Scaffold(
      appBar: AppBar(title: Text(l.notificationsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  l.notificationsSubtitle,
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                Gap.h16,

                if (!available) ...[
                  _Notice(
                    icon: Icons.cloud_off_rounded,
                    title: l.notificationsUnavailable,
                  ),
                  Gap.h16,
                ] else if (!_granted) ...[
                  _Notice(
                    icon: Icons.notifications_off_rounded,
                    title: l.notificationsOff,
                    body: l.notificationsOffBody,
                    action: _permission == 'denied'
                        ? FilledButton(
                            onPressed: _openSettings,
                            child: Text(l.notificationsOpenSettings),
                          )
                        : FilledButton(
                            onPressed: _ask,
                            child: Text(l.notificationsAllow),
                          ),
                  ),
                  Gap.h16,
                ] else if (_prefs.isSilent) ...[
                  _Notice(
                    icon: Icons.volume_off_rounded,
                    title: l.notificationsSilent,
                    tone: context.zb.warning,
                  ),
                  Gap.h16,
                ],

                // The switches stay readable but inert without permission:
                // greying them out explains the state better than hiding them,
                // which would make the screen look broken.
                Opacity(
                  opacity: _granted && available ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !_granted || !available || _saving,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(ZbTokens.rLg),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _Toggle(
                            icon: Icons.local_shipping_rounded,
                            title: l.notificationsOrders,
                            body: l.notificationsOrdersBody,
                            value: _prefs.orders,
                            onChanged: (v) => _set(_prefs.copyWith(orders: v)),
                          ),
                          const _Divider(),
                          _Toggle(
                            icon: Icons.sell_rounded,
                            title: l.notificationsOffers,
                            body: l.notificationsOffersBody,
                            value: _prefs.offers,
                            onChanged: (v) => _set(_prefs.copyWith(offers: v)),
                          ),
                          const _Divider(),
                          _Toggle(
                            icon: Icons.restart_alt_rounded,
                            title: l.notificationsReorder,
                            body: l.notificationsReorderBody,
                            value: _prefs.reorder,
                            onChanged: (v) => _set(_prefs.copyWith(reorder: v)),
                          ),
                          const _Divider(),
                          _Toggle(
                            icon: Icons.pets_rounded,
                            title: l.notificationsFamily,
                            body: l.notificationsFamilyBody,
                            value: _prefs.family,
                            onChanged: (v) => _set(_prefs.copyWith(family: v)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 60),
        child: Divider(height: 1, color: context.cs.outlineVariant),
      );
}

/// One category, said in the customer's own terms — what arrives, not which
/// server event fires.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 10),
      secondary: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: cs.onSurfaceVariant),
      ),
      title: Text(
        title,
        style: context.tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        body,
        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// The state of the world, when it is not the customer's switches that decide.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final ink = tone ?? cs.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: context.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(ZbTokens.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: ink),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (body != null) ...[
                      Gap.h4,
                      Text(
                        body!,
                        style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[Gap.h12, action!],
        ],
      ),
    );
  }
}
