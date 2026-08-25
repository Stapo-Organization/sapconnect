import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/catalog_models.dart';

/// Sort options, supplied by the server so "recommended" can mean whatever the
/// ranking engine currently says it means.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.options, this.selected});

  final List<SortOption> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    // With nothing chosen, the first option is what the server is already
    // applying — showing it as selected keeps the sheet honest.
    final effective = selected ?? (options.isEmpty ? null : options.first.key);

    return BottomSheetScaffold(
      title: l.listingSortTitle,
      bodyPadding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: option.key == effective
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () {
                Haptics.selection();
                Navigator.of(context).pop(option.key);
              },
            ),
          Gap.h8,
        ],
      ),
    );
  }
}
