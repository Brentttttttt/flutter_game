import 'package:flutter/material.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_screen.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/xp_gem.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_game/game/widgets/upgrade_overlay.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visual = Key('movement_joystick_visual');

  Future<void> mount(
    WidgetTester tester,
    GameWorld world, {
    VoidCallback? onMainMenu,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late GameAssets assets;
    await tester.runAsync(() async => assets = await GameAssets.load());
    addTearDown(assets.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'friendlyscribbles'),
        home: GameScreen(
          assets: assets,
          palette: PlayerPalette.color1,
          initialWorld: world,
          onMainMenu: onMainMenu ?? () {},
        ),
      ),
    );
  }

  testWidgets('moving camera does not move the held joystick origin', (
    tester,
  ) async {
    final world = GameWorld(spawningEnabled: false);
    await mount(tester, world);
    const origin = Offset(235, 360);
    final gesture = await tester.startGesture(origin);
    await gesture.moveBy(const Offset(100, -100));
    final playerBefore = world.player.position;
    final cameraBefore = world.camera.position;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(world.player.position, isNot(playerBefore));
    expect(world.camera.position, isNot(cameraBefore));
    expect(world.player.movementInput.distance, closeTo(1, 0.000001));
    expect(tester.getCenter(find.byKey(visual)), origin);

    await gesture.up();
    expect(world.player.movementInput, Offset.zero);
    final stoppedAt = world.player.position;
    await tester.pump(const Duration(milliseconds: 50));
    expect(world.player.position, stoppedAt);
    expect(find.byKey(visual), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'level-up resets held input and upgrade touches never move kitty',
    (tester) async {
      final world = GameWorld(spawningEnabled: false);
      await mount(tester, world);
      final held = await tester.startGesture(
        const Offset(120, 560),
        pointer: 1,
      );
      await held.moveBy(const Offset(60, 0));
      expect(world.player.movementInput, const Offset(1, 0));
      world.xpGems.add(
        XpGem(
          position: world.player.position,
          value: world.player.stats.xpRequired,
        ),
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(world.isChoosingUpgrade, isTrue);
      expect(world.player.movementInput, Offset.zero);
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(find.byKey(visual), findsNothing);

      // The original finger remains held across removal and replacement of the
      // input layer. It must never take ownership of the new run input layer.
      await held.moveBy(const Offset(40, 0));
      final choice = world.upgradeChoices.first;
      final card = find.byKey(ValueKey('upgrade_card_${choice.id.name}'));
      final tap = await tester.startGesture(tester.getCenter(card), pointer: 2);
      await tester.pump();
      expect(world.player.movementInput, Offset.zero);
      expect(find.byKey(visual), findsNothing);
      await tap.up();
      await tester.pump();
      expect(find.byType(UpgradeOverlay), findsNothing);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(find.byKey(visual), findsNothing);
      await held.moveBy(const Offset(40, 0));
      expect(world.player.movementInput, Offset.zero);
      await held.up();

      final fresh = await tester.startGesture(
        const Offset(280, 330),
        pointer: 3,
      );
      await fresh.moveBy(const Offset(0, 65));
      expect(world.player.movementInput, const Offset(0, 1));
      await fresh.up();
      expect(world.player.movementInput, Offset.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('backgrounding clears held input until a fresh resumed touch', (
    tester,
  ) async {
    final world = GameWorld(spawningEnabled: false);
    await mount(tester, world);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    final held = await tester.startGesture(const Offset(120, 450), pointer: 1);
    await held.moveBy(const Offset(65, 0));
    expect(world.player.movementInput, const Offset(1, 0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(world.player.movementInput, Offset.zero);
    await tester.pump();
    expect(find.byKey(visual), findsNothing);
    expect(find.byType(VirtualJoystick), findsNothing);
    final pausedTime = world.survivalTime;
    await tester.pump(const Duration(seconds: 5));
    expect(world.survivalTime, pausedTime);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(find.byKey(visual), findsNothing);
    await held.moveBy(const Offset(45, 0));
    expect(world.player.movementInput, Offset.zero);
    await held.up();
    final fresh = await tester.startGesture(const Offset(230, 500), pointer: 2);
    await fresh.moveBy(const Offset(-65, 0));
    expect(world.player.movementInput, const Offset(-1, 0));
    await fresh.cancel();
    expect(world.player.movementInput, Offset.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'game-over buttons preserve input isolation across retry and menu',
    (tester) async {
      final world = GameWorld(spawningEnabled: false);
      var menuCalls = 0;
      await mount(tester, world, onMainMenu: () => menuCalls++);
      final held = await tester.startGesture(
        const Offset(110, 620),
        pointer: 1,
      );
      await held.moveBy(const Offset(60, 0));
      world.player.health.takeDamage(Player.maxHealth);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.isGameOver, isTrue);
      expect(world.player.movementInput, Offset.zero);
      expect(find.byType(VirtualJoystick), findsNothing);

      final retry = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('retry_button'))),
        pointer: 2,
      );
      await tester.pump();
      expect(find.byKey(visual), findsNothing);
      await retry.up();
      await tester.pump();
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(find.byKey(visual), findsNothing);

      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<GamePainter>()
          .single;
      final restarted = painter.world;
      expect(identical(restarted, world), isFalse);
      expect(restarted.player.movementInput, Offset.zero);
      await held.moveBy(const Offset(40, 0));
      expect(restarted.player.movementInput, Offset.zero);
      await held.up();

      restarted.player.health.takeDamage(Player.maxHealth);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final menu = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('game_over_menu_button'))),
        pointer: 3,
      );
      await tester.pump();
      expect(find.byKey(visual), findsNothing);
      await menu.up();
      await tester.pump();
      expect(menuCalls, 1);
      expect(restarted.player.movementInput, Offset.zero);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
