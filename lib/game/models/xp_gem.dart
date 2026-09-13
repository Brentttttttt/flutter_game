import 'dart:math' as math;
import 'dart:ui';

class XpGem {
  XpGem({required this.position, required this.value});
  Offset position;
  final int value;
  bool isAttracted = false;
  double animationTime = 0;
  double _speed = 90;
  int get animationFrame => (animationTime * 8).floor() % 4;

  /// Attraction latches, so moving away never strands an already drawn-in gem.
  bool update(double dt, Offset playerPosition, double pickupRadius) {
    animationTime += dt;
    final delta = playerPosition - position;
    final distance = delta.distance;
    if (distance <= pickupRadius) isAttracted = true;
    if (!isAttracted) return false;
    if (distance <= 20) return true;
    _speed = math.min(
      480,
      _speed + dt * (220 + 240 * (1 - (distance / pickupRadius).clamp(0, 1))),
    );
    final travel = _speed * dt;
    if (travel >= distance - 16) return true;
    position += delta / distance * travel;
    return false;
  }
}
