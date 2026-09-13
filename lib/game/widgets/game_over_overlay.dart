import 'package:flutter/material.dart';

import '../../ui/pixel_widgets.dart';
import '../game_world.dart';
import 'game_hud.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    required this.world,
    required this.onRetry,
    required this.onMainMenu,
    super.key,
  });

  final GameWorld world;
  final VoidCallback onRetry;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('game_over_overlay'),
      color: const Color(0xC9101820),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: PixelPanel(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFA232B35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GAME OVER',
                      style: TextStyle(
                        color: Color(0xFFFFC1B8),
                        fontSize: 42,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Color(0xFF4B2A78),
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'LEVEL REACHED  ${world.player.stats.level}',
                      style: const TextStyle(
                        color: Color(0xFFDDBAFF),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TIME SURVIVED  ${formatRunTime(world.survivalTime)}',
                      style: const TextStyle(
                        color: Color(0xFFFFFFC2),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SLIMES DEFEATED  ${world.defeatedEnemies}',
                      style: const TextStyle(
                        color: Color(0xFFB8C870),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PixelButton(
                      key: const Key('retry_button'),
                      label: 'RETRY',
                      onPressed: onRetry,
                    ),
                    const SizedBox(height: 12),
                    PixelButton(
                      key: const Key('game_over_menu_button'),
                      label: 'MAIN MENU',
                      primary: false,
                      onPressed: onMainMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
