import 'package:flutter/material.dart';

import 'audio/game_audio_controller.dart';
import 'game/game_assets.dart';
import 'game/game_screen.dart';
import 'game/models/player.dart';
import 'menu/character_color_screen.dart';
import 'menu/main_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WitchKittyApp());
}

class WitchKittyApp extends StatelessWidget {
  const WitchKittyApp({this.audio, super.key});

  final GameAudioController? audio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Witch Kitty',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'friendlyscribbles',
        scaffoldBackgroundColor: const Color(0xFF162A30),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9EB83B),
          brightness: Brightness.dark,
        ),
      ),
      home: GameFlow(audio: audio),
    );
  }
}

enum _AppStage { mainMenu, colorChoice, game }

class GameFlow extends StatefulWidget {
  const GameFlow({this.audio, super.key});

  final GameAudioController? audio;

  @override
  State<GameFlow> createState() => _GameFlowState();
}

class _GameFlowState extends State<GameFlow> with WidgetsBindingObserver {
  late final GameAudioController _audio;
  GameAssets? _assets;
  Object? _loadError;
  _AppStage _stage = _AppStage.mainMenu;
  PlayerPalette? _runPalette;
  int _runSession = 0;

  @override
  void initState() {
    super.initState();
    _audio = widget.audio ?? GameAudioController();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudio();
    _loadAssets();
  }

  Future<void> _initializeAudio() async {
    await _audio.initialize();
    if (!mounted) return;
    if (_stage == _AppStage.mainMenu) {
      _audio.setMusic(MusicTrack.menu);
    } else if (_stage == _AppStage.colorChoice) {
      _audio.setMusic(MusicTrack.attire);
    }
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await GameAssets.load();
      if (!mounted) {
        assets.dispose();
        return;
      }
      setState(() => _assets = assets);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Witch Kitty asset loading',
        ),
      );
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  void _showColorChoice() {
    _audio.setMusic(MusicTrack.attire);
    setState(() {
      _runPalette = null;
      _stage = _AppStage.colorChoice;
    });
  }

  void _startRun(PlayerPalette palette) {
    setState(() {
      _runPalette = palette;
      _runSession++;
      _stage = _AppStage.game;
    });
  }

  void _showMainMenu() {
    _audio.resume();
    _audio.setMusic(MusicTrack.menu);
    setState(() {
      _runPalette = null;
      _stage = _AppStage.mainMenu;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A run owns its own lifecycle so returning to a paused run stays paused.
    if (_stage == _AppStage.game) return;
    if (state == AppLifecycleState.resumed) {
      _audio.resume();
    } else {
      _audio.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.audio == null) _audio.dispose();
    _assets?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    if (_loadError != null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'THE MAGIC ASSETS COULD NOT BE LOADED',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (assets == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'SUMMONING WITCH KITTY...',
            style: TextStyle(color: Color(0xFFFFFFC2), fontSize: 20),
          ),
        ),
      );
    }

    return switch (_stage) {
      _AppStage.mainMenu => MainMenu(
        key: const ValueKey('main_menu'),
        assets: assets,
        audio: _audio,
        onPlay: _showColorChoice,
      ),
      _AppStage.colorChoice => CharacterColorScreen(
        key: const ValueKey('color_choice'),
        assets: assets,
        audio: _audio,
        onSelected: _startRun,
        onBack: _showMainMenu,
      ),
      _AppStage.game => GameScreen(
        key: ValueKey('game_$_runSession'),
        assets: assets,
        audio: _audio,
        palette: _runPalette!,
        onMainMenu: _showMainMenu,
      ),
    };
  }
}
