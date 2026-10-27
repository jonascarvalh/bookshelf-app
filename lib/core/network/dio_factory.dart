import 'package:book_app/core/error/exceptions.dart';
import 'package:book_app/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';

/// Configuração do cliente HTTP da Open Library.
abstract final class DioFactory {
  static const baseUrl = 'https://openlibrary.org';

  /// A Open Library pede um User-Agent identificável para clientes de API.
  static const userAgent = 'Estante/1.0 (https://github.com/jonascarvalh/bookshelf-app)';

  static Dio create({HttpClientAdapter? adapter, Sleep? sleep}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio: dio, sleep: sleep));
    return dio;
  }

  /// Converte um [DioException] (já depois das novas tentativas) em
  /// [ApiException].
  static ApiException mapError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => const ApiException(ApiErrorKind.timeout),
      DioExceptionType.connectionError => const ApiException(ApiErrorKind.noConnection),
      DioExceptionType.badResponse when e.response?.statusCode == 404 => const ApiException(
        ApiErrorKind.notFound,
        statusCode: 404,
      ),
      DioExceptionType.badResponse => ApiException(
        ApiErrorKind.server,
        statusCode: e.response?.statusCode,
      ),
      _ => const ApiException(ApiErrorKind.noConnection),
    };
  }
}
