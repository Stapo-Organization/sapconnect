import 'package:flutter/widgets.dart';

/// Screen-size helpers so layouts adapt to the small Android phones used in
/// the showrooms (360dp wide and below) as well as the iPhone.
///
/// - compact: < 380dp wide (most budget Android phones, iPhone SE/mini)
/// - tiny:    < 340dp wide (old 320dp phones, or large display zoom)
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < 380;
  bool get isTiny => screenWidth < 340;

  /// Picks a value by width class: [regular] by default, [compact] under
  /// 380dp, and [tiny] (falls back to compact) under 340dp.
  T byWidth<T>({required T regular, required T compact, T? tiny}) {
    if (isTiny) return tiny ?? compact;
    if (isCompact) return compact;
    return regular;
  }
}

/// The largest system font scale the layouts are designed for. Phones set to a
/// bigger font still get bigger text, just capped here so rows don't break.
const double kMaxAppTextScale = 1.15;

/// Bottom-nav label size that keeps every label on one line: 6 tabs on a
/// 360dp phone leave ~60dp per tab, too narrow for 11.5px «صحة المعرض».
double navLabelFontSize(BuildContext context, int tabCount) {
  final perTab = MediaQuery.sizeOf(context).width / (tabCount <= 0 ? 1 : tabCount);
  if (perTab >= 72) return 11.5;
  if (perTab >= 62) return 10.5;
  return 9.5;
}
