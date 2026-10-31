import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_label_badge.dart';
import '../../widgets/common.dart';
import '../auth/login_view.dart';
import 'comments_sheet.dart';
import 'episode_flow.dart';
import 'report_sheet.dart';

/// One full-screen film in the vertical feed. Video playback comes later, so
/// the picture area shows the same placeholder as the design.
class FilmPage extends StatelessWidget {
  const FilmPage({super.key, required this.film});

  final Film film;

  void _whenLoggedIn(BuildContext context, void Function(int userId) action) {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginView()));
    } else {
      action(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final userId = context.watch<AuthController>().user?.id;
    final episode = feed.currentEpisodeOf(film.id);
    final isLiked = userId != null && feed.repository.isLiked(userId, film.id);
    final isSaved = userId != null && feed.repository.isSaved(userId, film.id);
    final isFollowing =
        userId != null && feed.repository.isFollowing(userId, film.creatorId);
    final isOwn = userId == film.creatorId;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF17161F), Color(0xFF211D33), Color(0xFF0E0D12)],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'VIDEO · ${film.title.toUpperCase()} · EP $episode',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 340,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 96,
            child: Column(
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? AppColors.danger : AppColors.text,
                  label: compactCount(film.likeCount),
                  semanticLabel: 'Like, ${compactCount(film.likeCount)} likes',
                  onTap: () => _whenLoggedIn(
                    context,
                    (id) => feed.toggleLike(id, film.id),
                  ),
                ),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: compactCount(film.commentCount),
                  semanticLabel: 'Comments, ${compactCount(film.commentCount)}',
                  onTap: () => showCommentsSheet(context, film),
                ),
                _ActionButton(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? AppColors.primary : AppColors.text,
                  label: 'Save',
                  semanticLabel: isSaved ? 'Saved' : 'Save film',
                  onTap: () => _whenLoggedIn(
                    context,
                    (id) => feed.toggleSave(id, film.id),
                  ),
                ),
                _ActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Report',
                  semanticLabel: 'Report film',
                  onTap: () => _whenLoggedIn(
                    context,
                    (id) => showReportSheet(context, film, id),
                  ),
                ),
                _ActionButton(
                  icon: Icons.grid_view,
                  label: 'Eps',
                  semanticLabel: 'Episodes',
                  onTap: () => showEpisodes(context, film),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 72,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.surfaceHigh,
                      child: Text(
                        film.creatorName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '@${film.creatorName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isOwn)
                      _FollowButton(
                        isFollowing: isFollowing,
                        onTap: () => _whenLoggedIn(
                          context,
                          (id) => feed.toggleFollow(id, film.creatorId),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        film.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AiLabelBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(film.synopsis ?? '', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(film.genreName),
                    _Tag(film.aiToolName),
                    _Tag(
                      'Ep $episode / ${film.episodeCount} ›',
                      color: AppColors.link,
                      onTap: () => showEpisodes(context, film),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: episode / film.episodeCount,
                minHeight: 2,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
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
    return GestureDetector(
      key: const Key('follow-button'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isFollowing ? AppColors.surfaceHigh : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0x66000000),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color = AppColors.text, this.onTap});

  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return tag;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(height: 44, child: Center(widthFactor: 1, child: tag)),
    );
  }
}
