import 'dart:async';

import 'package:book_app/core/network/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Estado global de conexão: `true` quando há rede.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._service) : super(true) {
    _subscription = _service.onStatusChange.listen(emit);
    unawaited(_service.isOnline.then((online) => isClosed ? null : emit(online)));
  }

  final ConnectivityService _service;
  late final StreamSubscription<bool> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

/// Faixa exibida acima da barra de navegação enquanto o aparelho está offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              key: const Key('offline_banner'),
              color: scheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 18, color: scheme.onInverseSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sem internet. Mostrando o que está salvo no aparelho.',
                        style: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
