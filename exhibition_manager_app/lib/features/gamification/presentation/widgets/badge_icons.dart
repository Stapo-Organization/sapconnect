import 'package:flutter/material.dart';

/// Maps backend badge icon names to Material icons.
IconData badgeIcon(String name) {
  switch (name) {
    case 'flag':
      return Icons.flag_rounded;
    case 'autorenew':
      return Icons.autorenew_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'visibility':
      return Icons.visibility_rounded;
    case 'local_fire_department':
      return Icons.local_fire_department_rounded;
    case 'whatshot':
      return Icons.whatshot_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}
