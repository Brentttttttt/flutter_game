import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/player_stats.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/systems/enemy_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world({bool spawning = false}) => GameWorld(
  spawningEnabled: spawning,
  playerPosition: const Offset(720, 650),
  spawner: EnemySpawner(random: math.Random(43)),
  colorRandom: math.Random(29),
)..setViewport(const Size(390, 780));

void main() {
  test('boss lead uses actual normalized world velocity including walls', () {
    final world = _world();
    world.setMovementInput(const Offset(1, 1));
    world.update(0.05);
    expect(
      world.playerVelocity.distance,
      closeTo(world.player.stats.movementSpeed, 0.000001),
    );
    expect(world.playerVelocity.dx, closeTo(world.playerVelocity.dy, 0.000001));

    world.player.position = Offset(
      world.arena.walkableBounds.right - Player.radius,
      650,
    );
    final boss = world.boss =
        DinoTri(
            id: -1,
            position: world.player.position - const Offset(200, 0),
            encounterNumber: 1,
          )
          ..activity = DinoActivity.chasing
          ..attackCooldownRemaining = 999
          ..rangedCooldownRemaining = 0
          ..abilityCooldownRemaining = 999;
    world.update(0.05);
    expect(world.playerVelocity.dx, 0);
    expect(world.playerVelocity.dy, greaterThan(0));
    expect(boss.activity, DinoActivity.preparing);
    expect(boss.attackTarget.dy, greaterThan(world.player.position.dy));
    expect(boss.attackTarget.dx, lessThanOrEqualTo(world.player.position.dx));

    final target = boss.attackTarget;
    world.setMovementInput(const Offset(0, -1));
    world.update(0.05);
    expect(
      boss.attackTarget,
      target,
      reason: 'Windup commits; it cannot home.',
    );
    world.setMovementInput(Offset.zero);
    expect(world.playerVelocity, Offset.zero);
    world.update(0.05);
    expect(world.playerVelocity, Offset.zero);
  });

  test(
    'world passes vertical player movement into short ability prediction',
    () {
      final world = _world();
      final boss = world.boss =
          DinoTri(
              id: -1,
              position: world.player.position + const Offset(0, 200),
              encounterNumber: 1,
            )
            ..activity = DinoActivity.chasing
            ..abilityCooldownRemaining = 0;
      world.setMovementInput(const Offset(-0.6, -0.8));
      world.update(0.05);
      expect(boss.activity, DinoActivity.preparing);
      expect(boss.attackTarget.dx, lessThan(world.player.position.dx));
      expect(boss.attackTarget.dy, lessThan(world.player.position.dy));
      expect(
        (boss.attackTarget - world.player.position).distance,
        lessThanOrEqualTo(64),
      );

      world.awardXp(world.player.stats.xpRequired);
      expect(world.playerVelocity, Offset.zero);
      world.update(GameBalance.levelUpDuration);
      expect(world.playerVelocity, Offset.zero);
      expect(_world().playerVelocity, Offset.zero);
    },
  );

  test(
    'late live world spawns varied safe batches with stronger level pressure',
    () {
      GameWorld fill(int level) {
        final world = _world(spawning: true)
          ..survivalTime = 480
          ..nextBossTime = 99999;
        world.player.stats.level = level;
        for (var event = 0; event < 80; event++) {
          world.spawner.timeUntilNextSpawn = 0;
          world.update(0.001);
        }
        return world;
      }

      final lower = fill(8);
      final higher = fill(15);
      expect(lower.enemies.length, greaterThan(48));
      expect(higher.enemies.length, greaterThan(lower.enemies.length));
      expect(
        higher.enemies.length,
        lessThanOrEqualTo(
          higher.spawner.maximumEnemiesFor(
            higher.survivalTime,
            playerLevel: 15,
          ),
        ),
      );
      expect(
        higher.enemies.map((e) => e.color).toSet(),
        SlimeColor.values.toSet(),
      );
      for (final enemy in higher.enemies) {
        expect(
          (enemy.position - higher.player.position).distance,
          greaterThan(185),
        );
        expect(higher.arena.walkableBounds.contains(enemy.position), isTrue);
      }
      final fresh = _world(spawning: true);
      fresh.update(0.05);
      expect(fresh.enemies, isEmpty);
      expect(fresh.player.stats.level, 1);
    },
  );
}
