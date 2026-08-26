import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/location/location_controller.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../location/presentation/location_sheet.dart';

/// The address bar that follows the customer down the page.
///
/// The hero canvas carries the full address at the top; the moment it scrolls
/// away this compact bar slides in under the status bar, so "where is this
/// going?" is answerable from anywhere in the feed — the pattern every
/// delivery app trains people on. Tap → the location sheet.
class AddressNavBar extends ConsumerWidget {
  const AddressNavBar({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cs = context.cs;
    final locale = Localizations.localeOf(context).languageCode;
    final location = ref.watch(currentLocationProvider);
    final detail = location.detailLabel(locale) ?? l.locationChoose;
    final statusTop = MediaQuery.paddingOf(context).top;

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsetsDirectional.only(
              top: statusTop + 4,
              bottom: 8,
              start: 12,
              end: 12,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Haptics.selection();
                  showLocationSheet(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.place_rounded, size: 17, color: cs.primary),
                      Gap.w6,
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Gap.w4,
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      const Spacer(),
                      const PromiseLine(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
