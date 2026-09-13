import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class GameAssets {
  GameAssets({
    required this.tiles,
    required this.orbs,
    required this.color1Walk,
    required this.color1Idle,
    required this.color2Walk,
    required this.color2Idle,
    required this.slimeIdle,
    required this.slimeWalkEast,
    required this.slimeWalkWest,
    required this.slimeWalkNorth,
    required this.slimeWalkSouth,
    required this.slimeAttack,
    required this.slimeDeath,
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
  static const String slimeIdlePath =
      'assets/characters/enemies/slime/Stanby.png';
  static const String slimeWalkEastPath =
      'assets/characters/enemies/slime/walk E1.png';
  static const String slimeWalkWestPath =
      'assets/characters/enemies/slime/walk w1.png';
  static const String slimeWalkNorthPath =
      'assets/characters/enemies/slime/Walk N1.png';
  static const String slimeWalkSouthPath =
      'assets/characters/enemies/slime/Walk S1.png';
  static const String slimeAttackPath =
      'assets/characters/enemies/slime/Atack.png';
  static const String slimeDeathPath =
      'assets/characters/enemies/slime/Death.png';
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
  final ui.Image slimeIdle;
  final ui.Image slimeWalkEast;
  final ui.Image slimeWalkWest;
  final ui.Image slimeWalkNorth;
  final ui.Image slimeWalkSouth;
  final ui.Image slimeAttack;
  final ui.Image slimeDeath;
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
      _loadImage(slimeIdlePath),
      _loadImage(slimeWalkEastPath),
      _loadImage(slimeWalkWestPath),
      _loadImage(slimeWalkNorthPath),
      _loadImage(slimeWalkSouthPath),
      _loadImage(slimeAttackPath),
      _loadImage(slimeDeathPath),
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
      slimeIdle: images[6],
      slimeWalkEast: images[7],
      slimeWalkWest: images[8],
      slimeWalkNorth: images[9],
      slimeWalkSouth: images[10],
      slimeAttack: images[11],
      slimeDeath: images[12],
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
    slimeIdle.dispose();
    slimeWalkEast.dispose();
    slimeWalkWest.dispose();
    slimeWalkNorth.dispose();
    slimeWalkSouth.dispose();
    slimeAttack.dispose();
    slimeDeath.dispose();
    xpGem.dispose();
    levelUp.dispose();
    orbImpact.dispose();
    fireShot.dispose();
    fireExplosion.dispose();
  }
}
