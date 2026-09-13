import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'models/slime_enemy.dart';

class GameAssets {
  GameAssets({
    required this.tiles,
    required this.orbs,
    required this.color1Walk,
    required this.color1Idle,
    required this.color2Walk,
    required this.color2Idle,
    required this.slimeSheets,
    required this.xpGem,
    required this.levelUp,
    required this.orbImpact,
    required this.fireShot,
    required this.fireExplosion,
  });

  static const String color1WalkPath =
      'assets/characters/player_character/color_1/witchKitty_walk.png';
  static const String color1IdlePath =
      'assets/characters/player_character/color_1/'
      'witchKitty_curiousIdleBreaker.png';
  static const String color2WalkPath =
      'assets/characters/player_character/color_2/calicoKitty_walk.png';
  static const String color2IdlePath =
      'assets/characters/player_character/color_2/'
      'calicoKitty_curiousIdleBreaker.png';
  static const slimePaths = <SlimeColor, String>{
    SlimeColor.blue: 'assets/characters/enemies/slime_v2/Slime_Blue.png',
    SlimeColor.brown: 'assets/characters/enemies/slime_v2/Slime_Brown.png',
    SlimeColor.green: 'assets/characters/enemies/slime_v2/Slime_Green.png',
    SlimeColor.grey: 'assets/characters/enemies/slime_v2/Slime_Grey.png',
    SlimeColor.orange: 'assets/characters/enemies/slime_v2/Slime_Orange.png',
    SlimeColor.red: 'assets/characters/enemies/slime_v2/Slime_Red.png',
    SlimeColor.yellow: 'assets/characters/enemies/slime_v2/Slime_Yellow.png',
  };
  static const String orbsPath = 'assets/orbs/orbs-sheet.png';
  static const String tilesPath = 'assets/tileset/tiles.png';
  static const xpGemPath = 'assets/xp-gem/xp.png';
  static const levelUpPath =
      'assets/level-up-effect/Level Up Effect Spritesheet.png';
  static const orbImpactPath =
      'assets/orbs/orb-hit-effect/purple/purple-spritesheet.png';
  static const fireShotPath =
      'assets/orbs/fire-orb-projectile/ShotLoop-Sheet.png';
  static const fireExplosionPath =
      'assets/orbs/fire-orb-projectile/Explode-Sheet.png';

  final ui.Image tiles;
  final ui.Image orbs;
  final ui.Image color1Walk;
  final ui.Image color1Idle;
  final ui.Image color2Walk;
  final ui.Image color2Idle;
  final Map<SlimeColor, ui.Image> slimeSheets;
  final ui.Image xpGem;
  final ui.Image levelUp;
  final ui.Image orbImpact;
  final ui.Image fireShot;
  final ui.Image fireExplosion;

  static Future<GameAssets> load() async {
    final images = await Future.wait<ui.Image>([
      _loadImage(tilesPath),
      _loadImage(orbsPath),
      _loadImage(color1WalkPath),
      _loadImage(color1IdlePath),
      _loadImage(color2WalkPath),
      _loadImage(color2IdlePath),
      for (final color in SlimeColor.values) _loadImage(slimePaths[color]!),
      _loadImage(xpGemPath),
      _loadImage(levelUpPath),
      _loadImage(orbImpactPath),
      _loadImage(fireShotPath),
      _loadImage(fireExplosionPath),
    ], cleanUp: (image) => image.dispose());

    return GameAssets(
      tiles: images[0],
      orbs: images[1],
      color1Walk: images[2],
      color1Idle: images[3],
      color2Walk: images[4],
      color2Idle: images[5],
      slimeSheets: Map.unmodifiable({
        for (final color in SlimeColor.values) color: images[6 + color.index],
      }),
      xpGem: images[13],
      levelUp: images[14],
      orbImpact: images[15],
      fireShot: images[16],
      fireExplosion: images[17],
    );
  }

  static Future<ui.Image> _loadImage(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void dispose() {
    tiles.dispose();
    orbs.dispose();
    color1Walk.dispose();
    color1Idle.dispose();
    color2Walk.dispose();
    color2Idle.dispose();
    for (final sheet in slimeSheets.values) {
      sheet.dispose();
    }
    xpGem.dispose();
    levelUp.dispose();
    orbImpact.dispose();
    fireShot.dispose();
    fireExplosion.dispose();
  }
}
