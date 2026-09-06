import 'package:flutter/widgets.dart';

import '../../../core/delivery/delivery_eta.dart';
import '../../../core/location/location_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_models.dart';

/// The one sentence the header owes the customer: **when this arrives**.
///
/// Not "how fast we are" — a duration ("within 2 hours") makes a person do
/// arithmetic while holding a phone in a shop. A clock time does not: «الساعة
/// 10:30 م» is the same information already answered.
///
/// Which promise applies is the *shelf's* business, not the address's: on the
/// زوبكسي storefront the answer is tomorrow even while an express branch is a
/// kilometre away, so [scope] (server-resolved for the active tab) decides,
/// and the saved location is only the fallback before the first payload lands.
String deliveryWhenLabel(
  BuildContext context, {
  CatalogScope? scope,
  required ZbLocation location,
  DateTime? now,
}) {
  final l = L.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final tier = (scope != null && scope.tier.isNotEmpty)
      ? scope.tier
      : (location.deliveryType ?? '');

  switch (tier) {
    case 'express':
      final eta = resolveExpressEta(
        now: now ?? DateTime.now(),
        hours: scope?.expressHours,
      );
      // A whole hour is written bare — «الساعة 11 م», not «11:00 م».
      final clock = Fmt.clockShort(eta.at, locale);
      return eta.tomorrow ? l.etaTomorrowAt(clock) : l.etaAt(clock);
    case 'same_day':
      return l.etaTomorrow;
    default:
      final date = scope?.date ?? '';
      return date.isEmpty ? '' : l.etaOn(date);
  }
}
