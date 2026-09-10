import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../data/push_repository.dart';

/// «صندوق الإشعارات» — everything the store sent, whether or not the phone
/// rang for it.
///
/// The store caps how many alerts one customer may get in a day. What it
/// decides not to spend that cap on is still written here, marked «هادئ», so
/// a price drop the customer never saw is a message they can still find
/// rather than one that never existed. That is the whole reason this screen
/// is not simply iOS's own notification centre.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Ids marked read on this screen before the store confirmed it. A tap that
  /// waits for a round trip to un-bold a title reads as a tap that missed.
  final Set<int> _read = {};
  bool _markingAll = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final page = ref.watch(inboxProvider);
    final unread = page.value == null
        ? 0
        : page.value!.items.where((item) => !_isRead(item)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inboxTitle),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAll,
              child: Text(l.inboxMarkAllRead),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: AsyncView<InboxPage>(
          value: page,
          onRetry: () => ref.invalidate(inboxProvider),
          builder: (data) => _List(
            items: data.items,
            isRead: _isRead,
            onOpen: _open,
          ),
        ),
      ),
    );
  }

  bool _isRead(InboxItem item) => item.read || _read.contains(item.id);

  Future<void> _refresh() async {
    ref.invalidate(inboxProvider);
    try {
      await ref.read(inboxProvider.future);
    } catch (_) {
      // The list stays on screen while this runs, so a failed refresh is the
      // provider's error to render — not an exception thrown out of the
      // indicator, which would land as an unhandled framework error.
    }
  }

  /// A tap: read locally, told to the store in the background, and then the
  /// route the notification pointed at — in that order, because the push a
  /// customer taps is one they have read whether or not the store hears it.
  Future<void> _open(InboxItem item) async {
    Haptics.light();
    if (!_isRead(item)) {
      setState(() => _read.add(item.id));
      unawaited(_tellStore([item.id]));
    }
    if (item.hasRoute && mounted) unawaited(context.push(item.route!));
  }

  Future<void> _markAll() async {
    Haptics.selection();
    setState(() => _markingAll = true);
    try {
      // An empty list is the store's own shorthand for "all of them" — better
      // than posting back a page's worth of ids, which would leave anything
      // below the page still unread.
      await ref.read(pushRepositoryProvider).markRead(const []);
      if (!mounted) return;
      setState(() => _markingAll = false);
      ref.invalidate(inboxProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      AppToast.error(context, errorMessage(context, error));
    }
  }

  Future<void> _tellStore(List<int> ids) async {
    try {
      await ref.read(pushRepositoryProvider).markRead(ids);
    } catch (_) {
      // A read the store did not hear about comes back bold on the next
      // refresh. That is a better outcome than an error toast over a screen
      // the customer has already left.
    }
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.isRead, required this.onOpen});

  final List<InboxItem> items;
  final bool Function(InboxItem) isRead;
  final void Function(InboxItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final bottom = 28 + MediaQuery.paddingOf(context).bottom;

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            // Tall enough to centre the illustration, short enough that the
            // list still takes a pull-to-refresh.
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: EmptyState(
              icon: Icons.notifications_none_rounded,
              title: l.inboxEmpty,
              message: l.inboxEmptyHint,
              mascot: true,
            ),
          ),
        ],
      );
    }

    final hasQuiet = items.any((item) => item.quiet);

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => Gap.h8,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.inboxSubtitle,
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                // Said once, and only where it applies: a customer who has
                // never hit the daily cap should not have to read about it.
                if (hasQuiet) ...[
                  Gap.h4,
                  Text(
                    l.inboxQuietNote,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          );
        }
        final item = items[index - 1];
        return _InboxTile(
          item: item,
          read: isRead(item),
          onTap: () => onOpen(item),
        );
      },
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.read, required this.onTap});

  final InboxItem item;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final at = item.at;

    return Material(
      color: read ? cs.surface : cs.primary.withValues(alpha: context.isDark ? 0.10 : 0.05),
      borderRadius: BorderRadius.circular(ZbTokens.rLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZbTokens.rLg),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The unread mark keeps its space when read, so the column of
              // titles does not shift as the list is worked through.
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, end: 10),
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: read
                      ? null
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: context.tt.bodyLarge?.copyWith(
                              fontWeight: read ? FontWeight.w500 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (at != null) ...[
                          Gap.w8,
                          Text(
                            _relative(l, at, locale),
                            style: context.tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      Gap.h4,
                      Text(
                        item.body,
                        style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    Gap.h8,
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_topicLabel(l, item.topic) case final topic?)
                          _Chip(label: topic),
                        if (item.quiet)
                          _Chip(label: l.inboxQuiet, icon: Icons.volume_off_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A topic, or nothing. The store may send a topic this build has no word
/// for; a chip printing `promo_v2` is worse than no chip at all.
String? _topicLabel(L l, String topic) => switch (topic) {
      'orders' => l.notificationsOrders,
      'offers' => l.notificationsOffers,
      'reorder' => l.notificationsReorder,
      'family' => l.notificationsFamily,
      _ => null,
    };

/// «قبل ٣ ساعات» — in words while "how long ago" is the useful answer, and a
/// plain date once it stops being one.
String _relative(L l, DateTime at, String locale) {
  final diff = DateTime.now().difference(at.toLocal());
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
  return Fmt.dateShort(at, locale);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: cs.onSurfaceVariant),
            Gap.w4,
          ],
          Text(
            label,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
