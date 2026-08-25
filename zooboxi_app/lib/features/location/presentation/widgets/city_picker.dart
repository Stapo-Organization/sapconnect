import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/location_models.dart';
import '../../data/location_repository.dart';

/// Searchable list of the cities the store serves.
class CityPicker extends ConsumerStatefulWidget {
  const CityPicker({super.key, required this.onSelected});

  final ValueChanged<CityEntry> onSelected;

  @override
  ConsumerState<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends ConsumerState<CityPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(citiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.citiesSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Gap.h12,
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.46),
          child: AsyncView<List<CityEntry>>(
            value: cities,
            onRetry: () => ref.invalidate(citiesProvider),
            skeleton: const _CitiesSkeleton(),
            builder: (all) {
              final filtered = _filter(all, locale);
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      l.citiesEmpty,
                      style: context.tt.bodyMedium
                          ?.copyWith(color: context.cs.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final city = filtered[index];
                  return ListTile(
                    leading: Icon(Icons.location_city_rounded, color: context.cs.primary),
                    title: Text(city.nameFor(locale)),
                    trailing: Icon(
                      context.isRtl
                          ? Icons.keyboard_arrow_left_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onTap: () => widget.onSelected(city),
                  );
                },
              );
            },
          ),
        ),
        Gap.h8,
      ],
    );
  }

  List<CityEntry> _filter(List<CityEntry> all, String locale) {
    if (_query.isEmpty) return all;
    final needle = _query.toLowerCase();
    return all
        .where((city) =>
            city.city.toLowerCase().contains(needle) ||
            (city.nameEn ?? '').toLowerCase().contains(needle))
        .toList();
  }
}

class _CitiesSkeleton extends StatelessWidget {
  const _CitiesSkeleton();

  @override
  Widget build(BuildContext context) => ShimmerGroup(
        child: Column(
          children: List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  SkeletonBox.circle(size: 28),
                  SizedBox(width: 12),
                  SkeletonBox(width: 120, height: 13),
                ],
              ),
            ),
          ),
        ),
      );
}
