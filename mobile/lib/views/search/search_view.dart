import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/feed_controller.dart';
import '../../controllers/film_search_controller.dart';
import '../../data/film_filter.dart';
import '../../models/film.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/verified_badge.dart';
import '../player/player_view.dart';
import '../profile/creator_profile_view.dart';
import 'filters_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final search = context.read<FilmSearchController>();
      search.apply(search.filter);
    });
  }

  Future<void> _openFilters() async {
    final search = context.read<FilmSearchController>();
    final filter = await Navigator.of(context).push<FilmFilter>(
      MaterialPageRoute(builder: (_) => FiltersView(initial: search.filter)),
    );
    if (filter != null) search.apply(filter);
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<FilmSearchController>();
    final films = search.results;
    return Scaffold(
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
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          search.apply(search.filter.copyWith(query: value)),
                      decoration: InputDecoration(
                        hintText: 'Films, creators, prompts',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.muted,
                        ),
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.muted,
                                ),
                                onPressed: () {
                                  _query.clear();
                                  search.apply(
                                    search.filter.copyWith(query: ''),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Filters',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(50, 50),
                      side: BorderSide(
                        color: search.filter.hasFilters
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.tune),
                    onPressed: _openFilters,
                  ),
                ],
              ),
              if (search.creators.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Channels',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: search.creators.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _ChannelChip(
                      user: search.creators[i],
                      onTap: () =>
                          openCreatorProfile(context, search.creators[i].id),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${films.length} ${films.length == 1 ? 'film' : 'films'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: films.isEmpty
                    ? const EmptyView(message: 'No films match your search.')
                    : GridView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
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
              ),
            ],
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
    final verified =
        context
            .read<FeedController>()
            .repository
            .userById(film.creatorId)
            ?.isVerified ??
        false;
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
                  if (film.viewCount > 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _PosterPill(
                        icon: Icons.play_arrow_rounded,
                        text: compactCount(film.viewCount),
                      ),
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
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '@${film.creatorName}'),
                  if (verified)
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: VerifiedBadge(size: 13),
                      ),
                    ),
                  TextSpan(text: ' · ${film.genreName}'),
                ],
              ),
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
  const _PosterPill({required this.text, this.icon});

  final String text;
  final IconData? icon;

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
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 2)],
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName ?? user.username;
    return GestureDetector(
      key: Key('channel-${user.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                user.username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ChannelName(
              name,
              verified: user.isVerified,
              badgeSize: 12,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
