import 'dart:math' as math;
import 'dart:ui';

import '../models/arena.dart';
import '../models/game_camera.dart';
import '../models/slime_enemy.dart';

class EnemySpawner {
  EnemySpawner({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  double timeUntilNextSpawn = 1;

  double spawnIntervalFor(double survivalTime) {
    return math.max(0.9, 2.8 / (1 + survivalTime / 150));
  }

  int maximumEnemiesFor(double survivalTime) {
    return math.min(24, 4 + (survivalTime / 20).floor());
  }

  Offset? update({
    required double deltaTime,
    required double survivalTime,
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
    if (visibleEnemies.length >= maximumEnemiesFor(survivalTime)) {
      timeUntilNextSpawn = 0.3;
      return null;
    }

    final spawnPosition = _findSpawnPosition(
      arena: arena,
      camera: camera,
      playerPosition: playerPosition,
      existingEnemies: visibleEnemies,
    );
    timeUntilNextSpawn = spawnPosition == null
        ? 0.35
        : spawnIntervalFor(survivalTime);
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
