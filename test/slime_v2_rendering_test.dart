import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all colors render actual action rows with centered horizontal facing',
    () async {
      await (FontLoader(
        'friendlyscribbles',
      )..addFont(rootBundle.load('assets/font/friendlyscribbles.ttf'))).load();
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);
      final repaint = ValueNotifier(0);
      addTearDown(repaint.dispose);
      const panelSize = ui.Size(160, 144);
      const labels = [
        'IDLE',
        'WALK',
        'ATTACK LEFT',
        'ATTACK RIGHT',
        'DEATH BURST',
        'DEATH END',
      ];
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF171027), ui.BlendMode.src);
      for (final color in SlimeColor.values) {
        final sourcePixels = (await assets.slimeSheets[color]!.toByteData())!;
        for (var action = 0; action < labels.length; action++) {
          final world = GameWorld(
            spawningEnabled: false,
            playerPosition: const ui.Offset(400, 400),
          )..setViewport(panelSize);
          world.camera.position = const ui.Offset(346, 336);
          final slime = world.spawnSlimeAt(
            const ui.Offset(456, 416),
            color: color,
            spawnDelay: 0,
          );
          if (action == 1) {
            slime.activity = SlimeActivity.walking;
            slime.animationTime = 0.21;
          } else if (action == 2 || action == 3) {
            slime.update(
              0.401,
              playerPosition:
                  slime.position + ui.Offset(action == 2 ? -40 : 40, 0),
              playerRadius: 30,
              arena: world.arena,
            );
            expect(slime.mirrorHorizontally, action == 3);
          } else if (action >= 4) {
            slime.takeProjectileHit(slime.health.maxHealth);
            slime.deathAnimationTime = action == 4 ? 0.3 : 0.56;
          }
          final panelRecorder = ui.PictureRecorder();
          GamePainter(
            world: world,
            assets: assets,
            repaint: repaint,
          ).paint(ui.Canvas(panelRecorder), panelSize);
          final panelPicture = panelRecorder.endRecording();
          final panel = await panelPicture.toImage(160, 144);
          final actualPixels = (await panel.toByteData())!;
          final source = slime.sourceRect;
          var checked = 0;
          // Check every opaque destination pixel against the actual selected
          // color/action cell. This detects wrong rows, flips, anchors, or blur.
          for (var y = 0; y < 48; y++) {
            for (var x = 0; x < 48; x++) {
              // At 1.5x, every third destination sample lands exactly between
              // source pixels; either adjacent pixel is valid nearest sampling.
              if (x % 3 == 1 || y % 3 == 1) continue;
              final cellX = ((x + 0.5) / 1.5).floor();
              final cellY = ((y + 0.5) / 1.5).floor();
              final sourceX =
                  source.left.toInt() +
                  (slime.mirrorHorizontally ? 31 - cellX : cellX);
              final sourceY = source.top.toInt() + cellY;
              final sourceIndex = (sourceY * 320 + sourceX) * 4;
              if (sourcePixels.getUint8(sourceIndex + 3) != 255) continue;
              final destinationIndex = ((56 + y) * 160 + 86 + x) * 4;
              expect(
                actualPixels.getUint32(destinationIndex),
                sourcePixels.getUint32(sourceIndex),
                reason: '${color.name} ${labels[action]} at ($x,$y)',
              );
              checked++;
            }
          }
          expect(checked, greaterThan(action == 5 ? 10 : 100));
          final origin = ui.Offset(color.index * 160.0, action * 174.0);
          canvas.drawImage(panel, origin + const ui.Offset(0, 30), ui.Paint());
          final text = TextPainter(
            text: TextSpan(
              text: '${color.name.toUpperCase()} / ${labels[action]}',
              style: const TextStyle(
                color: ui.Color(0xFFFFFFFF),
                fontFamily: 'friendlyscribbles',
                fontSize: 12,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout(maxWidth: 156);
          text.paint(canvas, origin + const ui.Offset(4, 8));
          text.dispose();
          panel.dispose();
          panelPicture.dispose();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1120, 1044);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final directory = await Directory(
        'build/verification',
      ).create(recursive: true);
      await File(
        '${directory.path}/12_slime_v2_colors_and_actions.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
}
