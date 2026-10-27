import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Informa se o aparelho tem alguma conexão de rede ativa.
///
/// Ter conexão não garante que a API responda; por isso o repositório também
/// trata falhas de rede mesmo quando o status é "online".
abstract interface class ConnectivityService {
  Future<bool> get isOnline;

  /// Emite `true`/`false` quando o status muda (sem repetir valores).
  Stream<bool> get onStatusChange;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async => _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
}
