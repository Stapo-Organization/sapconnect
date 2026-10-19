import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';

/// Calm "nothing urgent" row for the Action Center — a soft success check and
/// one line, no confetti. Sits inside the same section as the alerts would.
class AllClearCard extends StatelessWidget {
  /// When false the row renders bare (it already sits inside an [AppSection]).
  final bool asCard;

  const AllClearCard({super.key, this.asCard = true});

  @override
  Widget build(BuildContext context) {
    final row = AppListRow(
      icon: Icons.check_rounded,
      iconColor: AppColors.success,
      title: context.tr('all_clear_title'),
      subtitle: context.tr('all_clear_subtitle'),
    );
    return asCard ? AppSection(children: [row]) : row;
  }
}
