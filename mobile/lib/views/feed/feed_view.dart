import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../l10n/app_language.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'film_page.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key, this.onSearch});

  final VoidCallback? onSearch;

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  /// The page the feed has settled on; only it may load or play a video.
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedController>().load(
        context.read<AuthController>().user?.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    // A reload swaps the PageView out, so the new one starts on its first page.
    if (feed.isLoading) _page = 0;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (feed.isLoading)
            const LoadingView()
          else if (feed.error != null)
            ErrorView(
              message: feed.error!,
              onRetry: () => feed.load(context.read<AuthController>().user?.id),
            )
          else if (feed.films.isEmpty)
            const EmptyView(message: 'No films to show yet.')
          else
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: feed.films.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, index) => FilmPage(
                key: ValueKey(feed.films[index].id),
                film: feed.films[index],
                // Only the page the feed has settled on may load or play.
                active: index == _page,
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      tooltip: context.tr('Search'),
                      icon: const Icon(Icons.search),
                      onPressed: widget.onSearch,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
