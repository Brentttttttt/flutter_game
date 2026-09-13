import 'package:flutter_game/game/game_assets.dart';
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
      expect((assets.slimeIdle.width, assets.slimeIdle.height), (896, 64));
      expect(
        (assets.slimeWalkEast.width, assets.slimeWalkEast.height),
        (256, 64),
      );
      expect(
        (assets.slimeWalkWest.width, assets.slimeWalkWest.height),
        (256, 64),
      );
      expect(
        (assets.slimeWalkNorth.width, assets.slimeWalkNorth.height),
        (256, 64),
      );
      expect(
        (assets.slimeWalkSouth.width, assets.slimeWalkSouth.height),
        (256, 64),
      );
      expect((assets.slimeAttack.width, assets.slimeAttack.height), (512, 64));
      expect((assets.slimeDeath.width, assets.slimeDeath.height), (384, 64));
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
