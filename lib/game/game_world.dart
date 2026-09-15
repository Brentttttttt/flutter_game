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
import 'models/dino_tri.dart';
import 'models/endless_balance.dart';
import 'models/game_sound.dart';
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
    math.Random? colorRandom,
  }) : arena = arena ?? const Arena(),
       spawner = spawner ?? EnemySpawner(),
       _random = random ?? math.Random(),
       _colorRandom = colorRandom ?? math.Random() {
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
  // Cosmetic choices must not change the sequence of gameplay upgrades.
  final math.Random _colorRandom;
  late final Player player;
  late final MagicOrb orb;
  late final GameCamera camera;
  final List<SlimeEnemy> enemies = [];
  final List<MagicOrb> orbs = [];
  final List<XpGem> xpGems = [];
  final List<CombatEffect> effects = [];
  final List<DamageNumber> damageNumbers = [];
  final List<FireProjectile> projectiles = [];
  DinoTri? boss;
  int bossesDefeated = 0;
  int bossEncounters = 0;
  double nextBossTime = EndlessBalance.bossInterval;
  double bossWarningRemaining = 0;
  double _spawnRecoveryRemaining = 0;
  int _pendingBossXp = 0;
  bool _lowHealthLatched = false;
  final List<GameSound> _soundEvents = [];
  List<UpgradeDefinition> upgradeChoices = const [];
  double levelUpEffectTime = 0;
  double _fireCooldownRemaining = 0;

  GameRunState runState = GameRunState.playing;
  double survivalTime = 0;
  Offset _playerVelocity = Offset.zero;
  Offset get playerVelocity => _playerVelocity;
  int defeatedEnemies = 0;
  int _nextEnemyId = 1;

  bool get isGameOver => runState == GameRunState.gameOver;
  bool get isPlaying => runState == GameRunState.playing;
  bool get isChoosingUpgrade => runState == GameRunState.choosingUpgrade;
  bool get isBossWarning => bossWarningRemaining > 0;

  List<GameSound> drainSoundEvents() {
    final result = List<GameSound>.of(_soundEvents);
    _soundEvents.clear();
    return result;
  }

  void _sound(GameSound sound) {
    if (_soundEvents.length < EndlessBalance.maximumQueuedSounds) {
      _soundEvents.add(sound);
    }
  }

  void setViewport(Size size) {
    camera.setViewport(size, arena, player.position);
  }

  void setMovementInput(Offset input) {
    if (!isPlaying) {
      _playerVelocity = Offset.zero;
      player.setMovementInput(Offset.zero);
      return;
    }
    player.setMovementInput(input);
    if (player.movementInput == Offset.zero) _playerVelocity = Offset.zero;
  }

  SlimeEnemy spawnSlimeAt(
    Offset position, {
    int maxHealth = SlimeEnemy.startingHealth,
    int damage = SlimeEnemy.contactDamage,
    double spawnDelay = 0.3,
    SlimeColor? color,
  }) {
    final slime = SlimeEnemy(
      id: _nextEnemyId++,
      position: arena.clampCircle(position, SlimeEnemy.radius),
      color:
          color ??
          SlimeColor.values[_colorRandom.nextInt(SlimeColor.values.length)],
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
    _updateBossEncounter(deltaTime);
    player.update(deltaTime);
    final previousPlayerPosition = player.position;
    _movePlayer(deltaTime);
    // Lead aims from actual world movement, including diagonal normalization
    // and walls/enemy blocking, instead of the joystick's intended direction.
    _playerVelocity = (player.position - previousPlayerPosition) / deltaTime;
    for (final orbitingOrb in orbs) {
      orbitingOrb.update(
        deltaTime,
        rotationSpeed: player.stats.orbRotationSpeed,
      );
    }
    _updateEffects(deltaTime);

    if (spawningEnabled && !isBossWarning && !(boss?.isActive ?? false)) {
      final spawnPositions = spawner.updateBatch(
        deltaTime: deltaTime * _slimeSpawnPace,
        survivalTime: survivalTime,
        playerLevel: player.stats.level,
        bossesDefeated: bossesDefeated,
        arena: arena,
        camera: camera,
        playerPosition: player.position,
        existingEnemies: enemies,
      );
      for (final spawnPosition in spawnPositions) {
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
    final currentBoss = boss;
    if (currentBoss != null) {
      final previousAttack = currentBoss.attackSequence;
      currentBoss.update(
        deltaTime,
        playerPosition: player.position,
        playerVelocity: _playerVelocity,
        playerRadius: Player.radius,
        arena: arena,
      );
      if (currentBoss.attackSequence != previousAttack) {
        _sound(GameSound.bossAttack);
      }
      final damage = currentBoss.consumeAttackHit(
        playerPosition: player.position,
        playerRadius: Player.radius,
      );
      if (damage > 0) _damagePlayer(damage);
    }
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
      final target = boss;
      if (target != null &&
          target.isActive &&
          circlesOverlap(
            orbitingOrb.positionAround(player.position),
            MagicOrb.radius,
            target.position,
            DinoTri.radius,
          )) {
        final result = target.takeOrbHit(
          player.stats.roundedOrbDamage,
          MagicOrb.hitCooldown,
        );
        if (result != SlimeDamageResult.none) {
          _recordBossHit(
            target,
            result,
            player.stats.roundedOrbDamage,
            Offset.lerp(
              orbitingOrb.positionAround(player.position),
              target.position,
              0.5,
            )!,
          );
        }
      }
    }
    _updateFireWeapon(deltaTime);
    _updateProjectiles(deltaTime);
    _collectXp(deltaTime);
    if (player.health.ratio > EndlessBalance.lowHealthResetThreshold) {
      _lowHealthLatched = false;
    }
    if (boss != null && !boss!.isVisible) boss = null;

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
    final target = boss;
    if (target != null &&
        target.isActive &&
        circlesOverlap(
          candidate,
          Player.radius,
          target.position,
          DinoTri.radius,
        ) &&
        (candidate - target.position).distanceSquared <
            (current - target.position).distanceSquared) {
      return true;
    }
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
        final distanceSquared = difference.distanceSquared;
        if (distanceSquared >= minimumDistance * minimumDistance) {
          continue;
        }
        final distance = math.sqrt(distanceSquared);

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
        _damagePlayer(enemy.damage);
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
    _hitFeedback(enemy.position, damage, contact, isFire: isFire);
    if (result == SlimeDamageResult.defeated) {
      defeatedEnemies++;
      xpGems.add(
        XpGem(position: enemy.position, value: GameBalance.xpPerSlime),
      );
    }
  }

  void _hitFeedback(
    Offset targetPosition,
    int damage,
    Offset contact, {
    bool isFire = false,
  }) {
    _sound(isFire ? GameSound.fireHit : GameSound.arcaneHit);
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
    damageNumbers.add(DamageNumber(targetPosition, damage, isFire: isFire));
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
    var collectedXp = _pendingBossXp;
    _pendingBossXp = 0;
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
    _sound(GameSound.powerUp);
    _playerVelocity = Offset.zero;
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
    if (player.health.ratio > EndlessBalance.lowHealthResetThreshold) {
      _lowHealthLatched = false;
    }
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
    Offset? target;
    var nearest = FireOrbStats.targetingRange * FireOrbStats.targetingRange;
    for (final enemy in enemies) {
      if (!enemy.isActive || enemy.spawnDelayRemaining > 0) continue;
      final distance = (enemy.position - origin).distanceSquared;
      if (distance < nearest) {
        nearest = distance;
        target = enemy.position;
      }
    }
    final currentBoss = boss;
    if (currentBoss != null &&
        currentBoss.isActive &&
        (currentBoss.position - origin).distanceSquared < nearest) {
      target = currentBoss.position;
    }
    if (target == null) return;
    final delta = target - origin;
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
    _sound(GameSound.fireShot);
  }

  void _updateProjectiles(double dt) {
    for (final projectile in projectiles) {
      if (projectile.isFinished) continue;
      projectile.update(dt);
      final hits = <({SlimeEnemy? slime, DinoTri? boss, double time})>[];
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
        if (hitTime != null) {
          hits.add((slime: enemy, boss: null, time: hitTime));
        }
      }
      final target = boss;
      if (target != null &&
          target.isActive &&
          !projectile.hitEnemyIds.contains(target.id)) {
        final hitTime = segmentCircleHitTime(
          projectile.previousPosition,
          projectile.position,
          target.position,
          DinoTri.radius + FireOrbStats.projectileRadius,
        );
        if (hitTime != null) {
          hits.add((slime: null, boss: target, time: hitTime));
        }
      }
      hits.sort((a, b) => a.time.compareTo(b.time));
      for (final hit in hits) {
        final result = hit.slime != null
            ? hit.slime!.takeProjectileHit(projectile.damage)
            : hit.boss!.takeProjectileHit(projectile.damage);
        if (result == SlimeDamageResult.none) continue;
        projectile.hitEnemyIds.add(hit.slime?.id ?? hit.boss!.id);
        final contact = Offset.lerp(
          projectile.previousPosition,
          projectile.position,
          hit.time,
        )!;
        if (hit.slime != null) {
          _recordHit(
            hit.slime!,
            result,
            projectile.damage,
            contact,
            isFire: true,
          );
        } else {
          _recordBossHit(
            hit.boss!,
            result,
            projectile.damage,
            contact,
            isFire: true,
          );
        }
        projectile.hitsRemaining--;
        if (projectile.hitsRemaining <= 0) break;
      }
    }
    projectiles.removeWhere((projectile) => projectile.isFinished);
  }

  double get _slimeSpawnPace {
    final untilBoss = nextBossTime - survivalTime;
    final windDown = (untilBoss / EndlessBalance.spawnWindDownDuration).clamp(
      0.15,
      1.0,
    );
    final recovery =
        (1 - _spawnRecoveryRemaining / EndlessBalance.spawnRecoveryDuration)
            .clamp(0.2, 1.0);
    return math.min(windDown, recovery);
  }

  void _updateBossEncounter(double dt) {
    _spawnRecoveryRemaining = math.max(0, _spawnRecoveryRemaining - dt);
    if (isBossWarning) {
      bossWarningRemaining = math.max(0, bossWarningRemaining - dt);
      if (!isBossWarning) {
        bossEncounters++;
        boss = DinoTri(
          id: -bossEncounters,
          position: _bossSpawnPosition(),
          encounterNumber: math.max(
            bossEncounters,
            (survivalTime / EndlessBalance.bossInterval).floor(),
          ),
        );
      }
      return;
    }
    if (boss != null || survivalTime < nextBossTime) return;
    bossWarningRemaining = EndlessBalance.warningDuration;
    // Only one boss exists at a time. Long encounters skip missed milestones;
    // they never accumulate bosses to spawn simultaneously afterward.
    nextBossTime =
        ((survivalTime / EndlessBalance.bossInterval).floor() + 1) *
        EndlessBalance.bossInterval;
    _sound(GameSound.bossWarning);
  }

  Offset _bossSpawnPosition() {
    final distance = math.max(
      260.0,
      camera.viewportSize.shortestSide / 2 + 100,
    );
    var best = arena.bounds.center;
    var bestDistance = -1.0;
    for (var side = 0; side < 8; side++) {
      final angle = side * math.pi / 4;
      final candidate = arena.clampCircle(
        player.position + Offset(math.cos(angle), math.sin(angle)) * distance,
        DinoTri.radius,
      );
      final away = (candidate - player.position).distanceSquared;
      if (away > bestDistance) {
        best = candidate;
        bestDistance = away;
      }
    }
    return best;
  }

  void _damagePlayer(int damage) {
    if (!player.takeDamage(damage)) return;
    _sound(GameSound.hurt);
    if (!player.isDead &&
        !_lowHealthLatched &&
        player.health.ratio <= EndlessBalance.lowHealthThreshold) {
      _lowHealthLatched = true;
      _sound(GameSound.lowHealth);
    }
  }

  void _recordBossHit(
    DinoTri target,
    SlimeDamageResult result,
    int damage,
    Offset contact, {
    bool isFire = false,
  }) {
    _hitFeedback(target.position, damage, contact, isFire: isFire);
    if (result != SlimeDamageResult.defeated) return;
    bossesDefeated++;
    _sound(GameSound.bossDefeated);
    _pendingBossXp += math.max(
      80 + 40 * target.encounterNumber,
      player.stats.xpRequired,
    );
    _spawnRecoveryRemaining = EndlessBalance.spawnRecoveryDuration;
    spawner.timeUntilNextSpawn = 1;
    final earliestNext = survivalTime + EndlessBalance.minimumBossRecovery;
    if (nextBossTime < earliestNext) {
      nextBossTime =
          (earliestNext / EndlessBalance.bossInterval).ceil() *
          EndlessBalance.bossInterval;
    }
    // Defeat preserves the same arena, player, timer, weapons, gems and kills.
    // The reward joins ordinary collected XP at the end of this update.
  }

  void _finishRun() {
    if (isGameOver) {
      return;
    }
    runState = GameRunState.gameOver;
    _playerVelocity = Offset.zero;
    player.setMovementInput(Offset.zero);
  }
}
