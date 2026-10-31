import 'package:flutter/material.dart';

import '../../models/episode.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_view.dart';
import '../auth/register_view.dart';

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
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Log in to keep watching',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'You watched the free episodes of ${film.title}. '
                  'Log in to continue from Episode ${episode.episodeNo}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => _open(context, const LoginView()),
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _open(context, const RegisterView()),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 8),
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
      ),
    );
  }
}
