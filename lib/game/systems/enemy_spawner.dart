import 'dart:math' as math;
import 'dart:ui';

import '../models/arena.dart';
import '../models/game_camera.dart';
import '../models/slime_enemy.dart';

/// Spawn pressure is separate from enemy combat stats and stays bounded on mobile.
abstract final class EnemySpawnBalance {
  static const startingInterval = 2.8;
  static const minimumInterval = 0.16;
  static const startingEnemyLimit = 4;
  static const maximumEnemyLimit = 240;
  static const maximumBatchSize = 4;
  static const secondsPerTimePressure = 120.0;
  static const secondsPerLevelPressure = 300.0;
  static const pressurePerLevel = 0.08;
  static const enemiesPerMinute = 8.0;
  static const populationAcceleration = 0.2;
  static const minimumPlayerDistance = 190.0;
}

class EnemySpawner {
  EnemySpawner({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  double timeUntilNextSpawn = 1;
  double _batchRemainder = 0;

  double spawnIntervalFor(
    double survivalTime, {
    int playerLevel = 1,
    int bossesDefeated = 0,
  }) {
    final seconds = math.max(0.0, survivalTime);
    final timePressure = seconds / EnemySpawnBalance.secondsPerTimePressure;
    final levelPressure =
        math.max(0, playerLevel - 1) *
        EnemySpawnBalance.pressurePerLevel *
        (1 + seconds / EnemySpawnBalance.secondsPerLevelPressure);
    // Time and every gained level still matter late in a run. The interval
    // approaches its safety limit instead of flattening at an early hard floor.
    return EnemySpawnBalance.minimumInterval +
        (EnemySpawnBalance.startingInterval -
                EnemySpawnBalance.minimumInterval) /
            (1 +
                timePressure +
                levelPressure +
                math.max(0, bossesDefeated) * 0.12);
  }

  int maximumEnemiesFor(
    double survivalTime, {
    int playerLevel = 1,
    int bossesDefeated = 0,
  }) {
    final minutes = math.max(0.0, survivalTime) / 60;
    final openingRamp = 1 - math.exp(-minutes);
    final timeSlots =
        EnemySpawnBalance.enemiesPerMinute * minutes * openingRamp +
        EnemySpawnBalance.populationAcceleration * minutes * minutes;
    final levelSlots = math.max(0, playerLevel - 1) * (0.5 + minutes * 0.35);
    return math
        .min(
          EnemySpawnBalance.maximumEnemyLimit.toDouble(),
          EnemySpawnBalance.startingEnemyLimit +
              timeSlots +
              levelSlots +
              math.max(0, bossesDefeated) * 2,
        )
        .floor();
  }

  double expectedBatchSizeFor(
    double survivalTime, {
    int playerLevel = 1,
    int bossesDefeated = 0,
  }) {
    final minutes = math.max(0.0, survivalTime) / 60;
    final openingRamp = 1 - math.exp(-minutes);
    final pressure =
        minutes / 10 +
        math.max(0, playerLevel - 1) * 0.04 * openingRamp +
        math.max(0, bossesDefeated) * 0.04;
    return 1 +
        (EnemySpawnBalance.maximumBatchSize - 1) * (1 - math.exp(-pressure));
  }

  /// Compatibility path for callers that explicitly want one spawn at a time.
  Offset? update({
    required double deltaTime,
    required double survivalTime,
    int playerLevel = 1,
    int bossesDefeated = 0,
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required Iterable<SlimeEnemy> existingEnemies,
  }) {
    final positions = _updateBatch(
      deltaTime: deltaTime,
      survivalTime: survivalTime,
      playerLevel: playerLevel,
      bossesDefeated: bossesDefeated,
      arena: arena,
      camera: camera,
      playerPosition: playerPosition,
      existingEnemies: existingEnemies,
      allowBatch: false,
    );
    return positions.isEmpty ? null : positions.first;
  }

  List<Offset> updateBatch({
    required double deltaTime,
    required double survivalTime,
    int playerLevel = 1,
    int bossesDefeated = 0,
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required Iterable<SlimeEnemy> existingEnemies,
  }) => _updateBatch(
    deltaTime: deltaTime,
    survivalTime: survivalTime,
    playerLevel: playerLevel,
    bossesDefeated: bossesDefeated,
    arena: arena,
    camera: camera,
    playerPosition: playerPosition,
    existingEnemies: existingEnemies,
    allowBatch: true,
  );

  List<Offset> _updateBatch({
    required double deltaTime,
    required double survivalTime,
    required int playerLevel,
    required int bossesDefeated,
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required Iterable<SlimeEnemy> existingEnemies,
    required bool allowBatch,
  }) {
    if (camera.viewportSize.isEmpty || !deltaTime.isFinite || deltaTime <= 0) {
      return const [];
    }
    timeUntilNextSpawn -= deltaTime;
    if (timeUntilNextSpawn > 0) return const [];

    final occupied = existingEnemies
        .where((enemy) => enemy.isVisible)
        .map((enemy) => enemy.position)
        .toList();
    final availableSlots =
        maximumEnemiesFor(
          survivalTime,
          playerLevel: playerLevel,
          bossesDefeated: bossesDefeated,
        ) -
        occupied.length;
    if (availableSlots <= 0) {
      timeUntilNextSpawn = 0.3;
      _batchRemainder = 0;
      return const [];
    }

    var requested = 1;
    if (allowBatch) {
      final budget =
          expectedBatchSizeFor(
            survivalTime,
            playerLevel: playerLevel,
            bossesDefeated: bossesDefeated,
          ) +
          _batchRemainder;
      requested = math.min(EnemySpawnBalance.maximumBatchSize, budget.floor());
      // Only the fractional part carries over; population limits and failed
      // placements never accumulate a debt of enemies to release later.
      _batchRemainder = budget - budget.floor();
    }
    final positions = <Offset>[];
    for (var index = 0; index < math.min(requested, availableSlots); index++) {
      final candidate = _findSpawnPosition(
        arena: arena,
        camera: camera,
        playerPosition: playerPosition,
        occupiedPositions: occupied,
      );
      if (candidate == null) break;
      positions.add(candidate);
      occupied.add(
        candidate,
      ); // Every member of this batch also reserves space.
    }
    // A long frame emits one bounded batch and starts a fresh interval. Never
    // catch up elapsed events after pauses, boss wind-downs, or device stalls.
    timeUntilNextSpawn = positions.isEmpty
        ? 0.35
        : spawnIntervalFor(
            survivalTime,
            playerLevel: playerLevel,
            bossesDefeated: bossesDefeated,
          );
    return positions;
  }

  Offset? _findSpawnPosition({
    required Arena arena,
    required GameCamera camera,
    required Offset playerPosition,
    required List<Offset> occupiedPositions,
  }) {
    final validCenters = arena.walkableBounds.deflate(SlimeEnemy.radius);
    final cameraRect = Rect.fromLTWH(
      camera.position.dx,
      camera.position.dy,
      camera.viewportSize.width,
      camera.viewportSize.height,
    );
    final blockedVisibleRect = cameraRect.inflate(20);

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
          !_isFarEnough(candidate, playerPosition, occupiedPositions)) {
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
          !_isFarEnough(candidate, playerPosition, occupiedPositions)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  bool _isFarEnough(
    Offset candidate,
    Offset playerPosition,
    List<Offset> occupiedPositions,
  ) {
    if ((candidate - playerPosition).distanceSquared <
        EnemySpawnBalance.minimumPlayerDistance *
            EnemySpawnBalance.minimumPlayerDistance) {
      return false;
    }
    const minimumEnemySpacing = SlimeEnemy.radius * 2 + 12;
    return occupiedPositions.every(
      (position) =>
          (candidate - position).distanceSquared >=
          minimumEnemySpacing * minimumEnemySpacing,
    );
  }
}
