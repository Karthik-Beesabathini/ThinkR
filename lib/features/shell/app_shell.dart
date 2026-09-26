import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/services/service_scope.dart';
import '../multiplayer/multiplayer_screen.dart';
import '../home/home_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';

/// Root of the app: 4 quiet tabs in an IndexedStack (state preserved),
/// with the shared bottom navigation. Full-screen flows (game detail,
/// gameplay) are pushed above this shell by [AppRouter].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openGameDetail(GameDefinition game) {
    AppRouter.pushGameDetail(context, game);
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenGameDetail: _openGameDetail),
          const MultiplayerScreen(),
          ProgressScreen(
            onPlayRequested: () => setState(() => _index = 0),
            onOpenGameDetail: _openGameDetail,
          ),
          SettingsScreen(services: services),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        index: _index,
        onTap: (tab) => setState(() => _index = tab.index),
      ),
    );
  }
}
