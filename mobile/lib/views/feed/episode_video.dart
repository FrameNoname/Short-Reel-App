import 'package:flutter/material.dart' hide Text;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/film.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';

/// Plays an episode of a film uploaded to ShortReel.
///
/// The backend decides whether this viewer may watch it and hands out a
/// short-lived link only when they may; a locked episode never reaches the
/// video player. One video exists at a time: it is disposed when the episode
/// changes, the page goes away, or another tab or screen covers this one.
class EpisodeVideo extends StatefulWidget {
  const EpisodeVideo({
    super.key,
    required this.film,
    required this.episodeNo,
    required this.paused,
    required this.speed,
    required this.onEnded,
    required this.onLocked,
    required this.overlay,
  });

  final Film film;
  final int episodeNo;
  final bool paused;
  final double speed;

  /// The episode played to its end.
  final VoidCallback onEnded;

  /// The viewer pressed the button on the "log in or unlock" prompt. The
  /// future completes when they are done there, and the episode is asked for
  /// again, so an unlock, a Plus plan or a login takes effect at once.
  final Future<void> Function() onLocked;

  /// The gesture layer. It sits above the video, which on the web is an HTML
  /// element that would otherwise take every click, and below the prompt.
  final Widget overlay;

  @override
  State<EpisodeVideo> createState() => _EpisodeVideoState();
}

class _EpisodeVideoState extends State<EpisodeVideo> {
  static const _settle = Duration(milliseconds: 500);

  VideoPlayerController? _video;
  String? _message;
  bool _locked = false;
  bool _loading = true;
  bool _visible = true;

  // Bumped whenever the episode changes or the page goes away, so a slow
  // reply for an old episode is dropped instead of starting a second video.
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TabActive.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible == _visible) return;
    _visible = visible;
    _applyPlayState();
  }

  @override
  void didUpdateWidget(EpisodeVideo old) {
    super.didUpdateWidget(old);
    if (old.episodeNo != widget.episodeNo || old.film.id != widget.film.id) {
      _reset();
      _scheduleLoad();
      return;
    }
    final video = _video;
    if (video == null) return;
    if (old.paused != widget.paused) _applyPlayState();
    if (old.speed != widget.speed) video.setPlaybackSpeed(widget.speed);
  }

  @override
  void dispose() {
    _token++;
    _video?.dispose();
    super.dispose();
  }

  void _applyPlayState() {
    final video = _video;
    if (video == null) return;
    _visible && !widget.paused ? video.play() : video.pause();
  }

  void _reset() {
    _token++;
    _video?.dispose();
    _video = null;
    _message = null;
    _locked = false;
    _loading = true;
  }

  void _scheduleLoad() {
    final token = _token;
    // Wait a moment so swiping past a page does not start a download.
    Future<void>.delayed(_settle, () {
      if (mounted && token == _token) _load();
    });
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final repository = context.read<FeedController>().repository;
      final episodes = await repository.episodes(widget.film.id);
      final match = episodes.where((e) => e.episodeNo == widget.episodeNo);
      if (match.isEmpty) throw StateError('no such episode');
      final playback = await repository.playback(match.first.id);
      if (token != _token || !mounted) return;
      final url = playback.streamUrl;
      if (url == null) {
        final loggedIn = context.read<AuthController>().isLoggedIn;
        setState(() {
          _loading = false;
          _locked = true;
          _message = loggedIn
              ? 'This episode costs coins. Unlock it to keep watching.'
              : 'Log in to keep watching this episode.';
        });
        return;
      }
      final next = VideoPlayerController.networkUrl(Uri.parse(url));
      await next.initialize();
      if (token != _token || !mounted) {
        await next.dispose();
        return;
      }
      await next.setPlaybackSpeed(widget.speed);
      var finished = false;
      next.addListener(() {
        final value = next.value;
        if (value.hasError && token == _token && mounted && _message == null) {
          setState(() => _message = 'This video cannot be played.');
        }
        if (finished || !value.isInitialized || value.duration == Duration.zero) {
          return;
        }
        if (value.position >= value.duration && !value.isPlaying) {
          finished = true;
          widget.onEnded();
        }
      });
      setState(() {
        _video = next;
        _loading = false;
      });
      if (_visible && !widget.paused) await next.play();
    } on Object catch (e) {
      if (token != _token || !mounted) return;
      setState(() {
        _loading = false;
        _message = e is StateError
            ? 'This episode is not available.'
            : errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final poster = widget.film.posterUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          Image.network(
            poster,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (video != null && video.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          ),
        PointerInterceptor(child: widget.overlay),
        if (video != null && video.value.isInitialized)
          // Drag to seek. It sits above the title, clear of the buttons on the
          // right, and is lifted over the web video element.
          Positioned(
            left: 14,
            right: 72,
            bottom: 196,
            child: PointerInterceptor(
              child: SizedBox(
                height: 24,
                child: VideoProgressIndicator(
                  video,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary,
                    bufferedColor: Color(0x55FFFFFF),
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
              ),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_message != null)
          PointerInterceptor(
            child: Center(
              child: Padding(
              // Clear of the action buttons down the right edge.
              padding: const EdgeInsets.fromLTRB(24, 24, 84, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text),
                  ),
                  const SizedBox(height: 10),
                  if (_locked)
                    FilledButton(
                      key: const Key('video-unlock'),
                      onPressed: () async {
                        await widget.onLocked();
                        if (!mounted) return;
                        _reset();
                        _load();
                      },
                      child: Text(
                        context.read<AuthController>().isLoggedIn
                            ? 'Unlock'
                            : 'Log in or unlock',
                      ),
                    )
                  else
                    OutlinedButton(
                      key: const Key('video-retry'),
                      onPressed: () {
                        _reset();
                        _load();
                      },
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
            ),
          ),
      ],
    );
  }
}
