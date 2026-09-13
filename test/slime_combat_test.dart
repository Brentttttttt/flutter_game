import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = Offset(400, 400);
  const left = Offset(360, 400);
  const right = Offset(440, 400);
  const farAway = Offset(600, 400);
  const playerRadius = 30.0;

  SlimeEnemy createSlime() =>
      SlimeEnemy(id: 1, position: origin, spawnDelayRemaining: 0);

  void advance(SlimeEnemy slime, double duration, Offset target) {
    slime.update(
      duration,
      playerPosition: target,
      playerRadius: playerRadius,
      arena: const Arena(),
    );
  }

  bool strike(SlimeEnemy slime, Offset target) => slime.consumeAttackHit(
    playerPosition: target,
    playerRadius: playerRadius,
  );

  test(
    'left attack stays original and right attack mirrors only that swing',
    () {
      final slime = createSlime();
      advance(slime, 0, left);
      expect(slime.activity, SlimeActivity.attacking);
      expect(slime.mirrorAttackHorizontally, isFalse);
      advance(slime, 0.1, right);
      expect(slime.mirrorAttackHorizontally, isFalse);
      expect(slime.facing, SlimeFacing.west);
      expect(slime.position, origin);

      advance(slime, SlimeEnemy.attackDuration, right);
      expect(slime.activity, SlimeActivity.idle);
      expect(slime.mirrorAttackHorizontally, isFalse);
      expect(slime.facing, SlimeFacing.east);
      final rightSlime = createSlime();
      advance(rightSlime, 0, right);
      expect(rightSlime.activity, SlimeActivity.attacking);
      expect(rightSlime.mirrorAttackHorizontally, isTrue);
      advance(rightSlime, 0.1, left);
      expect(rightSlime.mirrorAttackHorizontally, isTrue);
      expect(rightSlime.position, origin);
      advance(rightSlime, SlimeEnemy.attackDuration, left);
      expect(rightSlime.mirrorAttackHorizontally, isFalse);
      expect(rightSlime.facing, SlimeFacing.west);
      advance(rightSlime, 0.01, farAway);
      expect(rightSlime.activity, SlimeActivity.walking);
      expect(rightSlime.facing, SlimeFacing.east);
      expect(rightSlime.mirrorAttackHorizontally, isFalse);
    },
  );

  test('damage waits for the hit frame and is consumed once per swing', () {
    final slime = createSlime();
    advance(slime, 0, right);
    expect(strike(slime, right), isFalse);
    advance(slime, SlimeEnemy.attackHitTime - 0.01, right);
    expect(strike(slime, right), isFalse);
    advance(slime, 0.02, right);
    expect(slime.animationFrame, 4);
    expect(strike(slime, right), isTrue);
    expect(strike(slime, right), isFalse);
    advance(slime, 0.1, right);
    expect(strike(slime, right), isFalse);
  });

  test('moving out of range dodges without a late hit on returning', () {
    final slime = createSlime();
    advance(slime, 0, right);
    advance(slime, SlimeEnemy.attackHitTime, farAway);
    expect(strike(slime, farAway), isFalse);
    expect(strike(slime, right), isFalse);
    advance(slime, 0.1, right);
    expect(strike(slime, right), isFalse);
  });

  test('crossing behind an attack dodges its locked direction', () {
    final slime = createSlime();
    advance(slime, 0, right);
    advance(slime, SlimeEnemy.attackHitTime, left);
    expect(slime.mirrorAttackHorizontally, isTrue);
    expect(strike(slime, left), isFalse);
    expect(strike(slime, right), isFalse);
  });

  test('an ignored hit opportunity expires before the next update', () {
    final slime = createSlime();
    advance(slime, 0, left);
    advance(slime, SlimeEnemy.attackHitTime, left);
    advance(slime, 0.01, left);
    expect(strike(slime, left), isFalse);
  });

  test('attack cooldown prevents immediate repeat after recovery', () {
    final slime = createSlime();
    advance(slime, 0, left);
    advance(slime, SlimeEnemy.attackDuration, left);
    expect(slime.activity, SlimeActivity.idle);
    advance(slime, 0.4, left);
    expect(slime.activity, SlimeActivity.idle);
    advance(slime, 0.06, left);
    expect(slime.activity, SlimeActivity.attacking);
    expect(strike(slime, left), isFalse);
  });

  test('projectiles ignore orb cooldown and share one death transition', () {
    final slime = createSlime();
    expect(slime.takeOrbHit(10, 0.5), SlimeDamageResult.damaged);
    expect(slime.takeOrbHit(10, 0.5), SlimeDamageResult.none);
    expect(slime.takeProjectileHit(10), SlimeDamageResult.damaged);
    expect(slime.health.currentHealth, 10);
    advance(slime, 0, left);
    advance(slime, SlimeEnemy.attackHitTime, left);
    expect(slime.takeProjectileHit(10), SlimeDamageResult.defeated);
    expect(strike(slime, left), isFalse);
    expect(slime.takeProjectileHit(10), SlimeDamageResult.none);
    expect(slime.lifeState, SlimeLifeState.dying);
    expect(slime.isVisible, isTrue);
    advance(slime, SlimeEnemy.deathDuration, left);
    expect(slime.lifeState, SlimeLifeState.removed);
  });
}
