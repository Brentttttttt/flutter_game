import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_screen.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/magic_orb.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_game/game/widgets/game_over_overlay.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_game/menu/main_menu.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = ValueKey('visual_review_capture');

void main() {
  testWidgets(
    'capture real artwork and verify XP to upgrade to death to retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late GameAssets assets;
      await tester.runAsync(() async {
        assets = await GameAssets.load();
        await (FontLoader('friendlyscribbles')
              ..addFont(rootBundle.load('assets/font/friendlyscribbles.ttf')))
            .load();
      });
      addTearDown(assets.dispose);

      await tester.pumpWidget(_host(MainMenu(assets: assets, onPlay: () {})));
      await tester.pump();
      await _capture(tester, '01_main_menu');
      expect(tester.takeException(), isNull);

      final world = GameWorld(spawningEnabled: false, random: Random(7));
      final orbPosition = world.orb.positionAround(world.player.position);
      world.spawnSlimeAt(
        orbPosition + const Offset(-12, 0),
        maxHealth: 10,
        spawnDelay: 0,
      );
      world.spawnSlimeAt(
        orbPosition + const Offset(12, 0),
        maxHealth: 10,
        spawnDelay: 0,
      );
      await tester.pumpWidget(
        _host(
          GameScreen(
            assets: assets,
            palette: PlayerPalette.color1,
            initialWorld: world,
            onMainMenu: () {},
          ),
        ),
      );
      await _capture(tester, '02_gameplay_hud');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(world.defeatedEnemies, 2);
      expect(world.xpGems, hasLength(2));
      expect(world.effects, isNotEmpty);
      expect(world.damageNumbers, isNotEmpty);
      await _capture(tester, '03_gems_and_orb_impact');

      for (var frame = 0; frame < 30 && world.isPlaying; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(world.runState, GameRunState.levelUpEffect);
      expect(world.player.stats.level, 2);
      expect(world.xpGems, isEmpty);
      final frozenTime = world.survivalTime;
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _capture(tester, '04_level_up_animation');
      for (var frame = 0; frame < 24 && !world.isChoosingUpgrade; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(world.isChoosingUpgrade, isTrue);
      expect(world.upgradeChoices, hasLength(3));
      final overlayContext = tester.element(
        find.byKey(const Key('upgrade_overlay')),
      );
      await tester.runAsync(() async {
        for (final upgrade in world.upgradeChoices) {
          await precacheImage(AssetImage(upgrade.iconPath), overlayContext);
        }
      });
      await tester.pump();
      await _capture(tester, '05_upgrade_selection');
      await tester.pump(const Duration(seconds: 30));
      expect(world.survivalTime, frozenTime);
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(tester.takeException(), isNull);

      final choice = world.upgradeChoices.singleWhere(
        (choice) => choice.id == UpgradeId.fireOrb,
      );
      await tester.tap(find.byKey(ValueKey('upgrade_card_${choice.id.name}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(world.isPlaying, isTrue);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(world.player.stats.fireOrb.isOwned, isTrue);
      world.player.stats.orbRotationSpeed = 0;
      final fireOrb = world.orbs.singleWhere((orb) => orb.kind == OrbKind.fire);
      world.spawnSlimeAt(
        fireOrb.positionAround(world.player.position) + const Offset(120, 0),
        maxHealth: 100,
        spawnDelay: 0,
      );
      for (var frame = 0; frame < 7; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(world.projectiles, isNotEmpty);
      await _capture(tester, '09_fire_orb_projectile');
      world.player.health.takeDamage(world.player.health.maxHealth);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(GameOverOverlay), findsOneWidget);
      await _capture(tester, '06_game_over');
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pump();
      expect(find.byType(GameOverOverlay), findsNothing);
      expect(find.text('LV 1'), findsOneWidget);
      expect(find.text('XP  0 / 10'), findsOneWidget);
      expect(find.text('SLIMES  0'), findsOneWidget);
      expect(find.textContaining('100 / 100'), findsOneWidget);
      final freshPainter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<GamePainter>()
          .single;
      final fresh = freshPainter.world;
      expect(fresh, isNot(same(world)));
      expect(fresh.player.stats.level, 1);
      expect(fresh.player.stats.currentXp, 0);
      expect(fresh.player.stats.arcaneOrbCount, 1);
      expect(fresh.player.stats.fireOrb.isOwned, isFalse);
      expect(fresh.orbs, hasLength(1));
      expect(fresh.xpGems, isEmpty);
      expect(fresh.effects, isEmpty);
      expect(fresh.damageNumbers, isEmpty);
      expect(fresh.projectiles, isEmpty);
      expect(fresh.upgradeChoices, isEmpty);
      expect(fresh.enemies, isEmpty);
      await _capture(tester, '07_clean_retry');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      await _captureSlimeDirections(tester, assets);
    },
  );
}

Widget _host(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'friendlyscribbles',
  ),
  home: RepaintBoundary(key: _captureKey, child: child),
);

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    await _writeImage(image, name);
    image.dispose();
  });
}

Future<void> _writeImage(ui.Image image, String name) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final directory = await Directory(
    'build/verification',
  ).create(recursive: true);
  await File(
    '${directory.path}/$name.png',
  ).writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> _captureSlimeDirections(
  WidgetTester tester,
  GameAssets assets,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const viewSize = Size(320, 250);
  final repaint = ValueNotifier(0);
  for (var index = 0; index < 2; index++) {
    final world = GameWorld(
      spawningEnabled: false,
      playerPosition: const Offset(400, 400),
    );
    world.setViewport(viewSize);
    final slime = world.spawnSlimeAt(
      world.player.position + Offset(index == 0 ? 46 : -46, 0),
      spawnDelay: 0,
    );
    slime.update(
      0.401,
      playerPosition: world.player.position,
      playerRadius: Player.radius,
      arena: world.arena,
    );
    expect(slime.animationFrame, 4);
    expect(slime.mirrorAttackHorizontally, index == 1);
    canvas.save();
    canvas.translate(index * 320.0, 44);
    canvas.clipRect(Offset.zero & viewSize);
    GamePainter(
      world: world,
      assets: assets,
      repaint: repaint,
    ).paint(canvas, viewSize);
    canvas.restore();
    final label = TextPainter(
      text: TextSpan(
        text: index == 0 ? 'LEFT / ORIGINAL' : 'RIGHT / MIRRORED',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontFamily: 'friendlyscribbles',
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300);
    label.paint(canvas, Offset(index * 320.0 + 16, 10));
    label.dispose();
  }
  final picture = recorder.endRecording();
  await tester.runAsync(() async {
    final image = await picture.toImage(640, 294);
    await _writeImage(image, '08_slime_attack_left_and_right');
    image.dispose();
  });
  picture.dispose();
  repaint.dispose();
}
