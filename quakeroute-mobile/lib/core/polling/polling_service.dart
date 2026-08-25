import 'dart:async';

/// Reusable periodic polling primitive (GAP-05 confirmed decision).
///
/// Wraps a [Timer.periodic] loop around an async callback. The first tick
/// fires immediately on start; subsequent ticks every [interval].
/// Not aware of any feature — callers decide what to fetch per tick.
class PollingService {
  PollingService({required this.interval, required this.onTick});

  final Duration interval;
  final Future<void> Function() onTick;

  Timer? _timer;
  bool _busy = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _tick();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _busy = false;
  }

  /// Cancels and restarts the cycle — used after manual refresh so the
  /// next poll does not fire immediately afterwards.
  void restart() {
    stop();
    start();
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await onTick();
    } catch (_) {
      // Polling must survive transient failures; callers surface errors
      // through their own state. Never crash the timer.
    } finally {
      _busy = false;
    }
  }
}
