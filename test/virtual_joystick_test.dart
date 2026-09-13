import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visualKey = Key('movement_joystick_visual');

  Future<void> mount(
    WidgetTester tester,
    ValueChanged<Offset> onChanged,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VirtualJoystick(onChanged: onChanged)),
      ),
    );
  }

  testWidgets('hidden until touch, then appears at each new touch origin', (
    tester,
  ) async {
    var direction = Offset.zero;
    await mount(tester, (value) => direction = value);
    expect(find.byKey(visualKey), findsNothing);
    expect(tester.getSize(find.byType(VirtualJoystick)), const Size(800, 600));

    for (final origin in [const Offset(115, 300), const Offset(630, 175)]) {
      final gesture = await tester.startGesture(origin);
      await tester.pump();
      expect(find.byKey(visualKey), findsOneWidget);
      expect(tester.getCenter(find.byKey(visualKey)), origin);
      expect(direction, Offset.zero);

      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(tester.getCenter(find.byKey(visualKey)), origin);
      expect(direction.dx, closeTo(1, 0.000001));

      await gesture.up();
      // Movement stops in the pointer callback, without waiting for a frame.
      expect(direction, Offset.zero);
      await tester.pump();
      expect(find.byKey(visualKey), findsNothing);
    }
  });

  testWidgets('deadzone and analog strength preserve all eight directions', (
    tester,
  ) async {
    var direction = Offset.zero;
    await mount(tester, (value) => direction = value);
    const origin = Offset(350, 300);
    final gesture = await tester.startGesture(origin);

    await gesture.moveTo(origin + const Offset(3, 4));
    expect(direction, Offset.zero);
    await gesture.moveTo(origin + const Offset(7, 0));
    expect(direction, Offset.zero);
    await gesture.moveTo(origin + const Offset(21.5, 0));
    expect(direction.dx, closeTo(0.5, 0.000001));
    expect(direction.dy, 0);

    for (var step = 0; step < 8; step++) {
      final angle = step * math.pi / 4;
      final expected = Offset(math.cos(angle), math.sin(angle));
      await gesture.moveTo(origin + expected * 150);
      expect(direction.dx, closeTo(expected.dx, 0.000001));
      expect(direction.dy, closeTo(expected.dy, 0.000001));
      expect(direction.distance, closeTo(1, 0.000001));
    }

    await gesture.moveTo(origin);
    expect(direction, Offset.zero);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(visualKey), findsNothing);
  });

  testWidgets('ignores secondary pointers including their release', (
    tester,
  ) async {
    var direction = Offset.zero;
    await mount(tester, (value) => direction = value);
    const origin = Offset(200, 300);
    final owner = await tester.startGesture(origin, pointer: 1);
    await owner.moveBy(const Offset(100, 0));
    final second = await tester.startGesture(
      const Offset(650, 400),
      pointer: 2,
    );
    await second.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(direction, const Offset(1, 0));
    expect(tester.getCenter(find.byKey(visualKey)), origin);

    await second.up();
    expect(direction, const Offset(1, 0));
    await tester.pump();
    expect(find.byKey(visualKey), findsOneWidget);

    await owner.up();
    expect(direction, Offset.zero);
    await tester.pump();
    expect(find.byKey(visualKey), findsNothing);
  });

  testWidgets('does not adopt a held second finger after owner releases', (
    tester,
  ) async {
    var direction = Offset.zero;
    await mount(tester, (value) => direction = value);
    final owner = await tester.startGesture(const Offset(200, 300), pointer: 1);
    final second = await tester.startGesture(
      const Offset(650, 400),
      pointer: 2,
    );
    await owner.moveBy(const Offset(100, 0));
    await owner.up();
    await second.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(direction, Offset.zero);
    expect(find.byKey(visualKey), findsNothing);

    final fresh = await tester.startGesture(const Offset(400, 350), pointer: 3);
    await fresh.moveBy(const Offset(0, -100));
    await second.up();
    expect(direction, const Offset(0, -1));
    await fresh.up();
    await tester.pump();
    expect(direction, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pointer cancel immediately stops movement and hides controls', (
    tester,
  ) async {
    var direction = Offset.zero;
    await mount(tester, (value) => direction = value);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(0, 100));
    expect(direction, const Offset(0, 1));
    await gesture.cancel();
    expect(direction, Offset.zero);
    await tester.pump();
    expect(find.byKey(visualKey), findsNothing);
  });

  testWidgets('origin uses gameplay local coordinates inside a screen inset', (
    tester,
  ) async {
    var direction = Offset.zero;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(left: 30, top: 45),
            child: VirtualJoystick(onChanged: (value) => direction = value),
          ),
        ),
      ),
    );
    const screenTouch = Offset(170, 220);
    final gesture = await tester.startGesture(screenTouch);
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(tester.getCenter(find.byKey(visualKey)), screenTouch);
    expect(direction, const Offset(-1, 0));
    await gesture.up();
  });
}
