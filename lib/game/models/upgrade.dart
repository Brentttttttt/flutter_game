import 'player_stats.dart';

enum UpgradeId {
  vitality,
  swiftPaws,
  arcanePower,
  orbHaste,
  magnetism,
  arcaneOrb,
  fireOrb,
}

class UpgradeDefinition {
  const UpgradeDefinition(this.id, this.title, this.description, String icon)
    : iconPath = 'assets/upgrade-icons/16x16/$icon.png';

  final UpgradeId id;
  final String title;
  final String description;
  final String iconPath;

  static List<UpgradeDefinition> availableFor(PlayerStats stats) => [
    const UpgradeDefinition(
      UpgradeId.vitality,
      'VITALITY',
      '+20 Max HP\nRestore 10 HP',
      'potion_01a',
    ),
    const UpgradeDefinition(
      UpgradeId.swiftPaws,
      'SWIFT PAWS',
      '+8% Movement Speed',
      'boots_01c',
    ),
    const UpgradeDefinition(
      UpgradeId.arcanePower,
      'ARCANE POWER',
      '+15% Orb Damage',
      'staff_01c',
    ),
    const UpgradeDefinition(
      UpgradeId.orbHaste,
      'ORB HASTE',
      '+12% Orb Rotation Speed',
      'ring_01d',
    ),
    const UpgradeDefinition(
      UpgradeId.magnetism,
      'MAGNETISM',
      '+20% XP Pickup Radius',
      'crystal_01c',
    ),
    if (stats.arcaneOrbCount < GameBalance.maximumArcaneOrbs)
      const UpgradeDefinition(
        UpgradeId.arcaneOrb,
        'ARCANE ORB',
        'Add an orbiting Arcane Orb',
        'gem_01j',
      ),
    if (stats.fireOrb.canUpgrade)
      UpgradeDefinition(
        UpgradeId.fireOrb,
        stats.fireOrb.isOwned
            ? 'FIRE ORB ${stats.fireOrb.level + 1}'
            : 'FIRE ORB',
        switch (stats.fireOrb.level) {
          0 => 'An orbiting orb fires at nearby slimes',
          1 => '+20% Fire Projectile Damage',
          2 => '-15% Fire Attack Cooldown',
          3 => 'Fireballs pierce +1 enemy',
          _ => '+8 Fire Projectile Damage',
        },
        'pearl_01c',
      ),
  ];

  void apply(PlayerStats stats) {
    switch (id) {
      case UpgradeId.vitality:
        stats.health.increaseMaximum(20, restore: 10);
      case UpgradeId.swiftPaws:
        stats.movementSpeed *= 1.08;
      case UpgradeId.arcanePower:
        stats.orbDamage *= 1.15;
      case UpgradeId.orbHaste:
        stats.orbRotationSpeed *= 1.12;
      case UpgradeId.magnetism:
        stats.xpPickupRadius *= 1.2;
      case UpgradeId.arcaneOrb:
        if (stats.arcaneOrbCount < GameBalance.maximumArcaneOrbs) {
          stats.arcaneOrbCount++;
        }
      case UpgradeId.fireOrb:
        stats.fireOrb.upgrade();
    }
  }
}
