import 'dart:math' as math;
import 'dart:ui';

import '../models/arena.dart';
import '../models/game_camera.dart';
import '../models/slime_enemy.dart';

/// Spawn pressure is separate from enemy combat stats and stays bounded on mobile.
abstract final class EnemySpawnBalance {
  static const startingInterval = 2.8;
  static const minimumInterval = 0.9;
  static const startingEnemyLimit = 4;
  static const maximumEnemyLimit = 24;
  static const secondsPerTimePressure = 150.0;
  static const secondsPerEnemySlot = 20.0;
  static const pressurePerLevel = 0.08;
  static const levelsPerEnemySlot = 2;
  static const maximumContributingLevels = 12;
}

class EnemySpawner {
  EnemySpawner({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  double timeUntilNextSpawn = 1;

  double spawnIntervalFor(double survivalTime, {int playerLevel = 1}) {
    final timePressure =
        math.max(0.0, survivalTime) / EnemySpawnBalance.secondsPerTimePressure;
    final levelPressure =
        _levelSteps(playerLevel) * EnemySpawnBalance.pressurePerLevel;
    return math.max(
      EnemySpawnBalance.minimumInterval,
      EnemySpawnBalance.startingInterval / (1 + timePressure + levelPressure),
    );
  }

  int maximumEnemiesFor(double survivalTime, {int playerLevel = 1}) {
    final timeSlots =
        (math.max(0.0, survivalTime) / EnemySpawnBalance.secondsPerEnemySlot)
            .floor();
    final levelSlots =
        _levelSteps(playerLevel) ~/ EnemySpawnBalance.levelsPerEnemySlot;
    return math.min(
      EnemySpawnBalance.maximumEnemyLimit,
      EnemySpawnBalance.startingEnemyLimit + timeSlots + levelSlots,
    );
  }

  int _levelSteps(int playerLevel) {
    return (playerLevel - 1).clamp(
      0,
      EnemySpawnBalance.maximumContributingLevels,
    );
  }

  Offset? update({
    required double deltaTime,
    required double survivalTime,
    int playerLevel = 1,
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required Iterable<SlimeEnemy> existingEnemies,
  }) {
    if (camera.viewportSize.isEmpty) {
      return null;
    }

    timeUntilNextSpawn -= deltaTime;
    if (timeUntilNextSpawn > 0) {
      return null;
    }

    final visibleEnemies = existingEnemies.where((enemy) => enemy.isVisible);
    if (visibleEnemies.length >=
        maximumEnemiesFor(survivalTime, playerLevel: playerLevel)) {
      timeUntilNextSpawn = 0.3;
      return null;
    }

    final spawnPosition = _findSpawnPosition(
      arena: arena,
      camera: camera,
      playerPosition: playerPosition,
      existingEnemies: visibleEnemies,
    );
    // Start a fresh interval instead of catching up missed spawns after a slow
    // frame, a level-up pause, or a full enemy limit. One update adds at most one.
    timeUntilNextSpawn = spawnPosition == null
        ? 0.35
        : spawnIntervalFor(survivalTime, playerLevel: playerLevel);
    return spawnPosition;
  }

  Offset? _findSpawnPosition({
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required Iterable<SlimeEnemy> existingEnemies,
  }) {
    final validCenters = arena.walkableBounds.deflate(SlimeEnemy.radius);
    final cameraRect = Rect.fromLTWH(
      camera.position.dx,
      camera.position.dy,
      camera.viewportSize.width,
      camera.viewportSize.height,
    );
    final blockedVisibleRect = cameraRect.inflate(20);
    final enemies = existingEnemies.toList(growable: false);

    for (var attempt = 0; attempt < 28; attempt++) {
      const minimumBand = 64.0;
      final bandDistance = minimumBand + _random.nextDouble() * 64;
      late Offset candidate;
      switch (_random.nextInt(4)) {
        case 0:
          candidate = Offset(
            cameraRect.left - bandDistance,
            cameraRect.top + _random.nextDouble() * cameraRect.height,
          );
        case 1:
          candidate = Offset(
            cameraRect.right + bandDistance,
            cameraRect.top + _random.nextDouble() * cameraRect.height,
          );
        case 2:
          candidate = Offset(
            cameraRect.left + _random.nextDouble() * cameraRect.width,
            cameraRect.top - bandDistance,
          );
        default:
          candidate = Offset(
            cameraRect.left + _random.nextDouble() * cameraRect.width,
            cameraRect.bottom + bandDistance,
          );
      }

      if (!validCenters.contains(candidate) ||
          blockedVisibleRect.contains(candidate) ||
          !_isFarEnough(candidate, playerPosition, enemies)) {
        continue;
      }
      return candidate;
    }

    // Near arena corners, some off-camera bands fall outside the finite map.
    // A bounded fallback samples the walkable arena but keeps all safety rules.
    for (var attempt = 0; attempt < 36; attempt++) {
      final candidate = Offset(
        validCenters.left + _random.nextDouble() * validCenters.width,
        validCenters.top + _random.nextDouble() * validCenters.height,
      );
      if (blockedVisibleRect.contains(candidate) ||
          !_isFarEnough(candidate, playerPosition, enemies)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  bool _isFarEnough(
    Offset candidate,
    Offset playerPosition,
    List<SlimeEnemy> enemies,
  ) {
    if ((candidate - playerPosition).distance < 190) {
      return false;
    }
    const minimumEnemySpacing = SlimeEnemy.radius * 2 + 12;
    return enemies.every(
      (enemy) => (candidate - enemy.position).distance >= minimumEnemySpacing,
    );
  }
}
