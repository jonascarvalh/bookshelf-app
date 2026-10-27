import 'package:book_app/core/error/failures.dart';

/// Tipos de erro que a camada de rede consegue distinguir.
enum ApiErrorKind { noConnection, timeout, server, notFound, invalidResponse }

/// Exceção lançada pelos *data sources* remotos.
///
/// O repositório a captura e converte em [Failure] com [toFailure], de modo
/// que nenhuma exceção do Dio vaze para o domínio.
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode});

  final ApiErrorKind kind;
  final int? statusCode;

  Failure toFailure() => switch (kind) {
    ApiErrorKind.noConnection => const NoConnectionFailure(),
    ApiErrorKind.timeout => const TimeoutFailure(),
    ApiErrorKind.notFound => const NotFoundFailure(),
    ApiErrorKind.server => ServerFailure(statusCode),
    ApiErrorKind.invalidResponse => const ServerFailure(),
  };

  @override
  String toString() => 'ApiException($kind, statusCode: $statusCode)';
}
