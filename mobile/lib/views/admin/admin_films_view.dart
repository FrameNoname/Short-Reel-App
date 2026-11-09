import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../l10n/app_language.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';
import 'admin_episodes_view.dart';

/// Series Jeen series someone bought, then the app's own films. The rest of
/// Series Jeen is too big to list, so it is found with a search. A taken-down
/// film disappears for viewers but stays here, so the admin can bring it back.
class AdminFilmsView extends StatefulWidget {
  const AdminFilmsView({super.key});

  @override
  State<AdminFilmsView> createState() => _AdminFilmsViewState();
}

class _AdminFilmsViewState extends State<AdminFilmsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    context.read<AdminController>().searchCatalog('');
  }

  Widget _row(BuildContext context, AdminFilm film) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _FilmRow(
      film: film,
      onToggle: () => _toggle(context, film),
      // Series Jeen prices are set for the whole catalog in settings.
      onOpen: film.isCatalog
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminEpisodesView(film: film),
              ),
            ),
    ),
  );

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
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: admin.searchCatalog,
                  decoration: InputDecoration(
                    hintText: context.tr('Search Series Jeen'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: admin.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              if (admin.searchQuery.isNotEmpty) ...[
                if (admin.searchLoading) const LinearProgressIndicator(),
                if (admin.searchError != null)
                  AppCard(child: Text(admin.searchError!)),
                if (!admin.searchLoading &&
                    admin.searchError == null &&
                    admin.searchResults.isEmpty)
                  const _Note('Nothing found'),
                for (final film in admin.searchResults) _row(context, film),
              ] else ...[
                const _Heading('Series Jeen'),
                if (!admin.filmsLoading &&
                    !admin.films.any((f) => f.isCatalog))
                  const _Note(
                    'No Series Jeen series sold yet. Search to take one down.',
                  ),
                for (final film in admin.films.where((f) => f.isCatalog))
                  _row(context, film),
                const _Heading('App films'),
                for (final film in admin.films.where((f) => !f.isCatalog))
                  _row(context, film),
              ],
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
  final VoidCallback? onOpen;

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
                      film.isCatalog
                          ? 'Series Jeen · ${film.coinsSpent} coins'
                          : '${film.episodeCount} episodes · '
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

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
    child: Text(label, style: const TextStyle(color: AppColors.muted)),
  );
}
