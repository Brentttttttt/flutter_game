import 'package:flutter/material.dart';

import '../game/game_assets.dart';
import '../game/models/player.dart';
import '../ui/pixel_widgets.dart';
import 'menu_scene.dart';

class CharacterColorScreen extends StatefulWidget {
  const CharacterColorScreen({
    required this.assets,
    required this.onSelected,
    required this.onBack,
    super.key,
  });

  final GameAssets assets;
  final ValueChanged<PlayerPalette> onSelected;
  final VoidCallback onBack;

  @override
  State<CharacterColorScreen> createState() => _CharacterColorScreenState();
}

class _CharacterColorScreenState extends State<CharacterColorScreen>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MagicalMenuBackground(
        animation: _animation,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 600;
              final spriteSize = compact ? 64.0 : 128.0;

              return Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: PixelButton(
                      key: const Key('color_back_button'),
                      label: 'BACK',
                      width: 108,
                      height: 42,
                      primary: false,
                      onPressed: widget.onBack,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        compact ? 58 : 76,
                        18,
                        18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CHOOSE YOUR KITTY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFFFC2),
                              fontSize: compact ? 30 : 40,
                              letterSpacing: 1.5,
                              shadows: const [
                                Shadow(
                                  color: Color(0xFF4B2A78),
                                  offset: Offset(3, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'TAP A COLOR TO BEGIN',
                            style: TextStyle(
                              color: Color(0xFFB8C870),
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: compact ? 14 : 26),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 18,
                            runSpacing: 18,
                            children: [
                              _ColorChoice(
                                choiceKey: const Key('color_1_choice'),
                                label: 'WITCH',
                                subtitle: 'PURPLE',
                                assets: widget.assets,
                                palette: PlayerPalette.color1,
                                animation: _animation,
                                spriteSize: spriteSize,
                                onTap: () =>
                                    widget.onSelected(PlayerPalette.color1),
                              ),
                              _ColorChoice(
                                choiceKey: const Key('color_2_choice'),
                                label: 'CALICO',
                                subtitle: 'FOREST',
                                assets: widget.assets,
                                palette: PlayerPalette.color2,
                                animation: _animation,
                                spriteSize: spriteSize,
                                onTap: () =>
                                    widget.onSelected(PlayerPalette.color2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.choiceKey,
    required this.label,
    required this.subtitle,
    required this.assets,
    required this.palette,
    required this.animation,
    required this.spriteSize,
    required this.onTap,
  });

  final Key choiceKey;
  final String label;
  final String subtitle;
  final GameAssets assets;
  final PlayerPalette palette;
  final Animation<double> animation;
  final double spriteSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label kitty color',
      child: GestureDetector(
        key: choiceKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          backgroundColor: palette == PlayerPalette.color1
              ? const Color(0xEE34264B)
              : const Color(0xEE314736),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedKittyPreview(
                assets: assets,
                palette: palette,
                animation: animation,
                spriteSize: spriteSize,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFFFFC2),
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFB8C870),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
