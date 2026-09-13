import 'dart:ui';

import 'health.dart';
import 'player_stats.dart';

enum PlayerPalette { color1, color2 }

enum PlayerFacing { down, up, left, right }

class Player {
  Player({required this.position, this.palette = PlayerPalette.color1});

  static const double speed = GameBalance.movementSpeed;
  static const int maxHealth = GameBalance.maxHp;
  static const double damageInvulnerability = 0.75;
  // Covers the visible 64px sprite closely enough that Witch Kitty never
  // appears to pass through the perimeter wall.
  static const double radius = 30;

  Offset position;
  Offset movementInput = Offset.zero;
  PlayerPalette palette;
  final PlayerStats stats = PlayerStats();
  Health get health => stats.health;
  PlayerFacing facing = PlayerFacing.down;
  double walkAnimationTime = 0;
  double idleAnimationTime = 0;
  double invulnerabilityRemaining = 0;
  double damageFlashTime = 0;

  bool get isMoving => movementInput.distanceSquared > 0.0001;
  bool get isDead => health.isDepleted;

  void setMovementInput(Offset input) {
    movementInput = input.distanceSquared > 1 ? input / input.distance : input;

    if (!isMoving) {
      return;
    }

    if (movementInput.dx.abs() > movementInput.dy.abs()) {
      facing = movementInput.dx < 0 ? PlayerFacing.left : PlayerFacing.right;
    } else {
      facing = movementInput.dy < 0 ? PlayerFacing.up : PlayerFacing.down;
    }
  }

  void updateAnimation(double deltaTime) {
    if (isMoving) {
      walkAnimationTime += deltaTime;
      idleAnimationTime = 0;
    } else {
      idleAnimationTime += deltaTime;
    }
  }

  void update(double deltaTime) {
    updateAnimation(deltaTime);
    invulnerabilityRemaining = (invulnerabilityRemaining - deltaTime)
        .clamp(0.0, double.infinity)
        .toDouble();
    damageFlashTime = (damageFlashTime - deltaTime)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  bool takeDamage(int amount) {
    if (isDead || invulnerabilityRemaining > 0) {
      return false;
    }

    if (!health.takeDamage(amount)) {
      return false;
    }

    invulnerabilityRemaining = damageInvulnerability;
    damageFlashTime = 0.14;
    return true;
  }

  int get walkFrame => (walkAnimationTime * 8).floor() % 4;

  int get walkRow => switch (facing) {
    PlayerFacing.down => 0,
    PlayerFacing.up => 1,
    PlayerFacing.left => 2,
    PlayerFacing.right => 3,
  };

  int idleFrame(int frameCount) {
    return (idleAnimationTime * 6).floor() % frameCount;
  }
}
