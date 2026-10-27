import 'package:book_app/core/error/failures.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot.freezed.dart';

/// De onde veio o dado de um [Snapshot].
enum DataOrigin { cache, remote }

/// Um estado de uma leitura *offline-first*.
///
/// Um repositório emite vários snapshots para a mesma consulta:
///
/// 1. `cache` com `isRefreshing: true`: o que está salvo, mostrado na hora;
/// 2. `remote`: o dado novo, depois que a API respondeu;
/// 3. ou `cache` com `failure`: a API falhou, mas o cache continua na tela.
///
/// Quando não há cache e a API falha, `data` é `null` e `failure` explica.
@freezed
abstract class Snapshot<T> with _$Snapshot<T> {
  const factory Snapshot({
    T? data,
    required DataOrigin origin,
    @Default(false) bool isRefreshing,
    Failure? failure,
    DateTime? cachedAt,
  }) = _Snapshot<T>;

  const Snapshot._();

  bool get hasData => data != null;

  /// Mostrando dados salvos porque a atualização falhou.
  bool get isStale => origin == DataOrigin.cache && failure != null && hasData;
}
