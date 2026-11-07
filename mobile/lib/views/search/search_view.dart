import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/film_search_controller.dart';
import '../../l10n/app_language.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';
import '../player/player_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  /// Whether the recent and trending searches are on screen. Kept apart from
  /// focus because on the web a tap on a suggestion first takes focus away.
  bool _suggesting = false;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _useTerm(String term) {
    final search = context.read<FilmSearchController>();
    _query.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    search.apply(term);
    search.remember(term);
    _focus.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _suggesting = _focus.hasFocus));
  }

  /// Runs each time the tab is opened, so a film the admin took down (or a
  /// new one) shows up right away instead of after the next search.
  void _refresh() {
    final search = context.read<FilmSearchController>();
    search.apply(search.query);
    search.loadTrending();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<FilmSearchController>();
    final films = search.results;
    final showSuggestions = _suggesting && _query.text.isEmpty;
    return OnActivated(
      run: _refresh,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        focusNode: _focus,
                        onTapOutside: (_) {},
                        textInputAction: TextInputAction.search,
                        onChanged: search.type,
                        onSubmitted: (value) {
                          search.remember(value);
                          _focus.unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: context.tr('Search films'),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.muted,
                          ),
                          suffixIcon: _query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.tr('Clear search'),
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.muted,
                                  ),
                                  onPressed: () {
                                    _query.clear();
                                    search.apply('');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: showSuggestions
                      ? _Suggestions(
                          recent: search.recent,
                          trending: search.trending,
                          onTerm: _useTerm,
                          onForget: search.forget,
                          onClear: search.clearRecent,
                          onDismiss: _focus.unfocus,
                        )
                      : CustomScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 8,
                                ),
                                child: Text(
                                  '${films.length} ${films.length == 1 ? 'film' : 'films'}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (search.error != null)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: ErrorView(
                                  message: search.error!,
                                  onRetry: () => search.apply(search.query),
                                ),
                              )
                            else if (films.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyView(
                                  message: 'No films match your search.',
                                ),
                              )
                            else
                              SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 0.66,
                                    ),
                                itemCount: films.length,
                                itemBuilder: (_, i) => FilmCard(film: films[i]),
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

class FilmCard extends StatefulWidget {
  const FilmCard({super.key, required this.film});

  final Film film;

  @override
  State<FilmCard> createState() => _FilmCardState();
}

class _FilmCardState extends State<FilmCard> {
  bool _pressed = false;

  Film get film => widget.film;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PlayerView(film: film))),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FilmPoster(film: film),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _PosterPill(text: '${film.episodeCount} eps'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              film.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              film.genreName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterPill extends StatelessWidget {
  const _PosterPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.recent,
    required this.trending,
    required this.onTerm,
    required this.onForget,
    required this.onClear,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;
  final List<String> recent;
  final List<Film> trending;
  final ValueChanged<String> onTerm;
  final ValueChanged<String> onForget;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          if (recent.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent searches',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  key: const Key('recent-clear'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const SizedBox(
                    height: 44,
                    child: Align(
                      widthFactor: 1,
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          color: AppColors.link,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in recent)
                  _RecentChip(
                    term: term,
                    onTap: () => onTerm(term),
                    onRemove: () => onForget(term),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: AppColors.gold,
              ),
              SizedBox(width: 6),
              Text(
                'Trending',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final (i, film) in trending.indexed)
            GestureDetector(
              key: Key('trending-${film.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTerm(film.title),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: i < 3 ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        film.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${compactCount(film.likeCount)} likes',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
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

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: Key('recent-$term'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(term, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          GestureDetector(
            key: Key('recent-remove-$term'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
