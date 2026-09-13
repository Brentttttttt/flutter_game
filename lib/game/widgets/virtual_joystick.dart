import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({required this.onChanged, super.key});

  final ValueChanged<Offset> onChanged;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  static const double _size = 136;
  static const double _maximumTravel = 36;
  static const double _deadZone = 7;

  Offset _direction = Offset.zero;

  void _updateFromPosition(Offset localPosition) {
    final vector = localPosition - const Offset(_size / 2, _size / 2);
    final distance = vector.distance;
    late final Offset direction;

    if (distance <= _deadZone) {
      direction = Offset.zero;
    } else {
      final strength = ((distance - _deadZone) / (_maximumTravel - _deadZone))
          .clamp(0.0, 1.0)
          .toDouble();
      direction = vector / distance * strength;
    }

    setState(() => _direction = direction);
    widget.onChanged(direction);
  }

  void _release() {
    if (_direction != Offset.zero) {
      setState(() => _direction = Offset.zero);
    }
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Movement joystick',
      child: GestureDetector(
        key: const Key('movement_joystick'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _updateFromPosition(details.localPosition),
        onPanUpdate: (details) => _updateFromPosition(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: SizedBox.square(
          dimension: _size,
          child: CustomPaint(
            painter: _JoystickPainter(knobOffset: _direction * _maximumTravel),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({required this.knobOffset});

  final Offset knobOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final basePaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0x99314736);
    final outlinePaint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xCCDBD66A);
    final knobPaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xE64B2A78);
    final knobHighlightPaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFE8E77D);

    final baseRect = Rect.fromCenter(center: center, width: 104, height: 104);
    canvas.drawPath(_octagon(baseRect, 14), basePaint);
    canvas.drawPath(_octagon(baseRect, 14), outlinePaint);

    final knobCenter = center + knobOffset;
    final knobRect = Rect.fromCenter(center: knobCenter, width: 42, height: 42);
    canvas.drawPath(_octagon(knobRect, 7), knobPaint);
    canvas.drawRect(
      Rect.fromCenter(center: knobCenter, width: 12, height: 12),
      knobHighlightPaint,
    );
  }

  Path _octagon(Rect rect, double cut) {
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left + cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.knobOffset != knobOffset;
  }
}
