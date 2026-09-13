import 'package:flutter_game/game/game_assets.dart';
import 'package:flutter_game/game/models/slime_enemy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all audited gameplay sprite sheets load at native dimensions',
    () async {
      final assets = await GameAssets.load();
      addTearDown(assets.dispose);

      expect((assets.tiles.width, assets.tiles.height), (80, 240));
      expect((assets.orbs.width, assets.orbs.height), (192, 176));
      expect((assets.color1Walk.width, assets.color1Walk.height), (256, 256));
      expect((assets.color1Idle.width, assets.color1Idle.height), (192, 256));
      expect((assets.color2Walk.width, assets.color2Walk.height), (256, 256));
      expect((assets.color2Idle.width, assets.color2Idle.height), (320, 128));
      expect(assets.slimeSheets.keys, unorderedEquals(SlimeColor.values));
      for (final sheet in assets.slimeSheets.values) {
        expect((sheet.width, sheet.height), (320, 128));
        final pixels = (await sheet.toByteData())!;
        for (var row = 0; row < 4; row++) {
          final count = [6, 6, 9, 9][row];
          for (var column = 0; column < 10; column++) {
            var visiblePixels = 0;
            for (var y = row * 32; y < (row + 1) * 32; y++) {
              for (var x = column * 32; x < (column + 1) * 32; x++) {
                if (pixels.getUint8((y * sheet.width + x) * 4 + 3) > 0) {
                  visiblePixels++;
                }
              }
            }
            expect(
              visiblePixels > 0,
              column < count,
              reason: 'Slime row $row column $column frame/padding audit',
            );
          }
        }
      }
      expect((assets.xpGem.width, assets.xpGem.height), (64, 16));
      expect((assets.levelUp.width, assets.levelUp.height), (1536, 128));
      expect((assets.orbImpact.width, assets.orbImpact.height), (512, 384));
      expect((assets.fireShot.width, assets.fireShot.height), (256, 64));
      expect(
        (assets.fireExplosion.width, assets.fireExplosion.height),
        (448, 64),
      );
    },
  );
}
