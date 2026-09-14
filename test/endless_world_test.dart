import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
import 'package:flutter_game/game/models/endless_balance.dart';
import 'package:flutter_game/game/models/fire_projectile.dart';
import 'package:flutter_game/game/models/game_sound.dart';
import 'package:flutter_game/game/models/player_stats.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/systems/enemy_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

GameWorld fixture({bool spawning = false}) => GameWorld(
  spawningEnabled: spawning,
  playerPosition: const Offset(700, 650),
  random: math.Random(7),
  spawner: EnemySpawner(random: math.Random(7)),
)..setViewport(const Size(390, 780));

void step(GameWorld world, double seconds) {
  for (var elapsed = 0.0; elapsed < seconds - 0.000001; elapsed += 0.05) {
    world.update(math.min(0.05, seconds - elapsed));
  }
}

void finishChoices(GameWorld world) {
  for (var count = 0; count < 30 && !world.isPlaying; count++) {
    expect(world.isGameOver, isFalse);
    world.update(GameBalance.levelUpDuration);
    world.chooseUpgrade(
      world.upgradeChoices
          .firstWhere((choice) => choice.id != UpgradeId.vitality)
          .id,
    );
  }
  expect(world.isPlaying, isTrue);
}

void main() {
  test(
    'first warning starts at five minutes, freezes for levels, and spawns one boss',
    () {
      final world = fixture()..survivalTime = 299.9;
      world.update(0.05);
      expect(world.boss, isNull);
      expect(world.isBossWarning, isFalse);
      world.update(0.05);
      expect(world.isBossWarning, isTrue);
      expect(world.drainSoundEvents(), contains(GameSound.bossWarning));
      expect(world.nextBossTime, 600);
      final warning = world.bossWarningRemaining;
      world.awardXp(10);
      world.update(0.4);
      expect(world.bossWarningRemaining, warning);
      finishChoices(world);
      step(world, EndlessBalance.warningDuration + 0.05);
      expect(world.isBossWarning, isFalse);
      expect(world.bossEncounters, 1);
      expect(world.boss!.encounterNumber, 1);
      expect(
        (world.boss!.position - world.player.position).distance,
        greaterThan(200),
      );
      final boss = world.boss;
      world.survivalTime = 900;
      world.update(0.05);
      expect(world.boss, same(boss));
      expect(world.bossEncounters, 1);
      expect(world.isGameOver, isFalse);
    },
  );

  test(
    'boss defeat rewards XP and resumes the same run without resetting anything',
    () {
      final world = fixture(spawning: true)..survivalTime = 310;
      world.nextBossTime = 600;
      world.bossEncounters = 1;
      world.defeatedEnemies = 17;
      final player = world.player;
      final arena = world.arena;
      world.player.stats.orbRotationSpeed = 0;
      world.player.stats.orbDamage = 2000;
      world.boss = DinoTri(
        id: -1,
        position: world.orb.positionAround(player.position),
        encounterNumber: 1,
      );
      world.update(0.01);
      expect(world.boss!.isActive, isFalse);
      expect(world.bossesDefeated, 1);
      expect(world.defeatedEnemies, 17);
      expect(world.player, same(player));
      expect(world.arena, same(arena));
      expect(world.survivalTime, greaterThan(310));
      expect(world.player.health.currentHealth, 100);
      expect(world.player.stats.level, 2);
      expect(world.player.stats.currentXp, 110);
      expect(
        world.xpGems,
        isEmpty,
      ); // Boss XP is awarded directly; no healing drops.
      expect(
        world.drainSoundEvents(),
        containsAll([
          GameSound.arcaneHit,
          GameSound.bossDefeated,
          GameSound.powerUp,
        ]),
      );
      finishChoices(world);
      step(world, 12);
      expect(world.boss, isNull);
      expect(world.enemies, isNotEmpty);
      expect(world.bossesDefeated, 1);
      expect(world.nextBossTime, 600);
      expect(world.isGameOver, isFalse);
      expect(world.player.stats.orbDamage, greaterThanOrEqualTo(2000));
    },
  );

  test(
    'later milestones recur stronger and never queue a flood after long fights',
    () {
      final world = fixture()..survivalTime = 599.95;
      world.nextBossTime = 600;
      world.bossEncounters = 1;
      world.bossesDefeated = 1;
      world.update(0.05);
      step(world, 6.05);
      final boss = world.boss!;
      expect(boss.encounterNumber, 2);
      expect(boss.health.maxHealth, greaterThan(DinoTriStats(1).maxHealth));
      expect(
        boss.stats.attackADamage,
        greaterThan(DinoTriStats(1).attackADamage),
      );
      expect(world.nextBossTime, 900);
      world.survivalTime = 1190;
      boss.position = world.orb.positionAround(world.player.position);
      world.player.stats.orbRotationSpeed = 0;
      world.player.stats.orbDamage = 99999;
      world.update(0.01);
      expect(
        world.nextBossTime,
        1500,
      ); // Keeps 30 seconds of recovery across 20:00.
      expect(world.bossesDefeated, 2);
      expect(world.isGameOver, isFalse);
    },
  );

  test(
    'fire targets boss and swept collisions hit the first slime or boss only',
    () {
      final world = fixture();
      final boss = world.boss = DinoTri(
        id: -1,
        position: world.player.position + const Offset(120, 0),
        encounterNumber: 1,
      );
      final slime = world.spawnSlimeAt(
        boss.position + const Offset(90, 0),
        spawnDelay: 0,
      );
      world.projectiles.add(
        FireProjectile(
          position: world.player.position,
          direction: const Offset(1, 0),
          damage: 20,
          pierce: 0,
        ),
      );
      step(world, 0.5);
      expect(boss.health.currentHealth, boss.health.maxHealth - 20);
      expect(slime.health.currentHealth, slime.health.maxHealth);
      expect(world.projectiles, isEmpty);
      expect(world.drainSoundEvents(), contains(GameSound.fireHit));

      world.enemies.clear();
      world.awardXp(10);
      world.update(GameBalance.levelUpDuration);
      expect(world.chooseUpgrade(UpgradeId.fireOrb), isTrue);
      step(world, 0.3);
      expect(world.drainSoundEvents(), contains(GameSound.fireShot));
      expect(world.projectiles, isNotEmpty);
    },
  );

  test(
    'boss attack damages player once and low-health sound does not repeat',
    () {
      final world = fixture();
      final boss = world.boss = DinoTri(
        id: -1,
        position: world.player.position - const Offset(85, 0),
        encounterNumber: 1,
      );
      world.player.health.takeDamage(70);
      boss.activity = DinoActivity.chasing;
      boss.attackCooldownRemaining = 0;
      step(world, 1.5);
      expect(world.player.health.currentHealth, 12);
      final sounds = world.drainSoundEvents();
      expect(sounds.where((s) => s == GameSound.hurt), hasLength(1));
      expect(sounds.where((s) => s == GameSound.lowHealth), hasLength(1));
      step(world, 0.4);
      expect(world.drainSoundEvents(), isNot(contains(GameSound.lowHealth)));
      world.player.health.takeDamage(12);
      world.update(0.01);
      expect(world.isGameOver, isTrue);
      final frozen = world.survivalTime;
      world.update(600);
      expect(world.survivalTime, frozen);
    },
  );

  test('post-boss slime pressure grows within mobile bounds', () {
    final spawner = EnemySpawner();
    var interval = spawner.spawnIntervalFor(600, playerLevel: 20);
    var maximum = spawner.maximumEnemiesFor(600, playerLevel: 20);
    for (var victories = 1; victories <= 10; victories++) {
      final nextInterval = spawner.spawnIntervalFor(
        600 + victories * 300,
        playerLevel: 20,
        bossesDefeated: victories,
      );
      final nextMaximum = spawner.maximumEnemiesFor(
        600 + victories * 300,
        playerLevel: 20,
        bossesDefeated: victories,
      );
      expect(nextInterval, lessThan(interval));
      expect(nextMaximum, greaterThan(maximum));
      expect(nextInterval, greaterThanOrEqualTo(0.45));
      expect(nextMaximum, lessThanOrEqualTo(48));
      interval = nextInterval;
      maximum = nextMaximum;
    }
  });

  test('new run has no boss, timers, sound events or inherited progress', () {
    final fresh = fixture();
    expect(fresh.boss, isNull);
    expect(fresh.bossesDefeated, 0);
    expect(fresh.bossEncounters, 0);
    expect(fresh.nextBossTime, 300);
    expect(fresh.bossWarningRemaining, 0);
    expect(fresh.drainSoundEvents(), isEmpty);
    expect(fresh.player.stats.level, 1);
    expect(fresh.player.stats.currentXp, 0);
    expect(fresh.player.health.currentHealth, 100);
    expect(fresh.survivalTime, 0);
    expect(fresh.defeatedEnemies, 0);
  });
}
