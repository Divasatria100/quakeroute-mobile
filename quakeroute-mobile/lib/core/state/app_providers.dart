import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Global Riverpod providers — architecture-document.md §5 core/state.

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Active route id held in memory (routing feature).
final activeRouteIdProvider = StateProvider<String?>((ref) => null);

/// Connectivity placeholder — to be wired to connectivity_plus if needed.
final connectivityProvider = StateProvider<bool>((ref) => true);
