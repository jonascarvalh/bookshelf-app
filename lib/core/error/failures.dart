import 'package:equatable/equatable.dart';

/// Falha exposta pelas camadas de domínio e dados.
///
/// É uma *sealed class*: a apresentação trata cada caso com `switch`
/// exaustivo e mostra uma mensagem adequada ao usuário.
sealed class Failure extends Equatable {
  const Failure();

  /// Mensagem pronta para exibir na interface.
  String get message;

  @override
  List<Object?> get props => const [];
}

/// O aparelho está sem internet (ou a conexão caiu durante a requisição).
final class NoConnectionFailure extends Failure {
  const NoConnectionFailure();

  @override
  String get message => 'Você está sem internet.';
}

/// O servidor demorou demais para responder, mesmo após novas tentativas.
final class TimeoutFailure extends Failure {
  const TimeoutFailure();

  @override
  String get message => 'A Open Library demorou para responder. Tente de novo.';
}

/// O servidor respondeu com erro (5xx, 4xx inesperado ou JSON inválido).
final class ServerFailure extends Failure {
  const ServerFailure([this.statusCode]);

  final int? statusCode;

  @override
  String get message => statusCode == null
      ? 'Resposta inesperada da Open Library.'
      : 'A Open Library está com problemas (erro $statusCode).';

  @override
  List<Object?> get props => [statusCode];
}

/// O recurso procurado não existe (ex.: ISBN não catalogado).
final class NotFoundFailure extends Failure {
  const NotFoundFailure([this.detail]);

  final String? detail;

  @override
  String get message => detail ?? 'Nada encontrado.';

  @override
  List<Object?> get props => [detail];
}

/// Erro ao ler ou gravar no banco local.
final class CacheFailure extends Failure {
  const CacheFailure();

  @override
  String get message => 'Não foi possível acessar os dados salvos no aparelho.';
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();

  @override
  String get message => 'Algo deu errado. Tente novamente.';
}
