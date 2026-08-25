import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/envelope.dart';
import '../../../core/providers.dart';
import '../../catalog/data/catalog_models.dart';

class MetaRepository {
  MetaRepository(this._api);

  final ApiClient _api;

  Future<MetaConfig> meta() async => MetaConfig.fromJson(asMap(await _api.get('/meta')));
}

final metaRepositoryProvider =
    Provider<MetaRepository>((ref) => MetaRepository(ref.watch(apiClientProvider)));

/// Remote configuration: force-update gate, free-shipping threshold, feature
/// flags, maintenance switch. Read once per launch; a failure is non-fatal
/// because every value has a safe local default.
final metaProvider = FutureProvider<MetaConfig>(
  (ref) => ref.watch(metaRepositoryProvider).meta(),
);
