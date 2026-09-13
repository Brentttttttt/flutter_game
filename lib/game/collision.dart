import 'dart:ui';
import 'dart:math' as math;

/// Swept collision prevents a fast projectile skipping a small enemy.
double? segmentCircleHitTime(
  Offset start,
  Offset end,
  Offset center,
  double radius,
) {
  final relative = start - center;
  final c = relative.distanceSquared - radius * radius;
  if (c <= 0) return 0;
  final direction = end - start;
  final a = direction.distanceSquared;
  if (a < 0.000001) return null;
  final b = 2 * (relative.dx * direction.dx + relative.dy * direction.dy);
  final discriminant = b * b - 4 * a * c;
  if (discriminant < 0) return null;
  final time = (-b - math.sqrt(discriminant)) / (2 * a);
  return time >= 0 && time <= 1 ? time : null;
}

/// Keeps a circular hitbox fully inside [bounds].
Offset clampCircleToRect(Offset center, double radius, Rect bounds) {
  return Offset(
    center.dx.clamp(bounds.left + radius, bounds.right - radius).toDouble(),
    center.dy.clamp(bounds.top + radius, bounds.bottom - radius).toDouble(),
  );
}

bool circlesOverlap(
  Offset firstCenter,
  double firstRadius,
  Offset secondCenter,
  double secondRadius,
) {
  final combinedRadius = firstRadius + secondRadius;
  return (firstCenter - secondCenter).distanceSquared <
      combinedRadius * combinedRadius;
}

bool circlesTouchOrOverlap(
  Offset firstCenter,
  double firstRadius,
  Offset secondCenter,
  double secondRadius,
) {
  final combinedRadius = firstRadius + secondRadius;
  return (firstCenter - secondCenter).distanceSquared <=
      combinedRadius * combinedRadius;
}
