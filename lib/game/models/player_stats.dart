import 'dart:math' as math;

import 'health.dart';

/// Starting values and mobile budgets live together; upgrades modify run stats.
abstract final class GameBalance {
  static const maxHp = 100;
  static const movementSpeed = 170.0;
  static const orbDamage = 10;
  static const orbRotationSpeed = 3.1;
  static const pickupRadius = 92.0;
  static const xpPerSlime = 5;
  static const maximumArcaneOrbs = 6;
  static const maximumEffects = 48;
  static const maximumDamageNumbers = 40;
  static const maximumProjectiles = 32;
  static const levelUpDuration = 1.0;
  static const openingGraceDuration = 30.0;
  static const openingSlimeHealth = 20;
  static const openingSlimeDamage = 6;
}

class PlayerStats {
  final Health health = Health(GameBalance.maxHp);
  double movementSpeed = GameBalance.movementSpeed;
  double orbDamage = GameBalance.orbDamage.toDouble();
  double orbRotationSpeed = GameBalance.orbRotationSpeed;
  double xpPickupRadius = GameBalance.pickupRadius;
  int level = 1;
  int currentXp = 0;
  int arcaneOrbCount = 1;
  final FireOrbStats fireOrb = FireOrbStats();

  int get maxHp => health.maxHealth;
  int get currentHp => health.currentHealth;
  int get roundedOrbDamage => orbDamage.round();
  int get xpRequired => xpRequiredForLevel(level);
  double get xpRatio => (currentXp / xpRequired).clamp(0.0, 1.0);

  // 10, 15, 22, 31, 42 ... with no finite level table.
  static int xpRequiredForLevel(int level) {
    final step = math.max(0, level - 1);
    return 10 + 4 * step + step * step;
  }

  bool advanceLevelIfReady() {
    if (currentXp < xpRequired) return false;
    currentXp -= xpRequired;
    level++;
    return true;
  }
}

/// A small, independent weapon progression; no evolution tree.
class FireOrbStats {
  static const maximumLevel = 5;
  static const baseDamage = 20;
  static const baseCooldown = 2.6;
  static const targetingRange = 300.0;
  static const projectileSpeed = 260.0;
  static const projectileRange = 400.0;
  static const projectileLifetime = 2.0;
  static const projectileRadius = 7.0;

  int level = 0;
  bool get isOwned => level > 0;
  bool get canUpgrade => level < maximumLevel;
  int get damage => baseDamage + (level >= 2 ? 4 : 0) + (level >= 5 ? 8 : 0);
  double get cooldown => baseCooldown * (level >= 3 ? 0.85 : 1);
  int get pierce => level >= 4 ? 1 : 0;
  void upgrade() {
    if (canUpgrade) level++;
  }
}
