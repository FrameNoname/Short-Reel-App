import 'dart:ui';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/app_language.dart';
import '../../models/episode.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import '../auth/login_view.dart';
import '../auth/register_view.dart';

/// Shown when a guest reaches a locked episode: the film's poster blurred
/// behind a short pitch for logging in.
class LoginGateView extends StatelessWidget {
  const LoginGateView({super.key, required this.film, required this.episode});

  final Film film;
  final Episode episode;

  void _open(BuildContext context, Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filled(
            tooltip: context.tr('Back'),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x66000000),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Transform.scale(
              scale: 1.4,
              child: FilmPoster(film: film, showBadge: false),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0xE60E0D12)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 14),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    height: 160,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: FilmPoster(film: film, showBadge: false),
                        ),
                        Positioned(
                          right: -12,
                          bottom: -12,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 3,
                              ),
                            ),
                            child: const Icon(Icons.lock_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Log in to keep watching',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You watched the free episodes of ${film.title}. '
                    'Log in to continue from Episode ${episode.episodeNo}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _Perk(icon: Icons.lock_open_rounded, label: 'Unlock'),
                      _Perk(icon: Icons.favorite_rounded, label: 'Like'),
                      _Perk(icon: Icons.bookmark_rounded, label: 'Save'),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _open(context, const LoginView()),
                    child: const Text('Log in'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _open(context, const RegisterView()),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Keep browsing free episodes',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.link),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
