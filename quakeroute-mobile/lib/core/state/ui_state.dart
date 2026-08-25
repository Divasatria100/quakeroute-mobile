/// Standardized async UI state for every screen surface
/// (ui-ux-specification.md §7.4, §11 consolidated table).
///
/// Every feature notifier maps its repository results into one of these
/// states; [QRAsyncView] renders the matching loading/empty/error pattern.
sealed class UiState<T> {
  const UiState();

  /// Convenience cast helper — returns this state typed as [UiSuccess].
  UiSuccess<T>? get asSuccess => this is UiSuccess<T>
      ? this as UiSuccess<T>
      : null;
}

/// Nothing happened yet (e.g. before first fetch is triggered).
class UiInitial<T> extends UiState<T> {
  const UiInitial();
}

/// Fetch in progress.
class UiLoading<T> extends UiState<T> {
  const UiLoading({this.message});
  final String? message;
}

/// Success with data. [isRefresh] marks a silent refresh over already
/// visible content so screens can avoid flashing a spinner.
class UiSuccess<T> extends UiState<T> {
  const UiSuccess(this.data, {this.isRefresh = false});

  final T data;
  final bool isRefresh;
}

/// Success but no items to show.
class UiEmpty<T> extends UiState<T> {
  const UiEmpty({this.message});
  final String? message;
}

/// Failure — carries a plain-language message, never raw stack traces
/// (ui-ux §11: "never a raw error code/stack trace").
class UiError<T> extends UiState<T> {
  const UiError(this.message, {this.code, this.details});
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
}
