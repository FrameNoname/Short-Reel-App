import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../models/film.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';

Future<void> _takeDown(BuildContext context, Film film) async {
  final admin = context.read<AdminController>();
  final confirmed = await showConfirmDialog(
    context,
    title: 'Take this film down?',
    message: film.title,
    confirmLabel: 'Take down',
  );
  if (confirmed && context.mounted) {
    await _guard(context, () => admin.takeDown(film.id));
  }
}

/// Runs an admin action and shows the server's message if it fails.
Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }
}

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  bool _wasActive = false;

  /// Reads the films and sales again each time this tab comes to the front.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TabActive.of(context);
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AdminController>().load();
      });
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final sales = admin.sales;
    final live = admin.liveFilms;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const ChannelName(
              'Admin',
              verified: true,
              badgeSize: 24,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (admin.isLoading && live.isEmpty)
              const LinearProgressIndicator(),
            if (admin.error != null)
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: Text(admin.error!)),
                    TextButton(
                      onPressed: admin.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '\$${sales.totalUsd.toStringAsFixed(2)}',
                    label: 'Simulated sales (USD)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: '${sales.coinsSpent} coins',
                    label: 'Coins spent on ${sales.unlockCount} unlocks',
                    valueColor: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Live (${live.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (live.isEmpty)
              const EmptyView(message: 'No live films.')
            else
              for (final film in live) _LiveFilmCard(film: film),
          ],
        ),
      ),
    );
  }
}

class _FilmSummary extends StatelessWidget {
  const _FilmSummary({required this.film, this.detail});

  final Film film;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                '${film.genreName} · ${film.aiToolName}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveFilmCard extends StatelessWidget {
  const _LiveFilmCard({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _FilmSummary(
              film: film,
              detail: '${compactCount(film.likeCount)} likes',
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              onPressed: () => _takeDown(context, film),
              child: const Text('Take down'),
            ),
          ],
        ),
      ),
    );
  }
}
