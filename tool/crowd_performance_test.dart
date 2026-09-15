// Standalone host diagnostic, intentionally outside the normal test suite.
// Run: flutter test tool/crowd_performance_test.dart --reporter expanded
// Outputs: build/verification/crowd_performance.json and crowd_240_*fps.png.
// These debug-mode host timings are evidence, not mobile frame-rate guarantees.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/game_sound.dart';
import 'package:flutter_game/game/models/magic_orb.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';

const _viewport = ui.Size(390, 844);
const _enemyCount = 240;
const _seconds = 12;

void main() {
  testWidgets('profile 240 actual slimes at 30 and 60 simulated updates/sec', (
    tester,
  ) async {
    late GameAssets assets;
    await tester.runAsync(() async {
      assets = await GameAssets.load();
      await (FontLoader(
        'friendlyscribbles',
      )..addFont(rootBundle.load('assets/font/friendlyscribbles.ttf'))).load();
    });
    addTearDown(assets.dispose);
    final results = <Map<String, Object>>[];
    for (final fps in [30, 60]) {
      await tester.runAsync(() async {
        results.add(await _measure(assets, fps));
      });
    }
    final report = {
      'host': Platform.operatingSystem,
      'dartVersion': Platform.version,
      'mode': 'Flutter host test / debug',
      'viewportLogicalPixels': [_viewport.width, _viewport.height],
      'notes': [
        'No elapsed-time pass/fail thresholds: host load and warmup vary.',
        'Update measures GameWorld.update only; sound events are drained each frame.',
        'Paint measures canvas command recording, not GPU execution.',
        'Raster samples include offscreen toImage and CPU-readable RGBA readback.',
        'The fixture raises player/slime HP to retain 240 live targets. Production stats are unchanged.',
        'Six Arcane Orbs and level-5 Fire Orb use actual damage, targeting, hit cooldowns and VFX.',
        'Boss milestones/spawner are disabled to isolate the 240-enemy crowd.',
        'Measure a profile/release build on a physical target phone before claiming sustained mobile FPS.',
      ],
      'scenarios': results,
    };
    await tester.runAsync(() async {
      final folder = await Directory(
        'build/verification',
      ).create(recursive: true);
      await File(
        '${folder.path}/crowd_performance.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    });
    // This is an explicitly invoked diagnostic; keep the measured evidence
    // visible in its command output as well as the standalone JSON artifact.
    debugPrint(const JsonEncoder.withIndent('  ').convert(report));
  });
}

GameWorld _crowdWorld() {
  final world = GameWorld(spawningEnabled: false, random: math.Random(882));
  world.setViewport(_viewport);
  world.survivalTime = 1200;
  world.nextBossTime = double.infinity;
  world.player.health
    ..maxHealth = 1000000
    ..currentHealth = 1000000;
  world.player.stats
    ..arcaneOrbCount = 6
    ..level = 40;
  world.player.stats.fireOrb.level = 5;
  world.orbs.addAll([
    for (var index = 1; index < 6; index++) MagicOrb(),
    MagicOrb(kind: OrbKind.fire),
  ]);
  for (var index = 0; index < world.orbs.length; index++) {
    world.orbs[index].phaseOffset = 2 * math.pi * index / world.orbs.length;
  }
  for (var index = 0; index < _enemyCount; index++) {
    // Dense but distributed crowd: inner targets exercise actual orbit hits,
    // outer targets walk toward the same player and use normal separation.
    final angle = index * math.pi * (3 - math.sqrt(5));
    final radius = 60 + math.sqrt(index / (_enemyCount - 1)) * 240;
    world.spawnSlimeAt(
      world.player.position +
          ui.Offset(math.cos(angle), math.sin(angle)) * radius,
      maxHealth: 100000,
      spawnDelay: 0,
      color: SlimeColor.values[index % SlimeColor.values.length],
    );
  }
  return world;
}

Future<Map<String, Object>> _measure(GameAssets assets, int fps) async {
  final world = _crowdWorld();
  final repaint = ValueNotifier(0);
  final painter = GamePainter(world: world, assets: assets, repaint: repaint);
  final updates = <int>[];
  final paints = <int>[];
  final raster = <int>[];
  final soundCounts = <GameSound, int>{};
  var peakEffects = 0;
  var peakNumbers = 0;
  var peakProjectiles = 0;
  var peakVisible = 0;
  var peakWalking = 0;
  var bestFeedback = -1;
  ui.Picture? capture;
  final watch = Stopwatch();
  final dt = 1 / fps;

  // Warm the Dart execution paths and sprite drawing before collecting data.
  // Use a separate world so both rates start with the same crowd arrangement.
  final warmup = _crowdWorld();
  final warmupPainter = GamePainter(
    world: warmup,
    assets: assets,
    repaint: repaint,
  );
  for (var frame = 0; frame < 120; frame++) {
    warmup.update(dt);
    warmup.drainSoundEvents();
    final recorder = ui.PictureRecorder();
    warmupPainter.paint(ui.Canvas(recorder), _viewport);
    recorder.endRecording().dispose();
  }

  for (var frame = 0; frame < _seconds * fps; frame++) {
    final angle = frame * dt * 0.65;
    world.setMovementInput(ui.Offset(math.cos(angle), math.sin(angle)));
    watch
      ..reset()
      ..start();
    world.update(dt);
    watch.stop();
    updates.add(watch.elapsedMicroseconds);
    for (final sound in world.drainSoundEvents()) {
      soundCounts.update(sound, (count) => count + 1, ifAbsent: () => 1);
    }

    watch
      ..reset()
      ..start();
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), _viewport);
    final picture = recorder.endRecording();
    watch.stop();
    paints.add(watch.elapsedMicroseconds);

    if (frame % fps == 0) {
      watch
        ..reset()
        ..start();
      final image = await picture.toImage(
        _viewport.width.toInt(),
        _viewport.height.toInt(),
      );
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      watch.stop();
      raster.add(watch.elapsedMicroseconds);
      image.dispose();
    }

    peakEffects = math.max(peakEffects, world.effects.length);
    peakNumbers = math.max(peakNumbers, world.damageNumbers.length);
    peakProjectiles = math.max(peakProjectiles, world.projectiles.length);
    final visible = ui.Rect.fromLTWH(
      world.camera.position.dx,
      world.camera.position.dy,
      _viewport.width,
      _viewport.height,
    ).inflate(80);
    peakVisible = math.max(
      peakVisible,
      world.enemies.where((slime) => visible.contains(slime.position)).length,
    );
    peakWalking = math.max(
      peakWalking,
      world.enemies
          .where((slime) => slime.activity == SlimeActivity.walking)
          .length,
    );
    final feedback = world.effects.length + world.projectiles.length * 4;
    if (feedback > bestFeedback) {
      bestFeedback = feedback;
      capture?.dispose();
      capture = picture;
    } else {
      picture.dispose();
    }
  }

  expect(world.isPlaying, isTrue);
  expect(
    world.enemies.where((slime) => slime.isActive),
    hasLength(_enemyCount),
  );
  expect(soundCounts[GameSound.arcaneHit], greaterThan(0));
  expect(soundCounts[GameSound.fireShot], greaterThan(0));
  expect(soundCounts[GameSound.fireHit], greaterThan(0));
  expect(peakWalking, greaterThan(0));
  final image = await capture!.toImage(
    _viewport.width.toInt(),
    _viewport.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final folder = await Directory('build/verification').create(recursive: true);
  final capturePath = '${folder.path}/crowd_240_${fps}fps.png';
  await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  capture.dispose();
  repaint.dispose();

  return {
    'simulatedUpdatesPerSecond': fps,
    'simulatedSeconds': _seconds,
    'measuredFrames': updates.length,
    'liveEnemies': world.enemies.where((slime) => slime.isActive).length,
    'peakWalkingEnemies': peakWalking,
    'peakEnemiesWithinPainterCullBounds': peakVisible,
    'arcaneOrbs': 6,
    'fireOrbLevel': 5,
    'peakEffects': peakEffects,
    'peakDamageNumbers': peakNumbers,
    'peakProjectiles': peakProjectiles,
    'soundEvents': {
      for (final entry in soundCounts.entries) entry.key.name: entry.value,
    },
    'updateMilliseconds': _distribution(updates),
    'paintRecordingMilliseconds': _distribution(paints),
    'offscreenRasterReadbackMilliseconds': _distribution(raster),
    'capture': capturePath,
  };
}

Map<String, double> _distribution(List<int> samples) {
  final sorted = samples.toList()..sort();
  double percentile(double fraction) =>
      sorted[((sorted.length - 1) * fraction).round()] / 1000;
  return {
    'mean': sorted.reduce((a, b) => a + b) / sorted.length / 1000,
    'p50': percentile(0.5),
    'p95': percentile(0.95),
    'p99': percentile(0.99),
    'max': sorted.last / 1000,
  };
}
