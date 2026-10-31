import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/film.dart';
import '../../models/user.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_view.dart';
import '../search/search_view.dart';

void openCreatorProfile(BuildContext context, int creatorId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CreatorProfileView(creatorId: creatorId),
    ),
  );
}

/// A channel's public page: who they are, their numbers and the films they
/// have published.
class CreatorProfileView extends StatefulWidget {
  const CreatorProfileView({super.key, required this.creatorId});

  final int creatorId;

  @override
  State<CreatorProfileView> createState() => _CreatorProfileViewState();
}

class _CreatorProfileViewState extends State<CreatorProfileView> {
  int get creatorId => widget.creatorId;

  late final Future<List<Film>> _films = context
      .read<FeedController>()
      .repository
      .filmsOf(creatorId);

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final viewerId = context.watch<AuthController>().user?.id;
    final repository = feed.repository;
    final creator = repository.userById(creatorId);
    if (creator == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This channel is not available.')),
      );
    }
    final name = creator.displayName ?? creator.username;
    return FutureBuilder<List<Film>>(
      future: _films,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: errorMessage(snapshot.error!)),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const LoadingView());
        }
        final films = snapshot.data!
            .where((f) => f.status == 'approved')
            .toList();
        return _page(context, feed, viewerId, creator, name, films);
      },
    );
  }

  Widget _page(
    BuildContext context,
    FeedController feed,
    int? viewerId,
    User creator,
    String name,
    List<Film> films,
  ) {
    final repository = feed.repository;
    final likes = films.fold<int>(0, (sum, f) => sum + f.likeCount);
    final isOwn = viewerId == creatorId;
    final isFollowing =
        viewerId != null && repository.isFollowing(viewerId, creatorId);

    return Scaffold(
      appBar: AppBar(
        title: ChannelName(
          '@${creator.username}',
          verified: creator.isVerified,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Column(
                children: [
                  _Avatar(letter: creator.username[0].toUpperCase()),
                  const SizedBox(height: 12),
                  ChannelName(
                    name,
                    verified: creator.isVerified,
                    badgeSize: 20,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (creator.bio ?? '').isNotEmpty
                        ? creator.bio!
                        : creator.isVerified
                        ? 'Official Short Reel channel'
                        : '${creator.role.name[0].toUpperCase()}'
                              '${creator.role.name.substring(1)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Count(
                        value: repository.followingOf(creatorId).length,
                        label: 'Following',
                      ),
                      _Count(
                        value: repository.followerCount(creatorId),
                        label: 'Followers',
                      ),
                      _Count(value: likes, label: 'Likes'),
                    ],
                  ),
                  if (!isOwn) ...[
                    const SizedBox(height: 18),
                    _FollowButton(
                      isFollowing: isFollowing,
                      onTap: () {
                        if (viewerId == null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginView(),
                            ),
                          );
                        } else {
                          feed.toggleFollow(viewerId, creatorId);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _FilmsHeader()),
          if (films.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No films yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.52,
                ),
                itemCount: films.length,
                itemBuilder: (_, i) => FilmCard(film: films[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CircleAvatar(
        radius: 44,
        backgroundColor: AppColors.primarySoft,
        child: Text(
          letter,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Text(
            compactCount(value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isFollowing ? 'Following' : 'Follow';
    return SizedBox(
      width: 200,
      child: isFollowing
          ? OutlinedButton(
              key: const Key('profile-follow'),
              onPressed: onTap,
              child: Text(label),
            )
          : FilledButton(
              key: const Key('profile-follow'),
              onPressed: onTap,
              child: Text(label),
            ),
    );
  }
}

class _FilmsHeader extends StatelessWidget {
  const _FilmsHeader();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: SizedBox(
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 22),
              SizedBox(height: 10),
              SizedBox(
                width: 56,
                height: 2,
                child: ColoredBox(color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
