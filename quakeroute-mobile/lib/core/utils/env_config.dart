import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessors for `.env` configuration with safe defaults.
/// No business logic — configuration only.
abstract final class EnvConfig {
  /// Polling interval in seconds for all periodic refresh loops
  /// (hazards delta, active route, simulation run status).
  /// Confirmed decision GAP-05: default 20s, configurable via .env.
  static const int defaultPollIntervalSeconds = 20;

  static Duration pollInterval() {
    final raw = maybeGet('POLL_INTERVAL_SECONDS');
    final seconds = int.tryParse(raw ?? '') ?? defaultPollIntervalSeconds;
    if (seconds < 5) return const Duration(seconds: defaultPollIntervalSeconds);
    return Duration(seconds: seconds);
  }

  /// Safe read — never throws even when .env was not loaded
  /// (e.g. unit/widget tests or missing asset).
  static String? maybeGet(String key) {
    try {
      return dotenv.maybeGet(key);
    } catch (_) {
      return null;
    }
  }
}
