import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../game_assets.dart';
import '../game_world.dart';
import '../models/player.dart';
import '../models/slime_enemy.dart';
import '../models/dino_tri.dart';
import '../models/magic_orb.dart';
import '../models/combat_effect.dart';
import '../models/player_stats.dart';
import 'vfx_layout.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.world,
    required this.assets,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameWorld world;
  final GameAssets assets;

  static const double _sourceTileSize = 16;
  static const ui.Rect _lightGreenFloorSource = ui.Rect.fromLTWH(
    16,
    64,
    _sourceTileSize,
    _sourceTileSize,
  );

  final ui.Paint _spritePaint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawColor(const ui.Color(0xFF233A36), ui.BlendMode.src);
    canvas.save();
    canvas.clipRect(ui.Offset.zero & size);

    final maximumCameraX = math.max(0.0, world.arena.size.width - size.width);
    final maximumCameraY = math.max(0.0, world.arena.size.height - size.height);
    final cameraPosition = ui.Offset(
      world.camera.position.dx
          .roundToDouble()
          .clamp(0.0, maximumCameraX)
          .toDouble(),
      world.camera.position.dy
          .roundToDouble()
          .clamp(0.0, maximumCameraY)
          .toDouble(),
    );
    canvas.translate(-cameraPosition.dx, -cameraPosition.dy);

    _drawArena(canvas, size, cameraPosition);
    _drawBossTelegraphs(canvas);
    _drawLevelUpEffect(canvas);
    _drawWorldEntities(canvas, size, cameraPosition);
    _drawCombatEffects(canvas);
    canvas.restore();
  }

  void _drawArena(
    ui.Canvas canvas,
    ui.Size viewportSize,
    ui.Offset cameraPosition,
  ) {
    final tileSize = world.arena.tileSize;
    final visible = ui.Rect.fromLTWH(
      cameraPosition.dx,
      cameraPosition.dy,
      viewportSize.width,
      viewportSize.height,
    ).inflate(tileSize);

    final firstColumn = math.max(0, (visible.left / tileSize).floor());
    final lastColumn = math.min(
      world.arena.columns - 1,
      (visible.right / tileSize).ceil(),
    );
    final firstRow = math.max(0, (visible.top / tileSize).floor());
    final lastRow = math.min(
      world.arena.rows - 1,
      (visible.bottom / tileSize).ceil(),
    );

    for (var row = firstRow; row <= lastRow; row++) {
      for (var column = firstColumn; column <= lastColumn; column++) {
        final isBoundary =
            row == 0 ||
            column == 0 ||
            row == world.arena.rows - 1 ||
            column == world.arena.columns - 1;
        final source = isBoundary
            ? _darkGreenBoundarySource(column, row)
            : _lightGreenFloorSource;
        final destination = ui.Rect.fromLTWH(
          column * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawImageRect(assets.tiles, source, destination, _spritePaint);
      }
    }
  }

  ui.Rect _darkGreenBoundarySource(int column, int row) {
    final sourceColumn = column == 0
        ? 0
        : column == world.arena.columns - 1
        ? 2
        : 1;
    final sourceRow = row == 0
        ? 0
        : row == world.arena.rows - 1
        ? 2
        : 1;

    return ui.Rect.fromLTWH(
      sourceColumn * _sourceTileSize,
      96 + sourceRow * _sourceTileSize,
      _sourceTileSize,
      _sourceTileSize,
    );
  }

  void _drawWorldEntities(
    ui.Canvas canvas,
    ui.Size viewportSize,
    ui.Offset cameraPosition,
  ) {
    final visibleWorld = ui.Rect.fromLTWH(
      cameraPosition.dx,
      cameraPosition.dy,
      viewportSize.width,
      viewportSize.height,
    ).inflate(80);
    final visibleSlimes = world.enemies
        .where(
          (enemy) => enemy.isVisible && visibleWorld.contains(enemy.position),
        )
        .toList(growable: false);

    for (final gem in world.xpGems) {
      if (!visibleWorld.contains(gem.position)) continue;
      canvas.drawImageRect(
        assets.xpGem,
        ui.Rect.fromLTWH(gem.animationFrame * 16, 0, 16, 16),
        ui.Rect.fromCenter(
          center: _snapOffset(gem.position),
          width: 16,
          height: 16,
        ),
        _spritePaint,
      );
    }

    _drawShadow(canvas, world.player.position, 28);
    for (final slime in visibleSlimes) {
      _drawShadow(canvas, slime.position, 26, yOffset: 17);
    }
    final boss = world.boss;
    if (boss != null && boss.isVisible) {
      _drawShadow(canvas, boss.position, 84, yOffset: 34);
    }

    final drawables = <_WorldDrawable>[
      _WorldDrawable.player(world.player.position.dy),
      for (final orb in world.orbs)
        _WorldDrawable.orb(orb.positionAround(world.player.position).dy, orb),
      for (final slime in visibleSlimes)
        _WorldDrawable.slime(slime.position.dy, slime),
      if (boss != null && boss.isVisible)
        _WorldDrawable.boss(boss.position.dy, boss),
    ]..sort((first, second) => first.worldY.compareTo(second.worldY));

    for (final drawable in drawables) {
      switch (drawable.type) {
        case _DrawableType.player:
          _drawPlayer(canvas);
        case _DrawableType.slime:
          _drawSlime(canvas, drawable.slime!);
        case _DrawableType.orb:
          _drawOrb(canvas, drawable.orb!);
        case _DrawableType.boss:
          _drawBoss(canvas, drawable.boss!);
      }
    }
    for (final projectile in world.projectiles) {
      if (!visibleWorld.contains(projectile.position)) continue;
      final center = _snapOffset(projectile.position);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      // ShotLoop's flame points up, so add a quarter turn to atan2.
      canvas.rotate(
        math.atan2(projectile.direction.dy, projectile.direction.dx) +
            math.pi / 2,
      );
      canvas.drawImageRect(
        assets.fireShot,
        ui.Rect.fromLTWH(projectile.animationFrame * 64, 0, 64, 64),
        const ui.Rect.fromLTWH(
          -VfxLayout.fireProjectileSize / 2,
          -VfxLayout.fireProjectileSize / 2,
          VfxLayout.fireProjectileSize,
          VfxLayout.fireProjectileSize,
        ),
        _spritePaint,
      );
      canvas.restore();
    }
  }

  void _drawShadow(
    ui.Canvas canvas,
    ui.Offset center,
    double width, {
    double yOffset = 24,
  }) {
    final snappedCenter = _snapOffset(center + ui.Offset(0, yOffset));
    canvas.drawRect(
      ui.Rect.fromCenter(center: snappedCenter, width: width, height: 6),
      ui.Paint()
        ..isAntiAlias = false
        ..color = const ui.Color(0x55314B36),
    );
  }

  void _drawPlayer(ui.Canvas canvas) {
    const frameSize = 64.0;
    late final ui.Image sheet;
    late final ui.Rect source;

    if (world.player.isMoving) {
      sheet = world.player.palette == PlayerPalette.color1
          ? assets.color1Walk
          : assets.color2Walk;
      source = ui.Rect.fromLTWH(
        world.player.walkFrame * frameSize,
        world.player.walkRow * frameSize,
        frameSize,
        frameSize,
      );
    } else if (world.player.palette == PlayerPalette.color1) {
      const columns = 3;
      final frame = world.player.idleFrame(12);
      sheet = assets.color1Idle;
      source = ui.Rect.fromLTWH(
        (frame % columns) * frameSize,
        (frame ~/ columns) * frameSize,
        frameSize,
        frameSize,
      );
    } else {
      const columns = 5;
      final frame = world.player.idleFrame(10);
      sheet = assets.color2Idle;
      source = ui.Rect.fromLTWH(
        (frame % columns) * frameSize,
        (frame ~/ columns) * frameSize,
        frameSize,
        frameSize,
      );
    }

    final destination = ui.Rect.fromCenter(
      center: _snapOffset(world.player.position),
      width: frameSize,
      height: frameSize,
    );
    canvas.drawImageRect(sheet, source, destination, _spritePaint);
    if (world.player.damageFlashTime > 0) {
      canvas.drawImageRect(
        sheet,
        source,
        destination,
        _flashPaint(const ui.Color(0xCCFFF1A8)),
      );
    }
  }

  void _drawSlime(ui.Canvas canvas, SlimeEnemy slime) {
    final sheet = assets.slimeSheets[slime.color]!;
    final source = slime.sourceRect;
    final center = _snapOffset(slime.position);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (slime.mirrorHorizontally) canvas.scale(-1, 1);
    final destination = ui.Rect.fromCenter(
      center: ui.Offset.zero,
      width: SlimeEnemy.renderSize,
      height: SlimeEnemy.renderSize,
    );
    canvas.drawImageRect(sheet, source, destination, _spritePaint);
    if (slime.hurtFlashTime > 0 && slime.isActive) {
      canvas.drawImageRect(
        sheet,
        source,
        destination,
        _flashPaint(const ui.Color(0xCCFFFFFF)),
      );
    }
    canvas.restore();
  }

  void _drawOrb(ui.Canvas canvas, MagicOrb orb) {
    final position = orb.positionAround(world.player.position);
    final destination = ui.Rect.fromCenter(
      center: _snapOffset(position),
      width: MagicOrb.renderSize,
      height: MagicOrb.renderSize,
    );
    canvas.drawImageRect(
      assets.orbs,
      orb.sourceRectForFrame(orb.animationFrame),
      destination,
      _spritePaint,
    );
  }

  void _drawBoss(ui.Canvas canvas, DinoTri boss) {
    final center = _snapOffset(boss.position);
    if (boss.attackDirection.dy < 0) _drawBossDirectionalEffect(canvas, boss);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (boss.mirrorHorizontally) canvas.scale(-1, 1);
    final sheet = assets.dinoSheets[boss.animation]!;
    final paint = ui.Paint()
      ..isAntiAlias = false
      ..filterQuality = ui.FilterQuality.none
      ..color = ui.Color.fromRGBO(255, 255, 255, boss.opacity);
    canvas.drawImageRect(
      sheet,
      boss.bodySourceRect,
      boss.bodyDestinationRect,
      paint,
    );
    if (boss.hurtFlashTime > 0 && boss.isActive) {
      canvas.drawImageRect(
        sheet,
        boss.bodySourceRect,
        boss.bodyDestinationRect,
        _flashPaint(const ui.Color(0xCCFFFFFF)),
      );
    }
    canvas.restore();
    if (boss.attackDirection.dy >= 0) _drawBossDirectionalEffect(canvas, boss);
  }

  void _drawBossDirectionalEffect(ui.Canvas canvas, DinoTri boss) {
    if (!boss.hasDirectionalEffect) return;
    final charge = boss.activity == DinoActivity.attackingB;
    final center = _snapOffset(boss.position);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate only the isolated authored spit, never Dino's body or face.
    canvas.rotate(math.atan2(boss.attackDirection.dy, boss.attackDirection.dx));
    canvas.drawImageRect(
      assets.dinoSheets[charge
          ? DinoAnimation.attackB
          : DinoAnimation.attackA]!,
      ui.Rect.fromLTWH(boss.attackEffectFrame * 384 + 240, 56, 144, 72),
      ui.Rect.fromLTWH(charge ? -88 : DinoTri.radius + 14, -40, 144, 72),
      _spritePaint,
    );
    canvas.restore();
  }

  void _drawBossTelegraphs(ui.Canvas canvas) {
    final boss = world.boss;
    if (boss == null || !boss.isActive) return;
    final warning = boss.attackTelegraph;
    if (warning != null) {
      final direction = warning.end - warning.start;
      final bounds = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(
          -warning.radius,
          -warning.radius,
          direction.distance + warning.radius * 2,
          warning.radius * 2,
        ),
        ui.Radius.circular(warning.radius),
      );
      final color = warning.strong
          ? const ui.Color(0xFFFF8469)
          : const ui.Color(0xFFFFD677);
      canvas.save();
      canvas.translate(warning.start.dx, warning.start.dy);
      canvas.rotate(math.atan2(direction.dy, direction.dx));
      canvas.drawRRect(
        bounds,
        ui.Paint()
          ..isAntiAlias = false
          ..color = color.withValues(alpha: 0.18),
      );
      canvas.drawRRect(
        bounds,
        ui.Paint()
          ..isAntiAlias = false
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.85),
      );
      canvas.restore();
    }
    for (final hazard in boss.hazards) {
      final center = _snapOffset(hazard.position);
      if (hazard.isWarning) {
        final outline = _groundOctagon(center, DinoHazard.radius);
        canvas.drawPath(
          outline,
          ui.Paint()
            ..isAntiAlias = false
            ..color = const ui.Color(0x44FFD677),
        );
        canvas.drawPath(
          outline,
          ui.Paint()
            ..isAntiAlias = false
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const ui.Color(0xFFFFD677),
        );
        canvas.drawPath(
          _groundOctagon(center, DinoHazard.radius * hazard.progress),
          ui.Paint()
            ..isAntiAlias = false
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const ui.Color(0xFFF2AE61),
        );
      } else if (!hazard.isFinished) {
        // Only the authored green splash to the right of Dino's body; do not
        // duplicate the boss sprite or manufacture a new effect animation.
        canvas.drawImageRect(
          assets.dinoSheets[DinoAnimation.attackA]!,
          ui.Rect.fromLTWH(hazard.effectFrame * 384 + 240, 56, 144, 72),
          ui.Rect.fromLTWH(center.dx - 108, center.dy - 60, 216, 108),
          _spritePaint,
        );
      }
    }
  }

  ui.Path _groundOctagon(ui.Offset center, double radius) {
    final path = ui.Path();
    for (var index = 0; index < 8; index++) {
      final angle = (index + 0.5) * math.pi / 4;
      final x = (center.dx + math.cos(angle) * radius).roundToDouble();
      final y = (center.dy + math.sin(angle) * radius).roundToDouble();
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  void _drawCombatEffects(ui.Canvas canvas) {
    for (final effect in world.effects) {
      final isArcane = effect.kind == CombatEffectKind.arcaneImpact;
      final renderSize = isArcane
          ? VfxLayout.arcaneImpactSize
          : VfxLayout.fireExplosionSize;
      final source = isArcane
          ? ui.Rect.fromLTWH(
              (effect.frame % 4) * 128,
              (effect.frame ~/ 4) * 128,
              128,
              128,
            )
          : ui.Rect.fromLTWH(effect.frame * 64, 0, 64, 64);
      canvas.drawImageRect(
        isArcane ? assets.orbImpact : assets.fireExplosion,
        source,
        ui.Rect.fromCenter(
          center: _snapOffset(effect.position),
          width: renderSize,
          height: renderSize,
        ),
        _spritePaint,
      );
    }
    // Bounded to40 short-lived labels; cache the text layouts across paint calls.
    for (final number in world.damageNumbers) {
      final label = _damageLabel(number.damage, number.isFire);
      final position = _snapOffset(
        number.position + ui.Offset(-label.width / 2, -28 - number.age * 26),
      );
      canvas.saveLayer(
        ui.Rect.fromLTWH(
          position.dx - 2,
          position.dy - 2,
          label.width + 4,
          label.height + 4,
        ),
        ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, number.opacity),
      );
      label.paint(canvas, position);
      canvas.restore();
    }
  }

  void _drawLevelUpEffect(ui.Canvas canvas) {
    if (world.runState != GameRunState.levelUpEffect) return;
    final frame = (world.levelUpEffectTime / GameBalance.levelUpDuration * 12)
        .floor()
        .clamp(0, 11);
    // This upright, unmirrored aura shares the world/camera transform and is
    // painted before Kitty, so the beam and wings never cover her face/body.
    final center = _snapOffset(world.player.position);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawImageRect(
      assets.levelUp,
      ui.Rect.fromLTWH(frame * 128, 0, 128, 128),
      VfxLayout.levelUpBounds(ui.Offset.zero),
      _spritePaint,
    );
    canvas.restore();
  }

  final Map<(int, bool), TextPainter> _damageLabels = {};
  TextPainter _damageLabel(int damage, bool isFire) {
    final key = (damage, isFire);
    if (_damageLabels.length >= 64 && !_damageLabels.containsKey(key)) {
      for (final label in _damageLabels.values) {
        label.dispose();
      }
      _damageLabels.clear();
    }
    return _damageLabels.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: '$damage',
          style: TextStyle(
            fontFamily: 'friendlyscribbles',
            fontSize: 14,
            color: isFire
                ? const ui.Color(0xFFFFC27A)
                : const ui.Color(0xFFFFFFC2),
            shadows: const [
              ui.Shadow(color: ui.Color(0xFF251936), offset: ui.Offset(1, 1)),
            ],
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(),
    );
  }

  ui.Paint _flashPaint(ui.Color color) {
    return ui.Paint()
      ..isAntiAlias = false
      ..filterQuality = ui.FilterQuality.none
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcATop);
  }

  ui.Offset _snapOffset(ui.Offset value) {
    return ui.Offset(value.dx.roundToDouble(), value.dy.roundToDouble());
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.world != world || oldDelegate.assets != assets;
  }
}

enum _DrawableType { player, slime, orb, boss }

class _WorldDrawable {
  const _WorldDrawable._(
    this.type,
    this.worldY,
    this.slime,
    this.orb,
    this.boss,
  );

  const _WorldDrawable.player(double worldY)
    : this._(_DrawableType.player, worldY, null, null, null);

  const _WorldDrawable.orb(double worldY, MagicOrb orb)
    : this._(_DrawableType.orb, worldY, null, orb, null);

  const _WorldDrawable.slime(double worldY, SlimeEnemy slime)
    : this._(_DrawableType.slime, worldY, slime, null, null);

  const _WorldDrawable.boss(double worldY, DinoTri boss)
    : this._(_DrawableType.boss, worldY, null, null, boss);

  final _DrawableType type;
  final double worldY;
  final SlimeEnemy? slime;
  final MagicOrb? orb;
  final DinoTri? boss;
}
