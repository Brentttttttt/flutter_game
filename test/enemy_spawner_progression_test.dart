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
      for (final level in [1, 4, 8, 15, 40, 100]) {
        var previousInterval = double.infinity;
        var previousLimit = 0;
        var previousBatch = 1.0;
        for (var second = 0; second <= 1800; second++) {
          final time = second.toDouble();
          final interval = spawner.spawnIntervalFor(time, playerLevel: level);
          final limit = spawner.maximumEnemiesFor(time, playerLevel: level);
          final batch = spawner.expectedBatchSizeFor(time, playerLevel: level);
          expect(interval, lessThan(previousInterval));
          expect(
            interval,
            inInclusiveRange(EnemySpawnBalance.minimumInterval, 2.8),
          );
          expect(limit, greaterThanOrEqualTo(previousLimit));
          expect(
            limit,
            inInclusiveRange(4, EnemySpawnBalance.maximumEnemyLimit),
          );
          expect(batch, greaterThanOrEqualTo(previousBatch));
          expect(
            batch,
            inInclusiveRange(1, EnemySpawnBalance.maximumBatchSize),
          );
          previousInterval = interval;
          previousLimit = limit;
          previousBatch = batch;
        }
      }
      for (final time in [0.0, 30.0, 120.0, 480.0]) {
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
          lessThanOrEqualTo(8),
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
        inInclusiveRange(0, 2),
      );
    }
    for (var second = 31; second <= 60; second++) {
      expect(
        spawner.maximumEnemiesFor(second.toDouble(), playerLevel: 4),
        lessThanOrEqualTo(12),
      );
      expect(
        spawner.spawnIntervalFor(second.toDouble(), playerLevel: 4),
        greaterThan(1.5),
      );
      expect(
        spawner.expectedBatchSizeFor(second.toDouble(), playerLevel: 4),
        lessThan(1.5),
      );
    }
  });

  test('crowds grow across the whole run and high levels keep contributing', () {
    final spawner = EnemySpawner();
    expect(
      spawner.maximumEnemiesFor(90, playerLevel: 5),
      inInclusiveRange(15, 25),
    );
    expect(
      spawner.maximumEnemiesFor(180, playerLevel: 8),
      inInclusiveRange(35, 50),
    );
    expect(
      spawner.maximumEnemiesFor(300, playerLevel: 12),
      inInclusiveRange(65, 85),
    );
    expect(
      spawner.maximumEnemiesFor(480, playerLevel: 15),
      inInclusiveRange(110, 150),
    );
    expect(
      spawner.maximumEnemiesFor(600, playerLevel: 18),
      inInclusiveRange(145, 185),
    );
    expect(
      spawner.maximumEnemiesFor(1800),
      EnemySpawnBalance.maximumEnemyLimit,
    );
    final lowLevelLimit = spawner.maximumEnemiesFor(480, playerLevel: 8);
    final highLevelLimit = spawner.maximumEnemiesFor(480, playerLevel: 15);
    expect(highLevelLimit / lowLevelLimit, greaterThan(1.2));
    double inflow(int level) =>
        spawner.expectedBatchSizeFor(480, playerLevel: level) /
        spawner.spawnIntervalFor(480, playerLevel: level);
    expect(inflow(15) / inflow(8), greaterThan(1.24));
    expect(inflow(25), greaterThan(inflow(15)));
    expect(
      spawner.maximumEnemiesFor(480, playerLevel: 25),
      greaterThan(highLevelLimit),
    );
    // Reaching the emergency population budget does not freeze the pacing curve.
    expect(
      spawner.spawnIntervalFor(3600, playerLevel: 40),
      lessThan(spawner.spawnIntervalFor(1800, playerLevel: 40)),
    );
    expect(
      spawner.expectedBatchSizeFor(3600, playerLevel: 40),
      greaterThan(spawner.expectedBatchSizeFor(1800, playerLevel: 40)),
    );
  });

  test(
    'fractional batches follow smooth demand instead of fixed spawn tiers',
    () {
      final fixture = _SpawnFixture();
      var total = 0;
      final sizes = <int>{};
      for (var event = 0; event < 200; event++) {
        fixture.spawner.timeUntilNextSpawn = 0;
        final batch = fixture.batch(time: 480, level: 15);
        expect(
          batch.length,
          inInclusiveRange(1, EnemySpawnBalance.maximumBatchSize),
        );
        sizes.add(batch.length);
        total += batch.length;
      }
      expect(sizes, containsAll([3, 4]));
      expect(
        total / 200,
        closeTo(
          fixture.spawner.expectedBatchSizeFor(480, playerLevel: 15),
          1 / 200,
        ),
      );
    },
  );

  test('all batch members spawn safely apart even at arena corners', () {
    final fixture = _SpawnFixture();
    for (final focus in [
      fixture.arena.bounds.center,
      const Offset(70, 70),
      const Offset(1450, 1250),
      const Offset(70, 1250),
    ]) {
      fixture.playerPosition = focus;
      fixture.camera.snapTo(focus, fixture.arena);
      final occupied = <SlimeEnemy>[];
      for (var event = 0; event < 12; event++) {
        fixture.spawner.timeUntilNextSpawn = 0;
        final batch = fixture.batch(time: 480, level: 15, enemies: occupied);
        expect(batch, isNotEmpty);
        final blocked = (fixture.camera.position & fixture.camera.viewportSize)
            .inflate(20);
        for (final position in batch) {
          expect(
            fixture.arena.walkableBounds
                .deflate(SlimeEnemy.radius)
                .contains(position),
            isTrue,
          );
          expect(blocked.contains(position), isFalse);
          expect((position - focus).distance, greaterThanOrEqualTo(190));
          for (final existing in occupied) {
            expect(
              (position - existing.position).distance,
              greaterThanOrEqualTo(SlimeEnemy.radius * 2 + 12),
            );
          }
          occupied.add(SlimeEnemy(id: occupied.length, position: position));
        }
      }
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

  test(
    'long frame emits one bounded batch and never queues a catch-up burst',
    () {
      final fixture = _SpawnFixture();
      fixture.spawner.timeUntilNextSpawn = 0;
      final batch = fixture.batch(deltaTime: 60, time: 300, level: 12);
      expect(
        batch.length,
        inInclusiveRange(1, EnemySpawnBalance.maximumBatchSize),
      );
      for (var frame = 0; frame < 30; frame++) {
        expect(fixture.batch(deltaTime: 1 / 60, time: 300, level: 12), isEmpty);
      }
    },
  );

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

  test(
    'late batches respect a single free slot and never accumulate cap debt',
    () {
      final fixture = _SpawnFixture();
      final limit = fixture.spawner.maximumEnemiesFor(480, playerLevel: 15);
      final enemies = List.generate(
        limit,
        (index) => SlimeEnemy(id: index, position: fixture.playerPosition),
      );
      for (var event = 0; event < 100; event++) {
        expect(
          fixture.batch(deltaTime: 2, time: 480, level: 15, enemies: enemies),
          isEmpty,
        );
      }
      enemies.removeLast();
      final oneFree = fixture.batch(
        deltaTime: 2,
        time: 480,
        level: 15,
        enemies: enemies,
      );
      expect(oneFree, hasLength(1));
      enemies.clear();
      expect(fixture.batch(deltaTime: 0.01, time: 480, level: 15), isEmpty);
      final next = fixture.batch(deltaTime: 60, time: 480, level: 15);
      expect(
        next.length,
        lessThanOrEqualTo(EnemySpawnBalance.maximumBatchSize),
      );
      expect(fixture.batch(deltaTime: 0, time: 480, level: 15), isEmpty);
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
  Offset playerPosition = const Arena().bounds.center;

  List<Offset> batch({
    double deltaTime = 0.01,
    required double time,
    required int level,
    List<SlimeEnemy> enemies = const [],
  }) {
    return spawner.updateBatch(
      deltaTime: deltaTime,
      survivalTime: time,
      playerLevel: level,
      arena: arena,
      camera: camera,
      playerPosition: playerPosition,
      existingEnemies: enemies,
    );
  }

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
