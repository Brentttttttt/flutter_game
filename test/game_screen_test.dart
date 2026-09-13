import 'package:flutter/material.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_screen.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/widgets/game_over_overlay.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launches menu, requires color choice, then starts gameplay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const WitchKittyApp());
    await _waitFor(tester, find.byKey(const Key('play_button')));

    expect(find.byKey(const Key('exit_button')), findsOneWidget);
    expect(find.byType(VirtualJoystick), findsNothing);

    await tester.tap(find.byKey(const Key('play_button')));
    await tester.pump();
    expect(find.byKey(const Key('color_1_choice')), findsOneWidget);
    expect(find.byKey(const Key('color_2_choice')), findsOneWidget);
    expect(find.byType(VirtualJoystick), findsNothing);

    await tester.tap(find.byKey(const Key('color_2_choice')));
    await tester.pump();
    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).palette,
      PlayerPalette.color2,
    );
    expect(find.byKey(const Key('player_hp_text')), findsOneWidget);
    expect(find.byKey(const Key('survival_time_text')), findsOneWidget);
    expect(find.byKey(const Key('kill_count_text')), findsOneWidget);
    expect(find.byKey(const Key('color_1_choice')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(780, 390));
    await tester.pump();
    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('game over retry creates a fresh run without another ticker', (
    tester,
  ) async {
    final assets = await _loadAssets(tester);
    addTearDown(assets.dispose);
    final world = GameWorld(
      palette: PlayerPalette.color2,
      playerPosition: const Offset(400, 400),
      spawningEnabled: false,
    );
    world.player.health.takeDamage(90);
    world.spawnSlimeAt(const Offset(446, 400), maxHealth: 999, spawnDelay: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          assets: assets,
          palette: PlayerPalette.color2,
          initialWorld: world,
          onMainMenu: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    for (var step = 0; step < 22; step++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byType(GameOverOverlay), findsOneWidget);
    expect(find.byType(VirtualJoystick), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('player_health_bar'))).width,
      greaterThan(100),
    );

    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pump();
    expect(find.byType(GameOverOverlay), findsNothing);
    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(find.textContaining('100 / 100'), findsOneWidget);
    expect(find.text('TIME  00:00'), findsOneWidget);
    expect(find.text('SLIMES  0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('game over main-menu button invokes its single callback', (
    tester,
  ) async {
    final assets = await _loadAssets(tester);
    addTearDown(assets.dispose);
    final world = GameWorld(spawningEnabled: false);
    world.player.health.takeDamage(Player.maxHealth);
    world.update(0.01);
    var menuCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          assets: assets,
          palette: PlayerPalette.color1,
          initialWorld: world,
          onMainMenu: () => menuCalls++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GameOverOverlay), findsOneWidget);

    await tester.tap(find.byKey(const Key('game_over_menu_button')));
    await tester.pump();
    expect(menuCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Expected widget did not appear: $finder');
}

Future<GameAssets> _loadAssets(WidgetTester tester) async {
  late GameAssets assets;
  await tester.runAsync(() async {
    assets = await GameAssets.load();
  });
  return assets;
}
