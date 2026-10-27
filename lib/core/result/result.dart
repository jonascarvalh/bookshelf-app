import 'package:book_app/core/error/failures.dart';

/// Resultado de uma operação que pode falhar, sem uso de exceções.
///
/// Usa *sealed classes* do Dart 3, o que permite `switch` exaustivo:
///
/// ```dart
/// switch (result) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Atalho para encadear o tratamento de sucesso e falha.
  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) {
    return switch (this) {
      Ok<T>(:final value) => onSuccess(value),
      Err<T>(:final failure) => onFailure(failure),
    };
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Retorna o valor em caso de sucesso ou `null` em caso de falha.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// Retorna a falha ou `null` em caso de sucesso.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Err($failure)';
}

/// Valor de retorno para operações que não produzem dados.
final class Unit {
  const Unit._();
}

const unit = Unit._();
