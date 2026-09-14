import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
