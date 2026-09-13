// Run explicitly from the project root:
// flutter test tool/generate_launcher_icon.dart
//
// Uses Flutter's real Canvas to export the existing pixel sprites. This is an
// asset generation command, deliberately outside test/ so normal tests do not
// rewrite platform resources. No image-generation service or extra package is
// used. Source art is never changed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _background = ui.Color(0xFF332047);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export Witch Kitty launcher resources', () async {
    final kitty = await _load(
      'assets/characters/player_character/color_1/'
      'witchKitty_curiousIdleBreaker.png',
    );
    final orbs = await _load('assets/orbs/orbs-sheet.png');
    try {
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final entry in densities.entries) {
        final directory = 'android/app/src/main/res/mipmap-${entry.key}';
        await _export(
          kitty,
          orbs,
          (48 * entry.value).round(),
          '$directory/ic_launcher.png',
        );
        await _export(
          kitty,
          orbs,
          (48 * entry.value).round(),
          '$directory/ic_launcher_round.png',
          round: true,
        );
        await _export(
          kitty,
          orbs,
          (108 * entry.value).round(),
          '$directory/ic_launcher_foreground.png',
          adaptive: true,
        );
      }

      // Reuse the existing iOS app-icon manifest and its exact expected sizes.
      const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest =
          jsonDecode(await File('$iosDirectory/Contents.json').readAsString())
              as Map<String, dynamic>;
      final written = <String>{};
      for (final item in (manifest['images'] as List<dynamic>)) {
        final data = item as Map<String, dynamic>;
        final name = data['filename'] as String;
        if (!written.add(name)) {
          continue;
        }
        final points = double.parse((data['size'] as String).split('x').first);
        final scale = double.parse(
          (data['scale'] as String).replaceAll('x', ''),
        );
        await _export(
          kitty,
          orbs,
          (points * scale).round(),
          '$iosDirectory/$name',
        );
      }

      final windowsFrames = <int, Uint8List>{};
      for (final size in [16, 24, 32, 48, 64, 128, 256]) {
        windowsFrames[size] = await _render(kitty, orbs, size);
      }
      await File(
        'windows/runner/resources/app_icon.ico',
      ).writeAsBytes(_ico(windowsFrames));
      await _export(kitty, orbs, 512, 'docs/witch_kitty_icon.png');
      await _export(kitty, orbs, 192, 'build/asset-audit/launcher_preview.png');
      // Show the actual adaptive foreground under the circular launcher mask.
      await _export(
        kitty,
        orbs,
        432,
        'build/asset-audit/launcher_adaptive_preview.png',
        previewAdaptive: true,
      );
    } finally {
      kitty.dispose();
      orbs.dispose();
    }
  });
}

Future<ui.Image> _load(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<void> _export(
  ui.Image kitty,
  ui.Image orbs,
  int size,
  String path, {
  bool adaptive = false,
  bool round = false,
  bool previewAdaptive = false,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    await _render(
      kitty,
      orbs,
      size,
      adaptive: adaptive,
      round: round,
      previewAdaptive: previewAdaptive,
    ),
  );
}

Future<Uint8List> _render(
  ui.Image kitty,
  ui.Image orbs,
  int size, {
  bool adaptive = false,
  bool round = false,
  bool previewAdaptive = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final pixelPaint = ui.Paint()
    ..isAntiAlias = false
    ..filterQuality = ui.FilterQuality.none;
  final isAdaptive = adaptive || previewAdaptive;
  final logicalSize = isAdaptive ? 108.0 : 80.0;
  canvas.scale(size / logicalSize);
  if (round || previewAdaptive) {
    final mask = previewAdaptive
        ? const ui.Rect.fromLTWH(18, 18, 72, 72)
        : const ui.Rect.fromLTWH(0, 0, 80, 80);
    canvas.clipPath(ui.Path()..addOval(mask), doAntiAlias: false);
  }
  if (!adaptive) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, logicalSize, logicalSize),
      ui.Paint()..color = _background,
    );
  }
  // The 108dp foreground uses the central 66dp safe zone. Kitty's original
  // 64px source includes transparent margins; all visible pixels fit the safe
  // circle together with the small orb. Legacy uses the central 80px crop for
  // a prominent character at tiny launcher sizes.
  final inset = isAdaptive ? 22.0 : 8.0;
  canvas.drawImageRect(
    orbs,
    const ui.Rect.fromLTWH(0, 80, 16, 16),
    ui.Rect.fromLTWH(inset + 46, inset + 18, 16, 16),
    pixelPaint,
  );
  canvas.drawImageRect(
    kitty,
    const ui.Rect.fromLTWH(0, 0, 64, 64),
    ui.Rect.fromLTWH(inset - 1, inset - 1, 64, 64),
    pixelPaint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('PNG encoding failed');
    }
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

// Modern Windows ICO containers support PNG entries directly. Packaging the
// Canvas exports retains their exact pixels, including the smallest sizes.
Uint8List _ico(Map<int, Uint8List> frames) {
  final header = ByteData(6 + frames.length * 16)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, frames.length, Endian.little);
  var offset = header.lengthInBytes;
  var index = 0;
  for (final entry in frames.entries) {
    final start = 6 + index++ * 16;
    header
      ..setUint8(start, entry.key == 256 ? 0 : entry.key)
      ..setUint8(start + 1, entry.key == 256 ? 0 : entry.key)
      ..setUint16(start + 4, 1, Endian.little)
      ..setUint16(start + 6, 32, Endian.little)
      ..setUint32(start + 8, entry.value.length, Endian.little)
      ..setUint32(start + 12, offset, Endian.little);
    offset += entry.value.length;
  }
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(frames.values.expand((bytes) => bytes).toList()))
      .takeBytes();
}
