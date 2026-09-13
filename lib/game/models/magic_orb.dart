import 'dart:math' as math;
import 'dart:ui';

import '../collision.dart';
import 'slime_enemy.dart';
import 'player_stats.dart';

enum OrbKind { arcane, fire }

class MagicOrb {
  MagicOrb({this.kind = OrbKind.arcane});
  final OrbKind kind;
  static const double orbitRadius = 58;
  static const double radius = 9;
  static const double renderSize = 24;
  static const double angularSpeed = GameBalance.orbRotationSpeed;
  static const int damage = GameBalance.orbDamage;
  static const double hitCooldown = 0.55;

  static const int atlasColumns = 12;
  static const int atlasFrameSize = 16;
  // The outlined purple orb is one 8-frame sequence on atlas row 5.
  static const int atlasStartIndex = 60;
  static const int animationFrameCount = 8;
  static const double animationFps = 10;

  double angle = -math.pi / 2;
  double animationTime = 0;
  double phaseOffset = 0;

  void update(double deltaTime, {double rotationSpeed = angularSpeed}) {
    angle = (angle + rotationSpeed * deltaTime) % (math.pi * 2);
    animationTime += deltaTime;
  }

  Offset positionAround(Offset playerPosition) {
    return playerPosition +
        Offset(math.cos(angle + phaseOffset), math.sin(angle + phaseOffset)) *
            orbitRadius;
  }

  int get animationFrame {
    return (animationTime * animationFps).floor() %
        (kind == OrbKind.fire ? 5 : animationFrameCount);
  }

  Rect sourceRectForFrame(int frame) {
    final atlasIndex = kind == OrbKind.fire
        ? 47 + (frame % 5)
        : atlasStartIndex + (frame % animationFrameCount);
    return Rect.fromLTWH(
      (atlasIndex % atlasColumns) * atlasFrameSize.toDouble(),
      (atlasIndex ~/ atlasColumns) * atlasFrameSize.toDouble(),
      atlasFrameSize.toDouble(),
      atlasFrameSize.toDouble(),
    );
  }

  SlimeDamageResult tryHit(
    SlimeEnemy enemy,
    Offset playerPosition, {
    int hitDamage = damage,
  }) {
    if (!enemy.isActive || enemy.orbHitCooldownRemaining > 0) {
      return SlimeDamageResult.none;
    }

    if (!circlesOverlap(
      positionAround(playerPosition),
      radius,
      enemy.position,
      SlimeEnemy.radius,
    )) {
      return SlimeDamageResult.none;
    }

    return enemy.takeOrbHit(hitDamage, hitCooldown);
  }
}
