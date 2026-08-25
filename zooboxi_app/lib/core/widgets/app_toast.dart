import 'package:flutter/material.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';

enum ToastType { success, error, info }

/// A floating toast pinned below the status bar.
///
/// Deliberately not a SnackBar: commerce screens have a pinned add-to-cart bar
/// and a bottom nav, and a bottom-anchored message either covers the CTA or
/// pushes it. One toast at a time — a new one replaces the last.
abstract final class AppToast {
  static OverlayEntry? _current;

  static void success(BuildContext context, String message) =>
      show(context, message, ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, ToastType.error);

  static void info(BuildContext context, String message) =>
      show(context, message, ToastType.info);

  static void show(BuildContext context, String message, ToastType type) {
    if (message.trim().isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _current?.remove();
    _current = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        type: type,
        // Directionality lives on the app, not the overlay, so it is captured
        // here or the toast renders LTR inside an Arabic app.
        textDirection: Directionality.of(context),
        onDismissed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.textDirection,
    required this.onDismissed,
  });

  final String message;
  final ToastType type;
  final TextDirection textDirection;
  final VoidCallback onDismissed;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 3000), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _leaving) return;
    _leaving = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final zb = context.zb;

    final (color, icon) = switch (widget.type) {
      ToastType.success => (zb.success, Icons.check_circle_rounded),
      ToastType.error => (cs.error, Icons.error_rounded),
      ToastType.info => (cs.primary, Icons.info_rounded),
    };

    return Directionality(
      textDirection: widget.textDirection,
      child: Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 16,
        right: 16,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) => Opacity(
            opacity: _curve.value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, (1 - _curve.value) * -20),
              child: child,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GestureDetector(
                onTap: _dismiss,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.inverseSurface.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(ZbTokens.rMd),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: context.tt.bodyMedium?.copyWith(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
