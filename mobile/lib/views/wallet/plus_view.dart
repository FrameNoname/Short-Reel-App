import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_view.dart';

class PlusView extends StatelessWidget {
  const PlusView({super.key});

  Future<void> _start(BuildContext context) async {
    if (!context.read<AuthController>().isLoggedIn) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginView()));
      return;
    }
    await context.read<WalletController>().subscribe();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final planPrice = context.watch<WalletController>().planPrice;
    final start = DateTime.now();
    final end = start.add(const Duration(days: 30));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.1,
            colors: [Color(0xFF2B2358), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: CloseButton(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.star, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Watch every episode with Plus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No coins, no locks. Binge any film from the first episode to the last.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 22),
                      const _Benefit(
                        icon: Icons.play_arrow_outlined,
                        title: 'Every episode unlocked',
                        subtitle: 'Locked episodes play right away',
                      ),
                      const _Benefit(
                        icon: Icons.toll_outlined,
                        title: 'No coins needed',
                        subtitle: 'Keep your coins for later',
                      ),
                      const _Benefit(
                        icon: Icons.favorite_border,
                        title: 'Support creators',
                        subtitle: 'Your plan helps fund AI filmmakers',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Column(
                  children: [
                    AppCard(
                      color: AppColors.primarySoft,
                      borderColor: AppColors.primary,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Plus monthly',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${shortDate(start)} to ${shortDate(end)}, cancel anytime',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            planPrice,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            ' /mo',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _start(context),
                      child: Text('Start Plus for $planPrice'),
                    ),
                    const SizedBox(height: 8),
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                        children: [
                          TextSpan(
                            text: 'DEMO ',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text:
                                'Payment is simulated. No real money is charged.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
