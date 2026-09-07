import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/delivery/delivery_eta.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_countdown.dart';

/// The part of a composed hero slide that is only true for the next minute.
///
/// The server writes the slide — its subject, its artwork, its subtitle — but
/// never its clock. `/home` is cached for five minutes and read again off disk
/// when the app opens, so any time printed into it is a promise that goes
/// stale in the customer's hand: «يوصلك الساعة 10:30 م» must be computed on
/// the device, from the branch's own opening hours, every time the slide is
/// drawn.
///
/// The rules themselves live in `core/delivery/delivery_eta.dart`, which is
/// the same arithmetic the header and the cart promise use — there is one
/// answer in this app to "when does it arrive", not three.
enum HeroDeadline {
  /// The express branch pulls its shutter down at this moment.
  branchCloses,

  /// The main warehouse's cut-off for going out today.
  todayCutoff,
}

@immutable
class HeroLive {
  const HeroLive({this.title, this.badge, this.hint, this.deadline, this.deadlineAt});

  /// Replaces the server's headline when the device can say it better.
  final String? title;
  final String? badge;

  /// A pill with nothing to tick — the branch's opening hours, say.
  final String? hint;

  /// What the pill is counting down to, and when it lands.
  final HeroDeadline? deadline;
  final DateTime? deadlineAt;

  static const HeroLive none = HeroLive();

  bool get isEmpty =>
      title == null && badge == null && hint == null && deadlineAt == null;

  /// What [theme] says right now for this [scope].
  static HeroLive of(
    String? theme,
    CatalogScope? scope,
    L l,
    String locale, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    switch (theme) {
      // The flagship: not "two hours" — the clock time it lands. Whole hours
      // are written bare («الساعة 11 م»), exactly as the header writes them,
      // because the two sit one above the other on the same screen.
      case 'express_clock':
        final hours = scope?.expressHours;
        final eta = resolveExpressEta(now: n, hours: hours);
        // The meridiem is part of the time, not a word after it: bound with a
        // no-break space so «10:45 م» can never wrap and leave the headline
        // saying half past ten with no idea which half of the day.
        final clock = Fmt.clockShort(eta.at, locale).replaceAll(' ', '\u00A0');

        // The shutter, on the slide that already owns the clock. Inside the
        // last four hours the branch's closing time changes what a customer
        // does, so it ticks here — «يغلق بعد 02:48» — in the line that
        // otherwise just repeats «خلال ساعتين». A slide of its own for this
        // was the same poster twice with a different number on it.
        DateTime? closing;
        if (hours != null && !hours.overnight && isExpressOpen(n, hours)) {
          // A 21:30 order lands at midnight — tomorrow — and the shutter still
          // matters then, so the question is whether the shop is OPEN, not
          // where the arrival falls. An overnight branch has no evening
          // shutter to count down to.
          final closes = timeOfDayToday(hours.closeMinutes, now: n);
          final left = closes.difference(n);
          if (!left.isNegative && left <= const Duration(hours: 4)) closing = closes;
        }

        return HeroLive(
          // A branch that has already shut says so, in the header's own words,
          // rather than falling back to a promise of two hours it cannot keep.
          title: eta.tomorrow
              ? l.heroExpressArrivesTomorrow(clock)
              : l.heroExpressArrives(clock),
          badge: eta.tomorrow ? null : l.heroExpressWindow,
          deadline: closing == null ? null : HeroDeadline.branchCloses,
          deadlineAt: closing,
        );

      // زوبكسي's one deadline: order before one o'clock and it goes out today.
      //
      // The day is written here and never on the server: `/home` is cached for
      // five minutes and read again off disk at the next launch, so a printed
      // «اليوم» would still read «اليوم» the following morning — while the
      // header, computing from the same clock as this, said «غدًا».
      //
      // A city we only SHIP to has a date, not a cut-off. Its header names
      // that date; this slide must not answer a different question, so it
      // says nothing and the server does not compose it there either.
      case 'cutoff':
        if ((scope?.tier ?? '') != 'same_day') return const HeroLive();
        final minutes = scope?.standardCutoffMinutes ?? standardCutoffMinutes;
        final eta = resolveStandardEta(now: n, cutoffMinutes: minutes);
        return switch (eta.kind) {
          StandardEtaKind.today => HeroLive(
              title: l.heroCutoffToday,
              deadline: HeroDeadline.todayCutoff,
              deadlineAt: timeOfDayToday(minutes, now: n),
            ),
          StandardEtaKind.tomorrow => HeroLive(title: l.heroCutoffTomorrow),
          StandardEtaKind.later =>
            HeroLive(title: l.heroCutoffOn(Fmt.weekday(eta.day, locale))),
        };

      default:
        return const HeroLive();
    }
  }
}

/// True when a composed slide has outlived the moment it was written for.
///
/// The payload is held for the life of the home screen and re-read from disk
/// at launch, so a slider opened at half past eleven can still be carrying
/// «اطلب قبل الإغلاق ويوصلك الليلة» from a payload built at ten. The carousel
/// drops these instead of showing them until the refresh lands.
bool heroSlideIsStale(HeroSlide slide, CatalogScope? scope, {DateTime? now}) {
  final n = now ?? DateTime.now();
  // Express slides are only composed while a branch is serving — every one of
  // them, not just the clock: the polaroid's «ويوصلك خلال ساعتين» is the same
  // promise in smaller type. A payload built at ten and reopened at half past
  // eleven would still be making it, so they leave instead.
  if ((slide.theme ?? '').startsWith('express')) {
    return !isExpressOpen(n, scope?.expressHours);
  }
  return false;
}

/// The pill under a slide's subtitle: a ticking deadline, or a plain fact.
///
/// Its own [StatefulWidget] so a passing minute never rebuilds the carousel
/// around it, and it steps by the minute rather than the second — a hero is
/// read, not raced.
class HeroLivePill extends StatefulWidget {
  const HeroLivePill({
    super.key,
    required this.live,
    required this.fg,
    required this.accent,
    this.now,
  });

  final HeroLive live;

  /// The slide's own foreground, so the pill belongs to the panel.
  final Color fg;

  /// The theme's deep colour, used for text on the white deadline pill.
  final Color accent;

  /// Pins the clock for the design golden; null everywhere else, where the
  /// only honest answer is the device's own time.
  final DateTime? now;

  @override
  State<HeroLivePill> createState() => _HeroLivePillState();
}

class _HeroLivePillState extends State<HeroLivePill> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HeroLivePill old) {
    super.didUpdateWidget(old);
    if (old.live.deadlineAt != widget.live.deadlineAt) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    final at = widget.live.deadlineAt;
    if (at == null) return;
    _left = at.difference(widget.now ?? DateTime.now());
    // A pinned clock never moves, so there is nothing to tick.
    if (widget.now != null) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final left = at.difference(DateTime.now());
      setState(() => _left = left);
      // Past the deadline there is nothing to count: the next payload will
      // carry tomorrow's sentence anyway.
      if (left.isNegative) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final live = widget.live;

    if (live.deadlineAt != null && !_left.isNegative) {
      final clock = CampaignCountdown.format(_left, seconds: false);
      final label = switch (live.deadline) {
        HeroDeadline.branchCloses => l.heroBranchClosesIn(clock),
        HeroDeadline.todayCutoff => l.heroCutoffIn(clock),
        null => '',
      };
      if (label.isEmpty) return const SizedBox.shrink();
      return _Pill(
        label: label,
        icon: Icons.schedule_rounded,
        fg: widget.accent,
        bg: Colors.white,
      );
    }

    final hint = live.hint;
    if (hint == null || hint.isEmpty) return const SizedBox.shrink();
    return _Pill(
      label: hint,
      icon: Icons.schedule_rounded,
      fg: widget.fg,
      bg: widget.fg.withValues(alpha: 0.16),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
