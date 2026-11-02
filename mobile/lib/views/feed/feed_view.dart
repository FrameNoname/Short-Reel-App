import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../l10n/app_language.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/text.dart';
import '../auth/login_view.dart';
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

  void _selectTab(FeedTab tab) {
    final userId = context.read<AuthController>().user?.id;
    if (tab == FeedTab.following && userId == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginView()));
      return;
    }
    context.read<FeedController>().selectTab(tab, userId);
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
            _EmptyFeed(
              following: feed.tab == FeedTab.following,
              onDiscover: () => feed.selectTab(
                FeedTab.forYou,
                context.read<AuthController>().user?.id,
              ),
            )
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
                    _FeedTabLabel(
                      label: 'Following',
                      selected: feed.tab == FeedTab.following,
                      onTap: () => _selectTab(FeedTab.following),
                    ),
                    const SizedBox(width: 22),
                    _FeedTabLabel(
                      label: 'For you',
                      selected: feed.tab == FeedTab.forYou,
                      onTap: () => _selectTab(FeedTab.forYou),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: context.tr('Search'),
                          icon: const Icon(Icons.search),
                          onPressed: widget.onSearch,
                        ),
                      ),
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

class _FeedTabLabel extends StatelessWidget {
  const _FeedTabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.text : AppColors.muted,
                  shadows: const [
                    Shadow(blurRadius: 4, color: Color(0xAA000000)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 2,
                color: selected ? AppColors.text : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.following, required this.onDiscover});

  final bool following;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    if (!following) {
      return const EmptyView(message: 'No films to show yet.');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_alt_rounded,
              size: 44,
              color: AppColors.link,
            ),
            const SizedBox(height: 14),
            const Text(
              'Follow a creator to see their films here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the + on a creator in For you to follow them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onDiscover,
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
              child: const Text('Find films for you'),
            ),
          ],
        ),
      ),
    );
  }
}
