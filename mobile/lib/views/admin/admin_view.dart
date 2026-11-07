import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';
import 'admin_comments_view.dart';
import 'admin_films_view.dart';
import 'admin_settings_view.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  bool _wasActive = false;

  /// Reads the sales again each time this tab comes to the front.
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

  Future<void> _open(Widget view) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => view));
    if (mounted) context.read<AdminController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final sales = admin.sales;
    final top = sales.perFilm.take(5).toList();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: admin.load,
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
              if (admin.isLoading) const LinearProgressIndicator(),
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
              const SizedBox(height: 18),
              const _SectionLabel('Top sellers'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: top.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No unlocks yet',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final (i, f) in top.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      f.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${f.coinsSpent} coins',
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
              const SizedBox(height: 18),
              const _SectionLabel('Manage'),
              _MenuRow(
                icon: Icons.movie_outlined,
                title: 'Films and episodes',
                subtitle: 'Take films down, set episode prices',
                onTap: () => _open(const AdminFilmsView()),
              ),
              _MenuRow(
                icon: Icons.chat_bubble_outline,
                title: 'Comments',
                subtitle: 'Read and remove comments',
                onTap: () => _open(const AdminCommentsView()),
              ),
              _MenuRow(
                icon: Icons.tune,
                title: 'Prices and coin packs',
                subtitle: 'Series Jeen prices, free episodes, coin packs',
                onTap: () => _open(const AdminSettingsView()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: onTap,
        ),
      ),
    );
  }
}
