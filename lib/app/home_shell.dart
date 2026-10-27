import 'package:book_app/core/presentation/connectivity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Estrutura com a barra de navegação inferior das três abas.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OfflineBanner(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) =>
                shell.goBranch(index, initialLocation: index == shell.currentIndex),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shelves),
                selectedIcon: Icon(Icons.shelves),
                label: 'Estante',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Buscar',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_rounded),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Estatísticas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
