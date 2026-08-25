import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../state/ui_state.dart';
import 'qr_scaffold.dart';

/// Single standardized renderer for async surfaces (ui-ux §7.4, §11).
/// Maps [UiState] onto the shared loading / empty / error components so
/// every screen presents identical state patterns.
class QRAsyncView<T> extends StatelessWidget {
  const QRAsyncView({
    required this.state,
    required this.contentBuilder,
    super.key,
    this.onRetry,
    this.loadingMessage,
    this.emptyMessage,
    this.emptyIcon,
    this.showLoadingForInitial = false,
  });

  final UiState<T> state;
  final Widget Function(BuildContext context, T data) contentBuilder;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final String? emptyMessage;
  final IconData? emptyIcon;

  /// Whether [UiInitial] renders as a loading row. Surfaces that must not
  /// show anything before the first fetch leave this off.
  final bool showLoadingForInitial;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return switch (s) {
      UiInitial<T>() => showLoadingForInitial
          ? QRLoadingRow(message: loadingMessage)
          : const SizedBox.shrink(),
      UiLoading<T>() => QRLoadingRow(message: s.message ?? loadingMessage),
      UiEmpty<T>() => QREmptyState(
        message: s.message ?? emptyMessage ?? 'Nothing to show yet.',
        icon: emptyIcon,
      ),
      UiError<T>() => QRErrorState(message: s.message, onRetry: onRetry),
      UiSuccess<T>() => contentBuilder(context, s.data),
    };
  }
}

/// Maps a thrown repository/network failure to a user-facing message.
/// Plain language only — no raw codes or stack traces in the UI.
String friendlyErrorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
