import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_game/audio/game_audio_controller.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
import 'package:flutter_game/game/models/game_sound.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/models/upgrade.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _capture = Key('android_capture');

/// Exercises real native WAV playback and the production widgets/world. Only
/// this test advances milestone time or arranges combat fixtures; release main
/// has no debug controls, shortcuts, invulnerability, or altered boss timings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android audio, endless bosses, pause and retry',
    (tester) async {
      final audio = _AuditedAudio();
      addTearDown(audio.close);
      await audio.initialize();
      expect(audio.lastError, isNull);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _capture,
          child: WitchKittyApp(audio: audio),
        ),
      );
      await _until(
        tester,
        () => find.byKey(const Key('play_button')).evaluate().isNotEmpty,
      );
      await _settleMusic(audio, MusicTrack.menu);
      await _captureImage(tester, 'menu');
      await tester.tap(find.byKey(const Key('play_button')));
      await tester.pump();
      await _settleMusic(audio, MusicTrack.attire);
      expect(audio.sounds.where((s) => s == GameSound.meow), hasLength(1));
      await _captureImage(tester, 'attire');
      await tester.tap(find.byKey(const Key('color_2_choice')));
      await tester.pump();
      await _settleMusic(audio, MusicTrack.arena);
      expect(audio.sounds.where((s) => s == GameSound.meow), hasLength(2));
      final world = _world(tester);
      expect(world.player.palette, PlayerPalette.color2);
      world.spawner.timeUntilNextSpawn = 99999;
      world.player.stats.orbRotationSpeed = 0;
      world.spawnSlimeAt(
        world.orb.positionAround(world.player.position),
        maxHealth: 10,
        spawnDelay: 0,
      );
      await _until(tester, () => world.defeatedEnemies == 1);
      expect(audio.sounds, contains(GameSound.arcaneHit));
      for (
        var choice = 0;
        choice < 30 && !world.player.stats.fireOrb.isOwned;
        choice++
      ) {
        if (world.isPlaying) world.awardXp(world.player.stats.xpRequired);
        await _until(tester, () => world.isChoosingUpgrade);
        final fire = world.upgradeChoices.where(
          (c) => c.id == UpgradeId.fireOrb,
        );
        final selected = fire.isNotEmpty
            ? fire.first
            : world.upgradeChoices.first;
        await tester.tap(
          find.byKey(ValueKey('upgrade_card_${selected.id.name}')),
        );
        await tester.pump();
      }
      expect(world.player.stats.fireOrb.isOwned, isTrue);
      await _finishChoices(tester, world);
      world.enemies.clear();
      world.survivalTime = 299.99;
      await _until(tester, () => world.isBossWarning);
      await _settleMusic(audio, MusicTrack.bossWarning);
      await _captureImage(tester, 'warning');
      await _until(tester, () => world.boss?.isActive == true, seconds: 30);
      await _settleMusic(audio, MusicTrack.boss);
      final boss = world.boss!;
      final firstMaxHp = boss.health.maxHealth;
      boss.position = world.orb.positionAround(world.player.position);
      await _until(tester, () => boss.health.currentHealth < firstMaxHp);
      boss.position = world.player.position + const Offset(140, 0);
      final fireHits = audio.sounds.where((s) => s == GameSound.fireHit).length;
      await _until(
        tester,
        () =>
            audio.sounds.where((s) => s == GameSound.fireHit).length > fireHits,
      );
      expect(audio.sounds, contains(GameSound.fireShot));
      boss.health.takeDamage(boss.health.currentHealth - firstMaxHp ~/ 2);
      await tester.pump(const Duration(milliseconds: 50));
      expect(boss.isEnraged, isTrue);
      await _captureImage(tester, 'boss_enraged');

      // Melee must hit vertically as well as in the original horizontal cases.
      boss.position = world.player.position - const Offset(0, 85);
      boss.activity = DinoActivity.chasing;
      boss.attackCooldownRemaining = 0;
      boss.rangedCooldownRemaining = 999;
      boss.abilityCooldownRemaining = 999;
      final hp = world.player.health.currentHealth;
      await _until(tester, () => world.player.health.currentHealth < hp);
      expect(audio.sounds, contains(GameSound.hurt));
      final elapsed = world.survivalTime;
      final kills = world.defeatedEnemies;
      boss.position = world.orb.positionAround(world.player.position);
      world.player.stats.orbDamage = boss.health.maxHealth.toDouble();
      await _until(tester, () => world.bossesDefeated == 1);
      await _settleMusic(audio, MusicTrack.arena);
      expect(world.isGameOver, isFalse);
      expect(world.survivalTime, greaterThanOrEqualTo(elapsed));
      expect(world.defeatedEnemies, kills);
      expect(find.byKey(const Key('boss_health_bar')), findsNothing);
      await _finishChoices(tester, world);
      await _until(tester, () => world.boss == null);
      await _captureImage(tester, 'after_boss');
      world.survivalTime = 599.99;
      await _until(tester, () => world.isBossWarning);
      await _until(tester, () => world.boss?.isActive == true, seconds: 30);
      await _settleMusic(audio, MusicTrack.boss);
      expect(world.boss!.health.maxHealth, greaterThan(firstMaxHp));
      expect(world.bossEncounters, 2);
      final nextBoss = world.boss!;
      world.player.stats.orbDamage = 10;
      nextBoss.position = world.player.position - const Offset(0, 200);
      nextBoss.activity = DinoActivity.chasing;
      nextBoss.attackCooldownRemaining = 999;
      nextBoss.abilityCooldownRemaining = 999;
      nextBoss.rangedCooldownRemaining = 0;
      world.setMovementInput(const Offset(1, 0));
      await _until(tester, () => nextBoss.activity == DinoActivity.preparing);
      final predictedTarget = nextBoss.attackTarget;
      expect(predictedTarget.dx, greaterThan(world.player.position.dx));
      expect(nextBoss.attackDirection.dy, greaterThan(0.5));
      final healthBeforeDodge = world.player.health.currentHealth;
      world.setMovementInput(const Offset(-1, 0));
      await _until(tester, () => nextBoss.isCharging);
      expect(nextBoss.attackTarget, predictedTarget);
      await _captureImage(tester, 'predicted_charge');
      await _until(tester, () => nextBoss.activity == DinoActivity.recovering);
      expect(world.player.health.currentHealth, healthBeforeDodge);
      world.setMovementInput(Offset.zero);
      world.player.health.takeDamage(999999);
      await _until(tester, () => world.isGameOver);
      await _settleMusic(audio, null);
      expect(find.text('BOSSES DEFEATED  1'), findsOneWidget);
      await _captureImage(tester, 'game_over');
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pump();
      await _settleMusic(audio, MusicTrack.arena);
      final fresh = _world(tester);
      expect(fresh, isNot(same(world)));
      expect(fresh.bossesDefeated, 0);
      expect(fresh.nextBossTime, 300);
      expect(fresh.player.stats.level, 1);
      expect(fresh.player.palette, PlayerPalette.color2);
      await tester.tap(find.byKey(const Key('pause_button')));
      await tester.pump();
      final frozen = fresh.survivalTime;
      await tester.pump(const Duration(milliseconds: 500));
      expect(fresh.survivalTime, frozen);
      expect(audio.isPaused, isTrue);
      await tester.tap(find.byKey(const Key('pause_settings_button')));
      await tester.pump();
      await _captureImage(tester, 'settings');
      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('resume_button')));
      await tester.pump();
      await _settleMusic(audio, MusicTrack.arena);
      expect(audio.isPaused, isFalse);
      expect(audio.lastError, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.close();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _AuditedAudio extends GameAudioController {
  _AuditedAudio() : super(preferences: MemoryAudioPreferences());
  final sounds = <GameSound>[];
  @override
  Future<void> play(GameSound sound) {
    sounds.add(sound);
    return super.play(sound); // Real Android backend, never mocked.
  }
}

Future<void> _settleMusic(GameAudioController audio, MusicTrack? track) async {
  // Verify the real screen/world requested this track before waiting for native
  // playback. This must not hide a missing UI music transition.
  expect(audio.currentMusic, track);
  await audio.setMusic(track);
  expect(audio.lastError, isNull);
}

GameWorld _world(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<GamePainter>()
    .single
    .world;

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  int seconds = 30,
}) async {
  final limit = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(limit)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue, reason: 'Native game condition timed out');
}

Future<void> _finishChoices(WidgetTester tester, GameWorld world) async {
  for (var step = 0; step < 30 && !world.isPlaying; step++) {
    await _until(tester, () => world.isChoosingUpgrade);
    await tester.tap(
      find.byKey(
        ValueKey('upgrade_card_${world.upgradeChoices.first.id.name}'),
      ),
    );
    await tester.pump();
  }
  expect(world.isPlaying, isTrue);
}

Future<void> _captureImage(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final image = await boundary.toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final directory = Directory('${Directory.systemTemp.path}/verification');
  await directory.create(recursive: true);
  await File(
    '${directory.path}/$name.png',
  ).writeAsBytes(bytes.buffer.asUint8List());
  image.dispose();
}
