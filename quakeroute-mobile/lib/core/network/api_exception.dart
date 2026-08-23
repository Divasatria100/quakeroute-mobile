/// Maps api-specification.md §2 error format to typed exception.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

class NetworkException extends ApiException {
  const NetworkException({
    required super.code,
    required super.message,
    super.statusCode,
    super.details,
  });
}
