import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AudioSettings {
  const AudioSettings({
    this.musicVolume = 0.65,
    this.sfxVolume = 0.8,
    this.musicMuted = false,
    this.sfxMuted = false,
  });

  final double musicVolume;
  final double sfxVolume;
  final bool musicMuted;
  final bool sfxMuted;

  Map<String, Object> toJson() => {
    'musicVolume': musicVolume,
    'sfxVolume': sfxVolume,
    'musicMuted': musicMuted,
    'sfxMuted': sfxMuted,
  };

  factory AudioSettings.fromJson(Map<String, dynamic> values) {
    double volume(String key, double fallback) {
      final value = values[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(0, 1)
          : fallback;
    }

    return AudioSettings(
      musicVolume: volume('musicVolume', 0.65),
      sfxVolume: volume('sfxVolume', 0.8),
      musicMuted: values['musicMuted'] == true,
      sfxMuted: values['sfxMuted'] == true,
    );
  }
}

abstract interface class AudioPreferences {
  Future<AudioSettings> load();
  Future<void> save(AudioSettings settings);
}

class DeviceAudioPreferences implements AudioPreferences {
  static const storageKey = 'witch_kitty.audio.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<AudioSettings> load() async {
    final saved = await _preferences.getString(storageKey);
    if (saved == null) return const AudioSettings();
    try {
      final decoded = jsonDecode(saved);
      if (decoded is Map<String, dynamic>) {
        return AudioSettings.fromJson(decoded);
      }
    } on FormatException {
      // A corrupt preference should never prevent starting a run.
    }
    return const AudioSettings();
  }

  @override
  Future<void> save(AudioSettings settings) =>
      _preferences.setString(storageKey, jsonEncode(settings.toJson()));
}

class MemoryAudioPreferences implements AudioPreferences {
  MemoryAudioPreferences([this.settings = const AudioSettings()]);
  AudioSettings settings;

  @override
  Future<AudioSettings> load() async => settings;

  @override
  Future<void> save(AudioSettings settings) async => this.settings = settings;
}
