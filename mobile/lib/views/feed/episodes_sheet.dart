import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../data/app_repository.dart';
import '../../models/episode.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_label_badge.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import '../wallet/plus_view.dart';

class EpisodesSheet extends StatelessWidget {
  const EpisodesSheet({super.key, required this.film, required this.episodes});

  final Film film;
  final List<Episode> episodes;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final user = context.watch<AuthController>().user;
    final current = feed.currentEpisodeOf(film.id);
    final wallet = context.watch<WalletController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      // A long series has more tiles than the sheet has room for.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                if (film.isAiGenerated) ...[
                  const SizedBox(width: 8),
                  const AiLabelBadge(),
                ],
                const Spacer(),
                if (user != null) CoinAmount(user.coinBalance),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${episodes.length} episodes · @${film.creatorName}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final episode in episodes)
                  _EpisodeTile(
                    key: Key('episode-${episode.episodeNo}'),
                    episode: episode,
                    isCurrent: episode.episodeNo == current,
                    access: feed.repository.accessOf(user?.id, episode),
                    onTap: () => Navigator.of(context).pop(episode),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const _Legend(color: AppColors.green, label: 'Free'),
                const SizedBox(width: 14),
                const _Legend(color: AppColors.primary, label: 'Unlocked'),
                const SizedBox(width: 14),
                _Legend(
                  color: AppColors.gold,
                  label: '${wallet.episodePrice} coins',
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PlusView()),
                );
              },
              child: AppCard(
                color: AppColors.primarySoft,
                borderColor: const Color(0x667C5CFF),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Plus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Watch every episode',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Plus · ${wallet.planPrice} / month, no coins needed',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.isCurrent,
    required this.access,
    required this.onTap,
  });

  final Episode episode;
  final bool isCurrent;
  final EpisodeAccess access;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = isCurrent
        ? ('Playing', AppColors.link)
        : switch (access) {
            EpisodeAccess.free => ('Free', AppColors.green),
            EpisodeAccess.unlocked => ('Unlocked', AppColors.link),
            EpisodeAccess.plus => ('Plus', AppColors.link),
            EpisodeAccess.locked => (
              '${episode.priceCoins} coins',
              AppColors.gold,
            ),
          };
    final icon = isCurrent
        ? Icons.equalizer_rounded
        : access == EpisodeAccess.locked
        ? Icons.lock_rounded
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 14,
              child: icon == null ? null : Icon(icon, size: 14, color: color),
            ),
            Text(
              '${episode.episodeNo}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
