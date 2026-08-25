import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';

/// Standard chrome for a modal sheet: title row, optional trailing action,
/// a scrollable body that never exceeds ~88% of the screen, and a pinned
/// footer that stays clear of the home indicator and the keyboard.
class BottomSheetScaffold extends StatelessWidget {
  const BottomSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.trailing,
    this.maxHeightFactor = 0.88,
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? trailing;
  final double maxHeightFactor;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 20, end: 12, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.tt.titleLarge),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                subtitle!,
                                style: context.tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: bodyPadding,
                  child: child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a sheet with the app's standard presentation. Scrolling is controlled
/// so a tall sheet (facets, cities) can still grow with the keyboard.
Future<T?> showZbSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    builder: builder,
  );
}
