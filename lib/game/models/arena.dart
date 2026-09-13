import 'dart:ui';

import '../collision.dart';

class Arena {
  const Arena({this.columns = 48, this.rows = 42, this.tileSize = 32});

  final int columns;
  final int rows;
  final double tileSize;

  Size get size => Size(columns * tileSize, rows * tileSize);

  Rect get bounds => Offset.zero & size;

  /// The outer tile ring is a solid wall.
  Rect get walkableBounds => Rect.fromLTRB(
    tileSize,
    tileSize,
    size.width - tileSize,
    size.height - tileSize,
  );

  Offset clampCircle(Offset center, double radius) {
    return clampCircleToRect(center, radius, walkableBounds);
  }
}
