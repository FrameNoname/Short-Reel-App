import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../models/subscription.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/login_prompt.dart';
import '../auth/login_view.dart';
import 'plus_view.dart';
import 'top_up_view.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  bool _historyOpen = true;

  void _open(Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  Future<void> _cancelPlan() async {
    final wallet = context.read<WalletController>();
    final end = shortDate(wallet.subscription!.endDate);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel Plus?',
      message:
          'You keep every episode until $end. After that, coins apply again.',
      confirmLabel: 'Cancel plan',
      cancelLabel: 'Keep Plus',
    );
    if (confirmed) wallet.cancelPlan();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthController>().isLoggedIn;
    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: LoginPrompt(onLogin: () => _open(const LoginView())),
      );
    }
    final wallet = context.watch<WalletController>();
    final history = wallet.transactions;
    final subscription = wallet.subscription;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wallet',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                DemoBadge(),
              ],
            ),
            const SizedBox(height: 14),
            BalanceCard(
              balance: wallet.balance,
              episodePrice: wallet.episodePrice,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _open(const TopUpView()),
                    child: const Text('Top up coins'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 124,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: wallet.demoTopUp,
                    child: const Text('+100 free'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Payments are simulated. No real money is charged.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _PlusCard(
              subscription: subscription,
              planPrice: wallet.planPrice,
              onGet: () => _open(const PlusView()),
              onCancel: _cancelPlan,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${history.length}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _historyOpen = !_historyOpen),
                  child: Text(
                    _historyOpen ? 'Hide' : 'Show',
                    style: const TextStyle(color: AppColors.link),
                  ),
                ),
              ],
            ),
            if (_historyOpen)
              if (history.isEmpty)
                const EmptyView(message: 'No coin activity yet.')
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final item in history) _HistoryRow(item: item),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.episodePrice,
  });

  final int balance;
  final int episodePrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B2F0E), Color(0xFF1F1A0C)],
        ),
        border: Border.all(color: const Color(0x55FFC53D)),
      ),
      child: Column(
        children: [
          const Text(
            'Your balance',
            style: TextStyle(color: AppColors.gold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.toll, color: AppColors.gold, size: 32),
              const SizedBox(width: 10),
              Text(
                '$balance',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            'Enough for ${balance ~/ episodePrice} episodes',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlusCard extends StatelessWidget {
  const _PlusCard({
    required this.subscription,
    required this.planPrice,
    required this.onGet,
    required this.onCancel,
  });

  final Subscription? subscription;
  final String planPrice;
  final VoidCallback onGet;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final plan = subscription;
    final daysLeft = plan?.endDate.difference(DateTime.now()).inDays ?? 0;
    final total = plan?.endDate.difference(plan.startDate).inDays ?? 1;
    return GestureDetector(
      onTap: plan == null ? onGet : null,
      child: AppCard(
        color: AppColors.primarySoft,
        borderColor: const Color(0x667C5CFF),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plus',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Every episode, no coins.\n$planPrice a month',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan != null)
                  StatusText(plan.isCancelled ? 'Cancelled' : 'Active')
                else
                  const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            if (plan != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: 1 - daysLeft / total,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Started ${shortDate(plan.startDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Flexible(
                    child: Text(
                      plan.isCancelled
                          ? 'Ends ${shortDate(plan.endDate)}'
                          : '$daysLeft days left, renews ${shortDate(plan.endDate)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (!plan.isCancelled)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel Plus',
                      style: TextStyle(color: AppColors.link),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusText extends StatelessWidget {
  const StatusText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x263DD68C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final Transaction item;

  @override
  Widget build(BuildContext context) {
    final isTopUp = item.amount > 0;
    final sign = isTopUp ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTopUp ? const Color(0x33FFC53D) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isTopUp ? Icons.add : Icons.download,
              size: 16,
              color: isTopUp ? AppColors.gold : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isTopUp
                      ? shortDate(item.createdAt)
                      : 'Unlocked ${shortDate(item.createdAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$sign${item.amount.abs()}',
            style: TextStyle(
              color: isTopUp ? AppColors.gold : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
