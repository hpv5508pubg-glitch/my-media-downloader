import 'dart:async';
import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// In-memory circular buffer for secret 5-tap Debug Logger screen
class DebugLogStore {
  static final DebugLogStore instance = DebugLogStore._();
  DebugLogStore._();

  final List<String> _logs = [];
  static const int _maxLogs = 300;

  List<String> get logs => List.unmodifiable(_logs);

  void add(String log) {
    final entry = '[${DateTime.now().toIso8601String()}] $log';
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
  }

  void clear() {
    _logs.clear();
  }
}

/// Automatically attaches X-API-Key to all requests
class ApiKeyInterceptor extends Interceptor {
  String _apiKey;

  ApiKeyInterceptor({String? apiKey})
      : _apiKey = apiKey ?? AppConstants.defaultApiKey;

  void updateApiKey(String newKey) {
    _apiKey = newKey;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-API-Key'] = _apiKey;
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }
}

/// Auto-retries failed requests up to 5 times with exponential backoff.
/// Does not retry on 401 Unauthorized, 400 Bad Request, or User Cancelation.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = AppConstants.maxRetryAttempts,
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if request was intentionally cancelled by user
    if (err.type == DioExceptionType.cancel) {
      DebugLogStore.instance.add('Request cancelled by user: ${err.requestOptions.path}');
      return handler.next(err);
    }

    // Do not retry on client errors (400, 401, 403, 404)
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      DebugLogStore.instance.add('Client error $statusCode on ${err.requestOptions.path}, skipping retry.');
      return handler.next(err);
    }

    final extra = err.requestOptions.extra;
    final int retryCount = (extra['retry_count'] as int?) ?? 0;

    if (retryCount < maxRetries) {
      final nextRetry = retryCount + 1;
      final delayMs = 600 * nextRetry;

      DebugLogStore.instance.add(
        'Retrying request (${nextRetry}/$maxRetries) in ${delayMs}ms: ${err.requestOptions.path}',
      );

      await Future.delayed(Duration(milliseconds: delayMs));

      final newOptions = Options(
        method: err.requestOptions.method,
        headers: err.requestOptions.headers,
        responseType: err.requestOptions.responseType,
        contentType: err.requestOptions.contentType,
        extra: Map<String, dynamic>.from(err.requestOptions.extra)
          ..['retry_count'] = nextRetry,
      );

      try {
        final response = await dio.request<dynamic>(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          cancelToken: err.requestOptions.cancelToken,
          options: newOptions,
        );
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return onError(retryErr, handler);
      } catch (unknownErr) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}

/// Logs all HTTP traffic into DebugLogStore for in-app diagnostics
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    DebugLogStore.instance.add('--> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    DebugLogStore.instance.add(
      '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DebugLogStore.instance.add(
      '<-- ERROR ${err.response?.statusCode ?? err.type.name} on ${err.requestOptions.method} ${err.requestOptions.uri}: ${err.message}',
    );
    handler.next(err);
  }
}
