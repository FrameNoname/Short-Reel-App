import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/feed_controller.dart';
import '../../l10n/app_language.dart';
import '../../models/film.dart';
import '../feed/film_page.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key, required this.film});

  final Film film;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  late final FeedController _feed = context.read<FeedController>();
  late final PageController _pages = PageController(
    initialPage: _feed.currentEpisodeOf(widget.film.id) - 1,
  );

  Film get film => widget.film;

  // A catalog series pages through its episodes with a vertical swipe.
  bool get _pagesEpisodes => film.catalogDramaId != null;

  @override
  void initState() {
    super.initState();
    _feed.addListener(_followFeed);
  }

  @override
  void dispose() {
    _feed.removeListener(_followFeed);
    _pages.dispose();
    super.dispose();
  }

  /// The episode list and the end of an episode change the feed's current
  /// episode; the pages follow it.
  void _followFeed() {
    if (!_pagesEpisodes || !_pages.hasClients) return;
    final target = _feed.currentEpisodeOf(film.id) - 1;
    final now = _pages.page?.round() ?? target;
    if (target == now) return;
    if ((target - now).abs() == 1) {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _pages.jumpToPage(target);
    }
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
      body: _pagesEpisodes
          ? PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pages,
              itemCount: film.episodeCount,
              onPageChanged: (i) => _feed.resume(film.id, i + 1),
              itemBuilder: (_, i) =>
                  FilmPage(key: ValueKey(i), film: film, episode: i + 1),
            )
          : FilmPage(film: film),
    );
  }
}
