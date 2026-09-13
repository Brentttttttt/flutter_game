import 'dart:math' as math;

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/combat_effect.dart';
import 'package:flutter_game/game/models/fire_projectile.dart';
import 'package:flutter_game/game/models/magic_orb.dart';
import 'package:flutter_game/game/models/player_stats.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/models/xp_gem.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld _world() => GameWorld(
  spawningEnabled: false,
  playerPosition: const Offset(400, 400),
  random: math.Random(7),
);

void _chooseWhenOffered(GameWorld world, UpgradeId wanted) {
  for (var attempt = 0; attempt < 80; attempt++) {
    expect(world.isPlaying, isTrue);
    world.awardXp(world.player.stats.xpRequired - world.player.stats.currentXp);
    world.update(GameBalance.levelUpDuration);
    final hasWanted = world.upgradeChoices.any((card) => card.id == wanted);
    final selected = hasWanted
        ? wanted
        : world.upgradeChoices
              .firstWhere(
                (card) =>
                    card.id != UpgradeId.fireOrb &&
                    card.id != UpgradeId.arcaneOrb,
              )
              .id;
    expect(world.chooseUpgrade(selected), isTrue);
    if (hasWanted) return;
  }
  fail('Seeded upgrade offers never included $wanted.');
}

// Stationary windups make projectile paths deterministic while exercising the
// real world collision loop, enemy health, and shared death/effect handling.
void _startStationaryAttack(SlimeEnemy slime) {
  slime.update(
    0,
    playerPosition: slime.position + const Offset(0, 40),
    playerRadius: 30,
    arena: const Arena(),
  );
}

void main() {
  group('XP pickups and level transitions', () {
    test(
      'one defeated slime drops one permanent gem at its death position',
      () {
        final world = _world();
        world.player.stats
          ..xpPickupRadius = 24
          ..orbRotationSpeed = 0;
        final slime = world.spawnSlimeAt(
          world.orb.positionAround(world.player.position),
          maxHealth: 10,
          spawnDelay: 0,
        );

        world.update(0.001);

        expect(slime.lifeState, SlimeLifeState.dying);
        expect(world.defeatedEnemies, 1);
        expect(world.xpGems, hasLength(1));
        final gem = world.xpGems.single;
        expect(gem.position, slime.position);
        expect(gem.value, GameBalance.xpPerSlime);
        expect(world.player.stats.currentXp, 0);
        final position = gem.position;

        world.update(30);

        expect(world.enemies, isEmpty);
        expect(world.defeatedEnemies, 1);
        expect(world.xpGems.single, same(gem));
        expect(gem.position, position);
        expect(gem.isAttracted, isFalse);
      },
    );

    test(
      'nearby gems accelerate, follow after leaving radius, and collect',
      () {
        final world = _world();
        final gem = XpGem(
          position: world.player.position + const Offset(80, 0),
          value: 3,
        );
        world.xpGems.add(gem);
        final start = gem.position;
        world.update(0.05);
        final firstStep = (gem.position - start).distance;
        final afterFirst = gem.position;
        world.update(0.05);
        expect(gem.isAttracted, isTrue);
        expect((gem.position - afterFirst).distance, greaterThan(firstStep));
        expect(world.player.stats.currentXp, 0);

        world.player.position += const Offset(300, 0);
        final distanceBefore = (world.player.position - gem.position).distance;
        expect(distanceBefore, greaterThan(world.player.stats.xpPickupRadius));
        world.update(0.05);
        expect(
          (world.player.position - gem.position).distance,
          lessThan(distanceBefore),
        );
        for (var frame = 0; frame < 100 && world.xpGems.isNotEmpty; frame++) {
          world.update(0.05);
        }
        expect(world.xpGems, isEmpty);
        expect(world.player.stats.currentXp, 3);
        expect(world.player.stats.level, 1);
      },
    );

    test(
      'collecting gems drives the level-up effect and fills XP accurately',
      () {
        final world = _world();
        world.xpGems.add(XpGem(position: world.player.position, value: 7));
        world.update(0.01);
        expect(world.player.stats.currentXp, 7);
        expect(world.player.stats.xpRatio, closeTo(0.7, 0.0001));
        world.xpGems.add(XpGem(position: world.player.position, value: 5));
        world.update(0.01);
        expect(world.runState, GameRunState.levelUpEffect);
        expect(world.player.stats.level, 2);
        expect(world.player.stats.currentXp, 2);
        expect(world.player.stats.xpRequired, 15);
        expect(world.xpGems, isEmpty);
      },
    );

    test(
      'level-up freezes movement, combat, projectiles, effects, and clocks',
      () {
        final world = _world();
        final enemy = world.spawnSlimeAt(const Offset(800, 400), spawnDelay: 0);
        final gem = XpGem(position: const Offset(700, 700), value: 1);
        final projectile = FireProjectile(
          position: const Offset(100, 100),
          direction: const Offset(1, 0),
          damage: 20,
          pierce: 0,
        );
        final effect = CombatEffect(
          const Offset(100, 100),
          CombatEffectKind.arcaneImpact,
        );
        final number = DamageNumber(const Offset(100, 100), 10);
        world.xpGems.add(gem);
        world.projectiles.add(projectile);
        world.effects.add(effect);
        world.damageNumbers.add(number);
        world.setMovementInput(const Offset(1, 0));
        final playerPosition = world.player.position;
        final orbAngle = world.orb.angle;
        final spawnClock = world.spawner.timeUntilNextSpawn;

        world.awardXp(world.player.stats.xpRequired);
        expect(world.player.movementInput, Offset.zero);
        world.setMovementInput(const Offset(1, 0));
        expect(world.player.movementInput, Offset.zero);
        world.update(GameBalance.levelUpDuration / 2);
        expect(world.runState, GameRunState.levelUpEffect);
        expect(world.chooseUpgrade(world.upgradeChoices.first.id), isFalse);
        world.update(GameBalance.levelUpDuration / 2);
        expect(world.isChoosingUpgrade, isTrue);
        world.update(10);

        expect(world.survivalTime, 0);
        expect(world.player.position, playerPosition);
        expect(world.player.health.currentHealth, GameBalance.maxHp);
        expect(world.orb.angle, orbAngle);
        expect(enemy.position, const Offset(800, 400));
        expect(enemy.animationTime, 0);
        expect(gem.animationTime, 0);
        expect(projectile.position, const Offset(100, 100));
        expect(projectile.age, 0);
        expect(effect.age, 0);
        expect(number.age, 0);
        expect(world.spawner.timeUntilNextSpawn, spawnClock);

        final selected = world.upgradeChoices.first.id;
        final invalid = UpgradeId.values.firstWhere(
          (id) => !world.upgradeChoices.any((card) => card.id == id),
        );
        expect(world.chooseUpgrade(invalid), isFalse);
        expect(world.chooseUpgrade(selected), isTrue);
        expect(world.chooseUpgrade(selected), isFalse);
        expect(world.isPlaying, isTrue);
        expect(world.upgradeChoices, isEmpty);
        world.update(0.01);
        expect(world.survivalTime, closeTo(0.01, 0.0001));
        expect(projectile.age, greaterThan(0));
      },
    );

    test(
      'excess XP gives a separate three-card choice for every earned level',
      () {
        final world = _world();
        world.awardXp(10 + 15 + 22 + 7);
        for (var expectedLevel = 2; expectedLevel <= 4; expectedLevel++) {
          expect(world.player.stats.level, expectedLevel);
          expect(world.runState, GameRunState.levelUpEffect);
          expect(world.upgradeChoices, hasLength(3));
          expect(
            world.upgradeChoices.map((card) => card.id).toSet(),
            hasLength(3),
          );
          final eligible = UpgradeDefinition.availableFor(
            world.player.stats,
          ).map((card) => card.id);
          expect(
            world.upgradeChoices.every((card) => eligible.contains(card.id)),
            isTrue,
          );
          world.update(GameBalance.levelUpDuration);
          expect(world.chooseUpgrade(world.upgradeChoices.first.id), isTrue);
        }
        expect(world.isPlaying, isTrue);
        expect(world.player.stats.level, 4);
        expect(world.player.stats.currentXp, 7);
        expect(world.upgradeChoices, isEmpty);
        expect(
          PlayerStats.xpRequiredForLevel(100),
          greaterThan(PlayerStats.xpRequiredForLevel(99)),
        );
        expect(
          PlayerStats.xpRequiredForLevel(1000),
          greaterThan(PlayerStats.xpRequiredForLevel(100)),
        );
      },
    );
  });

  group('upgrade application and orbit spacing', () {
    test(
      'stat upgrades apply their displayed amounts and preserve missing HP',
      () {
        final stats = PlayerStats();
        stats.health.takeDamage(50);
        final cards = UpgradeDefinition.availableFor(stats);
        for (final id in [
          UpgradeId.vitality,
          UpgradeId.swiftPaws,
          UpgradeId.arcanePower,
          UpgradeId.orbHaste,
          UpgradeId.magnetism,
        ]) {
          cards.singleWhere((card) => card.id == id).apply(stats);
        }
        expect(stats.maxHp, 120);
        expect(stats.currentHp, 60);
        expect(
          stats.movementSpeed,
          closeTo(GameBalance.movementSpeed * 1.08, 0.0001),
        );
        expect(stats.orbDamage, closeTo(GameBalance.orbDamage * 1.15, 0.0001));
        expect(
          stats.orbRotationSpeed,
          closeTo(GameBalance.orbRotationSpeed * 1.12, 0.0001),
        );
        expect(
          stats.xpPickupRadius,
          closeTo(GameBalance.pickupRadius * 1.2, 0.0001),
        );
      },
    );

    test(
      'added orbs stay evenly spaced at one radius, including the Fire Orb',
      () {
        final world = _world();
        for (var count = 2; count <= GameBalance.maximumArcaneOrbs; count++) {
          _chooseWhenOffered(world, UpgradeId.arcaneOrb);
          expect(world.player.stats.arcaneOrbCount, count);
          expect(world.orbs, hasLength(count));
          for (var index = 0; index < count; index++) {
            expect(
              world.orbs[index].phaseOffset,
              closeTo(2 * math.pi * index / count, 0.0001),
            );
          }
        }
        expect(
          UpgradeDefinition.availableFor(
            world.player.stats,
          ).any((card) => card.id == UpgradeId.arcaneOrb),
          isFalse,
        );
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(
          world.orbs.where((orb) => orb.kind == OrbKind.arcane),
          hasLength(6),
        );
        expect(
          world.orbs.where((orb) => orb.kind == OrbKind.fire),
          hasLength(1),
        );
        world.update(0.2);
        final count = world.orbs.length;
        final adjacentDistance =
            2 * MagicOrb.orbitRadius * math.sin(math.pi / count);
        for (var index = 0; index < count; index++) {
          final position = world.orbs[index].positionAround(
            world.player.position,
          );
          final next = world.orbs[(index + 1) % count].positionAround(
            world.player.position,
          );
          expect(
            (position - world.player.position).distance,
            closeTo(MagicOrb.orbitRadius, 0.0001),
          );
          expect((position - next).distance, closeTo(adjacentDistance, 0.0001));
        }
      },
    );

    test(
      'Fire Orb levels improve damage, cooldown, piercing, and stop at five',
      () {
        final world = _world();
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(world.player.stats.fireOrb.level, 1);
        expect(world.player.stats.fireOrb.damage, 20);
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(world.player.stats.fireOrb.damage, 24);
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(
          world.player.stats.fireOrb.cooldown,
          closeTo(2.6 * 0.85, 0.0001),
        );
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(world.player.stats.fireOrb.pierce, 1);
        _chooseWhenOffered(world, UpgradeId.fireOrb);
        expect(world.player.stats.fireOrb.damage, 32);
        expect(world.player.stats.fireOrb.level, 5);
        expect(
          world.orbs.where((orb) => orb.kind == OrbKind.fire),
          hasLength(1),
        );
        expect(
          UpgradeDefinition.availableFor(
            world.player.stats,
          ).any((card) => card.id == UpgradeId.fireOrb),
          isFalse,
        );
        world.player.stats.fireOrb.upgrade();
        expect(world.player.stats.fireOrb.level, 5);
      },
    );
  });

  group('Fire Orb targeting and projectile collision', () {
    test('unlocked Fire Orb fires from itself toward nearest valid slime', () {
      final world = _world();
      _chooseWhenOffered(world, UpgradeId.fireOrb);
      world.player.stats.orbRotationSpeed = 0;
      final fireOrb = world.orbs.singleWhere((orb) => orb.kind == OrbKind.fire);
      final origin = fireOrb.positionAround(world.player.position);
      world.spawnSlimeAt(
        origin + const Offset(0, 220),
        maxHealth: 999,
        spawnDelay: 0,
      );
      final nearest = world.spawnSlimeAt(
        origin + const Offset(120, 0),
        maxHealth: 999,
        spawnDelay: 0,
      );
      world.spawnSlimeAt(
        origin + const Offset(45, 0),
        maxHealth: 999,
        spawnDelay: 100,
      );
      final dying = world.spawnSlimeAt(
        origin + const Offset(-40, 0),
        spawnDelay: 0,
      );
      dying.takeProjectileHit(100);

      world.update(0.26);

      expect(world.projectiles, hasLength(1));
      final projectile = world.projectiles.single;
      expect(projectile.previousPosition, origin);
      final expectedDirection = nearest.position - origin;
      expect(
        (projectile.direction - expectedDirection / expectedDirection.distance)
            .distance,
        lessThan(0.0001),
      );
      expect(projectile.damage, world.player.stats.fireOrb.damage);
      world.update(0.01);
      expect(world.projectiles, hasLength(1));
    });

    test('Fire Orb waits when every valid target is out of range', () {
      final world = _world();
      _chooseWhenOffered(world, UpgradeId.fireOrb);
      world.player.stats.orbRotationSpeed = 0;
      world.spawnSlimeAt(const Offset(1100, 1100), spawnDelay: 0);
      world.update(0.5);
      expect(world.projectiles, isEmpty);
    });

    test(
      'fast projectile damages first intersected slime regardless of list order',
      () {
        final world = _world();
        final far = world.spawnSlimeAt(const Offset(240, 200), spawnDelay: 0);
        final near = world.spawnSlimeAt(const Offset(180, 200), spawnDelay: 0);
        _startStationaryAttack(far);
        _startStationaryAttack(near);
        world.projectiles.add(
          FireProjectile(
            position: const Offset(100, 200),
            direction: const Offset(1, 0),
            damage: 20,
            pierce: 0,
          ),
        );
        world.update(0.6);
        expect(near.health.currentHealth, 10);
        expect(far.health.currentHealth, 30);
        expect(world.projectiles, isEmpty);
        expect(world.effects.single.kind, CombatEffectKind.fireExplosion);
        expect(world.damageNumbers.single.damage, 20);
        expect(world.damageNumbers.single.isFire, isTrue);
      },
    );

    test(
      'piercing hits each enemy once and disappears after its second hit',
      () {
        final world = _world();
        final near = world.spawnSlimeAt(const Offset(180, 200), spawnDelay: 0);
        final far = world.spawnSlimeAt(const Offset(320, 200), spawnDelay: 0);
        _startStationaryAttack(near);
        _startStationaryAttack(far);
        final projectile = FireProjectile(
          position: const Offset(100, 200),
          direction: const Offset(1, 0),
          damage: 20,
          pierce: 1,
        );
        world.projectiles.add(projectile);
        world.update(0.25);
        expect(near.health.currentHealth, 10);
        expect(far.health.currentHealth, 30);
        expect(projectile.hitsRemaining, 1);
        world.update(0.02);
        expect(near.health.currentHealth, 10);
        expect(projectile.hitsRemaining, 1);
        world.update(0.65);
        expect(far.health.currentHealth, 10);
        expect(world.projectiles, isEmpty);
      },
    );

    test(
      'projectile expires at its range without hitting beyond the endpoint',
      () {
        final world = _world();
        final enemy = world.spawnSlimeAt(const Offset(430, 200), spawnDelay: 0);
        _startStationaryAttack(enemy);
        final projectile = FireProjectile(
          position: const Offset(390, 200),
          direction: const Offset(1, 0),
          damage: 20,
          pierce: 0,
        )..distanceTravelled = FireOrbStats.projectileRange - 10;
        world.projectiles.add(projectile);
        world.update(0.2);
        expect(enemy.health.currentHealth, 30);
        expect(
          projectile.distanceTravelled,
          lessThanOrEqualTo(FireOrbStats.projectileRange),
        );
        expect(world.projectiles, isEmpty);
        expect(world.effects, isEmpty);
      },
    );

    test('projectile expires at its lifetime during a long frame', () {
      final world = _world();
      final enemy = world.spawnSlimeAt(const Offset(160, 200), spawnDelay: 0);
      _startStationaryAttack(enemy);
      final projectile = FireProjectile(
        position: const Offset(100, 200),
        direction: const Offset(1, 0),
        damage: 20,
        pierce: 0,
      )..age = FireOrbStats.projectileLifetime - 0.01;
      world.projectiles.add(projectile);
      world.update(0.2);
      expect(enemy.health.currentHealth, 30);
      expect(world.projectiles, isEmpty);
      expect(world.effects, isEmpty);
    });
  });

  group('combat feedback and fresh runs', () {
    test(
      'orb effects only spawn on actual cooldown-qualified damage and expire',
      () {
        final world = _world();
        world.player.stats.orbRotationSpeed = 0;
        final slime = world.spawnSlimeAt(
          world.orb.positionAround(world.player.position),
          maxHealth: 999,
          spawnDelay: 0,
        );
        world.update(0.001);
        expect(world.effects, hasLength(1));
        expect(world.damageNumbers, hasLength(1));
        final healthAfterHit = slime.health.currentHealth;
        final effect = world.effects.single;
        final number = world.damageNumbers.single;
        for (var frame = 0; frame < 10; frame++) {
          world.update(0.01);
        }
        expect(slime.health.currentHealth, healthAfterHit);
        expect(world.effects.single, same(effect));
        expect(world.damageNumbers.single, same(number));
        slime.position = const Offset(1000, 1000);
        world.update(0.7);
        expect(world.effects, isEmpty);
        expect(world.damageNumbers, isEmpty);
        expect(number.opacity, 0);
      },
    );

    test(
      'feedback retains bounded lists during a heavy burst of real hits',
      () {
        final world = _world();
        world.player.stats.orbRotationSpeed = 0;
        for (var index = 0; index < GameBalance.maximumEffects + 12; index++) {
          world.enemies.clear();
          world.spawnSlimeAt(
            world.orb.positionAround(world.player.position),
            maxHealth: 999,
            spawnDelay: 0,
          );
          world.update(0.0001);
        }
        expect(world.effects, hasLength(GameBalance.maximumEffects));
        expect(
          world.damageNumbers,
          hasLength(GameBalance.maximumDamageNumbers),
        );
        world.enemies.clear();
        world.update(1);
        expect(world.effects, isEmpty);
        expect(world.damageNumbers, isEmpty);
      },
    );

    test(
      'a new run has fresh stats, one orb, no pending systems or choices',
      () {
        final oldWorld = _world();
        _chooseWhenOffered(oldWorld, UpgradeId.arcaneOrb);
        _chooseWhenOffered(oldWorld, UpgradeId.fireOrb);
        oldWorld.spawnSlimeAt(const Offset(700, 700));
        oldWorld.xpGems.add(XpGem(position: const Offset(600, 600), value: 5));
        oldWorld.effects.add(
          CombatEffect(const Offset(500, 500), CombatEffectKind.arcaneImpact),
        );
        oldWorld.damageNumbers.add(DamageNumber(const Offset(500, 500), 10));
        oldWorld.projectiles.add(
          FireProjectile(
            position: const Offset(100, 100),
            direction: const Offset(1, 0),
            damage: 20,
            pierce: 0,
          ),
        );
        oldWorld.player.health.takeDamage(9999);
        oldWorld.update(0.01);
        expect(oldWorld.isGameOver, isTrue);

        final fresh = _world();
        expect(fresh.isPlaying, isTrue);
        expect(fresh.player.stats.level, 1);
        expect(fresh.player.stats.currentXp, 0);
        expect(fresh.player.health.currentHealth, GameBalance.maxHp);
        expect(fresh.player.stats.arcaneOrbCount, 1);
        expect(fresh.player.stats.fireOrb.isOwned, isFalse);
        expect(fresh.orbs, hasLength(1));
        expect(fresh.enemies, isEmpty);
        expect(fresh.xpGems, isEmpty);
        expect(fresh.effects, isEmpty);
        expect(fresh.damageNumbers, isEmpty);
        expect(fresh.projectiles, isEmpty);
        expect(fresh.upgradeChoices, isEmpty);
        expect(fresh.survivalTime, 0);
        expect(fresh.defeatedEnemies, 0);
        expect(fresh.spawner, isNot(same(oldWorld.spawner)));
        expect(fresh.player.stats, isNot(same(oldWorld.player.stats)));
        fresh.update(0.25);
        expect(fresh.survivalTime, 0.25);
        expect(fresh.orbs, hasLength(1));
      },
    );
  });
}
