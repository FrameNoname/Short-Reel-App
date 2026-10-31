import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/catalog_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../l10n/app_language.dart';
import '../../models/catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/text.dart';
import '../player/player_view.dart';

class CatalogView extends StatefulWidget {
  const CatalogView({super.key});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CatalogController>().load(),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: catalog.search,
              decoration: InputDecoration(
                hintText: context.tr('Search series'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (catalog.platforms.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final p in catalog.platforms)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(p.name),
                        selected: p.id == catalog.platform?.id,
                        onSelected: (_) => catalog.selectPlatform(p),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _body(catalog)),
        ],
      ),
    );
  }

  Widget _body(CatalogController catalog) {
    if (catalog.dramas.isEmpty) {
      if (catalog.isLoading) return const LoadingView();
      final error = catalog.error;
      if (error != null) {
        return ErrorView(
          message: error,
          onRetry: () => catalog.search(catalog.query),
        );
      }
      return const EmptyView(message: 'No series found');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          catalog.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.58,
        ),
        itemCount: catalog.dramas.length,
        itemBuilder: (_, i) => _DramaCard(drama: catalog.dramas[i]),
      ),
    );
  }
}

class _DramaCard extends StatelessWidget {
  const _DramaCard({required this.drama});

  final CatalogDrama drama;

  Widget _noPoster() => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        drama.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final film = context.read<FeedController>().repository.catalogFilm(
          drama,
        );
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => PlayerView(film: film)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppColors.surfaceHigh),
                    // Without artwork the tile carries the title instead.
                    _noPoster(),
                    if (drama.posterUrl != null)
                      Image.network(
                        drama.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _noPoster(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(drama.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
