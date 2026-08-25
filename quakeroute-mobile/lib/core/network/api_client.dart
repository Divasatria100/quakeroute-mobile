import 'package:dio/dio.dart';

import '../utils/env_config.dart';
import 'api_exception.dart';

/// Dio-based REST client — single networking layer for all
/// mobile↔backend communication (tech-stack.md §2.5, architecture-document.md §5 core/network).
///
/// Base path /api/v1 per api-specification.md §1.
/// Auth placeholder: X-Session-Id header (TBD, api-specification.md §1).
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl =
        EnvConfig.maybeGet('API_BASE_URL') ?? 'http://10.0.2.2:8000/api/v1';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Accept'] = 'application/json';

    final sessionId = EnvConfig.maybeGet('SESSION_ID');
    if (sessionId != null && sessionId.isNotEmpty) {
      _dio.options.headers['X-Session-Id'] = sessionId;
    }

    _dio.interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false),
    );
  }

  final Dio _dio;

  Dio get dio => _dio;

  /// Generic GET.
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Generic POST.
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  ApiException _mapDioException(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    String code = 'NETWORK_ERROR';
    String message = e.message ?? 'Network error';
    Map<String, dynamic>? details;

    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        code = err['code'] as String? ?? code;
        message = err['message'] as String? ?? message;
        if (err['details'] is Map<String, dynamic>) {
          details = err['details'] as Map<String, dynamic>;
        }
      }
    }

    if (status == null) {
      return NetworkException(code: code, message: message, details: details);
    }

    return ApiException(
      code: code,
      message: message,
      statusCode: status,
      details: details,
    );
  }
}
