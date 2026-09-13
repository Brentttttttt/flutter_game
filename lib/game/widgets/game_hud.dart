import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/pixel_widgets.dart';
import '../game_world.dart';

class GameHud extends StatelessWidget {
  const GameHud({required this.world, super.key});

  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    final health = world.player.health;
    final stats = world.player.stats;
    const labelStyle = TextStyle(
      color: Color(0xFFFFFFC2),
      fontSize: 14,
      letterSpacing: 0.4,
    );
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: PixelPanel(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'WITCH KITTY  ${health.currentHealth} / ${health.maxHealth}',
                            key: const Key('player_hp_text'),
                            style: labelStyle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'LV ${stats.level}',
                        key: const Key('level_text'),
                        style: labelStyle.copyWith(
                          color: const Color(0xFFDDBAFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _PixelBar(
                    key: const Key('player_health_bar'),
                    value: health.ratio,
                    color: const Color(0xFFD95763),
                    semanticLabel: 'Health',
                    semanticValue:
                        '${health.currentHealth} of ${health.maxHealth}',
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'XP  ${stats.currentXp} / ${stats.xpRequired}',
                        key: const Key('xp_progress_text'),
                        style: labelStyle.copyWith(
                          color: const Color(0xFF9DE9F0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PixelBar(
                          key: const Key('player_xp_bar'),
                          value: stats.xpRatio,
                          color: const Color(0xFF59D4DF),
                          semanticLabel: 'Experience',
                          semanticValue:
                              '${stats.currentXp} of ${stats.xpRequired}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TIME  ${formatRunTime(world.survivalTime)}',
                          key: const Key('survival_time_text'),
                          style: labelStyle,
                        ),
                      ),
                      Text(
                        'SLIMES  ${world.defeatedEnemies}',
                        key: const Key('kill_count_text'),
                        style: labelStyle.copyWith(
                          color: const Color(0xFFB8C870),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelBar extends StatelessWidget {
  const _PixelBar({
    required this.value,
    required this.color,
    required this.semanticLabel,
    required this.semanticValue,
    super.key,
  });

  final double value;
  final Color color;
  final String semanticLabel;
  final String semanticValue;

  @override
  Widget build(BuildContext context) {
    final ratio = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      child: SizedBox(
        width: double.infinity,
        height: 14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = math.max(0.0, (constraints.maxWidth - 8) * ratio);
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF172226),
                      border: Border.all(
                        color: const Color(0xFFFFFFC2),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (fillWidth > 0)
                  Positioned(
                    left: 4,
                    top: 4,
                    bottom: 4,
                    width: fillWidth,
                    child: ColoredBox(color: color),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String formatRunTime(double seconds) {
  final totalSeconds = seconds.floor();
  final minutes = totalSeconds ~/ 60;
  final remainingSeconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainingSeconds.toString().padLeft(2, '0')}';
}
