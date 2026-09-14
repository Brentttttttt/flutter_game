import '../game/models/game_sound.dart';

enum MusicTrack { menu, attire, arena, bossWarning, boss }

/// Paths are relative to the existing assets/ directory. The spaces immediately
/// before .wav in three of the downloaded tracks are intentional.
abstract final class AudioCatalog {
  static const music = <MusicTrack, String>{
    MusicTrack.menu: 'bgm/xDeviruchi - Title Theme .wav',
    MusicTrack.attire: 'bgm/xDeviruchi - And The Journey Begins .wav',
    MusicTrack.arena: 'bgm/xDeviruchi - Exploring The Unknown.wav',
    MusicTrack.bossWarning: 'bgm/xDeviruchi - Prepare for Battle! .wav',
    MusicTrack.boss: 'bgm/xDeviruchi - Decisive Battle.wav',
  };

  static const sounds = <GameSound, String>{
    GameSound.meow: 'sfx/Cat_Meow.wav',
    GameSound.arcaneHit: 'sfx/Sword_Slash.wav',
    GameSound.fireShot: 'sfx/Gun.wav',
    GameSound.fireHit: 'sfx/Explosion.wav',
    GameSound.hurt: 'sfx/Hurt.wav',
    GameSound.powerUp: 'sfx/Powerup.wav',
    GameSound.confirm: 'sfx/Confirm.wav',
    GameSound.cancel: 'sfx/Cancel.wav',
    GameSound.pause: 'sfx/Pause.wav',
    GameSound.lowHealth: 'sfx/Low_Health.wav',
    GameSound.bossWarning: 'sfx/Siren.wav',
    GameSound.bossDefeated: 'sfx/Powerup.wav',
    GameSound.bossAttack: 'sfx/Monster_Scream.wav',
  };

  static Duration minimumGap(GameSound sound) => switch (sound) {
    GameSound.arcaneHit ||
    GameSound.fireHit => const Duration(milliseconds: 85),
    GameSound.fireShot => const Duration(milliseconds: 100),
    GameSound.hurt => const Duration(milliseconds: 220),
    GameSound.lowHealth || GameSound.bossWarning => const Duration(seconds: 1),
    _ => const Duration(milliseconds: 80),
  };

  static int voicesFor(String asset) => switch (asset) {
    'sfx/Sword_Slash.wav' || 'sfx/Explosion.wav' || 'sfx/Gun.wav' => 2,
    _ => 1,
  };
}
