import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../models/transaction.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/login_prompt.dart';
import '../../widgets/tab_active.dart';
import '../../widgets/text.dart';
import '../auth/login_view.dart';
import 'top_up_view.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  bool _historyOpen = true;
  _HistoryFilter _filter = _HistoryFilter.all;

  bool _wasActive = false;

  /// Tabs stay alive side by side, so the numbers are read again each time
  /// this tab comes to the front.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TabActive.of(context);
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<WalletController>().load();
      });
    }
    _wasActive = active;
  }

  Future<void> _demoTopUp(WalletController wallet) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await wallet.demoTopUp();
      messenger.showSnackBar(
        SnackBar(content: Text('Added ${wallet.demoTopUpCoins} free coins.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  void _open(Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
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
    final shown = history.where(_filter.matches).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Wallet',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(width: 8),
                DemoBadge(),
              ],
            ),
            const SizedBox(height: 14),
            if (wallet.isLoading && wallet.transactions.isEmpty)
              const LinearProgressIndicator(),
            if (wallet.error != null)
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: Text(wallet.error!)),
                    TextButton(
                      onPressed: wallet.load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
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
                    onPressed: () => _demoTopUp(wallet),
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
            const SizedBox(height: 4),
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
            if (_historyOpen) ...[
              const SizedBox(height: 4),
              _FilterChips(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                const EmptyView(message: 'No coin activity yet.')
              else if (shown.isEmpty)
                EmptyView(message: _filter.emptyMessage)
              else ...[
                _HistorySummary(items: shown),
                const SizedBox(height: 10),
                for (final group in _groupByDay(shown)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
                    child: Text(
                      group.label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (final item in group.items) _HistoryRow(item: item),
                      ],
                    ),
                  ),
                ],
              ],
            ],
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
            _enoughFor(balance ~/ episodePrice),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _enoughFor(int episodes) =>
    'Enough for $episodes ${episodes == 1 ? 'episode' : 'episodes'}';

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
                  isTopUp ? 'Top-up' : 'Episode unlock',
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

enum _HistoryFilter {
  all('All', 'No coin activity yet.'),
  added('Added', 'No top-ups yet.'),
  spent('Spent', 'No unlocks yet.');

  const _HistoryFilter(this.label, this.emptyMessage);

  final String label;
  final String emptyMessage;

  bool matches(Transaction item) => switch (this) {
    all => true,
    added => item.amount > 0,
    spent => item.amount < 0,
  };
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _HistoryFilter selected;
  final ValueChanged<_HistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _HistoryFilter.values)
          Padding(
            padding: EdgeInsets.zero,
            child: Semantics(
              button: true,
              selected: filter == selected,
              label: 'Show ${filter.label.toLowerCase()}',
              excludeSemantics: true,
              onTap: () => onSelected(filter),
              child: GestureDetector(
                key: Key('history-${filter.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(filter),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: filter == selected
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: filter == selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: filter == selected ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Totals for whatever the current filter is showing.
class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.items});

  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final added = items
        .where((i) => i.amount > 0)
        .fold(0, (a, i) => a + i.amount);
    final spent = items
        .where((i) => i.amount < 0)
        .fold(0, (a, i) => a - i.amount);
    return Row(
      children: [
        if (added > 0)
          _Total(label: 'Added', value: '+$added', color: AppColors.gold),
        if (added > 0 && spent > 0) const SizedBox(width: 16),
        if (spent > 0)
          _Total(label: 'Spent', value: '−$spent', color: AppColors.text),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DayGroup {
  const _DayGroup(this.label, this.items);

  final String label;
  final List<Transaction> items;
}

/// Newest first, as the repository already orders them.
List<_DayGroup> _groupByDay(List<Transaction> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  String labelFor(DateTime date) {
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    return switch (days) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => shortDate(date),
    };
  }

  final groups = <_DayGroup>[];
  for (final item in items) {
    final label = labelFor(item.createdAt);
    if (groups.isNotEmpty && groups.last.label == label) {
      groups.last.items.add(item);
    } else {
      groups.add(_DayGroup(label, [item]));
    }
  }
  return groups;
}
