import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_game/game/game_world.dart';
import 'package:flutter_game/game/models/arena.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'spawns choose all seven colors independently of upgrade randomness',
    () {
      final world = GameWorld(
        spawningEnabled: false,
        random: math.Random(7),
        colorRandom: math.Random(24),
      );
      final control = GameWorld(spawningEnabled: false, random: math.Random(7));
      final counts = <SlimeColor, int>{};
      for (var index = 0; index < 350; index++) {
        final slime = world.spawnSlimeAt(const Offset(200, 200));
        counts.update(slime.color, (count) => count + 1, ifAbsent: () => 1);
      }
      expect(counts.keys, unorderedEquals(SlimeColor.values));
      expect(counts.values.every((count) => count > 20 && count < 80), isTrue);
      world.awardXp(world.player.stats.xpRequired);
      control.awardXp(control.player.stats.xpRequired);
      expect(
        world.upgradeChoices.map((upgrade) => upgrade.id),
        control.upgradeChoices.map((upgrade) => upgrade.id),
      );
    },
  );

  test(
    'all colors share movement, strike timing, damage, and death duration',
    () {
      for (final color in SlimeColor.values) {
        final slime = SlimeEnemy(
          id: color.index,
          color: color,
          position: const Offset(400, 400),
          spawnDelayRemaining: 0,
        );
        void update(double time, Offset target) => slime.update(
          time,
          playerPosition: target,
          playerRadius: 30,
          arena: const Arena(),
        );

        update(0.1, const Offset(600, 400));
        expect(slime.position.dx, closeTo(406.2, 0.00001));
        expect(slime.mirrorHorizontally, isTrue);
        final target = slime.position + const Offset(40, 0);
        update(0.399, target);
        expect(
          slime.consumeAttackHit(playerPosition: target, playerRadius: 30),
          isFalse,
        );
        update(0.001, target);
        expect(
          slime.consumeAttackHit(playerPosition: target, playerRadius: 30),
          isTrue,
        );
        expect(
          slime.consumeAttackHit(playerPosition: target, playerRadius: 30),
          isFalse,
        );
        expect(slime.sourceRect, const Rect.fromLTWH(128, 64, 32, 32));
        update(0.401, target);
        expect(slime.activity, SlimeActivity.idle);
        expect(slime.health.currentHealth, 30);
        expect(slime.damage, 10);
        expect(slime.takeOrbHit(10, 0.5), SlimeDamageResult.damaged);
        expect(slime.takeOrbHit(10, 0.5), SlimeDamageResult.none);
        expect(slime.takeProjectileHit(20), SlimeDamageResult.defeated);
        final seenDeathFrames = <int>{slime.deathFrame};
        for (var frame = 0; frame < 59; frame++) {
          update(0.01, target);
          seenDeathFrames.add(slime.deathFrame);
          expect(slime.sourceRect.top, 96);
          expect(slime.isVisible, isTrue);
        }
        expect(seenDeathFrames, unorderedEquals(List.generate(9, (i) => i)));
        update(0.011, target);
        expect(slime.lifeState, SlimeLifeState.removed);
      }
    },
  );

  test(
    'idle and walk loop only occupied cells; attacks play all nine cells',
    () {
      final slime = SlimeEnemy(id: 1, position: Offset.zero);
      for (final activity in [SlimeActivity.idle, SlimeActivity.walking]) {
        slime.activity = activity;
        final seen = <int>{};
        for (var tick = 0; tick < 180; tick++) {
          slime.animationTime = tick / 60;
          seen.add(slime.animationFrame);
          expect(slime.sourceRect.top, activity == SlimeActivity.idle ? 0 : 32);
          expect(slime.animationFrame, inInclusiveRange(0, 5));
        }
        expect(seen, unorderedEquals(List.generate(6, (i) => i)));
      }
      slime.activity = SlimeActivity.attacking;
      final attackFrames = <int>{};
      for (var tick = 0; tick < 48; tick++) {
        slime.animationTime = tick / 60;
        attackFrames.add(slime.animationFrame);
        expect(slime.sourceRect.top, 64);
      }
      expect(attackFrames, unorderedEquals(List.generate(9, (i) => i)));
    },
  );
}
