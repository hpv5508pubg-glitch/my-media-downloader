import 'dart:async';
import 'package:dio/dio.dart';

import '../../data/models/extract_envelope.dart';
import '../../data/models/job_status.dart';
import '../constants/app_constants.dart';
import 'api_interceptors.dart';

class ApiClient {
  late final Dio _dio;
  late final ApiKeyInterceptor _apiKeyInterceptor;

  ApiClient({
    String? baseUrl,
    String? apiKey,
  }) {
    final effectiveBaseUrl = baseUrl ?? AppConstants.defaultBaseUrl;
    final effectiveApiKey = apiKey ?? AppConstants.defaultApiKey;

    _dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        responseType: ResponseType.json,
      ),
    );

    _apiKeyInterceptor = ApiKeyInterceptor(apiKey: effectiveApiKey);

    _dio.interceptors.addAll([
      _apiKeyInterceptor,
      LoggingInterceptor(),
      RetryInterceptor(dio: _dio, maxRetries: AppConstants.maxRetryAttempts),
    ]);
  }

  Dio get rawDio => _dio;

  /// Update base URL dynamically when user edits Settings
  void updateBaseUrl(String newUrl) {
    var formatted = newUrl.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    _dio.options.baseUrl = formatted;
    DebugLogStore.instance.add('Base URL updated to: $formatted');
  }

  /// Update API Key dynamically when user edits Settings
  void updateApiKey(String newKey) {
    _apiKeyInterceptor.updateApiKey(newKey.trim());
    DebugLogStore.instance.add('API Key updated');
  }

  /// Ping /health to wake up HF Spaces or verify server availability
  Future<bool> checkHealth({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/health',
        cancelToken: cancelToken,
      );
      return response.statusCode == 200;
    } catch (exc) {
      DebugLogStore.instance.add('Health check failed: $exc');
      return false;
    }
  }

  /// POST /api/extract: Parse video, playlist, or search keywords
  Future<ExtractEnvelope> extractMedia(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/extract',
      data: {'query': query.trim()},
      cancelToken: cancelToken,
    );

    if (response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Empty response body received from server',
      );
    }

    return ExtractEnvelope.fromJson(response.data!);
  }

  /// POST /api/download-job: Dispatch background download and transcode job
  Future<String> createDownloadJob({
    required String url,
    required String formatId,
    String? customTitle,
    String? customArtist,
    CancelToken? cancelToken,
  }) async {
    final payload = <String, dynamic>{
      'url': url.trim(),
      'format_id': formatId,
      if (customTitle != null && customTitle.isNotEmpty)
        'custom_title': customTitle.trim(),
      if (customArtist != null && customArtist.isNotEmpty)
        'custom_artist': customArtist.trim(),
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/download-job',
      data: payload,
      cancelToken: cancelToken,
    );

    final data = response.data;
    if (data == null || !data.containsKey('job_id')) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Invalid response from /api/download-job: missing job_id',
      );
    }

    return data['job_id'] as String;
  }

  /// GET /api/job-status/{job_id}: Poll download and conversion progress
  Future<JobStatus> getJobStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/job-status/$jobId',
      cancelToken: cancelToken,
    );

    if (response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Empty response body from /api/job-status',
      );
    }

    return JobStatus.fromJson(response.data!);
  }

  /// DELETE /api/job/{job_id}: Two-way job cancellation on server
  Future<bool> cancelJob(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/api/job/$jobId',
        cancelToken: cancelToken,
      );
      return response.statusCode == 200;
    } catch (exc) {
      DebugLogStore.instance.add('Failed to cancel job $jobId on server: $exc');
      return false;
    }
  }

  /// GET /api/stream/{job_id}: Fetch media stream with optional Range header
  Future<Response<ResponseBody>> getStreamResponse(
    String jobId, {
    String? rangeHeader,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{};
    if (rangeHeader != null) {
      headers['Range'] = rangeHeader;
    }

    return await _dio.get<ResponseBody>(
      '/api/stream/$jobId',
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
      ),
      cancelToken: cancelToken,
    );
  }

  /// POST /api/admin/cookies: Push Netscape cookies to server
  Future<bool> updateCookies(
    String cookiesText, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/admin/cookies',
      data: {'cookies': cookiesText},
      cancelToken: cancelToken,
    );
    return response.statusCode == 200;
  }
}
