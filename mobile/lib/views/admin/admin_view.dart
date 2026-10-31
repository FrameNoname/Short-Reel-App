import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_view.dart';

enum _Section { queue, reports, live }

Future<void> _takeDown(BuildContext context, int filmId) async {
  final admin = context.read<AdminController>();
  final reason = await showReasonDialog(
    context,
    title: 'Take this film down?',
    hint: 'Why is it being removed?',
    confirmLabel: 'Take down',
  );
  if (reason != null) admin.review(filmId, 'taken_down', note: reason);
}

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  _Section _section = _Section.queue;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final sales = admin.sales;
    final queue = admin.queue;
    final reports = admin.reports;
    final live = admin.liveFilms;
    final adminShare = admin.adminSharePercent;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Admin',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF6B6B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '\$${sales.totalUsd.toStringAsFixed(2)}',
                    label: 'Total sales (demo)',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: '${sales.adminCoins} coins',
                    label: 'Admin share',
                    valueColor: AppColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Revenue share',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Creator ${100 - adminShare}% · Admin $adminShare%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: (100 - adminShare).toDouble(),
                    max: 100,
                    divisions: 20,
                    label: 'Creator ${100 - adminShare}%',
                    onChanged: (value) =>
                        admin.setAdminShare(100 - value.round()),
                  ),
                  const Text(
                    'Applies to new unlocks. Admin-owned films always pay 100% to admin.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SectionTab(
                    label: 'Review queue (${queue.length})',
                    selected: _section == _Section.queue,
                    onTap: () => setState(() => _section = _Section.queue),
                  ),
                ),
                Expanded(
                  child: _SectionTab(
                    label: 'Reports (${reports.length})',
                    selected: _section == _Section.reports,
                    onTap: () => setState(() => _section = _Section.reports),
                  ),
                ),
                Expanded(
                  child: _SectionTab(
                    label: 'Live (${live.length})',
                    selected: _section == _Section.live,
                    onTap: () => setState(() => _section = _Section.live),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...switch (_section) {
              _Section.queue =>
                queue.isEmpty
                    ? const [EmptyView(message: 'The review queue is empty.')]
                    : [for (final film in queue) _ReviewCard(film: film)],
              _Section.reports =>
                reports.isEmpty
                    ? const [EmptyView(message: 'No open reports.')]
                    : [for (final r in reports) _ReportCard(report: r)],
              _Section.live =>
                live.isEmpty
                    ? const [EmptyView(message: 'No live films.')]
                    : [for (final film in live) _LiveFilmCard(film: film)],
            },
          ],
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.text : AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FilmSummary extends StatelessWidget {
  const _FilmSummary({required this.film, required this.detail});

  final Film film;
  final String detail;

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
                '@${film.creatorName} · ${film.genreName} · ${film.aiToolName}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                detail,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.film});

  final Film film;

  Future<void> _reject(BuildContext context) async {
    final admin = context.read<AdminController>();
    final reason = await showReasonDialog(
      context,
      title: 'Reject this film?',
      hint: 'Tell the creator what to fix',
      confirmLabel: 'Reject',
    );
    if (reason != null) admin.review(film.id, 'rejected', note: reason);
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminController>();
    final hasCredit = (film.promptCredit ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _FilmSummary(
              film: film,
              detail:
                  'AI label ${film.isAiGenerated ? '✓' : '✗'} · '
                  'prompt credit ${hasCredit ? '✓' : '✗'}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => admin.review(film.id, 'approved'),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _reject(context),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _takeDown(context, film.id),
                    child: const Text('Take down'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final FilmReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.filmTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              report.reason,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context
                        .read<AdminController>()
                        .resolveReport(report.id),
                    child: const Text('Mark resolved'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _takeDown(context, report.filmId),
                    child: const Text('Take down film'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
              detail: '${compactCount(film.viewCount)} views',
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              onPressed: () => _takeDown(context, film.id),
              child: const Text('Take down'),
            ),
          ],
        ),
      ),
    );
  }
}
