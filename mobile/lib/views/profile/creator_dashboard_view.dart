import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/upload_controller.dart';
import '../../data/app_repository.dart';
import '../../models/film.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_view.dart';
import '../upload/upload_view.dart';

class CreatorDashboardView extends StatelessWidget {
  const CreatorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<UploadController>().repository;
    final userId = context.watch<AuthController>().user!.id;
    final adminShare = context.watch<AdminController>().adminSharePercent;
    final creatorShare = 100 - adminShare;
    final earnings = repository.earningsOf(userId);
    final films = repository.filmsOf(userId);
    return Scaffold(
      appBar: AppBar(title: const Text('Creator studio')),
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
                child: StatTile(
                  value: compactCount(earnings.views),
                  label: 'Views',
                ),
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
                child: _CreatorFilmCard(film: film, repository: repository),
              ),
        ],
      ),
    );
  }
}

class _CreatorFilmCard extends StatelessWidget {
  const _CreatorFilmCard({required this.film, required this.repository});

  final Film film;
  final AppRepository repository;

  String get _detail {
    final pricing = repository.pricingOf(film.id);
    return switch (film.status) {
      'approved' =>
        '${film.episodeCount} eps · ${pricing.freeCount} free · '
            '${pricing.paidCount} × ${pricing.priceCoins} coins',
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
      controller.remove(film.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final earned = repository.earningsOfFilm(film.id);
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UploadView(film: film),
                  ),
                ),
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
