import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
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
    'eight-direction attacks keep Dino upright and draw aligned warning routes',
    () async {
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);
      final repaint = ValueNotifier(0);
      addTearDown(repaint.dispose);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF20182C), ui.BlendMode.src);
      const size = ui.Size(400, 400);
      for (var phase = 0; phase < 2; phase++) {
        for (var index = 0; index < 8; index++) {
          final angle = index * math.pi / 4;
          final direction = ui.Offset(math.cos(angle), math.sin(angle));
          final target =
              const ui.Offset(700, 700) + direction * (phase == 0 ? 80 : 150);
          final world = GameWorld(
            spawningEnabled: false,
            playerPosition: target,
          )..setViewport(size);
          world.camera.position = const ui.Offset(500, 490);
          world.orb.angle = angle;
          final boss = world.boss =
              DinoTri(
                  id: -1,
                  position: const ui.Offset(700, 700),
                  encounterNumber: 1,
                )
                ..activity = DinoActivity.chasing
                ..attackCooldownRemaining = phase == 0 ? 0 : 999
                ..rangedCooldownRemaining = phase == 0 ? 999 : 0
                ..abilityCooldownRemaining = 999;
          boss.update(
            0.001,
            playerPosition: target,
            playerRadius: 18,
            arena: world.arena,
          );
          if (phase == 0) {
            boss.update(
              0.52,
              playerPosition: target,
              playerRadius: 18,
              arena: world.arena,
            );
            boss.update(
              0.96,
              playerPosition: target,
              playerRadius: 18,
              arena: world.arena,
            );
            expect(boss.hasDirectionalEffect, isTrue);
          }
          final panelRecorder = ui.PictureRecorder();
          GamePainter(
            world: world,
            assets: assets,
            repaint: repaint,
          ).paint(ui.Canvas(panelRecorder), size);
          final panelPicture = panelRecorder.endRecording();
          final panel = await panelPicture.toImage(400, 400);
          final actual = (await panel.toByteData())!;
          final sheet = assets.dinoSheets[boss.animation]!;
          final source = (await sheet.toByteData())!;
          var checked = 0;
          // All opaque pink body pixels remain the native upright image. Avoid
          // exact 1.5x pixel-boundary samples and the separately aimed spell.
          for (var y = 0; y < 128; y++) {
            for (var x = 148; x < 234; x++) {
              final sourceIndex =
                  (y * sheet.width + boss.sourceRect.left.toInt() + x) * 4;
              final red = source.getUint8(sourceIndex);
              final green = source.getUint8(sourceIndex + 1);
              final blue = source.getUint8(sourceIndex + 2);
              if (source.getUint8(sourceIndex + 3) != 255 ||
                  red < 150 ||
                  blue < 95 ||
                  green > red - 25) {
                continue;
              }
              final dx = ((x + 0.5 - DinoTri.sourceBodyOrigin.dx) * 1.5)
                  .floor();
              final dy = ((y + 0.5 - DinoTri.sourceBodyOrigin.dy) * 1.5)
                  .floor();
              final destinationX =
                  200 + (boss.mirrorHorizontally ? -dx - 1 : dx);
              final destinationY = 210 + dy;
              final actualIndex = (destinationY * 400 + destinationX) * 4;
              expect(
                actual.getUint32(actualIndex),
                source.getUint32(sourceIndex),
                reason:
                    'Body must stay upright phase$phase direction$index pixel($x,$y)',
              );
              checked++;
            }
          }
          expect(checked, greaterThan(500));
          final panelIndex = phase * 8 + index;
          final origin = ui.Offset(
            (panelIndex % 4) * 400.0,
            (panelIndex ~/ 4) * 430.0,
          );
          canvas.drawImage(panel, origin + const ui.Offset(0, 30), ui.Paint());
          final label = TextPainter(
            text: TextSpan(
              text:
                  '${phase == 0 ? 'MELEE + GREEN SPELL' : 'LOCKED CHARGE WARNING'} / ${index * 45} DEGREES',
              style: const TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 13),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          label.paint(canvas, origin + const ui.Offset(6, 6));
          label.dispose();
          panel.dispose();
          panelPicture.dispose();
        }
      }
      final picture = recorder.endRecording();
      final output = await picture.toImage(1600, 1720);
      final bytes = (await output.toByteData(format: ui.ImageByteFormat.png))!;
      final directory = Directory('build/verification')
        ..createSync(recursive: true);
      File(
        '${directory.path}/31_dino_360_attacks_and_telegraphs.png',
      ).writeAsBytesSync(bytes.buffer.asUint8List());
      output.dispose();
      picture.dispose();
    },
  );
  test(
    'Dino native wide frames render upright at a fixed body origin',
    () async {
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);
      for (final animation in DinoAnimation.values) {
        final sheet = assets.dinoSheets[animation]!;
        expect(sheet.width, DinoTri.frameCounts[animation]! * 384);
        expect(sheet.height, 128);
      }
      final repaint = ValueNotifier(0);
      addTearDown(repaint.dispose);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final actions = [
        DinoActivity.chasing,
        DinoActivity.preparing,
        DinoActivity.attackingA,
        DinoActivity.attackingB,
        DinoActivity.ability,
        DinoActivity.defeated,
      ];
      const size = ui.Size(400, 300);
      for (var row = 0; row < 2; row++) {
        for (var index = 0; index < actions.length; index++) {
          final world = GameWorld(
            spawningEnabled: false,
            playerPosition: ui.Offset(row == 0 ? 810 : 510, 650),
          )..setViewport(size);
          world.camera.position = const ui.Offset(460, 450);
          final boss = world.boss =
              DinoTri(
                  id: -1,
                  position: const ui.Offset(660, 650),
                  encounterNumber: 1,
                )
                ..activity = DinoActivity.chasing
                ..attackCooldownRemaining = 0;
          boss.update(
            0.001,
            playerPosition: boss.position + ui.Offset(row == 0 ? 80 : -80, 0),
            playerRadius: 30,
            arena: world.arena,
          );
          expect(boss.mirrorHorizontally, row == 1);
          boss.activity = actions[index];
          boss.animationTime = switch (actions[index]) {
            DinoActivity.preparing => 0.3,
            DinoActivity.attackingA || DinoActivity.attackingB => 0.96,
            DinoActivity.ability => 1.0,
            DinoActivity.defeated => 0.45,
            _ => 0.2,
          };
          if (actions[index] == DinoActivity.ability) {
            boss.hazards.add(
              DinoHazard(position: world.player.position, damage: 22)
                ..age = 1.3,
            );
          }
          expect(
            boss.destinationRect.width / 384,
            boss.destinationRect.height / 128,
          );
          expect(
            boss.sourceRect.right,
            lessThanOrEqualTo(assets.dinoSheets[boss.animation]!.width),
          );
          canvas.save();
          canvas.translate(index * size.width, row * (size.height + 30) + 30);
          canvas.clipRect(ui.Offset.zero & size);
          GamePainter(
            world: world,
            assets: assets,
            repaint: repaint,
          ).paint(canvas, size);
          canvas.restore();
          final label = TextPainter(
            text: TextSpan(
              text: '${row == 0 ? 'RIGHT' : 'LEFT'} / ${actions[index].name}',
              style: const TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 16),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          label.paint(
            canvas,
            ui.Offset(index * size.width + 8, row * (size.height + 30) + 4),
          );
          label.dispose();
        }
      }
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(2400, 660);
      final bytes = (await rendered.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      final directory = Directory('build/verification')
        ..createSync(recursive: true);
      File(
        '${directory.path}/25_dino_poses_directions_and_ability.png',
      ).writeAsBytesSync(bytes.buffer.asUint8List());
      rendered.dispose();
      picture.dispose();
    },
  );
}
