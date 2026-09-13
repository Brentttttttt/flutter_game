import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_assets.dart';
import '../game/models/player.dart';
import '../ui/pixel_widgets.dart';
import 'menu_scene.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    required this.assets,
    required this.onPlay,
    this.exitOverride,
    super.key,
  });

  final GameAssets assets;
  final VoidCallback onPlay;
  final VoidCallback? exitOverride;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _exitGame() {
    final override = widget.exitOverride;
    if (override != null) {
      override();
      return;
    }

    final supportsProgrammaticExit =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (supportsProgrammaticExit) {
      SystemNavigator.pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('USE YOUR DEVICE CONTROLS TO CLOSE WITCH KITTY'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MagicalMenuBackground(
        animation: _animation,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 600;
              final titleSize = compact ? 38.0 : 52.0;
              final spriteSize = compact ? 64.0 : 128.0;
              final buttonHeight = compact ? 44.0 : 52.0;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WITCH KITTY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFFFC2),
                          fontSize: titleSize,
                          letterSpacing: 2.5,
                          height: 0.95,
                          shadows: const [
                            Shadow(
                              color: Color(0xFF4B2A78),
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'MOONLIT SURVIVAL',
                        style: TextStyle(
                          color: Color(0xFFB8C870),
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 16),
                      AnimatedKittyPreview(
                        assets: widget.assets,
                        palette: PlayerPalette.color1,
                        animation: _animation,
                        spriteSize: spriteSize,
                        showOrb: true,
                      ),
                      SizedBox(height: compact ? 10 : 20),
                      PixelButton(
                        key: const Key('play_button'),
                        label: 'PLAY',
                        height: buttonHeight,
                        onPressed: widget.onPlay,
                      ),
                      const SizedBox(height: 12),
                      PixelButton(
                        key: const Key('exit_button'),
                        label: 'EXIT',
                        height: buttonHeight,
                        primary: false,
                        onPressed: _exitGame,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
