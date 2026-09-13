import 'dart:ui';
import 'dart:math' as math;

import 'player_stats.dart';

class FireProjectile {
  FireProjectile({
    required this.position,
    required this.direction,
    required this.damage,
    required int pierce,
  }) : previousPosition = position,
       hitsRemaining = pierce + 1;
  Offset position;
  Offset previousPosition;
  final Offset direction;
  final int damage;
  int hitsRemaining;
  final Set<int> hitEnemyIds = {};
  double age = 0;
  double distanceTravelled = 0;
  int get animationFrame => (age * 12).floor() % 4;
  bool get isFinished =>
      hitsRemaining <= 0 ||
      age >= FireOrbStats.projectileLifetime ||
      distanceTravelled >= FireOrbStats.projectileRange;

  void update(double dt) {
    previousPosition = position;
    if (isFinished || dt <= 0) return;
    final activeTime = math.min(dt, FireOrbStats.projectileLifetime - age);
    final travel = math.min(
      FireOrbStats.projectileSpeed * activeTime,
      FireOrbStats.projectileRange - distanceTravelled,
    );
    position += direction * travel;
    distanceTravelled += travel;
    age += activeTime;
  }
}
