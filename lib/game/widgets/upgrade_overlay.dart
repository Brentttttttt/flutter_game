import 'package:flutter/material.dart';

import '../../ui/pixel_widgets.dart';
import '../models/upgrade.dart';

class UpgradeOverlay extends StatelessWidget {
  const UpgradeOverlay({
    required this.level,
    required this.choices,
    required this.onSelected,
    super.key,
  });

  final int level;
  final List<UpgradeDefinition> choices;
  final ValueChanged<UpgradeId> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('upgrade_overlay'),
      color: const Color(0xDC101220),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LEVEL UP!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFF1A8),
                    fontSize: 38,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Color(0xFF633785),
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LEVEL $level  /  CHOOSE ONE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFDDBAFF),
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 18),
                for (var index = 0; index < choices.length; index++) ...[
                  _UpgradeCard(
                    key: ValueKey('upgrade_card_${choices[index].id.name}'),
                    upgrade: choices[index],
                    onPressed: () => onSelected(choices[index].id),
                  ),
                  if (index < choices.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 18),
                const Text(
                  'THE ARENA IS PAUSED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6B7C8),
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.onPressed,
    super.key,
  });

  final UpgradeDefinition upgrade;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${upgrade.title}. ${upgrade.description}',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF29233C),
        child: InkWell(
          onTap: onPressed,
          splashColor: const Color(0x665B4280),
          highlightColor: const Color(0x665B4280),
          child: PixelPanel(
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF171823),
                    border: Border.all(
                      color: const Color(0xFF79608C),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    upgrade.iconPath,
                    key: ValueKey('upgrade_icon_${upgrade.id.name}'),
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upgrade.title,
                        style: const TextStyle(
                          color: Color(0xFFFFF1B0),
                          fontSize: 20,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        upgrade.description,
                        style: const TextStyle(
                          color: Color(0xFFE2DEEC),
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
