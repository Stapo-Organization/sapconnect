import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings/app_settings.dart';
import '../../features/loyalty/data/loyalty_models.dart';
import '../../features/loyalty/data/loyalty_repository.dart';

const MethodChannel _channel = MethodChannel('zb/widget');

/// The food line «رفّ لولو» counts down: the pet's food (dry or wet) that runs
/// out soonest. Null when the store forecasts none.
@visibleForTesting
SupplyItem? widgetFoodLine(LoyaltySummary? summary) {
  if (summary == null) return null;
  final food = [
    for (final item in summary.supply.items)
      if ((item.kind == 'dry' || item.kind == 'wet') && item.runsOutAt != null) item,
  ]..sort((a, b) => a.runsOutAt!.compareTo(b.runsOutAt!));
  return food.isEmpty ? null : food.first;
}

/// The JSON the widget reads, or null to clear it. The run-out instant, not
/// a day count: the widget counts down to it by itself.
@visibleForTesting
String? petShelfJson(SupplyItem? food, {required String lang}) {
  if (food == null) return null;
  return jsonEncode({
    'lang': lang,
    'pet': food.pet?.name,
    'species': food.pet?.species.key,
    'product': food.product.name,
    'runsOut': food.runsOutAt!.millisecondsSinceEpoch ~/ 1000,
  });
}

String? _lastSent;

/// Keeps the iOS home-screen widget in step with the food gauge. Watched by
/// the shell, like the basket that follows the shelf. On a build whose binary
/// predates the widget the channel is missing, and that is simply ignored.
final petWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isIOS) return;
  final summary = ref.watch(loyaltySummaryProvider).value;
  final lang = ref.watch(appSettingsProvider).languageCode;
  final json = petShelfJson(widgetFoodLine(summary), lang: lang);
  if (json == _lastSent) return;
  _lastSent = json;
  unawaited(
    _channel.invokeMethod<void>('setPetShelf', {'json': json}).catchError((Object _) {}),
  );
});
