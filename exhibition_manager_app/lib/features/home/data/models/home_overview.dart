import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/permissions/app_abilities.dart';
import 'package:exhibition_manager_app/features/inventory_counting/data/models/counting_session.dart';
import 'package:exhibition_manager_app/features/gamification/data/models/gamification_models.dart';
import 'package:exhibition_manager_app/features/quality_control/data/models/quality_task_models.dart';
import 'package:exhibition_manager_app/features/zooboxi_orders/data/models/zooboxi_order.dart';
import 'package:exhibition_manager_app/features/promotions/data/models/campaign.dart';

/// The whole home screen in one payload — the smart `/home/overview` response.
///
/// Mirrors HomeOverviewController on the backend: a server-ranked priority
/// [feed], the contextual [yourDay] + [progress] strip, a dynamic
/// [moduleOrder], and the typed [modules] (reusing each feature's own model so
/// the existing section cards render unchanged).
class HomeOverview {
  final bool isOwner;
  final String greetingPeriod; // morning | afternoon | evening
  final List<HomeFeedItem> feed;
  final YourDay yourDay;
  final HomeProgress progress;
  final List<String> moduleOrder;
  final HomeModules modules;

  const HomeOverview({
    required this.isOwner,
    required this.greetingPeriod,
    required this.feed,
    required this.yourDay,
    required this.progress,
    required this.moduleOrder,
    required this.modules,
  });

  factory HomeOverview.fromJson(Map<String, dynamic> json) {
    final feedList = (json['feed'] as List?) ?? const [];
    final order = ((json['module_order'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return HomeOverview(
      isOwner: json['is_owner'] == true,
      greetingPeriod: (json['greeting_period'] ?? 'morning').toString(),
      feed: feedList
          .map((e) => HomeFeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      yourDay: YourDay.fromJson(Map<String, dynamic>.from((json['your_day'] ?? {}) as Map)),
      progress: HomeProgress.fromJson(Map<String, dynamic>.from((json['progress'] ?? {}) as Map)),
      moduleOrder: order,
      modules: HomeModules.fromJson(Map<String, dynamic>.from((json['modules'] ?? {}) as Map)),
    );
  }
}

/// One ranked, actionable item in the Action Center feed.
class HomeFeedItem {
  final String id;
  final String type;
  final String domain; // zooboxi | counting | quality | transfers | promotions
  final String title;
  final String subtitle;
  final int score;
  final String urgency; // critical | warning | info
  final String route;
  final Map<String, dynamic> meta;

  const HomeFeedItem({
    required this.id,
    required this.type,
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.urgency,
    required this.route,
    required this.meta,
  });

  factory HomeFeedItem.fromJson(Map<String, dynamic> json) => HomeFeedItem(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        domain: (json['domain'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        subtitle: (json['subtitle'] ?? '').toString(),
        score: (json['score'] ?? 0) as int,
        urgency: (json['urgency'] ?? 'info').toString(),
        route: (json['route'] ?? '').toString(),
        meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta']) : const {},
      );

  /// The app feature this item belongs to — used to gate it against the user's
  /// permissions (so a feed item never routes to a screen they can't open).
  String get feature => switch (domain) {
        'zooboxi' => Feature.zooboxiOrders,
        'counting' => Feature.inventoryCounting,
        'quality' => Feature.qualityControl,
        'transfers' => Feature.stockTransfer,
        'promotions' => Feature.promotions,
        _ => '',
      };

  /// Domain colour identity for the item's icon chip / accent.
  AppDomain get appDomain => switch (domain) {
        'zooboxi' => AppDomain.zooboxi,
        'counting' => AppDomain.counting,
        'quality' => AppDomain.quality,
        'transfers' => AppDomain.transfers,
        'promotions' => AppDomain.promotions,
        _ => AppDomain.home,
      };

  /// SLA / urgency colour for the left band + badge.
  Color get bandColor => switch (urgency) {
        'critical' => AppColors.error,
        'warning' => AppColors.warning,
        _ => appDomain.accent,
      };

  IconData get icon => switch (type) {
        'zooboxi_order' => Icons.bolt_rounded,
        'overdue_cycle' || 'due_cycle' => Icons.autorenew_rounded,
        'overdue_quality' || 'due_quality' => Icons.verified_rounded,
        'pending_receive' => Icons.inventory_rounded,
        'pending_send' => Icons.local_shipping_rounded,
        'promo_approval' => Icons.auto_awesome_rounded,
        _ => Icons.notifications_active_rounded,
      };

  int? get orderId => meta['order_id'] as int?;
  int? get taskId => meta['task_id'] as int?;
  int? get sessionId => meta['session_id'] as int?;
}

/// A de-duplicated feed row. Repeated items of the same type+title (e.g. the
/// same overdue cleaning task across days) collapse into one [lead] row carrying
/// the total [count], so the Action Center stays a short, scannable list.
class FeedGroup {
  final HomeFeedItem lead;
  final int count;

  const FeedGroup(this.lead, this.count);

  bool get isFolded => count > 1;
}

/// "Your day" mini-summary — work closed out today + the streak.
class YourDay {
  final int ordersFulfilledToday;
  final int tasksDoneToday;
  final int streak;

  const YourDay({
    required this.ordersFulfilledToday,
    required this.tasksDoneToday,
    required this.streak,
  });

  factory YourDay.fromJson(Map<String, dynamic> json) => YourDay(
        ordersFulfilledToday: (json['orders_fulfilled_today'] ?? 0) as int,
        tasksDoneToday: (json['tasks_done_today'] ?? 0) as int,
        streak: (json['streak'] ?? 0) as int,
      );
}

/// Daily progress ring (weekly cycle-count goal).
class HomeProgress {
  final String kind;
  final int percent;
  final String label;
  final int current;
  final int target;

  const HomeProgress({
    required this.kind,
    required this.percent,
    required this.label,
    required this.current,
    required this.target,
  });

  factory HomeProgress.fromJson(Map<String, dynamic> json) => HomeProgress(
        kind: (json['kind'] ?? 'weekly_goal').toString(),
        percent: (json['percent'] ?? 0) as int,
        label: (json['label'] ?? '').toString(),
        current: (json['current'] ?? 0) as int,
        target: (json['target'] ?? 0) as int,
      );

  bool get hasGoal => target > 0;
}

/// The per-domain module summaries, parsed into each feature's existing model
/// so the home section cards render exactly as before.
class HomeModules {
  final int zbCount;
  final List<ZooboxiOrder> zbOrders;

  final int qcDue;
  final int qcOverdue;
  final List<QualityTaskInstance> qcTasks;

  final List<CountingSession> countingTasks;

  final int pendingSend;
  final int pendingReceive;
  final int inProgressCounting;

  final int promoPending;
  final int promoActive;
  final List<Campaign> promos;

  final GamificationProfile? gamification;

  const HomeModules({
    required this.zbCount,
    required this.zbOrders,
    required this.qcDue,
    required this.qcOverdue,
    required this.qcTasks,
    required this.countingTasks,
    required this.pendingSend,
    required this.pendingReceive,
    required this.inProgressCounting,
    required this.promoPending,
    required this.promoActive,
    required this.promos,
    required this.gamification,
  });

  factory HomeModules.fromJson(Map<String, dynamic> json) {
    final zb = _map(json['zooboxi']);
    final qc = _map(json['quality']);
    final counting = _map(json['counting']);
    final transfers = _map(json['transfers']);
    final promotions = json['promotions'] is Map ? _map(json['promotions']) : null;
    final gam = json['gamification'] is Map ? _map(json['gamification']) : null;

    final countingTasks = <CountingSession>[];
    for (final key in ['overdue', 'upcoming']) {
      for (final e in (counting[key] as List?) ?? const []) {
        countingTasks.add(CountingSession.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }

    return HomeModules(
      zbCount: (zb['urgent_count'] ?? 0) as int,
      zbOrders: ((zb['orders'] as List?) ?? const [])
          .map((e) => ZooboxiOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      qcDue: (qc['due_count'] ?? 0) as int,
      qcOverdue: (qc['overdue_count'] ?? 0) as int,
      qcTasks: ((qc['due'] as List?) ?? const [])
          .map((e) => QualityTaskInstance.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      countingTasks: countingTasks,
      pendingSend: (transfers['pending_send'] ?? 0) as int,
      pendingReceive: (transfers['pending_receive'] ?? 0) as int,
      inProgressCounting: (transfers['in_progress_counting'] ?? 0) as int,
      promoPending: (promotions?['pending_count'] ?? 0) as int,
      promoActive: (promotions?['active_count'] ?? 0) as int,
      promos: ((promotions?['campaigns'] as List?) ?? const [])
          .map((e) => Campaign.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      gamification: gam != null ? GamificationProfile.fromJson(gam) : null,
    );
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}
