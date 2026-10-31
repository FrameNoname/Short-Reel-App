import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_label_badge.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_view.dart';
import '../profile/creator_profile_view.dart';
import 'catalog_video.dart';
import 'comments_sheet.dart';
import 'episode_video.dart';
import 'episode_flow.dart';
import 'rail_icons.dart';
import 'report_sheet.dart';
import 'share_sheet.dart';

const _textShadow = [Shadow(blurRadius: 6, color: Color(0xAA000000))];

/// One full-screen film in the vertical feed. Video playback comes later, so
/// the picture area shows the same placeholder as the design.
///
/// Gestures follow the short-video convention: tap to pause or resume, double
/// tap anywhere to like.
class FilmPage extends StatefulWidget {
  const FilmPage({super.key, required this.film, this.episode});

  final Film film;

  /// The episode this page shows, when the caller pages through episodes
  /// itself. Otherwise the feed's current episode for the film is used.
  final int? episode;

  @override
  State<FilmPage> createState() => _FilmPageState();
}

class _FilmPageState extends State<FilmPage> {
  /// Holding the right edge plays at this speed until the finger lifts.
  static const _boostSpeed = 2.0;

  /// Pixels per second a left swipe needs to open the channel.
  static const _swipeVelocity = 600.0;

  /// How much of the screen, from the right, counts as the speed edge.
  static const _boostZone = 0.3;

  bool _paused = false;
  bool _boosting = false;
  late double _speed = context.read<SettingsController>().defaultSpeed;
  Offset _lastTap = Offset.zero;
  final List<_Burst> _bursts = [];
  int _burstId = 0;

  Film get film => widget.film;

  bool get playsVideo => context.read<FeedController>().repository.playsVideo;

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

  void _doubleTapLike() {
    final feed = context.read<FeedController>();
    _whenLoggedIn(context, (userId) {
      setState(() => _bursts.add(_Burst(_burstId++, _lastTap)));
      if (!feed.repository.isLiked(userId, film.id)) {
        feed.toggleLike(userId, film.id);
      }
    });
  }

  Future<void> _openMore(BuildContext context) async {
    final choice = await showShareSheet(context, film: film, speed: _speed);
    if (!context.mounted) return;
    switch (choice) {
      case SpeedChoice(:final speed):
        setState(() => _speed = speed);
      case ShareFilmChoice():
        await copyFilmDetails(context, film);
      case ReportChoice():
        _whenLoggedIn(context, (id) => showReportSheet(context, film, id));
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final userId = context.watch<AuthController>().user?.id;
    final episode = widget.episode ?? feed.currentEpisodeOf(film.id);
    final isLiked = userId != null && feed.repository.isLiked(userId, film.id);
    final isSaved = userId != null && feed.repository.isSaved(userId, film.id);
    final isFollowing =
        userId != null && feed.repository.isFollowing(userId, film.creatorId);
    final isOwn = userId == film.creatorId;
    // Room for the floating navigation bar when the feed runs under it.
    final inset = MediaQuery.paddingOf(context).bottom;

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
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                final gestures = Semantics(
                  button: true,
                  label: _paused ? 'Resume video' : 'Pause video',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _paused = !_paused),
                    onDoubleTapDown: (d) => _lastTap = d.localPosition,
                    onDoubleTap: _doubleTapLike,
                    onLongPressStart: (d) {
                      if (d.localPosition.dx <
                          box.maxWidth * (1 - _boostZone)) {
                        return;
                      }
                      if (context.read<SettingsController>().haptics) {
                        HapticFeedback.mediumImpact();
                      }
                      setState(() => _boosting = true);
                    },
                    onHorizontalDragEnd: (d) {
                      // A quick swipe to the left opens the channel.
                      if ((d.primaryVelocity ?? 0) < -_swipeVelocity) {
                        openCreatorProfile(context, film.creatorId);
                      }
                    },
                    onLongPressEnd: (_) => setState(() => _boosting = false),
                    onLongPressCancel: () => setState(() => _boosting = false),
                    child: film.catalogDramaId != null || playsVideo
                        ? const SizedBox.expand()
                        : Center(
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
                  ),
                );
                if (film.catalogDramaId == null && !playsVideo) return gestures;
                void next() {
                  if (episode < film.episodeCount) {
                    feed.resume(film.id, episode + 1);
                  }
                }

                // On the web the video is an HTML element that takes every
                // click, so the gestures sit above it behind an interceptor.
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (film.catalogDramaId != null) ...[
                      CatalogVideo(
                        film: film,
                        episode: episode,
                        paused: _paused,
                        speed: _boosting ? _boostSpeed : _speed,
                        onEnded: next,
                      ),
                      PointerInterceptor(child: gestures),
                    ] else
                      EpisodeVideo(
                        overlay: gestures,
                        // A new person or a new balance (after an unlock)
                        // asks the backend again.
                        key: ValueKey((
                          film.id,
                          userId,
                          context.read<AuthController>().user?.coinBalance,
                        )),
                        film: film,
                        episodeNo: episode,
                        paused: _paused,
                        speed: _boosting ? _boostSpeed : _speed,
                        onEnded: next,
                        onLocked: () => showEpisodes(context, film),
                      ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 104,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _boosting || _speed != 1 ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Center(
                  child: _SpeedPill(
                    label: speedLabel(_boosting ? _boostSpeed : _speed),
                    fast: _boosting || _speed > 1,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 340 + inset,
            child: const IgnorePointer(
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
          Center(
            child: IgnorePointer(
              child: AnimatedScale(
                scale: _paused ? 1 : 1.3,
                duration: const Duration(milliseconds: 180),
                child: AnimatedOpacity(
                  opacity: _paused ? 0.85 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 88,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 12, color: Color(0x66000000))],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: inset + 96,
            child: Column(
              children: [
                if (!isOwn)
                  _CreatorAvatar(
                    name: film.creatorName,
                    isFollowing: isFollowing,
                    onOpen: () => openCreatorProfile(context, film.creatorId),
                    onFollow: () => _whenLoggedIn(
                      context,
                      (id) => feed.toggleFollow(id, film.creatorId),
                    ),
                  ),
                _ActionButton(
                  icon: Icons.favorite_rounded,
                  color: isLiked ? AppColors.danger : AppColors.text,
                  label: compactCount(film.likeCount),
                  semanticLabel: 'Like, ${compactCount(film.likeCount)} likes',
                  onTap: () => _whenLoggedIn(
                    context,
                    (id) => feed.toggleLike(id, film.id),
                  ),
                ),
                _ActionButton(
                  customIcon: (c) => CommentIcon(color: c),
                  label: compactCount(film.commentCount),
                  semanticLabel: 'Comments, ${compactCount(film.commentCount)}',
                  onTap: () => showCommentsSheet(context, film),
                ),
                _ActionButton(
                  icon: Icons.bookmark_rounded,
                  color: isSaved ? AppColors.gold : AppColors.text,
                  label: 'Save',
                  semanticLabel: isSaved ? 'Saved' : 'Save film',
                  onTap: () => _whenLoggedIn(
                    context,
                    (id) => feed.toggleSave(id, film.id),
                  ),
                ),
                _ActionButton(
                  customIcon: (c) => ShareIcon(color: c),
                  label: 'Share',
                  semanticLabel: 'Share, speed and report',
                  onTap: () => _openMore(context),
                ),
                _ActionButton(
                  icon: Icons.playlist_play_rounded,
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
            bottom: inset + 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openCreatorProfile(context, film.creatorId),
                  child: ChannelName(
                    '@${film.creatorName}',
                    verified:
                        feed.repository.userById(film.creatorId)?.isVerified ??
                        false,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: _textShadow,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        film.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: _textShadow,
                        ),
                      ),
                    ),
                    if (film.isAiGenerated) ...[
                      const SizedBox(width: 8),
                      const AiLabelBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _Synopsis(film: film),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: inset + 8,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: episode / film.episodeCount,
                  minHeight: 2,
                  backgroundColor: const Color(0x33FFFFFF),
                  color: Colors.white,
                ),
              ),
            ),
          ),
          for (final burst in _bursts)
            _HeartBurst(
              key: ValueKey(burst.id),
              origin: burst.origin,
              onDone: () => setState(() => _bursts.remove(burst)),
            ),
        ],
      ),
    );
  }
}

const _synopsisStyle = TextStyle(
  fontSize: 13,
  height: 1.35,
  shadows: _textShadow,
);

/// The film's blurb, cut to two lines with a More link when it is longer.
class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.film});

  static const _lines = 2;

  final Film film;

  @override
  Widget build(BuildContext context) {
    final text = film.synopsis ?? '';
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _synopsisStyle),
          maxLines: _lines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: box.maxWidth);
        final cut = painter.didExceedMaxLines;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cut ? () => _showFullSynopsis(context, film) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: _lines,
                overflow: TextOverflow.ellipsis,
                style: _synopsisStyle,
              ),
              if (cut)
                const Text(
                  'More',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    shadows: _textShadow,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

void _showFullSynopsis(BuildContext context, Film film) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                film.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                film.synopsis ?? '',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Burst {
  const _Burst(this.id, this.origin);

  final int id;
  final Offset origin;
}

/// The big heart that pops where the person double-tapped, then drifts up
/// and fades.
class _HeartBurst extends StatelessWidget {
  const _HeartBurst({super.key, required this.origin, required this.onDone});

  final Offset origin;
  final VoidCallback onDone;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: origin.dx - _size / 2,
      top: origin.dy - _size / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          onEnd: onDone,
          builder: (_, t, child) {
            final pop = Curves.easeOutBack.transform((t * 3).clamp(0.0, 1.0));
            final fade = t < 0.65 ? 1.0 : (1 - t) / 0.35;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -50 * t),
                child: Transform.rotate(
                  angle: -0.2,
                  child: Transform.scale(scale: 0.4 + 0.8 * pop, child: child),
                ),
              ),
            );
          },
          child: const Icon(
            Icons.favorite_rounded,
            size: _size,
            color: AppColors.danger,
            shadows: [Shadow(blurRadius: 16, color: Color(0x66000000))],
          ),
        ),
      ),
    );
  }
}

/// Creator avatar at the top of the action rail. Tapping it opens the
/// channel; the plus badge follows the creator and goes away once followed.
class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({
    required this.name,
    required this.isFollowing,
    required this.onOpen,
    required this.onFollow,
  });

  final String name;
  final bool isFollowing;
  final VoidCallback onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: 52,
        height: 72,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Semantics(
              button: true,
              label: 'Open $name channel',
              excludeSemantics: true,
              onTap: onOpen,
              child: GestureDetector(
                key: const Key('channel-avatar'),
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.surfaceHigh,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isFollowing)
              Positioned(
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: 'Follow $name',
                  excludeSemantics: true,
                  onTap: onFollow,
                  child: GestureDetector(
                    key: const Key('follow-button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onFollow,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.label, required this.fast});

  final String label;
  final bool fast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label speed',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (fast) ...[
            const SizedBox(width: 4),
            const Icon(Icons.fast_forward_rounded, size: 18),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.icon,
    this.customIcon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.color = AppColors.text,
  });

  final IconData? icon;
  final Widget Function(Color color)? customIcon;
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
              customIcon?.call(color) ??
                  Icon(
                    icon,
                    size: 34,
                    color: color,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Color(0x80000000)),
                    ],
                  ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 4, color: Color(0xAA000000))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
