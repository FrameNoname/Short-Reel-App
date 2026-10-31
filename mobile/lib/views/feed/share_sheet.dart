import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/text.dart';

const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String speedLabel(double speed) =>
    speed == speed.roundToDouble() ? '${speed.toInt()}x' : '${speed}x';

sealed class ShareChoice {
  const ShareChoice();
}

class SpeedChoice extends ShareChoice {
  const SpeedChoice(this.speed);

  final double speed;
}

class ShareFilmChoice extends ShareChoice {
  const ShareFilmChoice();
}

class ReportChoice extends ShareChoice {
  const ReportChoice();
}

/// The "more" sheet behind the share button: playback speed, share, report.
/// Returns what the person picked, or null when they dismiss it.
Future<ShareChoice?> showShareSheet(
  BuildContext context, {
  required Film film,
  required double speed,
}) {
  return showModalBottomSheet<ShareChoice>(
    context: context,
    builder: (_) => _ShareSheet(film: film, speed: speed),
  );
}

/// Puts the film's details on the clipboard. There is no share target yet,
/// so this is the whole of "share" for now.
Future<void> copyFilmDetails(BuildContext context, Film film) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(
    ClipboardData(
      text: 'Watch "${film.title}" by @${film.creatorName} on Short Reel',
    ),
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.film, required this.speed});

  final Film film;
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
                        onTap: () => Navigator.of(context).pop(SpeedChoice(s)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            _OptionRow(
              icon: Icons.shortcut_rounded,
              title: 'Share',
              subtitle: 'Copy this film’s details',
              onTap: () => Navigator.of(context).pop(const ShareFilmChoice()),
            ),
            _OptionRow(
              icon: Icons.flag_rounded,
              title: 'Report',
              subtitle: 'Tell us what is wrong',
              color: AppColors.danger,
              onTap: () => Navigator.of(context).pop(const ReportChoice()),
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

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
