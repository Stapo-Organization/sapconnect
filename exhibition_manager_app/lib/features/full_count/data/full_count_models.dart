/// Data models for the full (wall-to-wall) showroom count and the showroom map.
library;

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

// ─── Showroom map ─────────────────────────────────────────────

class StoreShelf {
  final String code; // G04-R2
  final int shelfNo;
  final bool labeled;
  const StoreShelf({required this.code, required this.shelfNo, required this.labeled});
  factory StoreShelf.fromJson(Map<String, dynamic> j) =>
      StoreShelf(code: j['code'] ?? '', shelfNo: _i(j['shelf_no']), labeled: j['labeled'] == true);
}

class StoreUnit {
  final String unitCode; // G04
  final String kind; // gondola | wall | endcap | cashier | backroom | other
  final String? name;
  final List<StoreShelf> shelves;
  final int labeled;
  const StoreUnit({required this.unitCode, required this.kind, this.name, required this.shelves, required this.labeled});
  factory StoreUnit.fromJson(Map<String, dynamic> j) => StoreUnit(
        unitCode: j['unit_code'] ?? '',
        kind: j['kind'] ?? 'other',
        name: j['name'],
        shelves: ((j['shelves'] as List?) ?? []).map((e) => StoreShelf.fromJson(e)).toList(),
        labeled: _i(j['labeled']),
      );
}

class StoreMap {
  final String warehouseCode;
  final List<StoreUnit> units;
  final int shelves;
  final int labeled;
  const StoreMap({required this.warehouseCode, required this.units, required this.shelves, required this.labeled});
  factory StoreMap.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? {};
    return StoreMap(
      warehouseCode: j['warehouse_code'] ?? '',
      units: ((j['units'] as List?) ?? []).map((e) => StoreUnit.fromJson(e)).toList(),
      shelves: _i(t['shelves']),
      labeled: _i(t['labeled']),
    );
  }
}

// ─── Session + board ──────────────────────────────────────────

class FullCountSession {
  final int id;
  final String warehouseCode;
  final String? warehouseName;
  final String status; // in_progress | completed
  final String? phase; // counting | recount | missing | review | approved
  final String? snapshotStatus; // pending | running | ready | failed
  final DateTime? startedAt;
  const FullCountSession({
    required this.id,
    required this.warehouseCode,
    this.warehouseName,
    required this.status,
    this.phase,
    this.snapshotStatus,
    this.startedAt,
  });
  bool get inProgress => status == 'in_progress';
  bool get bookReady => snapshotStatus == 'ready';
  factory FullCountSession.fromJson(Map<String, dynamic> j) => FullCountSession(
        id: _i(j['id']),
        warehouseCode: j['warehouse_code'] ?? '',
        warehouseName: j['warehouse_name'],
        status: j['status'] ?? 'in_progress',
        phase: j['phase'],
        snapshotStatus: j['snapshot_status'],
        startedAt: DateTime.tryParse('${j['started_at'] ?? ''}'),
      );
}

class BoardUnit {
  final String unitCode;
  final String kind;
  final String? name;
  final int shelves;
  final int shelvesCounted;
  final String status; // free | counting | done
  final int? userId;
  final String? userName;
  final List<String> shelfCodes;
  final Set<String> countedShelves;
  const BoardUnit({
    required this.unitCode,
    required this.kind,
    this.name,
    required this.shelves,
    required this.shelvesCounted,
    required this.status,
    this.userId,
    this.userName,
    this.shelfCodes = const [],
    this.countedShelves = const {},
  });
  double get progress => shelves == 0 ? 0 : shelvesCounted / shelves;
  factory BoardUnit.fromJson(Map<String, dynamic> j) => BoardUnit(
        unitCode: j['unit_code'] ?? '',
        kind: j['kind'] ?? 'other',
        name: j['name'],
        shelves: _i(j['shelves']),
        shelvesCounted: _i(j['shelves_counted']),
        status: j['status'] ?? 'free',
        userId: j['user_id'] == null ? null : _i(j['user_id']),
        userName: j['user_name'],
        shelfCodes: ((j['shelf_codes'] as List?) ?? []).map((e) => '$e').toList(),
        countedShelves: ((j['counted_shelves'] as List?) ?? []).map((e) => '$e').toSet(),
      );
}

class BoardPerson {
  final int userId;
  final String name;
  final int lines;
  final double units;
  final int unitsPerHour;
  const BoardPerson({required this.userId, required this.name, required this.lines, required this.units, required this.unitsPerHour});
  factory BoardPerson.fromJson(Map<String, dynamic> j) => BoardPerson(
        userId: _i(j['user_id']),
        name: j['name'] ?? '',
        lines: _i(j['lines']),
        units: _d(j['units']),
        unitsPerHour: _i(j['units_per_hour']),
      );
}

/// Someone on the showroom's team the manager can hand a unit to.
class TeamMember {
  final int userId;
  final String name;
  const TeamMember({required this.userId, required this.name});
  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(userId: _i(j['user_id']), name: j['name'] ?? '');
}

class FullCountBoard {
  final FullCountSession session;
  final double bookUnits;
  final int bookItems;
  final double countedUnits;
  final int countedItems;
  final double progress;
  final int unitsTotal;
  final int unitsDone;
  final int elapsedMinutes;
  final int recount;
  final int supervisor;
  final int missing;
  final List<BoardUnit> units;
  final List<BoardPerson> people;
  /// Approve, cancel and hand units between people: the owner only.
  final bool canManage;
  final List<TeamMember> team;
  const FullCountBoard({
    required this.session,
    required this.bookUnits,
    required this.bookItems,
    required this.countedUnits,
    required this.countedItems,
    required this.progress,
    required this.unitsTotal,
    required this.unitsDone,
    required this.elapsedMinutes,
    required this.recount,
    required this.supervisor,
    required this.missing,
    required this.units,
    required this.people,
    this.canManage = false,
    this.team = const [],
  });
  factory FullCountBoard.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?) ?? {};
    final q = (j['queues'] as Map?) ?? {};
    return FullCountBoard(
      session: FullCountSession.fromJson(Map<String, dynamic>.from(j['session'] ?? {})),
      bookUnits: _d(t['book_units']),
      bookItems: _i(t['book_items']),
      countedUnits: _d(t['counted_units']),
      countedItems: _i(t['counted_items']),
      progress: _d(t['progress']),
      unitsTotal: _i(t['units_total']),
      unitsDone: _i(t['units_done']),
      elapsedMinutes: _i(t['elapsed_minutes']),
      recount: _i(q['recount']),
      supervisor: _i(q['supervisor']),
      missing: _i(q['missing']),
      units: ((j['units'] as List?) ?? []).map((e) => BoardUnit.fromJson(Map<String, dynamic>.from(e))).toList(),
      people: ((j['people'] as List?) ?? []).map((e) => BoardPerson.fromJson(Map<String, dynamic>.from(e))).toList(),
      canManage: j['can_manage'] == true,
      team: ((j['team'] as List?) ?? []).map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

// ─── Counting ─────────────────────────────────────────────────

class CountProduct {
  final String itemCode;
  final String? itemName;
  final String? itemNameAr;
  final String? pieceBarcode;
  final String? imageUrl;
  const CountProduct({required this.itemCode, this.itemName, this.itemNameAr, this.pieceBarcode, this.imageUrl});
  String name(bool arabic) {
    final ar = (itemNameAr ?? '').trim();
    final en = (itemName ?? '').trim();
    if (arabic && ar.isNotEmpty) return ar;
    return en.isNotEmpty ? en : (ar.isNotEmpty ? ar : itemCode);
  }

  factory CountProduct.fromJson(Map<String, dynamic> j) => CountProduct(
        itemCode: j['item_code'] ?? '',
        itemName: j['item_name'],
        itemNameAr: j['item_name_ar'],
        pieceBarcode: j['piece_barcode'],
        imageUrl: j['image_url'] ??
            ((j['item_code'] ?? '').toString().length >= 4
                ? 'https://ppte.sa/imghd/${(j['item_code'] as String).substring(0, 4)}/${j['item_code']}.png'
                : null),
      );
}

// ─── Expiry ───────────────────────────────────────────────────

/// One date read on the packs. [date] is `yyyy-MM` (the pack prints month/year)
/// or `yyyy-MM-dd` (a SAP batch date tapped as is).
class ExpirySplit {
  final String date;
  final double qty;
  final String? batch;
  const ExpirySplit({required this.date, required this.qty, this.batch});

  DateTime get end {
    final p = date.split('-').map(int.parse).toList();
    return p.length == 2 ? DateTime(p[0], p[1] + 1, 0) : DateTime(p[0], p[1], p[2]);
  }

  /// `03/2027` or `15/04/2029` — the way packs print it, Latin digits.
  String get label {
    final p = date.split('-');
    return p.length == 2 ? '${p[1]}/${p[0]}' : '${p[2]}/${p[1]}/${p[0]}';
  }

  ExpirySplit withQty(double q) => ExpirySplit(date: date, qty: q, batch: batch);

  Map<String, dynamic> toJson() => {'date': date, 'qty': qty, 'batch': ?batch};
  factory ExpirySplit.fromJson(Map<String, dynamic> j) =>
      ExpirySplit(date: '${j['date']}', qty: _d(j['qty']), batch: j['batch']?.toString());
}

/// A SAP batch of the item in this showroom: its date is a one-tap choice.
class ExpiryOption {
  final String date; // yyyy-MM-dd
  final String? batch;
  const ExpiryOption({required this.date, this.batch});
  ExpirySplit split(double qty) => ExpirySplit(date: date, qty: qty, batch: batch);
  factory ExpiryOption.fromJson(Map<String, dynamic> j) => ExpiryOption(date: '${j['date']}', batch: j['batch']?.toString());
}

class ScanLocation {
  final String code;
  final String unitCode;
  final int shelfNo;
  final String? name;
  const ScanLocation({required this.code, required this.unitCode, required this.shelfNo, this.name});
  factory ScanLocation.fromJson(Map<String, dynamic> j) =>
      ScanLocation(code: j['code'] ?? '', unitCode: j['unit_code'] ?? '', shelfNo: _i(j['shelf_no']), name: j['name']);
}

/// What a scan turned out to be: a shelf label or a product (piece/carton).
class ScanResolution {
  final ScanLocation? location;
  final CountProduct? product;
  final String? matchedKind; // piece | carton | pos | other | item_code
  final double? packSize;
  final List<ExpiryOption> expiryOptions;
  const ScanResolution({this.location, this.product, this.matchedKind, this.packSize, this.expiryOptions = const []});
  bool get isLocation => location != null;
  bool get isCarton => matchedKind == 'carton';
  factory ScanResolution.fromJson(Map<String, dynamic> j) => ScanResolution(
        location: j['type'] == 'location' ? ScanLocation.fromJson(Map<String, dynamic>.from(j['location'])) : null,
        product: j['type'] == 'product' ? CountProduct.fromJson(Map<String, dynamic>.from(j['product'])) : null,
        matchedKind: j['matched_kind'],
        packSize: j['pack_size'] == null ? null : _d(j['pack_size']),
        expiryOptions: ((j['expiry_options'] as List?) ?? [])
            .map((e) => ExpiryOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class CountLine {
  final int id;
  final String itemCode;
  final String? itemName;
  final String? itemNameAr;
  final String? locationCode;
  final int round;
  final double quantity;
  final double? cartons;
  final double? packSize;
  final double? loose;
  final List<ExpirySplit>? expiries; // null = not asked, [] = no date on the packs
  final DateTime? createdAt;
  const CountLine({
    required this.id,
    required this.itemCode,
    this.itemName,
    this.itemNameAr,
    this.locationCode,
    required this.round,
    required this.quantity,
    this.cartons,
    this.packSize,
    this.loose,
    this.expiries,
    this.createdAt,
  });
  String name(bool arabic) {
    final ar = (itemNameAr ?? '').trim();
    if (arabic && ar.isNotEmpty) return ar;
    return (itemName ?? '').trim().isNotEmpty ? itemName! : itemCode;
  }

  factory CountLine.fromJson(Map<String, dynamic> j) => CountLine(
        id: _i(j['id']),
        itemCode: j['item_code'] ?? '',
        itemName: j['item_name'],
        itemNameAr: j['item_name_ar'],
        locationCode: j['location_code'],
        round: _i(j['count_round']),
        quantity: _d(j['quantity']),
        cartons: j['cartons'] == null ? null : _d(j['cartons']),
        packSize: j['pack_size'] == null ? null : _d(j['pack_size']),
        loose: j['loose'] == null ? null : _d(j['loose']),
        expiries: j['expiries'] is List
            ? (j['expiries'] as List).map((e) => ExpirySplit.fromJson(Map<String, dynamic>.from(e))).toList()
            : null,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
      );
}

class RecountItem {
  final CountProduct product;
  final int round; // 2 blind recount, 3 supervisor
  final List<String> locations;
  final bool yours;
  /// Started and not yet closed — by this user when [yours], else by [byName].
  final bool inProgress;
  final String? byName;
  const RecountItem({
    required this.product,
    required this.round,
    required this.locations,
    required this.yours,
    this.inProgress = false,
    this.byName,
  });
  factory RecountItem.fromJson(Map<String, dynamic> j) => RecountItem(
        product: CountProduct.fromJson(j),
        round: _i(j['round']),
        locations: ((j['locations'] as List?) ?? []).map((e) => '$e').toList(),
        yours: j['yours'] == true,
        inProgress: j['in_progress'] == true,
        byName: j['by_name'],
      );
}

// ─── Result ───────────────────────────────────────────────────

class VarianceRow {
  final CountProduct product;
  final double systemQty;
  final double countedQty;
  final double variance;
  final double? varianceValue;
  const VarianceRow({required this.product, required this.systemQty, required this.countedQty, required this.variance, this.varianceValue});
  factory VarianceRow.fromJson(Map<String, dynamic> j) => VarianceRow(
        product: CountProduct.fromJson(j),
        systemQty: _d(j['system_qty']),
        countedQty: _d(j['counted_qty']),
        variance: _d(j['variance']),
        varianceValue: j['variance_value'] == null ? null : _d(j['variance_value']),
      );
}

class FullCountResult {
  final FullCountSession session;
  final int items;
  final int matched;
  final int withVariance;
  final double? accuracy;
  final double overValue;
  final double shortValue;
  final double netValue;
  final List<VarianceRow> topVariances;
  final ExpiryReport? expiry;
  const FullCountResult({
    required this.session,
    required this.items,
    required this.matched,
    required this.withVariance,
    this.accuracy,
    required this.overValue,
    required this.shortValue,
    required this.netValue,
    required this.topVariances,
    this.expiry,
  });
  factory FullCountResult.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map?) ?? {};
    return FullCountResult(
      session: FullCountSession.fromJson(Map<String, dynamic>.from(j['session'] ?? {})),
      items: _i(s['items']),
      matched: _i(s['matched']),
      withVariance: _i(s['with_variance']),
      accuracy: s['accuracy'] == null ? null : _d(s['accuracy']),
      overValue: _d(s['over_value']),
      shortValue: _d(s['short_value']),
      netValue: _d(s['net_value']),
      topVariances: ((j['top_variances'] as List?) ?? []).map((e) => VarianceRow.fromJson(Map<String, dynamic>.from(e))).toList(),
      expiry: j['expiry'] is Map ? ExpiryReport.fromJson(Map<String, dynamic>.from(j['expiry'])) : null,
    );
  }
}

class ExpiryBucket {
  final int items;
  final double units;
  final double value;
  const ExpiryBucket({this.items = 0, this.units = 0, this.value = 0});
  factory ExpiryBucket.fromJson(Map<String, dynamic> j) =>
      ExpiryBucket(items: _i(j['items']), units: _d(j['units']), value: _d(j['value']));
}

class ExpiryRow {
  final CountProduct product;
  final ExpirySplit split;
  final int days;
  final double? value;
  final String? bucket; // expired | d30 | d60 | d90
  final List<String> locations;
  final List<String> sapDates;
  const ExpiryRow({
    required this.product,
    required this.split,
    required this.days,
    this.value,
    this.bucket,
    this.locations = const [],
    this.sapDates = const [],
  });
  factory ExpiryRow.fromJson(Map<String, dynamic> j) => ExpiryRow(
        product: CountProduct.fromJson(j),
        split: ExpirySplit(date: '${j['date']}', qty: _d(j['qty'])),
        days: _i(j['days']),
        value: j['value'] == null ? null : _d(j['value']),
        bucket: j['bucket'],
        locations: ((j['locations'] as List?) ?? []).map((e) => '$e').toList(),
        sapDates: ((j['sap_dates'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

/// What the counters read on the packs: what has expired or expires soon, and
/// shelf dates SAP has no batch for in this showroom.
class ExpiryReport {
  final int lines;
  final int linesWithDate;
  final int linesNoDate;
  final Map<String, ExpiryBucket> buckets;
  final List<ExpiryRow> soon;
  final List<ExpiryRow> mismatch;
  final int mismatchTotal;
  const ExpiryReport({
    required this.lines,
    required this.linesWithDate,
    required this.linesNoDate,
    required this.buckets,
    required this.soon,
    required this.mismatch,
    required this.mismatchTotal,
  });
  factory ExpiryReport.fromJson(Map<String, dynamic> j) {
    List<ExpiryRow> rows(dynamic v) =>
        ((v as List?) ?? []).map((e) => ExpiryRow.fromJson(Map<String, dynamic>.from(e))).toList();
    final b = Map<String, dynamic>.from((j['buckets'] as Map?) ?? {});
    return ExpiryReport(
      lines: _i(j['lines']),
      linesWithDate: _i(j['lines_with_date']),
      linesNoDate: _i(j['lines_no_date']),
      buckets: b.map((k, v) => MapEntry(k, ExpiryBucket.fromJson(Map<String, dynamic>.from(v)))),
      soon: rows(j['soon']),
      mismatch: rows(j['mismatch']),
      mismatchTotal: _i(j['mismatch_total']),
    );
  }
}
