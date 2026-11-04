import 'package:flutter/material.dart' hide Text;

import '../../theme/app_theme.dart';
import '../../widgets/text.dart';

const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String speedLabel(double speed) =>
    speed == speed.roundToDouble() ? '${speed.toInt()}x' : '${speed}x';

/// The sheet behind the speed button. Returns the picked speed, or null when
/// the person dismisses it.
Future<double?> showSpeedSheet(BuildContext context, {required double speed}) {
  return showModalBottomSheet<double>(
    context: context,
    builder: (_) => _SpeedSheet(speed: speed),
  );
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Playback speed',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final s in playbackSpeeds)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: s == playbackSpeeds.last ? 0 : 6,
                      ),
                      child: _SpeedChip(
                        label: speedLabel(s),
                        selected: s == speed,
                        onTap: () => Navigator.of(context).pop(s),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Speed $label',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
