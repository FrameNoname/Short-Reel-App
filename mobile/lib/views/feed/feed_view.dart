import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import '../auth/login_view.dart';
import 'film_page.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key, this.onSearch});

  final VoidCallback? onSearch;

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (feed.isLoading)
            const LoadingView()
          else if (feed.films.isEmpty)
            const EmptyView(
              message: 'Follow a creator to see their films here.',
            )
          else
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: feed.films.length,
              itemBuilder: (_, index) => FilmPage(film: feed.films[index]),
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
                          tooltip: 'Search',
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.text : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 52,
            height: 2,
            color: selected ? AppColors.text : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
