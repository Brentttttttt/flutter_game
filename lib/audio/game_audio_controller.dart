import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/models/game_sound.dart';
import 'audio_backend.dart';
import 'audio_catalog.dart';
import 'audio_preferences.dart';

export 'audio_backend.dart' show AudioBackend, SilentAudioBackend;
export 'audio_catalog.dart' show MusicTrack;
export 'audio_preferences.dart'
    show AudioPreferences, AudioSettings, MemoryAudioPreferences;

class GameAudioController extends ChangeNotifier {
  GameAudioController({
    AudioBackend? backend,
    AudioPreferences? preferences,
    this.fadeDuration = const Duration(milliseconds: 350),
    Future<void> Function(Duration)? delay,
    Duration Function()? elapsed,
  }) : _backend = backend ?? DeviceAudioBackend(),
       _preferences = preferences ?? DeviceAudioPreferences(),
       _delay = delay ?? Future<void>.delayed {
    final clock = Stopwatch()..start();
    _elapsed = elapsed ?? (() => clock.elapsed);
  }

  factory GameAudioController.silent() => GameAudioController(
    backend: SilentAudioBackend(),
    preferences: MemoryAudioPreferences(),
    fadeDuration: Duration.zero,
  );

  final AudioBackend _backend;
  final AudioPreferences _preferences;
  final Duration fadeDuration;
  final Future<void> Function(Duration) _delay;
  late final Duration Function() _elapsed;
  final Map<GameSound, Duration> _lastSound = {};
  final Set<String> _editedSettings = {};
  Future<void>? _initialization;
  Future<void>? _disposal;
  Future<void> _musicWork = Future.value();
  Future<void> _preferencesWork = Future.value();
  MusicTrack? _currentMusic;
  MusicTrack? _loadedMusic;
  double _musicVolume = 0.65;
  double _sfxVolume = 0.8;
  double _musicGain = 0;
  bool _musicMuted = false;
  bool _sfxMuted = false;
  bool _paused = false;
  bool _disposed = false;
  bool _available = false;
  int _musicGeneration = 0;
  int _settingsGeneration = 0;
  Object? _lastError;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get musicMuted => _musicMuted;
  bool get sfxMuted => _sfxMuted;
  bool get isPaused => _paused;
  MusicTrack? get currentMusic => _currentMusic;
  Object? get lastError => _lastError;
  double get _effectiveMusic => _musicMuted ? 0 : _musicVolume;
  double get _effectiveSfx => _sfxMuted ? 0 : _sfxVolume;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final saved = await _preferences.load();
      if (_disposed) return;
      if (!_editedSettings.contains('musicVolume')) {
        _musicVolume = _clampVolume(saved.musicVolume);
      }
      if (!_editedSettings.contains('sfxVolume')) {
        _sfxVolume = _clampVolume(saved.sfxVolume);
      }
      if (!_editedSettings.contains('musicMuted')) {
        _musicMuted = saved.musicMuted;
      }
      if (!_editedSettings.contains('sfxMuted')) {
        _sfxMuted = saved.sfxMuted;
      }
      notifyListeners();
    } catch (error) {
      _lastError = error;
    }
    if (_disposed) return;
    try {
      await _backend.initialize();
      _available = !_disposed;
    } catch (error) {
      // Audio/device errors must not prevent the game from loading.
      _lastError = error;
    }
  }

  Future<void> setMusic(MusicTrack? track, {bool restart = false}) {
    if (_disposed) return Future.value();
    if (track == _currentMusic && !restart) return _musicWork;
    _currentMusic = track;
    final generation = ++_musicGeneration;
    return _enqueueMusic(() => _transition(generation, restart: restart));
  }

  bool _isCurrent(int generation) =>
      !_disposed && !_paused && generation == _musicGeneration;

  Future<void> _transition(int generation, {bool restart = false}) async {
    if (!_isCurrent(generation)) return;
    final target = _currentMusic;
    if (_loadedMusic != target || restart) {
      if (_loadedMusic != null) await _fade(0, generation);
      if (!_isCurrent(generation)) return;
      await _backend.stopMusic();
      _loadedMusic = null;
      _musicGain = 0;
      if (target == null) return;
      await _backend.setMusicVolume(0);
      await _backend.loadMusic(AudioCatalog.music[target]!);
      _loadedMusic = target;
      // Native preparation can finish after a newer menu/lifecycle request.
      if (!_isCurrent(generation)) return;
    }
    if (target == null) return;
    await _backend.resumeMusic();
    await _fade(1, generation);
  }

  Future<void> _fade(double target, int generation) async {
    final start = _musicGain;
    final steps = fadeDuration == Duration.zero ? 1 : 8;
    final stepDuration = Duration(
      microseconds: fadeDuration.inMicroseconds ~/ (2 * steps),
    );
    for (var step = 1; step <= steps; step++) {
      if (!_isCurrent(generation)) return;
      _musicGain = start + (target - start) * step / steps;
      await _backend.setMusicVolume(_musicGain * _effectiveMusic);
      if (stepDuration > Duration.zero) await _delay(stepDuration);
    }
  }

  Future<void> _enqueueMusic(Future<void> Function() action) {
    _musicWork = _musicWork.then((_) async {
      await initialize();
      if (!_disposed && _available) await _safely(action);
    });
    return _musicWork;
  }

  Future<void> play(GameSound sound) async {
    final uiSound =
        sound == GameSound.confirm ||
        sound == GameSound.cancel ||
        sound == GameSound.pause;
    if (_disposed || (_paused && !uiSound) || _effectiveSfx == 0) return;
    final time = _elapsed();
    final previous = _lastSound[sound];
    if (previous != null && time - previous < AudioCatalog.minimumGap(sound)) {
      return;
    }
    _lastSound[sound] = time;
    await initialize();
    if (_disposed ||
        !_available ||
        (_paused && !uiSound) ||
        _effectiveSfx == 0) {
      return;
    }
    await _safely(
      () => _backend.playSound(AudioCatalog.sounds[sound]!, _effectiveSfx),
    );
  }

  Future<void> pause() {
    if (_disposed || _paused) return _musicWork;
    _paused = true;
    ++_musicGeneration;
    _lastSound.clear();
    return _enqueueMusic(() async {
      if (!_paused) return;
      await _backend.pauseMusic();
      await _backend.stopSounds();
    });
  }

  Future<void> resume() {
    if (_disposed || !_paused) return _musicWork;
    _paused = false;
    final generation = ++_musicGeneration;
    return _enqueueMusic(() => _transition(generation));
  }

  Future<void> setMusicVolume(double volume) async {
    if (_disposed) return;
    _editedSettings.add('musicVolume');
    _musicVolume = _clampVolume(volume);
    await _settingsChanged(music: true);
  }

  Future<void> setSfxVolume(double volume) async {
    if (_disposed) return;
    _editedSettings.add('sfxVolume');
    _sfxVolume = _clampVolume(volume);
    await _settingsChanged(music: false);
  }

  Future<void> setMusicMuted(bool muted) async {
    if (_disposed) return;
    _editedSettings.add('musicMuted');
    _musicMuted = muted;
    await _settingsChanged(music: true);
  }

  Future<void> setSfxMuted(bool muted) async {
    if (_disposed) return;
    _editedSettings.add('sfxMuted');
    _sfxMuted = muted;
    await _settingsChanged(music: false);
  }

  Future<void> _settingsChanged({required bool music}) async {
    final generation = ++_settingsGeneration;
    notifyListeners();
    // Serialize and coalesce rapid slider writes, preserving the newest value.
    _preferencesWork = _preferencesWork.then((_) async {
      await initialize();
      if (generation != _settingsGeneration) return;
      await _safely(
        () => _preferences.save(
          AudioSettings(
            musicVolume: _musicVolume,
            sfxVolume: _sfxVolume,
            musicMuted: _musicMuted,
            sfxMuted: _sfxMuted,
          ),
        ),
      );
    });
    await initialize();
    if (!_disposed && _available) {
      await _safely(
        () => music
            ? _backend.setMusicVolume(_musicGain * _effectiveMusic)
            : _backend.setSfxVolume(_effectiveSfx),
      );
    }
    await _preferencesWork;
  }

  static double _clampVolume(double volume) =>
      volume.isFinite ? volume.clamp(0, 1) : 0;

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _lastError = error;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _musicGeneration++;
    _disposal = Future.wait<void>([
      ?_initialization,
      _musicWork,
      _preferencesWork,
    ]).then((_) => _safely(_backend.dispose));
    unawaited(_disposal);
    super.dispose();
  }

  /// Allows native integration/host shutdown to await resource release.
  Future<void> close() {
    dispose();
    return _disposal!;
  }
}
