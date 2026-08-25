/// Session-scoped reference to the user's active route (routing feature).
/// In-memory only — the backend remains source of truth via
/// `GET /routes/active` (api-specification.md §6.3).
class ActiveRouteInfo {
  const ActiveRouteInfo({
    required this.routeId,
    required this.destinationId,
    required this.destinationName,
  });

  final String routeId;
  final String destinationId;
  final String destinationName;
}
