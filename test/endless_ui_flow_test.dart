import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game/audio/game_audio_controller.dart';
import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/game_screen.dart';
import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/game_sound.dart';
import 'package:flutter_game/game/models/player.dart';
import 'package:flutter_game/game/rendering/game_painter.dart';
import 'package:flutter_game/game/widgets/virtual_joystick.dart';
import 'package:flutter_game/main.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = Key('endless_ui_capture');

void main() {
  Future<GameAssets> assetsFor(WidgetTester tester) async {
    late GameAssets assets;
    await tester.runAsync(() async {
      assets = await GameAssets.load();
      await (FontLoader(
        'friendlyscribbles',
      )..addFont(rootBundle.load('assets/font/friendlyscribbles.ttf'))).load();
    });
    addTearDown(assets.dispose);
    return assets;
  }

  Future<void> sizeFor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'pause and settings stop all run timers and release the owning finger',
    (tester) async {
      await sizeFor(tester);
      final assets = await assetsFor(tester);
      final audio = _RecordingAudio();
      addTearDown(audio.dispose);
      final world = GameWorld(spawningEnabled: false);
      world.player.stats.orbDamage = 24;
      world.player.stats.level = 5;
      world.bossWarningRemaining = 4;
      await tester.pumpWidget(
        _host(
          GameScreen(
            assets: assets,
            palette: PlayerPalette.color1,
            initialWorld: world,
            audio: audio,
            onMainMenu: () {},
          ),
        ),
      );
      final held = await tester.startGesture(
        const Offset(120, 510),
        pointer: 101,
      );
      await held.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 20));
      final pauseTouch = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('pause_button'))),
        pointer: 102,
      );
      await pauseTouch.up();
      await tester.pump();
      expect(find.byType(VirtualJoystick), findsNothing);
      expect(world.player.movementInput, Offset.zero);
      expect(audio.isPaused, isTrue);
      final elapsed = world.survivalTime;
      final warning = world.bossWarningRemaining;
      final position = world.player.position;
      await tester.pump(const Duration(seconds: 4));
      expect(world.survivalTime, elapsed);
      expect(world.bossWarningRemaining, warning);
      await _capture(tester, '20_pause');

      await tester.tap(find.byKey(const Key('pause_settings_button')));
      await tester.pump();
      tester
          .widget<Slider>(find.byKey(const Key('music_volume_slider')))
          .onChanged!(0.25);
      tester
          .widget<Switch>(find.byKey(const Key('sfx_mute_switch')))
          .onChanged!(true);
      await tester.pump();
      expect(audio.musicVolume, 0.25);
      expect(audio.sfxMuted, isTrue);
      expect(find.text('25%'), findsOneWidget);
      expect(world.player.stats.orbDamage, 24);
      expect(world.player.stats.level, 5);
      expect(world.player.position, position);
      await _capture(tester, '21_sound_settings');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.isPaused, isTrue);
      expect(world.survivalTime, elapsed);

      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('resume_button')));
      await tester.pump();
      expect(audio.isPaused, isFalse);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      await held.moveBy(const Offset(30, 0));
      expect(world.player.movementInput, Offset.zero);
      await held.up();
      final next = await tester.startGesture(const Offset(110, 520));
      await next.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(world.survivalTime, greaterThan(elapsed));
      expect(world.player.position.dx, greaterThan(position.dx));
      await next.up();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'menu and cosmetic attire have one meow per choice and correct music',
    (tester) async {
      await sizeFor(tester);
      final audio = _RecordingAudio();
      addTearDown(audio.dispose);
      await tester.pumpWidget(WitchKittyApp(audio: audio));
      await _waitFor(tester, find.byKey(const Key('play_button')));
      expect(audio.currentMusic, MusicTrack.menu);
      await tester.tap(find.byKey(const Key('menu_settings_button')));
      await tester.pump();
      expect(find.byKey(const Key('audio_settings_overlay')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('play_button')));
      await tester.pump();
      expect(audio.currentMusic, MusicTrack.attire);
      expect(find.text('WITCH KITTY SELECT'), findsOneWidget);
      expect(find.text('CHOOSE YOUR ATTIRE'), findsOneWidget);
      expect(
        audio.sounds.where((sound) => sound == GameSound.meow),
        hasLength(1),
      );
      await tester.tap(find.byKey(const Key('color_2_choice')));
      await tester.pump();
      expect(
        audio.sounds.where((sound) => sound == GameSound.meow),
        hasLength(2),
      );
      expect(audio.currentMusic, MusicTrack.arena);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<GamePainter>()
          .single;
      expect(painter.world.player.palette, PlayerPalette.color2);
      expect(painter.world.player.stats.orbDamage, 10);
      expect(painter.world.player.stats.level, 1);
      await tester.tap(find.byKey(const Key('pause_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pause_menu_button')));
      await tester.pump();
      expect(audio.currentMusic, MusicTrack.menu);
      expect(audio.isPaused, isFalse);
      expect(find.byKey(const Key('play_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'boss warning passes touches, boss music returns to arena, death retry is fresh',
    (tester) async {
      await sizeFor(tester);
      final assets = await assetsFor(tester);
      final audio = _RecordingAudio();
      addTearDown(audio.dispose);
      final world = GameWorld(spawningEnabled: false)..survivalTime = 299.99;
      await tester.pumpWidget(
        _host(
          GameScreen(
            assets: assets,
            palette: PlayerPalette.color1,
            initialWorld: world,
            audio: audio,
            onMainMenu: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('boss_warning_banner')), findsOneWidget);
      expect(audio.currentMusic, MusicTrack.bossWarning);
      final warningFinger = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('boss_warning_banner'))),
      );
      await warningFinger.moveBy(const Offset(40, 40));
      expect(world.player.movementInput.distance, closeTo(1, 0.0001));
      await warningFinger.up();
      await _capture(tester, '22_boss_warning');
      world.bossWarningRemaining = 0.001;
      await tester.pump(const Duration(milliseconds: 20));
      expect(world.boss, isNotNull);
      expect(find.byKey(const Key('boss_health_bar')), findsOneWidget);
      expect(audio.currentMusic, MusicTrack.boss);
      world.boss!.health.takeDamage(world.boss!.health.maxHealth ~/ 2);
      await tester.pump(const Duration(milliseconds: 20));
      await _capture(tester, '23_boss_hud');
      expect(tester.takeException(), isNull);
      world.boss!.takeProjectileHit(100000);
      await tester.pump(const Duration(milliseconds: 20));
      expect(audio.currentMusic, MusicTrack.arena);
      expect(find.byKey(const Key('boss_health_bar')), findsNothing);
      world.bossesDefeated = 2;
      world.player.health.takeDamage(100000);
      await tester.pump(const Duration(milliseconds: 20));
      expect(audio.currentMusic, isNull);
      expect(find.text('BOSSES DEFEATED  2'), findsOneWidget);
      expect(find.byType(VirtualJoystick), findsNothing);
      await _capture(tester, '24_endless_game_over');
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pump();
      expect(audio.currentMusic, MusicTrack.arena);
      expect(audio.musicRequests.last, (MusicTrack.arena, true));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<GamePainter>()
          .single;
      expect(painter.world.bossesDefeated, 0);
      expect(painter.world.boss, isNull);
      expect(painter.world.survivalTime, 0);
      expect(find.byType(VirtualJoystick), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _RecordingAudio extends GameAudioController {
  _RecordingAudio()
    : super(
        backend: SilentAudioBackend(),
        preferences: MemoryAudioPreferences(),
        fadeDuration: Duration.zero,
      );
  final sounds = <GameSound>[];
  final musicRequests = <(MusicTrack?, bool)>[];

  @override
  Future<void> play(GameSound sound) async => sounds.add(sound);

  @override
  Future<void> setMusic(MusicTrack? track, {bool restart = false}) {
    musicRequests.add((track, restart));
    return super.setMusic(track, restart: restart);
  }
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'friendlyscribbles',
  ),
  home: RepaintBoundary(key: _captureKey, child: child),
);

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Expected widget did not appear: $finder');
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/verification')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    rendered.dispose();
  });
}
