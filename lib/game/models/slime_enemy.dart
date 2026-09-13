import 'dart:math' as math;
import 'dart:ui';

import 'arena.dart';
import 'health.dart';

enum SlimeFacing { north, south, east, west }

enum SlimeColor { blue, brown, green, grey, orange, red, yellow }

enum SlimeLifeState { active, dying, removed }

enum SlimeActivity { idle, walking, attacking }

enum SlimeDamageResult { none, damaged, defeated }

class SlimeEnemy {
  SlimeEnemy({
    required this.id,
    required this.position,
    this.color = SlimeColor.blue,
    int maxHealth = startingHealth,
    this.damage = contactDamage,
    this.spawnDelayRemaining = 0.3,
  }) : health = Health(maxHealth);

  static const int startingHealth = 30;
  static const int contactDamage = 10;
  static const double renderSize = 48;
  static const double radius = 16;
  static const double baseSpeed = 62;
  // Larger than this finite arena's diagonal so spawned slimes never become
  // stranded while still occupying the mobile-friendly enemy cap.
  static const double chaseRange = 2500;
  // Every slime_v2 sheet is 320 x 128, with 32 px cells. Rows contain
  // 6 idle, 6 walk, 9 attack, and 9 death frames; remaining cells are blank.
  static const double frameSize = 32;
  static const int idleFrameCount = 6;
  static const int walkFrameCount = 6;
  static const int attackFrameCount = 9;
  static const int deathFrameCount = 9;
  static const double animationFps = 10;
  // Keep combat timing independent of the replacement artwork's frame count.
  static const double deathDuration = 0.6;
  static const double attackDuration = 0.8;
  static const double attackHitTime = 0.4;
  static const double attackCooldown = 1.25;
  static const double attackReachPadding = 4;

  final int id;
  final SlimeColor color;
  final int damage;
  Offset position;
  final Health health;
  SlimeFacing facing = SlimeFacing.south;
  SlimeLifeState lifeState = SlimeLifeState.active;
  SlimeActivity activity = SlimeActivity.idle;
  double animationTime = 0;
  double deathAnimationTime = 0;
  double hurtFlashTime = 0;
  double orbHitCooldownRemaining = 0;
  double attackCooldownRemaining = 0;
  double spawnDelayRemaining;
  bool _attackFacesRight = false;
  bool _facesRight = false;
  bool _attackHitPending = false;
  bool _attackHitConsumed = false;

  bool get isActive => lifeState == SlimeLifeState.active;
  bool get isVisible => lifeState != SlimeLifeState.removed;
  bool get isDamaged => health.currentHealth < health.maxHealth;

  // Native slime_v2 artwork faces LEFT. Lock the attack facing for that swing,
  // then restore movement/idle facing without moving the sprite's anchor.
  bool get mirrorAttackHorizontally =>
      isActive && activity == SlimeActivity.attacking && _attackFacesRight;

  bool get mirrorHorizontally => isActive && activity == SlimeActivity.attacking
      ? _attackFacesRight
      : _facesRight;

  Rect get sourceRect {
    final row = lifeState == SlimeLifeState.dying
        ? 3
        : switch (activity) {
            SlimeActivity.idle => 0,
            SlimeActivity.walking => 1,
            SlimeActivity.attacking => 2,
          };
    final frame = lifeState == SlimeLifeState.dying
        ? deathFrame
        : animationFrame;
    return Rect.fromLTWH(
      frame * frameSize,
      row * frameSize,
      frameSize,
      frameSize,
    );
  }

  void update(
    double deltaTime, {
    required Offset playerPosition,
    required double playerRadius,
    required Arena arena,
    double speedMultiplier = 1,
  }) {
    // The strike can only connect on the update that reaches its hit frame.
    // A missed/ignored strike must not turn into delayed contact damage.
    _attackHitPending = false;
    hurtFlashTime = math.max(0, hurtFlashTime - deltaTime);
    orbHitCooldownRemaining = math.max(0, orbHitCooldownRemaining - deltaTime);
    attackCooldownRemaining = math.max(0, attackCooldownRemaining - deltaTime);

    if (lifeState == SlimeLifeState.dying) {
      deathAnimationTime += deltaTime;
      if (deathAnimationTime >= deathDuration) {
        lifeState = SlimeLifeState.removed;
      }
      return;
    }
    if (!isActive) {
      return;
    }

    if (spawnDelayRemaining > 0) {
      spawnDelayRemaining = math.max(0, spawnDelayRemaining - deltaTime);
      _setActivity(SlimeActivity.idle);
      animationTime += deltaTime;
      return;
    }

    final toPlayer = playerPosition - position;
    final distance = toPlayer.distance;

    if (activity == SlimeActivity.attacking) {
      _advanceAttack(deltaTime, toPlayer);
      return;
    }

    _updateFacing(toPlayer);

    if (distance > chaseRange) {
      _setActivity(SlimeActivity.idle);
      animationTime += deltaTime;
      return;
    }

    final stoppingDistance = playerRadius + radius;
    if (distance <= stoppingDistance + 0.5) {
      if (attackCooldownRemaining <= 0) {
        _attackFacesRight = toPlayer.dx > 0;
        _attackHitConsumed = false;
        attackCooldownRemaining = attackCooldown;
        _setActivity(SlimeActivity.attacking);
        _advanceAttack(deltaTime, toPlayer);
      } else {
        _setActivity(SlimeActivity.idle);
        animationTime += deltaTime;
      }
      return;
    }

    _setActivity(SlimeActivity.walking);
    animationTime += deltaTime;
    final travel = math.min(
      baseSpeed * speedMultiplier * deltaTime,
      distance - stoppingDistance,
    );
    if (distance > 0) {
      position = arena.clampCircle(
        position + toPlayer / distance * travel,
        radius,
      );
    }
  }

  void _advanceAttack(double deltaTime, Offset toPlayer) {
    animationTime += deltaTime;
    if (!_attackHitConsumed && animationTime >= attackHitTime) {
      _attackHitPending = true;
      _attackHitConsumed = true;
    }
    if (animationTime >= attackDuration) {
      _setActivity(SlimeActivity.idle);
      _updateFacing(toPlayer);
    }
  }

  /// Returns one strike opportunity per swing, even if the player dodges or
  /// their shared invulnerability window prevents the resulting damage.
  bool consumeAttackHit({
    required Offset playerPosition,
    required double playerRadius,
  }) {
    if (!isActive || !_attackHitPending) {
      return false;
    }
    _attackHitPending = false;
    final toPlayer = playerPosition - position;
    final reach = radius + playerRadius + attackReachPadding;
    if (toPlayer.distanceSquared > reach * reach) {
      return false;
    }
    // A little center tolerance keeps nearly vertical attacks consistent.
    // Running behind a slime during its windup still dodges that swing.
    return _attackFacesRight ? toPlayer.dx >= -2 : toPlayer.dx <= 2;
  }

  SlimeDamageResult takeOrbHit(int damage, double cooldown) {
    if (!isActive || orbHitCooldownRemaining > 0 || damage <= 0) {
      return SlimeDamageResult.none;
    }

    orbHitCooldownRemaining = cooldown;
    return _takeDamage(damage);
  }

  SlimeDamageResult takeProjectileHit(int damage) => _takeDamage(damage);

  SlimeDamageResult _takeDamage(int damage) {
    if (!isActive || !health.takeDamage(damage)) {
      return SlimeDamageResult.none;
    }
    hurtFlashTime = 0.12;
    if (health.isDepleted) {
      lifeState = SlimeLifeState.dying;
      activity = SlimeActivity.idle;
      deathAnimationTime = 0;
      _attackHitPending = false;
      return SlimeDamageResult.defeated;
    }
    return SlimeDamageResult.damaged;
  }

  int get animationFrame {
    final frameCount = switch (activity) {
      SlimeActivity.idle => idleFrameCount,
      SlimeActivity.walking => walkFrameCount,
      SlimeActivity.attacking => attackFrameCount,
    };
    final frame =
        (animationTime *
                (activity == SlimeActivity.attacking
                    ? attackFrameCount / attackDuration
                    : animationFps))
            .floor();
    return activity == SlimeActivity.attacking
        ? math.min(frameCount - 1, frame)
        : frame % frameCount;
  }

  int get deathFrame => math.min(
    deathFrameCount - 1,
    (deathAnimationTime / deathDuration * deathFrameCount).floor(),
  );

  void _setActivity(SlimeActivity next) {
    if (activity != next) {
      activity = next;
      animationTime = 0;
    }
  }

  void _updateFacing(Offset direction) {
    if (direction.distanceSquared < 0.0001) {
      return;
    }
    if (direction.dx.abs() > 0.001) {
      _facesRight = direction.dx > 0;
    }
    if (direction.dx.abs() > direction.dy.abs()) {
      facing = direction.dx < 0 ? SlimeFacing.west : SlimeFacing.east;
    } else {
      facing = direction.dy < 0 ? SlimeFacing.north : SlimeFacing.south;
    }
  }
}
