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

enum _Section { queue, live }

Future<void> _takeDown(BuildContext context, int filmId) async {
  final admin = context.read<AdminController>();
  final reason = await showReasonDialog(
    context,
    title: 'Take this film down?',
    hint: 'Why is it being removed?',
    confirmLabel: 'Take down',
  );
  if (reason != null && context.mounted) {
    await _guard(
      context,
      () => admin.review(filmId, 'taken_down', note: reason),
    );
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
  _Section _section = _Section.queue;

  bool _wasActive = false;

  /// Reads the queue again each time this tab comes to the front.
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
    final queue = admin.queue;
    final live = admin.liveFilms;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ChannelName(
                  'Admin',
                  verified: true,
                  badgeSize: 24,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF6B6B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Moderator',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (admin.isLoading &&
                admin.queue.isEmpty &&
                admin.liveFilms.isEmpty)
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
  const _FilmSummary({required this.film, this.detail, this.footer});

  final Film film;
  final String? detail;
  final Widget? footer;

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
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        ),
      ],
    );
  }
}

/// A film waiting for review. The server only lets a pending film become
/// approved or rejected (taking down is for live films), so only those two
/// actions are offered, and they are off while one is being sent.
class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.film});

  final Film film;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _busy = false;

  Film get film => widget.film;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _guard(context, action);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(BuildContext context) async {
    final admin = context.read<AdminController>();
    final reason = await showReasonDialog(
      context,
      title: 'Reject this film?',
      hint: 'Write the reason',
      confirmLabel: 'Reject',
    );
    if (reason != null && mounted) {
      await _run(() => admin.review(film.id, 'rejected', note: reason));
    }
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
              footer: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CheckChip(label: 'AI label', ok: film.isAiGenerated),
                  _CheckChip(label: 'Prompt credit', ok: hasCredit),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() => admin.review(film.id, 'approved')),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: _busy ? null : () => _reject(context),
                    child: const Text('Reject'),
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
              detail: '${compactCount(film.likeCount)} likes',
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

class _CheckChip extends StatelessWidget {
  const _CheckChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.green : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
