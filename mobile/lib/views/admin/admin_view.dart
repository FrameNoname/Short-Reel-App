import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';

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

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final sales = admin.sales;
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
            if (admin.isLoading)
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
          ],
        ),
      ),
    );
  }
}
