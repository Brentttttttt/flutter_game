import 'dart:math' as math;
import 'dart:ui';

import '../collision.dart';
import 'arena.dart';
import 'health.dart';
import 'slime_enemy.dart';

enum DinoAnimation {
  idle,
  move,
  sitStart,
  sitLoop,
  sitEnd,
  thought,
  attackA,
  attackB,
}

enum DinoActivity {
  arriving,
  chasing,
  preparing,
  attackingA,
  attackingB,
  ability,
  recovering,
  defeated,
  removed,
}

/// Encounter scaling leaves the telegraph and strike animation durations intact.
class DinoTriStats {
  DinoTriStats(int encounterNumber)
    : encounterNumber = math.max(1, encounterNumber);

  final int encounterNumber;
  int get _extraEncounters => encounterNumber - 1;
  int get maxHealth => (1100 * (1 + 0.30 * _extraEncounters)).round();
  int get attackADamage => (18 * (1 + 0.08 * _extraEncounters)).round();
  int get attackBDamage => (28 * (1 + 0.08 * _extraEncounters)).round();
  int get abilityDamage => (22 * (1 + 0.08 * _extraEncounters)).round();
  double get movementSpeed =>
      58 * (1 + math.min(0.30, 0.03 * _extraEncounters));
  double get cooldownMultiplier => math.max(0.65, 1 - 0.03 * _extraEncounters);
}

class DinoTri {
  DinoTri({
    required this.id,
    required this.position,
    required this.encounterNumber,
  }) : stats = DinoTriStats(encounterNumber),
       health = Health(DinoTriStats(encounterNumber).maxHealth);

  // All eight files use wide 384 x 128 frames. The transparent side padding
  // contains the authored spit during attacks; it is not extra empty frames.
  static const sourceSize = Size(384, 128);
  static const renderSize = Size(576, 192);
  static const sourceBodyOrigin = Offset(208, 104);
  static const radius = 38.0;
  static const arrivalDuration = 0.8;
  static const preparationDuration = 0.5;
  static const attackDuration = 1.5;
  static const attackAHitTime = 17 / 20;
  static const attackBHitTime = 20 / 20;
  static const abilityDuration = 2.0;
  static const recoveryDuration = 0.4;
  static const defeatDuration = 1.0;
  static const attackAReach = 110.0;
  static const attackBReach = 236.0;
  static const strikeRadius = 24.0;
  static const frameCounts = <DinoAnimation, int>{
    DinoAnimation.idle: 6,
    DinoAnimation.move: 8,
    DinoAnimation.sitStart: 8,
    DinoAnimation.sitLoop: 5,
    DinoAnimation.sitEnd: 8,
    DinoAnimation.thought: 20,
    DinoAnimation.attackA: 30,
    DinoAnimation.attackB: 30,
  };

  final int id;
  final int encounterNumber;
  final DinoTriStats stats;
  final Health health;
  Offset position;
  DinoActivity activity = DinoActivity.arriving;
  double animationTime = 0;
  double hurtFlashTime = 0;
  double orbHitCooldownRemaining = 0;
  double attackCooldownRemaining = 1.2;
  double rangedCooldownRemaining = 2.7;
  double abilityCooldownRemaining = 6.5;
  int attackSequence = 0;
  final List<DinoHazard> hazards = [];
  final List<_DinoStrike> _pendingStrikes = [];
  DinoActivity _preparedAttack = DinoActivity.attackingA;
  bool _facesRight = true;
  bool _attackFacesRight = true;
  bool _strikeConsumed = false;
  Offset _abilityTarget = Offset.zero;

  bool get isActive =>
      activity != DinoActivity.defeated && activity != DinoActivity.removed;
  bool get isVisible => activity != DinoActivity.removed;
  bool get isEnraged => isActive && health.ratio <= 0.5;
  double get movementSpeed => stats.movementSpeed * (isEnraged ? 1.15 : 1);
  double get cooldownMultiplier =>
      stats.cooldownMultiplier * (isEnraged ? 0.86 : 1);
  double get opacity => activity == DinoActivity.defeated
      ? (1 -
                math.max(0, animationTime - recoveryDuration) /
                    (defeatDuration - recoveryDuration))
            .clamp(0.0, 1.0)
      : 1;

  bool get _facingLocked =>
      activity == DinoActivity.preparing ||
      activity == DinoActivity.attackingA ||
      activity == DinoActivity.attackingB ||
      activity == DinoActivity.ability ||
      activity == DinoActivity.recovering ||
      activity == DinoActivity.defeated;

  // Dino Tri is native RIGHT-facing (the slimes are native LEFT-facing).
  // Keep one fixed body origin for both orientations and all authored poses.
  bool get mirrorHorizontally =>
      !(_facingLocked ? _attackFacesRight : _facesRight);
  DinoAnimation get animation => switch (activity) {
    DinoActivity.arriving => DinoAnimation.idle,
    DinoActivity.chasing => DinoAnimation.move,
    DinoActivity.preparing => DinoAnimation.sitStart,
    DinoActivity.attackingA => DinoAnimation.attackA,
    DinoActivity.attackingB => DinoAnimation.attackB,
    DinoActivity.ability => DinoAnimation.thought,
    DinoActivity.recovering ||
    DinoActivity.defeated ||
    DinoActivity.removed => DinoAnimation.sitEnd,
  };

  int get animationFrame {
    final count = frameCounts[animation]!;
    final duration = switch (activity) {
      DinoActivity.preparing => preparationDuration,
      DinoActivity.attackingA || DinoActivity.attackingB => attackDuration,
      DinoActivity.ability => abilityDuration,
      DinoActivity.recovering ||
      DinoActivity.defeated ||
      DinoActivity.removed => recoveryDuration,
      _ => 0.0,
    };
    return duration > 0
        ? math.min(count - 1, (animationTime / duration * count).floor())
        : (animationTime * 10).floor() % count;
  }

  Rect get sourceRect => Rect.fromLTWH(
    animationFrame * sourceSize.width,
    0,
    sourceSize.width,
    sourceSize.height,
  );
  Rect get destinationRect => Rect.fromLTWH(
    -sourceBodyOrigin.dx * 1.5,
    -sourceBodyOrigin.dy * 1.5,
    renderSize.width,
    renderSize.height,
  );

  /// A directional floor warning; the target direction locks at windup start.
  ({Offset start, Offset end, double radius, bool strong})?
  get attackTelegraph {
    final attack = activity == DinoActivity.preparing
        ? _preparedAttack
        : activity;
    final strong = attack == DinoActivity.attackingB;
    if (attack != DinoActivity.attackingA && !strong) return null;
    if (activity != DinoActivity.preparing && _strikeConsumed) return null;
    final direction = _attackFacesRight ? 1.0 : -1.0;
    return (
      start: position + Offset(direction * radius, 8),
      end:
          position +
          Offset(direction * (strong ? attackBReach : attackAReach), 8),
      radius: strikeRadius,
      strong: strong,
    );
  }

  void update(
    double deltaTime, {
    required Offset playerPosition,
    required double playerRadius,
    required Arena arena,
  }) {
    _pendingStrikes.clear();
    for (final hazard in hazards) {
      hazard.clearStrike();
    }
    if (!deltaTime.isFinite || deltaTime <= 0) return;
    // Small steps preserve each strike crossing even during a slow render frame.
    var remaining = deltaTime;
    while (remaining > 0.000001) {
      final dt = math.min(remaining, 0.05);
      _step(dt, playerPosition, playerRadius, arena);
      remaining -= dt;
    }
  }

  void _step(
    double dt,
    Offset playerPosition,
    double playerRadius,
    Arena arena,
  ) {
    hurtFlashTime = math.max(0, hurtFlashTime - dt);
    orbHitCooldownRemaining = math.max(0, orbHitCooldownRemaining - dt);
    attackCooldownRemaining = math.max(0, attackCooldownRemaining - dt);
    rangedCooldownRemaining = math.max(0, rangedCooldownRemaining - dt);
    abilityCooldownRemaining = math.max(0, abilityCooldownRemaining - dt);
    if (activity == DinoActivity.defeated) {
      animationTime += dt;
      if (animationTime >= defeatDuration) activity = DinoActivity.removed;
      return;
    }
    if (!isActive) return;
    for (final hazard in hazards) {
      hazard.update(dt);
    }
    hazards.removeWhere(
      (hazard) => hazard.isFinished && !hazard.hasPendingStrike,
    );
    animationTime += dt;
    switch (activity) {
      case DinoActivity.arriving:
        _updateFacing(playerPosition - position);
        if (animationTime >= arrivalDuration) {
          _setActivity(DinoActivity.chasing);
        }
      case DinoActivity.chasing:
        final toPlayer = playerPosition - position;
        final distance = toPlayer.distance;
        _updateFacing(toPlayer);
        if (abilityCooldownRemaining <= 0 && distance <= 380) {
          _startAttack(DinoActivity.ability, playerPosition, arena);
        } else if (attackCooldownRemaining <= 0 && distance <= 96) {
          _startAttack(DinoActivity.attackingA, playerPosition, arena);
        } else if (rangedCooldownRemaining <= 0 && distance <= 300) {
          _startAttack(DinoActivity.attackingB, playerPosition, arena);
        } else {
          final stoppingDistance = radius + playerRadius + 12;
          final travel = math.min(
            movementSpeed * dt,
            math.max(0.0, distance - stoppingDistance),
          );
          if (distance > 0) {
            position = arena.clampCircle(
              position + toPlayer / distance * travel,
              radius,
            );
          }
        }
      case DinoActivity.preparing:
        if (animationTime >= preparationDuration) {
          _setActivity(_preparedAttack);
          if (_preparedAttack == DinoActivity.ability) {
            hazards.add(
              DinoHazard(position: _abilityTarget, damage: stats.abilityDamage),
            );
          }
        }
      case DinoActivity.attackingA:
      case DinoActivity.attackingB:
        final strong = activity == DinoActivity.attackingB;
        final hitTime = strong ? attackBHitTime : attackAHitTime;
        if (!_strikeConsumed && animationTime >= hitTime) {
          _strikeConsumed = true;
          final direction = _attackFacesRight ? 1.0 : -1.0;
          _pendingStrikes.add(
            _DinoStrike(
              position + Offset(direction * radius, 8),
              position +
                  Offset(direction * (strong ? attackBReach : attackAReach), 8),
              strong ? stats.attackBDamage : stats.attackADamage,
            ),
          );
        }
        if (animationTime >= attackDuration) {
          _setActivity(DinoActivity.recovering);
        }
      case DinoActivity.ability:
        if (animationTime >= abilityDuration) {
          _setActivity(DinoActivity.recovering);
        }
      case DinoActivity.recovering:
        if (animationTime >= recoveryDuration) {
          _setActivity(DinoActivity.chasing);
        }
      case DinoActivity.defeated:
      case DinoActivity.removed:
        break;
    }
  }

  void _startAttack(DinoActivity next, Offset target, Arena arena) {
    _preparedAttack = next;
    _attackFacesRight = target.dx >= position.dx;
    _strikeConsumed = false;
    _abilityTarget = arena.clampCircle(target, DinoHazard.radius);
    attackCooldownRemaining = 3.2 * cooldownMultiplier;
    if (next == DinoActivity.attackingB) {
      rangedCooldownRemaining = 6.5 * cooldownMultiplier;
    }
    if (next == DinoActivity.ability) {
      abilityCooldownRemaining = 10 * cooldownMultiplier;
    }
    attackSequence++;
    _setActivity(DinoActivity.preparing);
  }

  /// One damage opportunity at the authored strike/release frame, or at a
  /// targeted splash's detonation. Moving sideways or behind dodges the spit.
  int consumeAttackHit({
    required Offset playerPosition,
    required double playerRadius,
  }) {
    if (!isActive) return 0;
    var damage = 0;
    for (final strike in _pendingStrikes) {
      if (segmentCircleHitTime(
            strike.start,
            strike.end,
            playerPosition,
            strikeRadius + playerRadius,
          ) !=
          null) {
        damage = math.max(damage, strike.damage);
      }
    }
    _pendingStrikes.clear();
    for (final hazard in hazards) {
      damage = math.max(
        damage,
        hazard.consumeAttackHit(playerPosition, playerRadius),
      );
    }
    return damage;
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
    if (!isActive || !health.takeDamage(damage)) return SlimeDamageResult.none;
    hurtFlashTime = 0.12;
    if (health.isDepleted) {
      _attackFacesRight = !mirrorHorizontally;
      _setActivity(DinoActivity.defeated);
      hazards.clear();
      _pendingStrikes.clear();
      return SlimeDamageResult.defeated;
    }
    return SlimeDamageResult.damaged;
  }

  void _setActivity(DinoActivity next) {
    activity = next;
    animationTime = 0;
  }

  void _updateFacing(Offset direction) {
    if (direction.dx.abs() > 0.001) _facesRight = direction.dx > 0;
  }
}

class _DinoStrike {
  const _DinoStrike(this.start, this.end, this.damage);
  final Offset start;
  final Offset end;
  final int damage;
}

/// Thought captures the player's world position once. Its floor marker gives
/// ample time to leave before the actual authored green splash appears.
class DinoHazard {
  DinoHazard({required this.position, required this.damage});
  static const radius = 56.0;
  static const warningDuration = 1.2;
  static const effectDuration = 0.6;
  final Offset position;
  final int damage;
  double age = 0;
  bool _struck = false;
  bool hasPendingStrike = false;
  bool get isWarning => age < warningDuration;
  bool get isFinished => age >= warningDuration + effectDuration;
  double get progress => (age / warningDuration).clamp(0.0, 1.0);
  int get effectFrame =>
      17 +
      (((age - warningDuration) / effectDuration).clamp(0.0, 0.999) * 10)
          .floor();

  void update(double dt) {
    age += dt;
    if (!_struck && age >= warningDuration) {
      hasPendingStrike = true;
      _struck = true;
    }
  }

  void clearStrike() => hasPendingStrike = false;

  int consumeAttackHit(Offset playerPosition, double playerRadius) {
    if (!hasPendingStrike) return 0;
    hasPendingStrike = false;
    return circlesTouchOrOverlap(position, radius, playerPosition, playerRadius)
        ? damage
        : 0;
  }
}
