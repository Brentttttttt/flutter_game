import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_screen.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/player_stats.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/models/xp_gem.dart';
import 'package:flutter_game/game/widgets/upgrade_overlay.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'XP choice freezes the run across lifecycle and resumes cleanly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late GameAssets assets;
      await tester.runAsync(() async => assets = await GameAssets.load());
      addTearDown(() {
        assets.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      final world = GameWorld(spawningEnabled: false, random: Random(3));
      world.xpGems.add(
        XpGem(
          position: world.player.position,
          value: world.player.stats.xpRequired,
        ),
      );
      world.setMovementInput(const Offset(1, 0));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'friendlyscribbles'),
          home: GameScreen(
            assets: assets,
            palette: PlayerPalette.color1,
            initialWorld: world,
            onMainMenu: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(world.player.stats.level, 2);
      expect(world.runState, GameRunState.levelUpEffect);
      expect(world.xpGems, isEmpty);
      expect(world.player.movementInput, Offset.zero);
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(find.byType(UpgradeOverlay), findsNothing);
      final pausedTime = world.survivalTime;
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(UpgradeOverlay), findsOneWidget);
      expect(world.upgradeChoices, hasLength(3));
      expect(world.survivalTime, pausedTime);
      expect(find.text('LV 2'), findsOneWidget);
      expect(find.byKey(const Key('player_xp_bar')), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 10));
      expect(world.isChoosingUpgrade, isTrue);
      expect(world.survivalTime, pausedTime);

      final choice = world.upgradeChoices.first;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.tap(find.byKey(ValueKey('upgrade_card_${choice.id.name}')));
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(UpgradeOverlay), findsNothing);
      expect(world.isPlaying, isTrue);
      expect(world.upgradeChoices, isEmpty);
      expect(world.survivalTime, pausedTime);
      expect(world.player.movementInput, Offset.zero);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(world.survivalTime, greaterThan(pausedTime));
      expect(world.survivalTime - pausedTime, lessThan(0.1));
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'three upgrade cards fit narrow portrait and scroll in landscape',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final available = UpgradeDefinition.availableFor(PlayerStats());
      final choices = [
        available.firstWhere((upgrade) => upgrade.id == UpgradeId.vitality),
        available.firstWhere((upgrade) => upgrade.id == UpgradeId.arcaneOrb),
        available.firstWhere((upgrade) => upgrade.id == UpgradeId.fireOrb),
      ];
      UpgradeId? selected;
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'friendlyscribbles'),
            home: Scaffold(
              body: UpgradeOverlay(
                level: 2,
                choices: choices,
                onSelected: (id) => selected = id,
              ),
            ),
          ),
        );
        final card = find.byKey(const ValueKey('upgrade_card_fireOrb'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        expect(selected, UpgradeId.fireOrb);
        expect(find.byType(Image), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
