import 'package:flutter/material.dart' hide Text;

import '../../l10n/app_language.dart';
import '../../models/episode.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

class UnlockSuccessView extends StatelessWidget {
  const UnlockSuccessView({
    super.key,
    required this.film,
    required this.episode,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.nextEpisode,
  });

  final Film film;
  final Episode episode;
  final int balanceBefore;
  final int balanceAfter;
  final Episode? nextEpisode;

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();
    final next = nextEpisode;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: context.tr('Close'),
                icon: const Icon(Icons.close),
                onPressed: close,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    SizedBox(
                      width: 180,
                      height: 230,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: FilmPoster(film: film)),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Text(
                              'Episode ${episode.episodeNo}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -18,
                            bottom: -18,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.elasticOut,
                              builder: (_, t, child) =>
                                  Transform.scale(scale: t, child: child),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.background,
                                    width: 4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Episode ${episode.episodeNo} is yours',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${film.title}. It stays in your library, so you can rewatch it anytime.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.toll_rounded,
                            size: 16,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$balanceBefore',
                            style: const TextStyle(
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            '$balanceAfter coins',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                children: [
                  if (next != null) ...[
                    AppCard(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Up next',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                          Text(
                            'Episode ${next.episodeNo}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.gold,
                          ),
                          Text(
                            ' ${next.priceCoins}',
                            style: const TextStyle(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: close,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Play episode ${episode.episodeNo}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
