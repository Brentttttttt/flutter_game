import 'dart:math' as math;

import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/dino_tri.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_test/flutter_test.dart';

const _arena = Arena();
const _origin = Offset(700, 700);
const _playerRadius = 18.0;

void _update(DinoTri boss, double dt, Offset player) => boss.update(
  dt,
  playerPosition: player,
  playerRadius: _playerRadius,
  arena: _arena,
);
int _consume(DinoTri boss, Offset player) =>
    boss.consumeAttackHit(playerPosition: player, playerRadius: _playerRadius);

DinoTri _readyBoss() => DinoTri(id: -1, position: _origin, encounterNumber: 1)
  ..activity = DinoActivity.chasing
  ..attackCooldownRemaining = 0
  ..rangedCooldownRemaining = 999
  ..abilityCooldownRemaining = 999;

void main() {
  test(
    'native right / mirrored left attack holds its body anchor and facing',
    () {
      for (final right in [false, true]) {
        final boss = _readyBoss();
        final target = _origin + Offset(right ? 80 : -80, 0);
        _update(boss, 0.001, target);
        expect(boss.activity, DinoActivity.preparing);
        expect(boss.mirrorHorizontally, !right);
        final fixedOrigin = boss.position;
        final fixedDestination = boss.destinationRect;
        _update(boss, 0.52, target);
        expect(boss.activity, DinoActivity.attackingA);
        _update(boss, 0.9, _origin + Offset(right ? -80 : 80, 0));
        expect(boss.mirrorHorizontally, !right);
        expect(boss.position, fixedOrigin);
        expect(boss.destinationRect, fixedDestination);
        expect(_consume(boss, _origin + Offset(right ? -80 : 80, 0)), 0);
        _update(boss, 1.2, _origin + Offset(right ? -220 : 220, 0));
        expect(boss.activity, DinoActivity.chasing);
        expect(boss.mirrorHorizontally, right);
      }
    },
  );

  test('close attack strikes once at authored release and can be dodged', () {
    final boss = _readyBoss();
    final player = _origin + const Offset(80, 0);
    _update(boss, 0.001, player);
    expect(boss.attackSequence, 1);
    expect(boss.attackTelegraph, isNotNull);
    _update(boss, 0.52, player);
    _update(boss, 0.75, player);
    expect(_consume(boss, player), 0);
    _update(boss, 0.15, player);
    expect(boss.animationFrame, greaterThanOrEqualTo(17));
    expect(_consume(boss, player), 18);
    expect(_consume(boss, player), 0);
    _update(boss, 0.15, player);
    expect(_consume(boss, player), 0);
    expect(boss.attackTelegraph, isNull);

    final dodged = _readyBoss();
    _update(dodged, 0.001, player);
    _update(dodged, 0.52, player);
    _update(dodged, 0.9, player + const Offset(0, 90));
    expect(_consume(dodged, player + const Offset(0, 90)), 0);
    // Reentering after a miss cannot turn it into delayed damage.
    _update(dodged, 0.05, player);
    expect(_consume(dodged, player), 0);
  });

  test(
    'strong red attack warns first and sideways movement dodges its line',
    () {
      for (final dodge in [false, true]) {
        final boss = _readyBoss()
          ..attackCooldownRemaining = 999
          ..rangedCooldownRemaining = 0;
        final player = _origin + const Offset(210, 0);
        _update(boss, 0.001, player);
        expect(boss.attackTelegraph!.strong, isTrue);
        _update(boss, 0.52, player);
        expect(boss.animation, DinoAnimation.attackB);
        _update(boss, 0.9, player);
        expect(_consume(boss, player), 0);
        final destination = dodge ? player + const Offset(0, 100) : player;
        _update(boss, 0.4, destination);
        expect(_consume(boss, destination), dodge ? 0 : 28);
        expect(_consume(boss, destination), 0);
      }
    },
  );

  test(
    'melee and charge connect in all eight directions with one hit each',
    () {
      for (var index = 0; index < 8; index++) {
        final angle = index * math.pi / 4;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final melee = _readyBoss();
        final closeTarget = _origin + direction * 80;
        _update(melee, 0.001, closeTarget);
        expect((melee.attackDirection - direction).distance, lessThan(0.00001));
        expect(melee.attackTarget, closeTarget);
        _update(melee, 0.52, closeTarget);
        _update(melee, 0.9, closeTarget);
        expect(
          _consume(melee, closeTarget),
          18,
          reason: 'Melee direction $index',
        );
        expect(_consume(melee, closeTarget), 0);

        final charge = _readyBoss()
          ..attackCooldownRemaining = 999
          ..rangedCooldownRemaining = 0;
        final distantTarget = _origin + direction * 210;
        _update(charge, 0.001, distantTarget);
        final warning = charge.attackTelegraph!;
        expect((warning.end - distantTarget).distance, lessThan(0.00001));
        _update(charge, 0.52, distantTarget);
        _update(charge, 0.8, distantTarget);
        expect(
          charge.position,
          _origin,
          reason: 'Charge must wait for its warning',
        );
        // A single slow update spans the entire dash, testing swept collision.
        _update(charge, 0.55, distantTarget);
        expect((charge.position - distantTarget).distance, lessThan(0.00001));
        expect(
          _consume(charge, distantTarget),
          28,
          reason: 'Charge direction $index',
        );
        expect(_consume(charge, distantTarget), 0);
        _update(charge, 0.1, distantTarget);
        expect(_consume(charge, distantTarget), 0);
      }
    },
  );

  test(
    'every charge direction stays committed when the player dodges sideways',
    () {
      for (var index = 0; index < 8; index++) {
        final angle = index * math.pi / 4;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final sideways = Offset(-direction.dy, direction.dx);
        final boss = _readyBoss()
          ..attackCooldownRemaining = 999
          ..rangedCooldownRemaining = 0;
        final target = _origin + direction * 210;
        _update(boss, 0.001, target);
        final lockedTarget = boss.attackTarget;
        final lockedDirection = boss.attackDirection;
        _update(boss, 0.52, target);
        final dodged = target + sideways * 120;
        _update(boss, 1.35, dodged);
        expect(_consume(boss, dodged), 0, reason: 'Dodge direction $index');
        expect(boss.attackTarget, lockedTarget);
        expect(boss.attackDirection, lockedDirection);
        expect((boss.position - target).distance, lessThan(0.001));
      }
    },
  );

  test('charge uses a modest capped velocity lead, never leads melee', () {
    for (final enraged in [false, true]) {
      final boss = _readyBoss()
        ..attackCooldownRemaining = 999
        ..rangedCooldownRemaining = 0;
      if (enraged) boss.takeProjectileHit(550);
      final target = _origin + const Offset(210, 0);
      boss.update(
        0.001,
        playerPosition: target,
        playerRadius: _playerRadius,
        arena: _arena,
        playerVelocity: const Offset(0, 170),
      );
      expect(boss.attackTarget.dx, target.dx);
      expect(
        boss.attackTarget.dy - target.dy,
        closeTo(enraged ? 61.2 : 51, 0.001),
      );
      final warning = boss.attackTelegraph!;
      boss.update(
        0.52,
        playerPosition: target + const Offset(-100, -100),
        playerRadius: _playerRadius,
        arena: _arena,
        playerVelocity: const Offset(-170, 0),
      );
      expect(boss.attackTelegraph!.end, warning.end);
    }
    final capped = _readyBoss()
      ..attackCooldownRemaining = 999
      ..rangedCooldownRemaining = 0;
    final target = _origin + const Offset(180, 0);
    capped.update(
      0.001,
      playerPosition: target,
      playerRadius: _playerRadius,
      arena: _arena,
      playerVelocity: const Offset(0, 10000),
    );
    expect((capped.attackTarget - target).distance, closeTo(64, 0.001));
    final melee = _readyBoss();
    final closeTarget = _origin + const Offset(60, 0);
    melee.update(
      0.001,
      playerPosition: closeTarget,
      playerRadius: _playerRadius,
      arena: _arena,
      playerVelocity: const Offset(0, 170),
    );
    expect(melee.attackTarget, closeTarget);
  });

  test('predicted Thought marker and charge stay inside arena at walls', () {
    for (final ability in [false, true]) {
      final boss = _readyBoss()
        ..position = const Offset(1370, 1190)
        ..attackCooldownRemaining = 999
        ..rangedCooldownRemaining = ability ? 999 : 0
        ..abilityCooldownRemaining = ability ? 0 : 999;
      const target = Offset(1470, 1260);
      boss.update(
        0.001,
        playerPosition: target,
        playerRadius: _playerRadius,
        arena: _arena,
        playerVelocity: const Offset(300, 300),
      );
      final expectedRadius = ability ? DinoHazard.radius : DinoTri.radius;
      expect(
        _arena.clampCircle(boss.attackTarget, expectedRadius),
        boss.attackTarget,
      );
      final captured = boss.attackTarget;
      _update(boss, 0.52, target);
      if (ability) {
        expect(boss.hazards.single.position, captured);
        _update(boss, 1.0, const Offset(100, 100));
        expect(boss.hazards.single.position, captured);
      } else {
        _update(boss, 1.35, target);
        expect(
          _arena.clampCircle(boss.position, DinoTri.radius),
          boss.position,
        );
        expect(boss.position, captured);
      }
    }
  });

  test('Thought marks captured world position then splashes once', () {
    final boss = _readyBoss()..abilityCooldownRemaining = 0;
    final target = _origin + const Offset(160, 80);
    _update(boss, 0.001, target);
    _update(boss, 0.52, target);
    expect(boss.animation, DinoAnimation.thought);
    expect(boss.hazards.single.position, target);
    expect(boss.hazards.single.isWarning, isTrue);
    _update(boss, 1.1, target + const Offset(180, 0));
    expect(boss.hazards.single.position, target);
    expect(_consume(boss, target), 0);
    _update(boss, 0.12, target);
    expect(_consume(boss, target), 22);
    expect(_consume(boss, target), 0);
    _update(boss, 0.7, target);
    expect(boss.hazards, isEmpty);
  });

  test(
    'enrage is mild and later encounters scale with bounded speed/cooldowns',
    () {
      final first = _readyBoss();
      final baseSpeed = first.movementSpeed;
      final baseCooldown = first.cooldownMultiplier;
      first.takeProjectileHit(first.health.maxHealth ~/ 2);
      expect(first.isEnraged, isTrue);
      expect(first.movementSpeed, closeTo(baseSpeed * 1.15, 0.001));
      expect(first.cooldownMultiplier, closeTo(baseCooldown * 0.86, 0.001));
      final second = DinoTriStats(2);
      final third = DinoTriStats(3);
      final distant = DinoTriStats(1000);
      expect(second.maxHealth, 1430);
      expect(third.maxHealth, 1760);
      expect(second.attackADamage, greaterThan(first.stats.attackADamage));
      expect(second.movementSpeed, closeTo(58 * 1.03, 0.001));
      expect(distant.movementSpeed, lessThan(80));
      expect(distant.cooldownMultiplier, 0.65);
      expect(distant.maxHealth, greaterThan(third.maxHealth));
    },
  );

  test(
    'orb cooldown, projectile damage, and defeat cancel all boss attacks',
    () {
      final boss = _readyBoss();
      expect(boss.takeOrbHit(10, 0.35), SlimeDamageResult.damaged);
      expect(boss.takeOrbHit(10, 0.35), SlimeDamageResult.none);
      expect(boss.takeProjectileHit(20), SlimeDamageResult.damaged);
      expect(boss.health.currentHealth, 1070);
      boss.hazards.add(DinoHazard(position: _origin, damage: 22)..update(1.3));
      expect(boss.takeProjectileHit(1070), SlimeDamageResult.defeated);
      expect(boss.isActive, isFalse);
      expect(boss.isVisible, isTrue);
      expect(boss.animation, DinoAnimation.sitEnd);
      expect(boss.hazards, isEmpty);
      expect(_consume(boss, _origin), 0);
      expect(boss.takeProjectileHit(999), SlimeDamageResult.none);
      _update(boss, 0.8, _origin);
      expect(boss.opacity, lessThan(0.5));
      _update(boss, 0.3, _origin);
      expect(boss.isVisible, isFalse);
    },
  );
}
