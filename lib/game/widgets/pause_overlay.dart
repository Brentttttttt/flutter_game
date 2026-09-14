import 'package:flutter/material.dart';

import '../../ui/pixel_widgets.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    required this.onResume,
    required this.onSettings,
    required this.onMainMenu,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('pause_overlay'),
      color: const Color(0xD9101820),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: PixelPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(fontSize: 38, color: Color(0xFFFFFFC2)),
                ),
                const SizedBox(height: 20),
                PixelButton(
                  key: const Key('resume_button'),
                  label: 'RESUME',
                  onPressed: onResume,
                ),
                const SizedBox(height: 12),
                PixelButton(
                  key: const Key('pause_settings_button'),
                  label: 'SETTINGS',
                  primary: false,
                  onPressed: onSettings,
                ),
                const SizedBox(height: 12),
                PixelButton(
                  key: const Key('pause_menu_button'),
                  label: 'MAIN MENU',
                  primary: false,
                  onPressed: onMainMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
