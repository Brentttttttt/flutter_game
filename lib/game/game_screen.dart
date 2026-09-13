import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game_assets.dart';
import 'game_world.dart';
import 'models/player.dart';
import 'models/upgrade.dart';
import 'rendering/game_painter.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/upgrade_overlay.dart';
import 'widgets/virtual_joystick.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.assets,
    required this.palette,
    required this.onMainMenu,
    this.initialWorld,
    super.key,
  });

  final GameAssets assets;
  final PlayerPalette palette;
  final VoidCallback onMainMenu;
  final GameWorld? initialWorld;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<int> _repaint = ValueNotifier(0);

  late final Ticker _ticker;
  late GameWorld _world;
  Duration? _lastElapsed;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  int _joystickGeneration = 0;

  @override
  void initState() {
    super.initState();
    _world = widget.initialWorld ?? GameWorld(palette: widget.palette);
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _ticker = createTicker(_onTick);
    _syncTicker();
  }

  bool get _shouldTick =>
      _lifecycleState == AppLifecycleState.resumed &&
      !_world.isChoosingUpgrade &&
      !_world.isGameOver;

  void _syncTicker() {
    if (_shouldTick && !_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    } else if (!_shouldTick && _ticker.isActive) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) {
      return;
    }

    final deltaTime = ((elapsed - previous).inMicroseconds / 1000000)
        .clamp(0.0, 0.05)
        .toDouble();
    final previousState = (
      _world.isPlaying,
      _world.isChoosingUpgrade,
      _world.isGameOver,
    );
    _world.update(deltaTime);
    final currentState = (
      _world.isPlaying,
      _world.isChoosingUpgrade,
      _world.isGameOver,
    );
    if (previousState != currentState) {
      _world.setMovementInput(Offset.zero);
      setState(() {
        _joystickGeneration++;
        _lastElapsed = null;
      });
      _syncTicker();
    }
    _repaint.value++;
  }

  void _chooseUpgrade(UpgradeId id) {
    if (!_world.chooseUpgrade(id)) {
      return;
    }
    _world.setMovementInput(Offset.zero);
    setState(() {
      _joystickGeneration++;
      _lastElapsed = null;
    });
    _repaint.value++;
    _syncTicker();
  }

  void _retry() {
    _world.setMovementInput(Offset.zero);
    setState(() {
      _world = GameWorld(palette: widget.palette);
      _joystickGeneration++;
      _lastElapsed = null;
    });
    _repaint.value++;
    _syncTicker();
  }

  void _returnToMainMenu() {
    _world.setMovementInput(Offset.zero);
    _ticker.stop();
    _lastElapsed = null;
    widget.onMainMenu();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _lastElapsed = null;
      _syncTicker();
      return;
    }

    _world.setMovementInput(Offset.zero);
    if (mounted) {
      setState(() => _joystickGeneration++);
    }
    _lastElapsed = null;
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFF233A36),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _world.setViewport(constraints.biggest);

              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: GamePainter(
                        world: _world,
                        assets: widget.assets,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _repaint,
                    builder: (context, value, child) {
                      return GameHud(world: _world);
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _repaint,
                    builder: (context, value, child) {
                      if (!_world.isPlaying) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        left: 14,
                        bottom: 14,
                        child: VirtualJoystick(
                          key: ValueKey(_joystickGeneration),
                          onChanged: _world.setMovementInput,
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _repaint,
                    builder: (context, value, child) {
                      if (!_world.isChoosingUpgrade) {
                        return const SizedBox.shrink();
                      }
                      return UpgradeOverlay(
                        level: _world.player.stats.level,
                        choices: _world.upgradeChoices,
                        onSelected: _chooseUpgrade,
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _repaint,
                    builder: (context, value, child) {
                      if (!_world.isGameOver) {
                        return const SizedBox.shrink();
                      }
                      return GameOverOverlay(
                        world: _world,
                        onRetry: _retry,
                        onMainMenu: _returnToMainMenu,
                      );
                    },
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
