import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/catalog_controller.dart';
import '../../models/catalog.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';

/// The picture area of a catalog film in the feed.
///
/// The provider only wants links for what a person is watching, so the link
/// for an episode is requested once the page has stayed on screen for a
/// moment, not while someone is swiping past it.
class CatalogVideo extends StatefulWidget {
  const CatalogVideo({
    super.key,
    required this.film,
    required this.episode,
    required this.paused,
    required this.speed,
    required this.onEnded,
  });

  final Film film;
  final int episode;
  final bool paused;
  final double speed;

  /// The last part of the episode has finished.
  final VoidCallback onEnded;

  @override
  State<CatalogVideo> createState() => _CatalogVideoState();
}

class _CatalogVideoState extends State<CatalogVideo> {
  static const _settle = Duration(milliseconds: 700);

  Timer? _timer;
  VideoPlayerController? _video;
  List<EpisodePart> _parts = const [];
  int _partIndex = 0;
  String? _error;

  // A link can run out while a page stays open; asking once more gets a new
  // one. Only one retry per episode, so a real failure is not repeated.
  bool _retried = false;

  // Bumped whenever the episode changes or the page goes away, so a slow
  // reply for an old episode is dropped.
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  /// False while the film is not on screen, under another tab or another
  /// screen, where nothing should keep playing.
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TabActive.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible == _visible) return;
    _visible = visible;
    _applyPlayState();
  }

  void _applyPlayState() {
    final video = _video;
    if (video == null) return;
    _visible && !widget.paused ? video.play() : video.pause();
  }

  @override
  void didUpdateWidget(CatalogVideo old) {
    super.didUpdateWidget(old);
    if (old.episode != widget.episode) {
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
    _timer?.cancel();
    _token++;
    _video?.dispose();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _token++;
    _video?.dispose();
    _video = null;
    _parts = const [];
    _partIndex = 0;
    _error = null;
    _retried = false;
  }

  void _scheduleLoad() {
    _timer = Timer(_settle, _load);
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() => _error = null);
    try {
      final service = context.read<CatalogController>().service;
      final parts = await service.episodeParts(
        widget.film.catalogDramaId!,
        widget.episode,
      );
      if (token != _token) return;
      if (parts.isEmpty) throw StateError('no parts');
      _parts = parts;
      await _openPart(0, token);
    } catch (_) {
      if (token != _token || !mounted) return;
      if (_retryOnce()) return;
      setState(() => _error = 'Cannot play this episode');
    }
  }

  bool _retryOnce() {
    if (_retried) return false;
    _retried = true;
    _load();
    return true;
  }

  Future<ClosedCaptionFile>? _captionFor(EpisodePart part) {
    final url = part.thaiSubtitleUrl;
    if (url == null) return null;
    final service = context.read<CatalogController>().service;
    return service
        .fetchSubtitle(url)
        .then((text) => WebVTTCaptionFile(text ?? r'WEBVTT'));
  }

  Future<void> _openPart(int index, int token) async {
    final next = VideoPlayerController.networkUrl(
      Uri.parse(_parts[index].url),
      closedCaptionFile: _captionFor(_parts[index]),
    );
    await next.initialize();
    if (token != _token) {
      await next.dispose();
      return;
    }
    await next.setPlaybackSpeed(widget.speed);
    var finished = false;
    next.addListener(() {
      final value = next.value;
      if (value.hasError && token == _token && mounted) _retryOnce();
      if (finished || !value.isInitialized || value.duration == Duration.zero) {
        return;
      }
      if (value.position >= value.duration && !value.isPlaying) {
        finished = true;
        _onPartEnded(token);
      }
    });
    final old = _video;
    setState(() {
      _video = next;
      _partIndex = index;
    });
    if (_visible && !widget.paused) await next.play();
    await old?.dispose();
  }

  void _onPartEnded(int token) {
    if (token != _token) return;
    if (_partIndex + 1 < _parts.length) {
      _openPart(_partIndex + 1, token);
    } else {
      widget.onEnded();
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
          )
        else if (_error != null)
          Center(
            child: Text(_error!, style: const TextStyle(color: AppColors.text)),
          )
        else
          const Center(child: CircularProgressIndicator()),
        if (video != null && video.value.isInitialized)
          // Kept clear of the buttons on the right and the title and blurb
          // underneath.
          Positioned(
            left: 18,
            right: 70,
            bottom: 200,
            child: IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: video,
                builder: (_, value, _) =>
                    _Subtitle(text: value.caption.text.trim()),
              ),
            ),
          ),
      ],
    );
  }
}

/// White text with a dark edge, the way subtitles sit on a picture, with no
/// box over the video.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});

  static const _edge = [
    Shadow(offset: Offset(-1, -1), color: Color(0xFF000000)),
    Shadow(offset: Offset(1, -1), color: Color(0xFF000000)),
    Shadow(offset: Offset(-1, 1), color: Color(0xFF000000)),
    Shadow(offset: Offset(1, 1), color: Color(0xFF000000)),
    Shadow(blurRadius: 6, color: Color(0xCC000000)),
  ];

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        shadows: _edge,
      ),
    );
  }
}
