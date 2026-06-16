// Models for Container Tracking (تتبّع الحاويات) — a read-only mirror of the
// Traqo ocean-freight board. Lifecycle/lateness is computed server-side; the app
// only renders the already-derived fields (state, remaining_label, progress).

int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
int? _iN(dynamic v) => v == null ? null : ((v is num) ? v.toInt() : int.tryParse('$v'));
double? _dN(dynamic v) => v == null ? null : ((v is num) ? v.toDouble() : double.tryParse('$v'));
String _s(dynamic v) => v == null ? '' : '$v';
String? _sN(dynamic v) => v == null ? null : '$v';
bool _b(dynamic v) => v == true || v == 1 || v == '1';
DateTime? _date(dynamic v) => (v == null || '$v'.isEmpty) ? null : DateTime.tryParse('$v');

/// One shipment as a list row / detail header.
class ContainerCard {
  final int id;
  final String name;
  final String reference;
  final String? carrier;
  final String? type;
  final String state; // overdue | arriving | in_transit | delivered | pending
  final String stateLabel;
  final String stateColor; // slate | emerald | rose | amber | cyan
  final String? origin;
  final String? destination;
  final String originShort;
  final String destinationShort;
  final String originFlag;
  final String destinationFlag;
  final DateTime? eta;
  final DateTime? shipDate;
  final int? remainingDays;
  final String remainingLabel;
  final int progressPercent;
  final int numberOfContainers;
  final int etaChangeCount;
  final bool needsAttention;

  ContainerCard({
    required this.id,
    required this.name,
    required this.reference,
    required this.carrier,
    required this.type,
    required this.state,
    required this.stateLabel,
    required this.stateColor,
    required this.origin,
    required this.destination,
    required this.originShort,
    required this.destinationShort,
    required this.originFlag,
    required this.destinationFlag,
    required this.eta,
    required this.shipDate,
    required this.remainingDays,
    required this.remainingLabel,
    required this.progressPercent,
    required this.numberOfContainers,
    required this.etaChangeCount,
    required this.needsAttention,
  });

  factory ContainerCard.fromJson(Map<String, dynamic> j) => ContainerCard(
        id: _i(j['id']),
        name: _s(j['name']),
        reference: _s(j['reference']),
        carrier: _sN(j['carrier']),
        type: _sN(j['type']),
        state: _s(j['state']).isEmpty ? 'pending' : _s(j['state']),
        stateLabel: _s(j['state_label']),
        stateColor: _s(j['state_color']).isEmpty ? 'slate' : _s(j['state_color']),
        origin: _sN(j['origin']),
        destination: _sN(j['destination']),
        originShort: _s(j['origin_short']),
        destinationShort: _s(j['destination_short']),
        originFlag: _s(j['origin_flag']),
        destinationFlag: _s(j['destination_flag']),
        eta: _date(j['eta']),
        shipDate: _date(j['ship_date']),
        remainingDays: _iN(j['remaining_days']),
        remainingLabel: _s(j['remaining_label']),
        progressPercent: _i(j['progress_percent']),
        numberOfContainers: _i(j['number_of_containers']),
        etaChangeCount: _i(j['eta_change_count']),
        needsAttention: _b(j['needs_attention']),
      );
}

class ContainerCounts {
  final int all, overdue, arriving, inTransit, pending, delivered;
  ContainerCounts({
    required this.all,
    required this.overdue,
    required this.arriving,
    required this.inTransit,
    required this.pending,
    required this.delivered,
  });
  factory ContainerCounts.fromJson(Map<String, dynamic> j) => ContainerCounts(
        all: _i(j['all']),
        overdue: _i(j['overdue']),
        arriving: _i(j['arriving']),
        inTransit: _i(j['in_transit']),
        pending: _i(j['pending']),
        delivered: _i(j['delivered']),
      );

  int forState(String s) => switch (s) {
        'overdue' => overdue,
        'arriving' => arriving,
        'in_transit' => inTransit,
        'pending' => pending,
        'delivered' => delivered,
        _ => all,
      };
}

class ContainerSummary {
  final ContainerCounts counts;
  final int attention;
  final String? nearestLabel;
  final String? nearestLane;
  final DateTime? lastSyncedAt;

  ContainerSummary({
    required this.counts,
    required this.attention,
    required this.nearestLabel,
    required this.nearestLane,
    required this.lastSyncedAt,
  });

  factory ContainerSummary.fromJson(Map<String, dynamic> j) => ContainerSummary(
        counts: ContainerCounts.fromJson(Map<String, dynamic>.from(j['counts'] as Map? ?? {})),
        attention: _i(j['attention']),
        nearestLabel: _sN(j['nearest_label']),
        nearestLane: _sN(j['nearest_lane']),
        lastSyncedAt: _date(j['last_synced_at']),
      );
}

class ContainerOverview {
  final ContainerSummary summary;
  final List<ContainerCard> containers;
  ContainerOverview({required this.summary, required this.containers});
  factory ContainerOverview.fromJson(Map<String, dynamic> j) => ContainerOverview(
        summary: ContainerSummary.fromJson(Map<String, dynamic>.from(j['summary'] as Map? ?? {})),
        containers: ((j['containers'] as List?) ?? [])
            .map((e) => ContainerCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class TrackingEvent {
  final String description;
  final String location;
  final String country;
  final DateTime? date;
  final bool isActual;
  TrackingEvent({
    required this.description,
    required this.location,
    required this.country,
    required this.date,
    required this.isActual,
  });
  factory TrackingEvent.fromJson(Map<String, dynamic> j) => TrackingEvent(
        description: _s(j['description']),
        location: _s(j['location']),
        country: _s(j['country']),
        date: _date(j['date']),
        isActual: _b(j['is_actual']),
      );
}

class EtaChange {
  final DateTime? eta;
  final DateTime? date;
  EtaChange({required this.eta, required this.date});
  factory EtaChange.fromJson(Map<String, dynamic> j) =>
      EtaChange(eta: _date(j['eta']), date: _date(j['date']));
}

class SiblingContainer {
  final int id;
  final String reference;
  final String state;
  SiblingContainer({required this.id, required this.reference, required this.state});
  factory SiblingContainer.fromJson(Map<String, dynamic> j) =>
      SiblingContainer(id: _i(j['id']), reference: _s(j['reference']), state: _s(j['state']));
}

class VesselInfo {
  final String? name;
  final String? imo;
  final String? mmsi;
  VesselInfo({this.name, this.imo, this.mmsi});
  factory VesselInfo.fromJson(Map<String, dynamic> j) =>
      VesselInfo(name: _sN(j['name']), imo: _sN(j['imo']), mmsi: _sN(j['mmsi']));
}

/// Full shipment detail = the header card + voyage tables.
class ContainerDetail {
  final ContainerCard card;
  final int? totalDays;
  final double? latitude;
  final double? longitude;
  final String? publicUrl;
  final VesselInfo? vessel;
  final List<TrackingEvent> events;
  final List<EtaChange> etaHistory;
  final List<SiblingContainer> siblings;

  ContainerDetail({
    required this.card,
    required this.totalDays,
    required this.latitude,
    required this.longitude,
    required this.publicUrl,
    required this.vessel,
    required this.events,
    required this.etaHistory,
    required this.siblings,
  });

  factory ContainerDetail.fromJson(Map<String, dynamic> j) {
    final v = j['current_vessel'];
    return ContainerDetail(
      card: ContainerCard.fromJson(j),
      totalDays: _iN(j['total_days']),
      latitude: _dN(j['latitude']),
      longitude: _dN(j['longitude']),
      publicUrl: _sN(j['public_url']),
      vessel: (v is Map && (v['name'] != null)) ? VesselInfo.fromJson(Map<String, dynamic>.from(v)) : null,
      events: ((j['events'] as List?) ?? [])
          .map((e) => TrackingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      etaHistory: ((j['eta_history'] as List?) ?? [])
          .map((e) => EtaChange.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      siblings: ((j['siblings'] as List?) ?? [])
          .map((e) => SiblingContainer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
