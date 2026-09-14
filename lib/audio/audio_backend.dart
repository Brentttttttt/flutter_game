import 'package:audioplayers/audioplayers.dart';

import 'audio_catalog.dart';

abstract interface class AudioBackend {
  Future<void> initialize();
  Future<void> loadMusic(String asset);
  Future<void> setMusicVolume(double volume);
  Future<void> resumeMusic();
  Future<void> pauseMusic();
  Future<void> stopMusic();
  Future<void> playSound(String asset, double volume);
  Future<void> setSfxVolume(double volume);
  Future<void> stopSounds();
  Future<void> dispose();
}

/// One streamed music player and a fixed number of preloaded sound voices.
/// AudioPool.maxPlayers does not cap active players, so the cap lives here.
/// Music is copied to the native cache on demand, never all decoded at startup.
class DeviceAudioBackend implements AudioBackend {
  final AudioCache _cache = AudioCache();
  final Map<String, List<_SoundVoice>> _voices = {};
  AudioPlayer? _music;
  bool _disposed = false;
  int _soundGeneration = 0;
  String? _musicAsset;

  @override
  Future<void> initialize() async {
    if (_disposed || _music != null) return;
    _music = AudioPlayer()
      ..audioCache = _cache
      ..positionUpdater = null; // The game never displays playback positions.
    await _music!.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(usageType: AndroidUsageType.game),
      ),
    );
    await _music!.setPlayerMode(PlayerMode.mediaPlayer);
    await _music!.setReleaseMode(ReleaseMode.loop);
    await _music!.setVolume(0);
    // Sequential initialization avoids racing native SoundPool preparation.
    for (final asset in AudioCatalog.sounds.values.toSet()) {
      final voices = _voices[asset] = [];
      for (var index = 0; index < AudioCatalog.voicesFor(asset); index++) {
        if (_disposed) return;
        final player = AudioPlayer()
          ..audioCache = _cache
          ..positionUpdater = null;
        voices.add(_SoundVoice(player));
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.game,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(asset));
      }
    }
  }

  @override
  Future<void> loadMusic(String asset) async {
    if (_disposed) return;
    final previous = _musicAsset;
    await _music!.stop();
    await _music!.setSource(AssetSource(asset));
    _musicAsset = asset;
    // Only the current long WAV remains cached; small SFX stay preloaded.
    if (previous != null && previous != asset) await _cache.clear(previous);
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    if (!_disposed) await _music?.setVolume(volume);
  }

  @override
  Future<void> resumeMusic() async {
    if (!_disposed) await _music?.resume();
  }

  @override
  Future<void> pauseMusic() async {
    if (!_disposed) await _music?.pause();
  }

  @override
  Future<void> stopMusic() async {
    if (!_disposed) await _music?.stop();
  }

  @override
  Future<void> playSound(String asset, double volume) async {
    final voices = _voices[asset];
    if (_disposed || voices == null) return;
    final generation = _soundGeneration;
    _SoundVoice? selected;
    for (final voice in voices) {
      if (!voice.busy) {
        selected = voice;
        break;
      }
    }
    if (selected == null) return;
    // Rotate the fixed pool. Reusing the oldest voice truncates its tail rather
    // than allocating unbounded players when six orbs hit a crowd together.
    voices.remove(selected);
    voices.add(selected);
    await selected.run(() async {
      if (_disposed || generation != _soundGeneration) return;
      await selected!.player.stop();
      await selected.player.setVolume(volume);
      if (!_disposed && generation == _soundGeneration) {
        await selected.player.resume();
      }
    });
  }

  @override
  Future<void> setSfxVolume(double volume) async {
    await Future.wait([
      for (final voices in _voices.values)
        for (final voice in voices)
          voice.run(() => voice.player.setVolume(volume)),
    ]);
  }

  @override
  Future<void> stopSounds() async {
    _soundGeneration++;
    await Future.wait([
      for (final voices in _voices.values)
        for (final voice in voices) voice.run(voice.player.stop),
    ]);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _soundGeneration++;
    await Future.wait([
      if (_music != null) _music!.dispose(),
      for (final voices in _voices.values)
        for (final voice in voices) voice.run(voice.player.dispose),
    ]);
    _voices.clear();
    await _cache.clearAll();
  }
}

class _SoundVoice {
  _SoundVoice(this.player);
  final AudioPlayer player;
  Future<void> _work = Future.value();
  int _pending = 0;
  bool get busy => _pending > 0;

  Future<void> run(Future<void> Function() action) {
    _pending++;
    final operation = _work.then((_) => action());
    _work = operation.then<void>((_) {}, onError: (Object error) {});
    return operation.whenComplete(() => _pending--);
  }
}

/// Headless widget tests can exercise the same settings and music state without
/// creating platform channels, native audio players, or background timers.
class SilentAudioBackend implements AudioBackend {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> loadMusic(String asset) async {}
  @override
  Future<void> setMusicVolume(double volume) async {}
  @override
  Future<void> resumeMusic() async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> playSound(String asset, double volume) async {}
  @override
  Future<void> setSfxVolume(double volume) async {}
  @override
  Future<void> stopSounds() async {}
  @override
  Future<void> dispose() async {}
}
