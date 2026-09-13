import 'dart:math' as math;
import 'dart:ui';

import 'arena.dart';

class GameCamera {
  Offset position = Offset.zero;
  Size viewportSize = Size.zero;

  void setViewport(Size size, Arena arena, Offset focus) {
    if (size.isEmpty || size == viewportSize) {
      return;
    }

    viewportSize = size;
    // Recenter after rotation/resizing so the player cannot be left outside a
    // newly shaped viewport.
    snapTo(focus, arena);
  }

  void snapTo(Offset focus, Arena arena) {
    if (viewportSize.isEmpty) {
      return;
    }

    position = _desiredPosition(focus, arena);
  }

  void update(double deltaTime, Offset focus, Arena arena) {
    if (viewportSize.isEmpty) {
      return;
    }

    final target = _desiredPosition(focus, arena);
    final smoothing = 1 - math.exp(-9 * deltaTime);
    position = Offset.lerp(position, target, smoothing)!;

    if ((position - target).distanceSquared < 0.01) {
      position = target;
    }
    position = _clampPosition(position, arena);
  }

  Offset _desiredPosition(Offset focus, Arena arena) {
    final centered =
        focus - Offset(viewportSize.width / 2, viewportSize.height / 2);
    return _clampPosition(centered, arena);
  }

  Offset _clampPosition(Offset value, Arena arena) {
    final maxX = math.max(0.0, arena.size.width - viewportSize.width);
    final maxY = math.max(0.0, arena.size.height - viewportSize.height);
    return Offset(
      value.dx.clamp(0.0, maxX).toDouble(),
      value.dy.clamp(0.0, maxY).toDouble(),
    );
  }
}
