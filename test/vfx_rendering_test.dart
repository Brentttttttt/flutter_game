import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/combat_effect.dart';
import 'package:flutter_game/game/models/magic_orb.dart';
import 'package:flutter_game/game/models/player_stats.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'friendlyscribbles',
    )..addFont(rootBundle.load('assets/font/friendlyscribbles.ttf'))).load();
  });

  test(
    'level-up preserves opaque Kitty pixels and follows world position',
    () async {
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);
      final kittyPixels = await assets.color1Idle.toByteData();
      final panels = <ui.Image>[];
      final crops = <Uint8List>[];
      const viewSize = ui.Size(320, 400);
      const frames = [3, 5, 8];
      for (final location in [
        (player: const ui.Offset(400, 400), camera: const ui.Offset(240, 200)),
        (
          player: const ui.Offset(1168, 784),
          camera: const ui.Offset(1036, 548),
        ),
      ]) {
        final world = GameWorld(
          spawningEnabled: false,
          playerPosition: location.player,
        )..setViewport(viewSize);
        world.camera.position = location.camera;
        final center = world.player.position - world.camera.position;
        final baseline = await _render(world, assets, viewSize);
        final baselinePixels = (await baseline.toByteData())!;
        world.awardXp(world.player.stats.xpRequired);
        expect(world.runState, GameRunState.levelUpEffect);
        for (final frame in frames) {
          world.levelUpEffectTime =
              (frame + 0.1) / 12 * GameBalance.levelUpDuration;
          final image = await _render(world, assets, viewSize);
          panels.add(image);
          final renderedPixels = (await image.toByteData())!;
          var checked = 0;
          for (var y = 0; y < 64; y++) {
            for (var x = 0; x < 64; x++) {
              if (kittyPixels!.getUint8(
                    (y * assets.color1Idle.width + x) * 4 + 3,
                  ) !=
                  255) {
                continue;
              }
              final pixel =
                  ((center.dy.toInt() - 32 + y) * viewSize.width.toInt() +
                      center.dx.toInt() -
                      32 +
                      x) *
                  4;
              expect(
                renderedPixels.getUint32(pixel),
                baselinePixels.getUint32(pixel),
                reason: 'Frame $frame covered Kitty pixel ($x,$y)',
              );
              checked++;
            }
          }
          expect(checked, greaterThan(1000));

          // A player-relative region includes the entire aura. Comparing it at
          // different camera offsets detects accidental screen-space anchoring.
          final crop = Uint8List(200 * 200 * 4);
          var changed = 0;
          for (var y = 0; y < 200; y++) {
            for (var x = 0; x < 200; x++) {
              final source =
                  ((center.dy.toInt() - 156 + y) * viewSize.width.toInt() +
                      center.dx.toInt() -
                      100 +
                      x) *
                  4;
              final different =
                  renderedPixels.getUint32(source) !=
                  baselinePixels.getUint32(source);
              if (different) changed++;
              // Use only changed VFX pixels; floor and player are irrelevant.
              if (different) {
                crop.buffer.asByteData().setUint32(
                  (y * 200 + x) * 4,
                  renderedPixels.getUint32(source),
                );
              }
            }
          }
          expect(changed, greaterThan(400));
          crops.add(crop);
        }
        baseline.dispose();
      }
      await _contactSheet(
        panels,
        [
          for (var location = 0; location < 2; location++)
            for (final frame in frames)
              'POSITION ${location + 1} / FRAME $frame',
        ],
        columns: 3,
        name: '10_level_up_layers_and_world_anchor',
      );
      for (var frameIndex = 0; frameIndex < frames.length; frameIndex++) {
        _expectSamePlayerRelativeAura(
          crops[frameIndex],
          crops[frameIndex + frames.length],
        );
      }
      for (final panel in panels) {
        panel.dispose();
      }
    },
  );

  test(
    'capture real orb hits, animated fire shots, and fire impacts',
    () async {
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);
      const viewSize = ui.Size(400, 280);
      final panels = <ui.Image>[];
      final labels = <String>[];
      final world = GameWorld(
        spawningEnabled: false,
        playerPosition: const ui.Offset(400, 400),
        random: math.Random(7),
      )..setViewport(viewSize);
      world.camera.position = const ui.Offset(272, 260);
      world.player.stats.orbRotationSpeed = 0;
      final slime = world.spawnSlimeAt(
        world.orb.positionAround(world.player.position),
        maxHealth: 999,
        spawnDelay: 0,
      );
      world.update(0.001);
      expect(world.effects.single.kind, CombatEffectKind.arcaneImpact);
      expect(world.damageNumbers, hasLength(1));
      // Inspect early, broad, and dispersing frames from an actual orb hit.
      for (final frame in [1, 3, 6]) {
        world.effects.single.age = (frame + 0.1) / world.effects.single.fps;
        panels.add(await _render(world, assets, viewSize));
        labels.add('ARCANE IMPACT / FRAME $frame');
      }
      world.effects.clear();
      world.damageNumbers.clear();
      world.awardXp(world.player.stats.xpRequired);
      world.update(GameBalance.levelUpDuration);
      expect(world.chooseUpgrade(UpgradeId.fireOrb), isTrue);
      final fireOrb = world.orbs.singleWhere((orb) => orb.kind == OrbKind.fire);
      fireOrb.angle = math.pi;
      slime.position = world.player.position + const ui.Offset(220, 0);
      for (var tick = 0; world.projectiles.isEmpty && tick < 30; tick++) {
        world.update(0.01);
      }
      expect(world.projectiles, hasLength(1));
      for (var sample = 0; sample < 3; sample++) {
        world.update(0.085);
        final frame = world.projectiles.single.animationFrame;
        world.camera.position = const ui.Offset(272, 260);
        panels.add(await _render(world, assets, viewSize));
        labels.add('FIRE PROJECTILE / FRAME $frame');
      }
      for (var tick = 0; world.effects.isEmpty && tick < 100; tick++) {
        world.update(0.01);
      }
      final fireImpact = world.effects.singleWhere(
        (effect) => effect.kind == CombatEffectKind.fireExplosion,
      );
      expect(world.projectiles, isEmpty);
      expect(world.damageNumbers.single.isFire, isTrue);
      for (final frame in [1, 3, 5]) {
        fireImpact.age = (frame + 0.1) / fireImpact.fps;
        world.camera.position = const ui.Offset(272, 260);
        panels.add(await _render(world, assets, viewSize));
        labels.add('FIRE IMPACT / FRAME $frame');
      }
      await _contactSheet(
        panels,
        labels,
        columns: 3,
        name: '11_arcane_and_fire_vfx_sizes',
      );
      for (final panel in panels) {
        panel.dispose();
      }
    },
  );
}

void _expectSamePlayerRelativeAura(Uint8List first, Uint8List second) {
  final firstPixels = first.buffer.asUint32List();
  final secondPixels = second.buffer.asUint32List();
  // Nearest-neighbor sampling at 1.5x may choose either side of an exact pixel
  // boundary after camera translation. Allow one pixel, not an anchor offset.
  for (final pair in [
    (firstPixels, secondPixels),
    (secondPixels, firstPixels),
  ]) {
    var occupied = 0;
    var missing = 0;
    for (var index = 0; index < pair.$1.length; index++) {
      final color = pair.$1[index];
      if (color == 0) continue;
      occupied++;
      final x = index % 200;
      final y = index ~/ 200;
      var found = false;
      for (var dy = -1; dy <= 1 && !found; dy++) {
        for (var dx = -1; dx <= 1 && !found; dx++) {
          final nextX = x + dx;
          final nextY = y + dy;
          if (nextX < 0 || nextX >= 200 || nextY < 0 || nextY >= 200) continue;
          // Compare occupied pixels; translucent parts blend with floor pixels.
          found = pair.$2[nextY * 200 + nextX] != 0;
        }
      }
      if (!found) missing++;
    }
    // Very faint edge pixels can round into the floor color. The visible aura
    // must still occupy the same player-relative pixels in both directions.
    expect(missing / occupied, lessThan(0.02));
  }
}

Future<ui.Image> _render(
  GameWorld world,
  GameAssets assets,
  ui.Size size,
) async {
  final recorder = ui.PictureRecorder();
  final repaint = ValueNotifier(0);
  GamePainter(
    world: world,
    assets: assets,
    repaint: repaint,
  ).paint(ui.Canvas(recorder), size);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  } finally {
    picture.dispose();
    repaint.dispose();
  }
}

Future<void> _contactSheet(
  List<ui.Image> panels,
  List<String> labels, {
  required int columns,
  required String name,
}) async {
  final width = panels.first.width;
  final height = panels.first.height + 32;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xFF231B35), ui.BlendMode.src);
  for (var index = 0; index < panels.length; index++) {
    final origin = ui.Offset(
      (index % columns * width).toDouble(),
      (index ~/ columns * height).toDouble(),
    );
    canvas.drawImage(
      panels[index],
      origin + const ui.Offset(0, 32),
      ui.Paint(),
    );
    final label = TextPainter(
      text: TextSpan(
        text: labels[index],
        style: const TextStyle(
          color: ui.Color(0xFFFFFFFF),
          fontFamily: 'friendlyscribbles',
          fontSize: 14,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width.toDouble() - 16);
    label.paint(canvas, origin + const ui.Offset(8, 8));
    label.dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    width * columns,
    height * (panels.length / columns).ceil(),
  );
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      'build/verification',
    ).create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}
