import 'dart:ui';

/// Presentation sizes only; combat radii and weapon statistics live in models.
abstract final class VfxLayout {
  static const double arcaneImpactSize = 96;
  static const double fireProjectileSize = 96;
  static const double fireExplosionSize = 104;
  static const double levelUpSize = 192;

  // The 128px source has its ground arc at y118–121 and wings at y70–106.
  // Align that ground origin with the 64px Kitty sprite's feet (source y60),
  // rather than aligning the transparent frame's center with the player.
  static const Offset _levelUpSourceOrigin = Offset(64, 120);
  static const Offset _playerFeetFromCenter = Offset(0, 28);

  static Rect levelUpBounds(Offset playerCenter) {
    final feet = playerCenter + _playerFeetFromCenter;
    final topLeft = feet - _levelUpSourceOrigin * (levelUpSize / 128);
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, levelUpSize, levelUpSize);
  }
}
