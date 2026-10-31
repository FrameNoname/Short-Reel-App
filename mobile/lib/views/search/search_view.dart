import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/film_search_controller.dart';
import '../../data/film_filter.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../player/player_view.dart';
import 'filters_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
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
                      onChanged: (value) =>
                          search.apply(search.filter.copyWith(query: value)),
                      decoration: const InputDecoration(
                        hintText: 'Films, creators, prompts',
                        prefixIcon: Icon(Icons.search, color: AppColors.muted),
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
              const SizedBox(height: 12),
              Text(
                '${films.length} films',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: films.isEmpty
                    ? const EmptyView(message: 'No films match your search.')
                    : GridView.builder(
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

class FilmCard extends StatelessWidget {
  const FilmCard({super.key, required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PlayerView(film: film))),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${film.episodeCount} eps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
          Text(
            '@${film.creatorName} · ${film.genreName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
