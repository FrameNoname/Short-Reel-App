import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/upload_controller.dart';
import '../../data/app_repository.dart';
import '../../models/film.dart';
import '../../services/api_client.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/text.dart';
import '../upload/upload_view.dart';
import 'creator_profile_view.dart';
import 'creator_stats.dart';

/// Everything the studio shows, read from the backend in one go.
class _Studio {
  const _Studio(this.earnings, this.films, this.pricing);

  final Earnings earnings;
  final List<Film> films;
  final Map<int, EpisodePricing> pricing;
}

class CreatorDashboardView extends StatefulWidget {
  const CreatorDashboardView({super.key});

  @override
  State<CreatorDashboardView> createState() => _CreatorDashboardViewState();
}

class _CreatorDashboardViewState extends State<CreatorDashboardView> {
  late Future<_Studio> _future = _load();

  Future<_Studio> _load() async {
    final repository = context.read<UploadController>().repository;
    final userId = context.read<AuthController>().user!.id;
    final earnings = await repository.earningsOf(userId);
    final films = await repository.filmsOf(userId);
    final pricing = {
      for (final film in films) film.id: await repository.pricingOf(film.id),
    };
    return _Studio(earnings, films, pricing);
  }

  void _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthController>().user!.id;
    // Re-read after an upload, edit or delete.
    context.watch<UploadController>();
    return FutureBuilder<_Studio>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Creator studio')),
            body: snapshot.hasError
                ? ErrorView(
                    message: errorMessage(snapshot.error!),
                    onRetry: _reload,
                  )
                : const LoadingView(),
          );
        }
        return _buildStudio(context, userId, data);
      },
    );
  }

  Widget _buildStudio(BuildContext context, int userId, _Studio data) {
    final repository = context.read<UploadController>().repository;
    final earnings = data.earnings;
    final films = data.films;
    final adminShare = earnings.adminSharePercent ?? 30;
    final creatorShare = 100 - adminShare;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator studio'),
        actions: [
          TextButton.icon(
            onPressed: () => openCreatorProfile(context, userId),
            icon: const Icon(Icons.person_outline_rounded, size: 18),
            label: const Text('My channel'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          AppCard(
            color: AppColors.primarySoft,
            borderColor: const Color(0x667C5CFF),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your earnings'),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Icon(
                      Icons.toll_rounded,
                      color: AppColors.gold,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${earnings.coins}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '  coins',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'From ${earnings.unlocks} paid unlock${earnings.unlocks == 1 ? '' : 's'} · '
                  'you keep $creatorShare%, admin share $adminShare%',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: creatorShare / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.primary,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(value: '${films.length}', label: 'Films'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  value: compactCount(earnings.likes),
                  label: 'Likes',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(value: '${earnings.unlocks}', label: 'Unlocks'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (repository.dailyStatsOf(userId).isNotEmpty) ...[
            PerformanceCard(stats: repository.dailyStatsOf(userId)),
            const SizedBox(height: 10),
          ],
          TopFilmsCard(
            films: films.where((f) => f.status == 'approved').toList(),
            coinsOf: (film) => earnings.coinsByFilm[film.id] ?? 0,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your films',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const UploadView()),
                ),
                child: const Text(
                  '+ Upload',
                  style: TextStyle(color: AppColors.link),
                ),
              ),
            ],
          ),
          if (films.isEmpty)
            const EmptyView(message: 'Upload your first film.')
          else
            for (final film in films)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CreatorFilmCard(
                  film: film,
                  pricing: data.pricing[film.id]!,
                  earned: earnings.coinsByFilm[film.id] ?? 0,
                  onChanged: _reload,
                ),
              ),
        ],
      ),
    );
  }
}

class _CreatorFilmCard extends StatelessWidget {
  const _CreatorFilmCard({
    required this.film,
    required this.pricing,
    required this.earned,
    required this.onChanged,
  });

  final Film film;
  final EpisodePricing pricing;
  final int earned;
  final VoidCallback onChanged;

  String get _detail {
    return switch (film.status) {
      'approved' =>
        '${film.episodeCount} eps · ${pricing.freeCount} free · '
            '${pricing.paidCount} × '
            '${pricing.hasMixedPrices ? '${pricing.priceCoins}–${pricing.maxPriceCoins}' : pricing.priceCoins} coins',
      'pending' => 'Waiting for admin review',
      'taken_down' => 'Taken down by admin',
      _ => '"${film.reviewNote ?? 'Not approved'}" — edit and resubmit',
    };
  }

  Future<void> _delete(BuildContext context) async {
    final controller = context.read<UploadController>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this film?',
      message: '${film.title} and all its episodes will be removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await controller.remove(film.id);
      onChanged();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 66,
                child: FilmPoster(film: film, showBadge: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            film.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusChip(film.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _detail,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (film.status == 'approved') ...[
                      const SizedBox(height: 3),
                      Text(
                        '$earned coins earned',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UploadView(film: film),
                    ),
                  );
                  onChanged();
                },
                child: const Text(
                  'Edit film',
                  style: TextStyle(color: AppColors.link),
                ),
              ),
              TextButton(
                onPressed: () => _delete(context),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
