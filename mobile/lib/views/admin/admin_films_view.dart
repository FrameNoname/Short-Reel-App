import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';
import 'admin_episodes_view.dart';

/// The app's own films. A taken-down film disappears for viewers but stays
/// here, so the admin can bring it back.
class AdminFilmsView extends StatelessWidget {
  const AdminFilmsView({super.key});

  Future<void> _toggle(BuildContext context, AdminFilm film) async {
    final admin = context.read<AdminController>();
    final messenger = ScaffoldMessenger.of(context);
    final takeDown = !film.takenDown;
    if (takeDown) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Take this film down?',
        message: 'Viewers will no longer see it. You can put it back later.',
        confirmLabel: 'Take down',
      );
      if (!confirmed) return;
    }
    try {
      await admin.setTakenDown(film, takeDown);
      messenger.showSnackBar(
        SnackBar(
          content: Text(takeDown ? 'Film taken down.' : 'Film is live again.'),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    return OnInit(
      run: () => context.read<AdminController>().loadFilms(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Films and episodes')),
        body: RefreshIndicator(
          onRefresh: admin.loadFilms,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            children: [
              if (admin.filmsLoading) const LinearProgressIndicator(),
              if (admin.filmsError != null)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(admin.filmsError!)),
                      TextButton(
                        onPressed: admin.loadFilms,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              for (final film in admin.films)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FilmRow(
                    film: film,
                    onToggle: () => _toggle(context, film),
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminEpisodesView(film: film),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilmRow extends StatelessWidget {
  const _FilmRow({
    required this.film,
    required this.onToggle,
    required this.onOpen,
  });

  final AdminFilm film;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: film.takenDown ? AppColors.danger : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      film.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${film.episodeCount} episodes · '
                      '${film.likeCount} likes · '
                      '${film.commentCount} comments · '
                      '${film.coinsSpent} coins',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (film.takenDown)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Taken down',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: !film.takenDown,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
