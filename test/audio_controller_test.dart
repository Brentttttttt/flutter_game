import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_game/audio/audio_catalog.dart';
import 'package:flutter_game/audio/game_audio_controller.dart';
import 'package:flutter_game/game/models/game_sound.dart';

class RecordingAudioBackend extends SilentAudioBackend {
  final events = <String>[];
  final volumes = <double>[];
  final sounds = <(String, double)>[];
  Completer<void>? initialization;
  bool fail = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (fail) throw MissingPluginException('Headless device');
    await initialization?.future;
    events.add('initialize');
  }

  @override
  Future<void> loadMusic(String asset) async => events.add('load:$asset');
  @override
  Future<void> resumeMusic() async => events.add('resume');
  @override
  Future<void> pauseMusic() async => events.add('pause');
  @override
  Future<void> stopMusic() async => events.add('stop');
  @override
  Future<void> setMusicVolume(double volume) async => volumes.add(volume);
  @override
  Future<void> playSound(String asset, double volume) async =>
      sounds.add((asset, volume));
  @override
  Future<void> setSfxVolume(double volume) async => events.add('sfx:$volume');
  @override
  Future<void> stopSounds() async => events.add('stopSounds');
  @override
  Future<void> dispose() async => disposed = true;
}

Future<void> settleMicrotasks() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.value();
  }
}

void main() {
  test(
    'audio catalog points to actual PCM files and only the five BGM tracks',
    () {
      expect(AudioCatalog.music.length, 5);
      expect(AudioCatalog.sounds.keys.toSet(), GameSound.values.toSet());
      for (final path in {
        ...AudioCatalog.music.values,
        ...AudioCatalog.sounds.values,
      }) {
        final file = File('assets/$path');
        expect(file.existsSync(), isTrue, reason: path);
        final input = file.openSync();
        final header = input.readSync(12);
        input.closeSync();
        expect(String.fromCharCodes(header.take(4)), 'RIFF');
        expect(String.fromCharCodes(header.skip(8)), 'WAVE');
      }
      expect(AudioCatalog.sounds[GameSound.arcaneHit], 'sfx/Sword_Slash.wav');
      expect(AudioCatalog.sounds[GameSound.fireShot], 'sfx/Gun.wav');
      expect(AudioCatalog.sounds[GameSound.fireHit], 'sfx/Explosion.wav');
    },
  );

  test('startup changes keep only the latest requested music', () async {
    final backend = RecordingAudioBackend()..initialization = Completer<void>();
    final audio = GameAudioController(
      backend: backend,
      preferences: MemoryAudioPreferences(),
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    final menu = audio.setMusic(MusicTrack.menu);
    await settleMicrotasks();
    final attire = audio.setMusic(MusicTrack.attire);
    final arena = audio.setMusic(MusicTrack.arena);
    backend.initialization!.complete();
    await Future.wait([menu, attire, arena]);
    expect(backend.events.where((e) => e.startsWith('load:')), [
      'load:${AudioCatalog.music[MusicTrack.arena]}',
    ]);
    expect(audio.currentMusic, MusicTrack.arena);
    expect(backend.volumes.last, 0.65);
  });

  test(
    'track changes fade out then in, with separate unchanged SFX volume',
    () async {
      final backend = RecordingAudioBackend();
      final waits = <Duration>[];
      final audio = GameAudioController(
        backend: backend,
        preferences: MemoryAudioPreferences(),
        delay: (duration) async => waits.add(duration),
      );
      addTearDown(audio.dispose);
      await audio.setMusic(MusicTrack.arena);
      backend.volumes.clear();
      waits.clear();
      await audio.setMusic(MusicTrack.bossWarning);
      expect(
        waits.fold(Duration.zero, (sum, duration) => sum + duration),
        const Duration(milliseconds: 350),
      );
      expect(
        backend.volumes.take(8).toList(),
        orderedEquals(List.generate(8, (i) => (1 - (i + 1) / 8) * 0.65)),
      );
      expect(
        backend.volumes.skip(9).toList(),
        orderedEquals(List.generate(8, (i) => (i + 1) / 8 * 0.65)),
      );
      expect(audio.sfxVolume, 0.8);
    },
  );

  test(
    'new request cancels an unfinished fade before the stale song loads',
    () async {
      final backend = RecordingAudioBackend();
      Completer<void>? gate;
      final audio = GameAudioController(
        backend: backend,
        preferences: MemoryAudioPreferences(),
        delay: (_) async => await gate?.future,
      );
      addTearDown(audio.dispose);
      await audio.setMusic(MusicTrack.menu);
      gate = Completer<void>();
      final attire = audio.setMusic(MusicTrack.attire);
      await settleMicrotasks();
      final arena = audio.setMusic(MusicTrack.arena);
      final pending = gate;
      gate = null;
      pending.complete();
      await Future.wait([attire, arena]);
      expect(
        backend.events,
        isNot(contains('load:${AudioCatalog.music[MusicTrack.attire]}')),
      );
      expect(audio.currentMusic, MusicTrack.arena);
      expect(backend.volumes.last, 0.65);
    },
  );

  test(
    'pause silences combat, permits UI cues, resumes without restarting music',
    () async {
      final backend = RecordingAudioBackend();
      final audio = GameAudioController(
        backend: backend,
        preferences: MemoryAudioPreferences(),
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      await audio.setMusic(MusicTrack.boss);
      await audio.pause();
      await audio.play(GameSound.arcaneHit);
      await audio.play(GameSound.pause);
      await audio.play(GameSound.confirm);
      expect(backend.events, containsAll(['pause', 'stopSounds']));
      expect(backend.sounds.map((e) => e.$1), [
        'sfx/Pause.wav',
        'sfx/Confirm.wav',
      ]);
      await audio.resume();
      expect(backend.events.where((e) => e.startsWith('load:')).length, 1);
      expect(audio.isPaused, isFalse);
      await audio.setMusic(MusicTrack.boss, restart: true);
      expect(backend.events.where((e) => e.startsWith('load:')).length, 2);
    },
  );

  test('boss defeat and gameover select arena music then silence', () async {
    final backend = RecordingAudioBackend();
    final audio = GameAudioController(
      backend: backend,
      preferences: MemoryAudioPreferences(),
      fadeDuration: Duration.zero,
    );
    addTearDown(audio.dispose);
    for (final track in [
      MusicTrack.arena,
      MusicTrack.bossWarning,
      MusicTrack.boss,
      MusicTrack.arena,
      null,
    ]) {
      await audio.setMusic(track);
    }
    expect(audio.currentMusic, isNull);
    expect(backend.events.last, 'stop');
    expect(backend.volumes.last, 0);
  });

  test(
    'sound bursts are bounded by event rate and separate sounds still play',
    () async {
      var elapsed = Duration.zero;
      final backend = RecordingAudioBackend();
      final audio = GameAudioController(
        backend: backend,
        preferences: MemoryAudioPreferences(),
        elapsed: () => elapsed,
      );
      addTearDown(audio.dispose);
      await Future.wait(
        List.generate(100, (_) => audio.play(GameSound.arcaneHit)),
      );
      await audio.play(GameSound.fireHit);
      expect(backend.sounds.length, 2);
      elapsed = const Duration(milliseconds: 86);
      await audio.play(GameSound.arcaneHit);
      expect(backend.sounds.length, 3);
      await audio.setSfxMuted(true);
      elapsed = const Duration(seconds: 2);
      await audio.play(GameSound.fireHit);
      expect(backend.sounds.length, 3);
    },
  );

  test(
    'settings restore and clamp, mutes retain slider volumes across controllers',
    () async {
      final preferences = MemoryAudioPreferences(
        const AudioSettings(
          musicVolume: 0.3,
          sfxVolume: 0.45,
          musicMuted: true,
        ),
      );
      final backend = RecordingAudioBackend();
      final audio = GameAudioController(
        backend: backend,
        preferences: preferences,
        fadeDuration: Duration.zero,
      );
      await audio.setMusic(MusicTrack.menu);
      expect(backend.volumes.last, 0);
      expect(audio.musicVolume, 0.3);
      await audio.setMusicMuted(false);
      expect(backend.volumes.last, 0.3);
      await Future.wait([
        audio.setMusicVolume(1.8),
        audio.setSfxVolume(-2),
        audio.setMusicVolume(0.7),
        audio.setSfxMuted(true),
      ]);
      expect(audio.musicVolume, 0.7);
      expect(audio.sfxVolume, 0);
      audio.dispose();
      final restored = GameAudioController(
        backend: SilentAudioBackend(),
        preferences: preferences,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.musicVolume, 0.7);
      expect(restored.sfxVolume, 0);
      expect(restored.musicMuted, isFalse);
      expect(restored.sfxMuted, isTrue);
    },
  );

  test(
    'editing before initialization retains both new and other stored settings',
    () async {
      final preferences = MemoryAudioPreferences(
        const AudioSettings(sfxVolume: 0.2),
      );
      final audio = GameAudioController(
        backend: SilentAudioBackend(),
        preferences: preferences,
      );
      addTearDown(audio.dispose);
      await audio.setMusicVolume(0.4);
      expect(audio.musicVolume, 0.4);
      expect(audio.sfxVolume, 0.2);
      expect(preferences.settings.musicVolume, 0.4);
      expect(preferences.settings.sfxVolume, 0.2);
    },
  );

  test('missing native audio is contained and settings still work', () async {
    final audio = GameAudioController(
      backend: RecordingAudioBackend()..fail = true,
      preferences: MemoryAudioPreferences(),
    );
    addTearDown(audio.dispose);
    await audio.setMusic(MusicTrack.menu);
    await audio.play(GameSound.meow);
    await audio.setMusicVolume(0.25);
    expect(audio.lastError, isA<MissingPluginException>());
    expect(audio.musicVolume, 0.25);
  });

  test(
    'dispose during native preparation prevents playback and releases backend',
    () async {
      final backend = RecordingAudioBackend()
        ..initialization = Completer<void>();
      final audio = GameAudioController(
        backend: backend,
        preferences: MemoryAudioPreferences(),
        fadeDuration: Duration.zero,
      );
      final playback = audio.setMusic(MusicTrack.menu);
      await settleMicrotasks();
      final shutdown = audio.close();
      backend.initialization!.complete();
      await playback;
      await shutdown;
      expect(backend.events, isNot(contains('resume')));
      expect(backend.disposed, isTrue);
      await audio.play(GameSound.meow);
      expect(backend.sounds, isEmpty);
    },
  );
}
