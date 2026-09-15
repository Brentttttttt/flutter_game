import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/game_camera.dart';
import 'package:flutter_game/game/models/magic_orb.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/systems/enemy_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preserved player, arena, and camera systems', () {
    test('normalizes diagonal joystick movement', () {
      final world = GameWorld(
        playerPosition: const Offset(400, 400),
        spawningEnabled: false,
      );
      final start = world.player.position;

      world.setMovementInput(const Offset(1, 1));
      world.update(0.1);

      expect(
        (world.player.position - start).distance,
        closeTo(Player.speed * 0.1, 0.001),
      );
    });

    test('cannot leave the finite arena wall ring', () {
      final world = GameWorld(
        playerPosition: const Offset(400, 400),
        spawningEnabled: false,
      );

      world.setMovementInput(const Offset(-1, -1));
      world.update(20);

      expect(
        world.player.position.dx,
        world.arena.walkableBounds.left + Player.radius,
      );
      expect(
        world.player.position.dy,
        world.arena.walkableBounds.top + Player.radius,
      );
    });

    test(
      'player can slide away from a touching slime but not deeper into it',
      () {
        final world = GameWorld(
          playerPosition: const Offset(300, 300),
          spawningEnabled: false,
        );
        final slime = world.spawnSlimeAt(
          const Offset(358, 300),
          maxHealth: 999,
          spawnDelay: 0,
        );

        world.setMovementInput(const Offset(1, 0));
        world.update(0.1);
        final blockedPosition = world.player.position;
        expect(blockedPosition.dx, closeTo(300, 0.001));

        world.setMovementInput(const Offset(-1, 0));
        world.update(0.1);
        expect(world.player.position.dx, lessThan(blockedPosition.dx));
        expect(slime.isActive, isTrue);
      },
    );

    test('camera clamps exactly and never overscrolls', () {
      const arena = Arena(columns: 100, rows: 100, tileSize: 10);
      final camera = GameCamera()
        ..setViewport(const Size(200, 300), arena, Offset.zero);

      camera.snapTo(Offset.zero, arena);
      expect(camera.position, Offset.zero);
      camera.snapTo(const Offset(1000, 1000), arena);
      expect(camera.position, const Offset(800, 700));

      for (var index = 0; index < 120; index++) {
        camera.update(1 / 60, const Offset(2000, 2000), arena);
        expect(camera.position.dx, inInclusiveRange(0, 800));
        expect(camera.position.dy, inInclusiveRange(0, 700));
      }
    });
  });

  group('health, slime combat, and death', () {
    test('player damage uses one shared invulnerability window', () {
      final player = Player(position: const Offset(400, 400));

      expect(player.takeDamage(10), isTrue);
      expect(player.health.currentHealth, 90);
      expect(player.takeDamage(10), isFalse);
      player.update(Player.damageInvulnerability - 0.01);
      expect(player.takeDamage(10), isFalse);
      player.update(0.02);
      expect(player.takeDamage(10), isTrue);
      expect(player.health.currentHealth, 80);
    });

    test('slime selects directional movement and attack states', () {
      const arena = Arena();
      final east = SlimeEnemy(
        id: 1,
        position: const Offset(400, 400),
        spawnDelayRemaining: 0,
      );
      east.update(
        0.1,
        playerPosition: const Offset(600, 400),
        playerRadius: Player.radius,
        arena: arena,
      );
      expect(east.facing, SlimeFacing.east);
      expect(east.activity, SlimeActivity.walking);

      final north = SlimeEnemy(
        id: 2,
        position: const Offset(400, 400),
        spawnDelayRemaining: 0,
      );
      north.update(
        0.1,
        playerPosition: const Offset(400, 200),
        playerRadius: Player.radius,
        arena: arena,
      );
      expect(north.facing, SlimeFacing.north);

      final touching = SlimeEnemy(
        id: 3,
        position: const Offset(446, 400),
        spawnDelayRemaining: 0,
      );
      touching.update(
        0.1,
        playerPosition: const Offset(400, 400),
        playerRadius: Player.radius,
        arena: arena,
      );
      expect(touching.activity, SlimeActivity.attacking);
    });

    test('a distant slime still pursues within the finite arena', () {
      const arena = Arena();
      final slime = SlimeEnemy(
        id: 1,
        position: const Offset(1400, 1200),
        spawnDelayRemaining: 0,
      );
      final start = slime.position;

      slime.update(
        0.1,
        playerPosition: const Offset(100, 100),
        playerRadius: Player.radius,
        arena: arena,
      );

      expect(slime.activity, SlimeActivity.walking);
      expect(
        (slime.position - const Offset(100, 100)).distance,
        lessThan((start - const Offset(100, 100)).distance),
      );
    });

    test('spawn grace prevents immediate contact damage', () {
      final world = GameWorld(
        playerPosition: const Offset(400, 400),
        spawningEnabled: false,
      );
      world.spawnSlimeAt(
        const Offset(450, 400),
        maxHealth: 999,
        spawnDelay: 0.3,
      );

      world.update(0.1);

      expect(world.player.health.currentHealth, Player.maxHealth);
    });

    test('death animation remains visible before removal', () {
      const arena = Arena();
      final slime = SlimeEnemy(
        id: 1,
        position: const Offset(400, 400),
        maxHealth: 10,
        spawnDelayRemaining: 0,
      );
      final start = slime.position;

      expect(
        slime.takeOrbHit(10, MagicOrb.hitCooldown),
        SlimeDamageResult.defeated,
      );
      slime.update(
        SlimeEnemy.deathDuration - 0.01,
        playerPosition: const Offset(800, 800),
        playerRadius: Player.radius,
        arena: arena,
      );
      expect(slime.lifeState, SlimeLifeState.dying);
      expect(slime.position, start);

      slime.update(
        0.02,
        playerPosition: const Offset(800, 800),
        playerRadius: Player.radius,
        arena: arena,
      );
      expect(slime.lifeState, SlimeLifeState.removed);
    });

    test('attack hit death freezes run time, spawning, and control', () {
      final world = GameWorld(
        playerPosition: const Offset(400, 400),
        spawningEnabled: false,
      );
      world.player.health.takeDamage(90);
      world.spawnSlimeAt(const Offset(446, 400), maxHealth: 999, spawnDelay: 0);

      world.update(0.02);
      expect(world.player.health.currentHealth, 10);
      for (var step = 0; step < 20; step++) {
        world.update(0.02);
      }
      expect(world.runState, GameRunState.gameOver);
      expect(world.player.health.currentHealth, 0);
      final frozenTime = world.survivalTime;
      final frozenEnemies = world.enemies.length;

      world.setMovementInput(const Offset(1, 0));
      world.update(10);
      expect(world.survivalTime, frozenTime);
      expect(world.enemies.length, frozenEnemies);
      expect(world.player.movementInput, Offset.zero);
    });

    test('coincident slimes separate to finite arena positions', () {
      final world = GameWorld(spawningEnabled: false);
      final first = world.spawnSlimeAt(
        const Offset(600, 600),
        maxHealth: 999,
        spawnDelay: 0,
      );
      final second = world.spawnSlimeAt(
        const Offset(600, 600),
        maxHealth: 999,
        spawnDelay: 0,
      );

      world.update(0.01);

      expect(first.position.dx.isFinite, isTrue);
      expect(first.position.dy.isFinite, isTrue);
      expect(second.position.dx.isFinite, isTrue);
      expect(second.position.dy.isFinite, isTrue);
      expect((first.position - second.position).distance, greaterThan(0));
      expect(
        world.arena.walkableBounds
            .deflate(SlimeEnemy.radius)
            .contains(first.position),
        isTrue,
      );
    });
  });

  group('orb atlas and per-enemy cooldown', () {
    test(
      'outlined purple animation uses audited atlas cells 60 through 67',
      () {
        final orb = MagicOrb();

        expect(orb.sourceRectForFrame(0), const Rect.fromLTWH(0, 80, 16, 16));
        expect(orb.sourceRectForFrame(7), const Rect.fromLTWH(112, 80, 16, 16));
        expect(orb.sourceRectForFrame(8), const Rect.fromLTWH(0, 80, 16, 16));
      },
    );

    test('one orb can hit two slimes while each keeps its own cooldown', () {
      const playerPosition = Offset(400, 400);
      const arena = Arena();
      final orb = MagicOrb();
      final orbPosition = orb.positionAround(playerPosition);
      final first = SlimeEnemy(
        id: 1,
        position: orbPosition,
        spawnDelayRemaining: 0,
      );
      final second = SlimeEnemy(
        id: 2,
        position: orbPosition,
        spawnDelayRemaining: 0,
      );

      expect(orb.tryHit(first, playerPosition), SlimeDamageResult.damaged);
      expect(orb.tryHit(second, playerPosition), SlimeDamageResult.damaged);
      expect(first.health.currentHealth, 20);
      expect(second.health.currentHealth, 20);
      expect(orb.tryHit(first, playerPosition), SlimeDamageResult.none);

      first.update(
        MagicOrb.hitCooldown + 0.01,
        playerPosition: playerPosition,
        playerRadius: Player.radius,
        arena: arena,
      );
      first.position = orb.positionAround(playerPosition);
      expect(orb.tryHit(first, playerPosition), SlimeDamageResult.damaged);
      expect(first.health.currentHealth, 10);
    });

    test('world counts a defeated slime exactly once', () {
      final world = GameWorld(
        playerPosition: const Offset(400, 400),
        spawningEnabled: false,
      );
      world.spawnSlimeAt(
        world.orb.positionAround(world.player.position),
        maxHealth: 10,
        spawnDelay: 0,
      );

      world.update(0.001);
      expect(world.defeatedEnemies, 1);
      world.update(SlimeEnemy.deathDuration + 0.1);
      expect(world.defeatedEnemies, 1);
    });
  });

  group('bounded progressive spawning', () {
    test('spawn position is walkable, offscreen, and far from player', () {
      const arena = Arena();
      final camera = GameCamera();
      final player = arena.bounds.center;
      camera.setViewport(const Size(390, 780), arena, player);
      final spawner = EnemySpawner(random: math.Random(7))
        ..timeUntilNextSpawn = 0;

      final position = spawner.update(
        deltaTime: 0.1,
        survivalTime: 0,
        arena: arena,
        camera: camera,
        playerPosition: player,
        existingEnemies: const [],
      );

      expect(position, isNotNull);
      expect(
        arena.walkableBounds.deflate(SlimeEnemy.radius).contains(position!),
        isTrue,
      );
      final visible = Rect.fromLTWH(
        camera.position.dx,
        camera.position.dy,
        camera.viewportSize.width,
        camera.viewportSize.height,
      ).inflate(20);
      expect(visible.contains(position), isFalse);
      expect((position - player).distance, greaterThanOrEqualTo(190));
    });

    test('difficulty increases smoothly while retaining a mobile cap', () {
      final spawner = EnemySpawner(random: math.Random(1));

      expect(
        spawner.spawnIntervalFor(30),
        lessThan(spawner.spawnIntervalFor(0)),
      );
      expect(
        spawner.spawnIntervalFor(120),
        lessThan(spawner.spawnIntervalFor(30)),
      );
      expect(
        spawner.spawnIntervalFor(10000),
        greaterThanOrEqualTo(EnemySpawnBalance.minimumInterval),
      );
      expect(spawner.maximumEnemiesFor(0), 4);
      expect(spawner.maximumEnemiesFor(60), inInclusiveRange(7, 16));
      expect(
        spawner.maximumEnemiesFor(120),
        greaterThan(spawner.maximumEnemiesFor(60)),
      );
      expect(
        spawner.maximumEnemiesFor(10000),
        EnemySpawnBalance.maximumEnemyLimit,
      );
    });
  });
}
