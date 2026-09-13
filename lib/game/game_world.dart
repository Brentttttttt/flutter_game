import 'dart:math' as math;
import 'dart:ui';

import 'collision.dart';
import 'models/arena.dart';
import 'models/game_camera.dart';
import 'models/magic_orb.dart';
import 'models/player.dart';
import 'models/slime_enemy.dart';
import 'models/player_stats.dart';
import 'models/upgrade.dart';
import 'models/xp_gem.dart';
import 'models/combat_effect.dart';
import 'models/fire_projectile.dart';
import 'systems/enemy_spawner.dart';

enum GameRunState { playing, levelUpEffect, choosingUpgrade, gameOver }

class GameWorld {
  GameWorld({
    Arena? arena,
    PlayerPalette palette = PlayerPalette.color1,
    Offset? playerPosition,
    EnemySpawner? spawner,
    this.spawningEnabled = true,
    math.Random? random,
  }) : arena = arena ?? const Arena(),
       spawner = spawner ?? EnemySpawner(),
       _random = random ?? math.Random() {
    final arenaCenter = this.arena.bounds.center;
    player = Player(position: playerPosition ?? arenaCenter, palette: palette);
    orb = MagicOrb();
    orbs.add(orb);
    camera = GameCamera();
  }

  final Arena arena;
  final EnemySpawner spawner;
  final bool spawningEnabled;
  final math.Random _random;
  late final Player player;
  late final MagicOrb orb;
  late final GameCamera camera;
  final List<SlimeEnemy> enemies = [];
  final List<MagicOrb> orbs = [];
  final List<XpGem> xpGems = [];
  final List<CombatEffect> effects = [];
  final List<DamageNumber> damageNumbers = [];
  final List<FireProjectile> projectiles = [];
  List<UpgradeDefinition> upgradeChoices = const [];
  double levelUpEffectTime = 0;
  double _fireCooldownRemaining = 0;

  GameRunState runState = GameRunState.playing;
  double survivalTime = 0;
  int defeatedEnemies = 0;
  int _nextEnemyId = 1;

  bool get isGameOver => runState == GameRunState.gameOver;
  bool get isPlaying => runState == GameRunState.playing;
  bool get isChoosingUpgrade => runState == GameRunState.choosingUpgrade;

  void setViewport(Size size) {
    camera.setViewport(size, arena, player.position);
  }

  void setMovementInput(Offset input) {
    if (!isPlaying) {
      player.setMovementInput(Offset.zero);
      return;
    }
    player.setMovementInput(input);
  }

  SlimeEnemy spawnSlimeAt(
    Offset position, {
    int maxHealth = SlimeEnemy.startingHealth,
    int damage = SlimeEnemy.contactDamage,
    double spawnDelay = 0.3,
  }) {
    final slime = SlimeEnemy(
      id: _nextEnemyId++,
      position: arena.clampCircle(position, SlimeEnemy.radius),
      maxHealth: maxHealth,
      damage: damage,
      spawnDelayRemaining: spawnDelay,
    );
    enemies.add(slime);
    return slime;
  }

  void update(double deltaTime) {
    if (!deltaTime.isFinite ||
        deltaTime <= 0 ||
        isGameOver ||
        isChoosingUpgrade) {
      return;
    }
    if (runState == GameRunState.levelUpEffect) {
      levelUpEffectTime += deltaTime;
      if (levelUpEffectTime >= GameBalance.levelUpDuration) {
        runState = GameRunState.choosingUpgrade;
      }
      return;
    }
    if (player.isDead) {
      _finishRun();
      return;
    }

    survivalTime += deltaTime;
    player.update(deltaTime);
    _movePlayer(deltaTime);
    for (final orbitingOrb in orbs) {
      orbitingOrb.update(
        deltaTime,
        rotationSpeed: player.stats.orbRotationSpeed,
      );
    }
    _updateEffects(deltaTime);

    if (spawningEnabled) {
      final spawnPosition = spawner.update(
        deltaTime: deltaTime,
        survivalTime: survivalTime,
        arena: arena,
        camera: camera,
        playerPosition: player.position,
        existingEnemies: enemies,
      );
      if (spawnPosition != null) {
        final isOpening = survivalTime < GameBalance.openingGraceDuration;
        spawnSlimeAt(
          spawnPosition,
          maxHealth: isOpening
              ? GameBalance.openingSlimeHealth
              : SlimeEnemy.startingHealth,
          damage: isOpening
              ? GameBalance.openingSlimeDamage
              : SlimeEnemy.contactDamage,
        );
      }
    }

    final speedMultiplier = 1.0 + math.min(0.25, survivalTime / 960);
    for (final enemy in enemies) {
      enemy.update(
        deltaTime,
        playerPosition: player.position,
        playerRadius: Player.radius,
        arena: arena,
        speedMultiplier: speedMultiplier,
      );
    }

    _separateSlimes();
    _applyAttackDamage();
    if (player.isDead) {
      _finishRun();
      camera.update(deltaTime, player.position, arena);
      return;
    }

    for (final orbitingOrb in orbs) {
      for (final enemy in enemies) {
        final result = orbitingOrb.tryHit(
          enemy,
          player.position,
          hitDamage: player.stats.roundedOrbDamage,
        );
        if (result != SlimeDamageResult.none) {
          final contact = Offset.lerp(
            orbitingOrb.positionAround(player.position),
            enemy.position,
            0.5,
          )!;
          _recordHit(enemy, result, player.stats.roundedOrbDamage, contact);
        }
      }
    }
    _updateFireWeapon(deltaTime);
    _updateProjectiles(deltaTime);
    _collectXp(deltaTime);

    enemies.removeWhere((enemy) => enemy.lifeState == SlimeLifeState.removed);
    camera.update(deltaTime, player.position, arena);
  }

  void _movePlayer(double deltaTime) {
    final displacement =
        player.movementInput * player.stats.movementSpeed * deltaTime;
    if (displacement == Offset.zero) {
      return;
    }

    var next = player.position;
    final horizontal = arena.clampCircle(
      next + Offset(displacement.dx, 0),
      Player.radius,
    );
    if (!_movesDeeperIntoEnemy(next, horizontal)) {
      next = horizontal;
    }

    final vertical = arena.clampCircle(
      next + Offset(0, displacement.dy),
      Player.radius,
    );
    if (!_movesDeeperIntoEnemy(next, vertical)) {
      next = vertical;
    }

    player.position = next;
  }

  bool _movesDeeperIntoEnemy(Offset current, Offset candidate) {
    for (final enemy in enemies.where((enemy) => enemy.isActive)) {
      if (!circlesOverlap(
        candidate,
        Player.radius,
        enemy.position,
        SlimeEnemy.radius,
      )) {
        continue;
      }
      final currentDistance = (current - enemy.position).distanceSquared;
      final candidateDistance = (candidate - enemy.position).distanceSquared;
      if (candidateDistance < currentDistance) {
        return true;
      }
    }
    return false;
  }

  void _separateSlimes() {
    final activeEnemies = enemies.where((enemy) => enemy.isActive).toList();
    const minimumDistance = SlimeEnemy.radius * 1.85;

    for (var firstIndex = 0; firstIndex < activeEnemies.length; firstIndex++) {
      final first = activeEnemies[firstIndex];
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < activeEnemies.length;
        secondIndex++
      ) {
        final second = activeEnemies[secondIndex];
        final difference = second.position - first.position;
        final distance = difference.distance;
        if (distance >= minimumDistance) {
          continue;
        }

        final direction = distance < 0.001
            ? Offset(
                math.cos((first.id + second.id) * 1.7),
                math.sin((first.id + second.id) * 1.7),
              )
            : difference / distance;
        final correction = (minimumDistance - distance) / 2;
        first.position = arena.clampCircle(
          first.position - direction * correction,
          SlimeEnemy.radius,
        );
        second.position = arena.clampCircle(
          second.position + direction * correction,
          SlimeEnemy.radius,
        );
      }
    }
  }

  void _applyAttackDamage() {
    for (final enemy in enemies.where((enemy) => enemy.isActive)) {
      if (enemy.consumeAttackHit(
        playerPosition: player.position,
        playerRadius: Player.radius,
      )) {
        player.takeDamage(enemy.damage);
      }
    }
  }

  void _recordHit(
    SlimeEnemy enemy,
    SlimeDamageResult result,
    int damage,
    Offset contact, {
    bool isFire = false,
  }) {
    if (effects.length >= GameBalance.maximumEffects) effects.removeAt(0);
    effects.add(
      CombatEffect(
        contact,
        isFire ? CombatEffectKind.fireExplosion : CombatEffectKind.arcaneImpact,
      ),
    );
    if (damageNumbers.length >= GameBalance.maximumDamageNumbers) {
      damageNumbers.removeAt(0);
    }
    damageNumbers.add(DamageNumber(enemy.position, damage, isFire: isFire));
    if (result == SlimeDamageResult.defeated) {
      defeatedEnemies++;
      xpGems.add(
        XpGem(position: enemy.position, value: GameBalance.xpPerSlime),
      );
    }
  }

  void _updateEffects(double dt) {
    for (final effect in effects) {
      effect.age += dt;
    }
    effects.removeWhere((effect) => effect.isFinished);
    for (final number in damageNumbers) {
      number.age += dt;
    }
    damageNumbers.removeWhere((number) => number.isFinished);
  }

  void _collectXp(double dt) {
    var collectedXp = 0;
    xpGems.removeWhere((gem) {
      if (!gem.update(dt, player.position, player.stats.xpPickupRadius)) {
        return false;
      }
      collectedXp += gem.value;
      return true;
    });
    if (collectedXp > 0) awardXp(collectedXp);
  }

  void awardXp(int amount) {
    if (amount <= 0 || !isPlaying) return;
    player.stats.currentXp += amount;
    _beginLevelUpIfReady();
  }

  void _beginLevelUpIfReady() {
    if (!player.stats.advanceLevelIfReady()) return;
    player.setMovementInput(Offset.zero);
    levelUpEffectTime = 0;
    final available = UpgradeDefinition.availableFor(player.stats)
      ..shuffle(_random);
    upgradeChoices = List.unmodifiable(available.take(3));
    runState = GameRunState.levelUpEffect;
  }

  bool chooseUpgrade(UpgradeId id) {
    if (!isChoosingUpgrade) return false;
    final matching = upgradeChoices.where((upgrade) => upgrade.id == id);
    if (matching.isEmpty) return false;
    matching.single.apply(player.stats);
    upgradeChoices = const [];
    _syncOrbs();
    runState = GameRunState.playing;
    _beginLevelUpIfReady(); // Excess XP gets a separate choice for every level.
    return true;
  }

  void _syncOrbs() {
    while (orbs.where((orb) => orb.kind == OrbKind.arcane).length <
        player.stats.arcaneOrbCount) {
      orbs.add(
        MagicOrb()
          ..angle = orb.angle
          ..animationTime = orb.animationTime,
      );
    }
    if (player.stats.fireOrb.isOwned &&
        !orbs.any((orb) => orb.kind == OrbKind.fire)) {
      orbs.add(
        MagicOrb(kind: OrbKind.fire)
          ..angle = orb.angle
          ..animationTime = orb.animationTime,
      );
      _fireCooldownRemaining = 0.25;
    }
    // Space every owned orb, including Fire, so no two occupy the same angle.
    for (var index = 0; index < orbs.length; index++) {
      orbs[index].phaseOffset = math.pi * 2 * index / orbs.length;
    }
  }

  void _updateFireWeapon(double dt) {
    if (!player.stats.fireOrb.isOwned) return;
    _fireCooldownRemaining -= dt;
    if (_fireCooldownRemaining > 0 ||
        projectiles.length >= GameBalance.maximumProjectiles) {
      return;
    }
    final fireOrb = orbs.firstWhere((orb) => orb.kind == OrbKind.fire);
    final origin = fireOrb.positionAround(player.position);
    SlimeEnemy? target;
    var nearest = FireOrbStats.targetingRange * FireOrbStats.targetingRange;
    for (final enemy in enemies) {
      if (!enemy.isActive || enemy.spawnDelayRemaining > 0) continue;
      final distance = (enemy.position - origin).distanceSquared;
      if (distance < nearest) {
        nearest = distance;
        target = enemy;
      }
    }
    if (target == null) return;
    final delta = target.position - origin;
    final direction = delta.distance < 0.001
        ? const Offset(0, -1)
        : delta / delta.distance;
    projectiles.add(
      FireProjectile(
        position: origin,
        direction: direction,
        damage: player.stats.fireOrb.damage,
        pierce: player.stats.fireOrb.pierce,
      ),
    );
    _fireCooldownRemaining = player.stats.fireOrb.cooldown;
  }

  void _updateProjectiles(double dt) {
    for (final projectile in projectiles) {
      if (projectile.isFinished) continue;
      projectile.update(dt);
      final hits = <({SlimeEnemy enemy, double time})>[];
      for (final enemy in enemies) {
        if (!enemy.isActive ||
            enemy.spawnDelayRemaining > 0 ||
            projectile.hitEnemyIds.contains(enemy.id)) {
          continue;
        }
        final hitTime = segmentCircleHitTime(
          projectile.previousPosition,
          projectile.position,
          enemy.position,
          SlimeEnemy.radius + FireOrbStats.projectileRadius,
        );
        if (hitTime != null) hits.add((enemy: enemy, time: hitTime));
      }
      hits.sort((a, b) => a.time.compareTo(b.time));
      for (final hit in hits) {
        final result = hit.enemy.takeProjectileHit(projectile.damage);
        if (result == SlimeDamageResult.none) continue;
        projectile.hitEnemyIds.add(hit.enemy.id);
        final contact = Offset.lerp(
          projectile.previousPosition,
          projectile.position,
          hit.time,
        )!;
        _recordHit(hit.enemy, result, projectile.damage, contact, isFire: true);
        projectile.hitsRemaining--;
        if (projectile.hitsRemaining <= 0) break;
      }
    }
    projectiles.removeWhere((projectile) => projectile.isFinished);
  }

  void _finishRun() {
    if (isGameOver) {
      return;
    }
    runState = GameRunState.gameOver;
    player.setMovementInput(Offset.zero);
  }
}
