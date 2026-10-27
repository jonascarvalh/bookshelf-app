import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

typedef Sleep = Future<void> Function(Duration duration);

/// Repete requisições que falharam por motivos transitórios.
///
/// Tenta de novo em caso de timeout, falha de conexão e respostas 408, 429 e
/// 5xx, com *backoff* exponencial (`baseDelay`, `2 × baseDelay`, `4 × …`).
/// Erros do cliente (404, 400…) não são repetidos, porque a resposta seria a
/// mesma.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 600),
    Sleep? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed;

  static const _attemptKey = 'retry_attempt';

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Sleep _sleep;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (attempt >= maxRetries || !shouldRetry(err)) {
      return handler.next(err);
    }

    await _sleep(baseDelay * math.pow(2, attempt).toInt());
    options.extra[_attemptKey] = attempt + 1;

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static bool shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 408 || status == 429 || status >= 500;
      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }
}
