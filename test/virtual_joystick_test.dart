import 'package:flutter/material.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('joystick clamps drag strength and resets on release', (
    tester,
  ) async {
    var latestDirection = Offset.zero;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: VirtualJoystick(onChanged: (value) => latestDirection = value),
        ),
      ),
    );

    final joystick = find.byKey(const Key('movement_joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(120, 0));
    await tester.pump();

    expect(latestDirection.dx, closeTo(1, 0.001));
    expect(latestDirection.dy, closeTo(0, 0.001));
    expect(latestDirection.distance, lessThanOrEqualTo(1));

    await gesture.up();
    await tester.pump();
    expect(latestDirection, Offset.zero);
  });
}
