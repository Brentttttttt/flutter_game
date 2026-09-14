import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import 'pixel_widgets.dart';

/// Shared by the main menu and the paused run; changing sound never resets a run.
class AudioSettingsPanel extends StatelessWidget {
  const AudioSettingsPanel({
    required this.audio,
    required this.onBack,
    super.key,
  });

  final GameAudioController? audio;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final controller = audio;
    if (controller == null) return _panel(null);
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => _panel(controller),
    );
  }

  Widget _panel(GameAudioController? controller) {
    return ColoredBox(
      key: const Key('audio_settings_overlay'),
      color: const Color(0xE5101820),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: PixelPanel(
              backgroundColor: const Color(0xFF232B35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SOUND SETTINGS',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFFFFFC2), fontSize: 27),
                  ),
                  const SizedBox(height: 18),
                  _volumeControl(
                    'MUSIC',
                    'music',
                    controller?.musicVolume ?? 0.7,
                    controller?.musicMuted ?? false,
                    controller == null
                        ? null
                        : (value) {
                            controller.setMusicVolume(value);
                          },
                    controller == null
                        ? null
                        : (value) {
                            controller.setMusicMuted(value);
                          },
                  ),
                  const SizedBox(height: 12),
                  _volumeControl(
                    'SOUND EFFECTS',
                    'sfx',
                    controller?.sfxVolume ?? 0.8,
                    controller?.sfxMuted ?? false,
                    controller == null
                        ? null
                        : (value) {
                            controller.setSfxVolume(value);
                          },
                    controller == null
                        ? null
                        : (value) {
                            controller.setSfxMuted(value);
                          },
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: PixelButton(
                      key: const Key('settings_back_button'),
                      label: 'BACK',
                      primary: false,
                      onPressed: onBack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _volumeControl(
    String label,
    String id,
    double volume,
    bool muted,
    ValueChanged<double>? onVolume,
    ValueChanged<bool>? onMute,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            Text('${(volume * 100).round()}%', key: Key('${id}_volume_text')),
          ],
        ),
        Slider(
          key: Key('${id}_volume_slider'),
          value: volume.clamp(0, 1),
          divisions: 100,
          label: '${(volume * 100).round()}%',
          onChanged: onVolume,
        ),
        Row(
          children: [
            Expanded(
              child: Text('MUTE $label', style: const TextStyle(fontSize: 13)),
            ),
            Switch(
              key: Key('${id}_mute_switch'),
              value: muted,
              onChanged: onMute,
            ),
          ],
        ),
      ],
    );
  }
}
