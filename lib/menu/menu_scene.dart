import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_assets.dart';
import '../game/models/magic_orb.dart';
import '../game/models/player.dart';

class MagicalMenuBackground extends StatelessWidget {
  const MagicalMenuBackground({
    required this.animation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _MagicalBackgroundPainter(animation)),
        child,
      ],
    );
  }
}

class AnimatedKittyPreview extends StatelessWidget {
  const AnimatedKittyPreview({
    required this.assets,
    required this.palette,
    required this.animation,
    this.spriteSize = 128,
    this.showOrb = false,
    super.key,
  });

  final GameAssets assets;
  final PlayerPalette palette;
  final Animation<double> animation;
  final double spriteSize;
  final bool showOrb;

  @override
  Widget build(BuildContext context) {
    final width = showOrb ? spriteSize + 80 : spriteSize;
    return SizedBox(
      width: width,
      height: spriteSize,
      child: CustomPaint(
        painter: _KittyPreviewPainter(
          assets: assets,
          palette: palette,
          animation: animation,
          spriteSize: spriteSize,
          showOrb: showOrb,
        ),
      ),
    );
  }
}

class _MagicalBackgroundPainter extends CustomPainter {
  _MagicalBackgroundPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF162A30), BlendMode.src);
    final phase = animation.value * math.pi * 2;
    final particlePaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xAA9EB83B);
    final faintPaint = Paint()
      ..isAntiAlias = false
      ..color = const Color(0x554B6A55);

    for (var index = 0; index < 30; index++) {
      final baseX = ((index * 83) % 997) / 997 * size.width;
      final baseY = ((index * 137) % 991) / 991 * size.height;
      final x = baseX + math.sin(phase + index * 0.7) * 7;
      final y = baseY + math.cos(phase * 0.65 + index) * 9;
      final side = index % 5 == 0 ? 4.0 : 2.0;
      canvas.drawRect(Rect.fromLTWH(x, y, side, side), particlePaint);
    }

    final gridSize = 32.0;
    for (var x = 0.0; x < size.width; x += gridSize) {
      canvas.drawRect(Rect.fromLTWH(x, size.height - 4, 16, 4), faintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MagicalBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

class _KittyPreviewPainter extends CustomPainter {
  _KittyPreviewPainter({
    required this.assets,
    required this.palette,
    required this.animation,
    required this.spriteSize,
    required this.showOrb,
  }) : super(repaint: animation);

  final GameAssets assets;
  final PlayerPalette palette;
  final Animation<double> animation;
  final double spriteSize;
  final bool showOrb;

  @override
  void paint(Canvas canvas, Size size) {
    final isDefault = palette == PlayerPalette.color1;
    final image = isDefault ? assets.color1Idle : assets.color2Idle;
    final columns = isDefault ? 3 : 5;
    final frameCount = isDefault ? 12 : 10;
    final frame = (animation.value * 60).floor() % frameCount;
    final source = Rect.fromLTWH(
      (frame % columns) * 64,
      (frame ~/ columns) * 64,
      64,
      64,
    );
    final destination = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: spriteSize,
      height: spriteSize,
    );
    final spritePaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, source, destination, spritePaint);

    if (showOrb) {
      final orb = MagicOrb()..animationTime = animation.value * 6;
      final phase = animation.value * math.pi * 2;
      final orbCenter =
          size.center(Offset.zero) +
          Offset(math.cos(phase) * 62, math.sin(phase) * 22 - 14);
      canvas.drawImageRect(
        assets.orbs,
        orb.sourceRectForFrame(orb.animationFrame),
        Rect.fromCenter(center: orbCenter, width: 32, height: 32),
        spritePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KittyPreviewPainter oldDelegate) {
    return oldDelegate.assets != assets ||
        oldDelegate.palette != palette ||
        oldDelegate.animation != animation ||
        oldDelegate.spriteSize != spriteSize ||
        oldDelegate.showOrb != showOrb;
  }
}
