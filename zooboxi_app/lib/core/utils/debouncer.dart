import 'dart:async';

/// Collapses a burst of calls into one, [duration] after the last.
/// Always `dispose()` it — a live timer firing into a dead widget is the
/// classic source of "setState called after dispose".
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 350)});

  final Duration duration;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs the pending action immediately, if any is scheduled.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
