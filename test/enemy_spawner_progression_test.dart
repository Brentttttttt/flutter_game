import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/game_camera.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/systems/enemy_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'time and levels each increase pressure without exceeding mobile limits',
    () {
      final spawner = EnemySpawner();
      for (final level in [1, 4, 7, 13, 100]) {
        var previousInterval = double.infinity;
        var previousLimit = 0;
        for (final time in [0.0, 30.0, 60.0, 120.0, 300.0, 3600.0]) {
          final interval = spawner.spawnIntervalFor(time, playerLevel: level);
          final limit = spawner.maximumEnemiesFor(time, playerLevel: level);
          expect(interval, lessThanOrEqualTo(previousInterval));
          expect(interval, inInclusiveRange(0.9, 2.8));
          expect(limit, greaterThanOrEqualTo(previousLimit));
          expect(limit, inInclusiveRange(4, 24));
          previousInterval = interval;
          previousLimit = limit;
        }
      }
      for (final time in [0.0, 30.0, 120.0]) {
        expect(
          spawner.spawnIntervalFor(time, playerLevel: 7),
          lessThan(spawner.spawnIntervalFor(time, playerLevel: 1)),
        );
        expect(
          spawner.maximumEnemiesFor(time, playerLevel: 7),
          greaterThan(spawner.maximumEnemiesFor(time, playerLevel: 1)),
        );
      }
    },
  );

  test('opening levels keep a small population and gentle spawn cadence', () {
    final spawner = EnemySpawner();
    for (var second = 0; second <= 30; second++) {
      for (var level = 1; level <= 4; level++) {
        expect(
          spawner.spawnIntervalFor(second.toDouble(), playerLevel: level),
          greaterThanOrEqualTo(1.9),
        );
        expect(
          spawner.maximumEnemiesFor(second.toDouble(), playerLevel: level),
          lessThanOrEqualTo(6),
        );
      }
    }
    // A single level cannot create a sudden wave or halve the spawn interval.
    for (var level = 1; level < 20; level++) {
      final before = spawner.spawnIntervalFor(90, playerLevel: level);
      final after = spawner.spawnIntervalFor(90, playerLevel: level + 1);
      expect(after / before, greaterThan(0.9));
      expect(
        spawner.maximumEnemiesFor(90, playerLevel: level + 1) -
            spawner.maximumEnemiesFor(90, playerLevel: level),
        inInclusiveRange(0, 1),
      );
    }
  });

  test('world passes current player level into the spawn cadence', () {
    GameWorld makeWorld(int level) {
      final world = GameWorld(spawner: EnemySpawner(random: math.Random(42)))
        ..setViewport(const Size(390, 780));
      world.player.stats.level = level;
      world.survivalTime = 90;
      world.spawner.timeUntilNextSpawn = 0;
      world.update(0.01);
      expect(world.enemies, hasLength(1));
      return world;
    }

    final startingLevel = makeWorld(1);
    final upgradedLevel = makeWorld(7);
    expect(
      upgradedLevel.spawner.timeUntilNextSpawn,
      lessThan(startingLevel.spawner.timeUntilNextSpawn),
    );
  });

  test('long frame emits one spawn and never queues a catch-up burst', () {
    final fixture = _SpawnFixture();
    fixture.spawner.timeUntilNextSpawn = 0;
    expect(fixture.update(deltaTime: 60, time: 300, level: 12), isNotNull);
    for (var frame = 0; frame < 30; frame++) {
      expect(fixture.update(deltaTime: 1 / 60, time: 300, level: 12), isNull);
    }
  });

  test(
    'population cap respects level and waits before replacing a removed slime',
    () {
      final fixture = _SpawnFixture();
      final limit = fixture.spawner.maximumEnemiesFor(60, playerLevel: 5);
      final enemies = List.generate(
        limit,
        (index) => SlimeEnemy(
          id: index,
          position: fixture.playerPosition + Offset(index * 5.0, 0),
        ),
      );
      fixture.spawner.timeUntilNextSpawn = 0;
      expect(fixture.update(time: 60, level: 5, enemies: enemies), isNull);
      enemies.removeLast();
      expect(
        fixture.update(deltaTime: 0.1, time: 60, level: 5, enemies: enemies),
        isNull,
      );
      expect(
        fixture.update(deltaTime: 0.21, time: 60, level: 5, enemies: enemies),
        isNotNull,
      );
      expect(
        fixture.update(deltaTime: 0.01, time: 60, level: 5, enemies: enemies),
        isNull,
      );
    },
  );
}

class _SpawnFixture {
  _SpawnFixture() {
    camera.setViewport(const Size(390, 780), arena, playerPosition);
  }

  final arena = const Arena();
  final camera = GameCamera();
  final spawner = EnemySpawner(random: math.Random(7));
  Offset get playerPosition => arena.bounds.center;

  Offset? update({
    double deltaTime = 0.01,
    required double time,
    required int level,
    List<SlimeEnemy> enemies = const [],
  }) {
    return spawner.update(
      deltaTime: deltaTime,
      survivalTime: time,
      playerLevel: level,
      arena: arena,
      camera: camera,
      playerPosition: playerPosition,
      existingEnemies: enemies,
    );
  }
}
