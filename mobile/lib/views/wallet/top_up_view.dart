import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/wallet_controller.dart';
import '../../models/coin_pack.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import 'wallet_view.dart';

class TopUpView extends StatefulWidget {
  const TopUpView({super.key});

  @override
  State<TopUpView> createState() => _TopUpViewState();
}

class _TopUpViewState extends State<TopUpView> {
  CoinPack? _selected;
  bool _busy = false;

  String _describe(CoinPack pack) {
    final episodes =
        pack.coins ~/ context.read<WalletController>().episodePrice;
    return switch (pack.coins) {
      330 => 'Includes 30 bonus coins, about $episodes episodes',
      750 => 'Includes 100 bonus coins, about $episodes episodes',
      _ => 'About $episodes episodes',
    };
  }

  String? _badge(CoinPack pack) => switch (pack.coins) {
    330 => 'Most popular',
    750 => 'Best value',
    _ => null,
  };

  Future<void> _buy(CoinPack pack) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<WalletController>().buy(
        coins: pack.coins,
        priceUsd: pack.priceUsd,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final packs = wallet.coinPacks;
    final selected = _selected ?? packs[1];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top up'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 14), child: DemoBadge()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          BalanceCard(
            balance: wallet.balance,
            episodePrice: wallet.episodePrice,
          ),
          const SizedBox(height: 22),
          const Text(
            'Choose a coin pack',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Demo purchase. No real money is charged.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          for (final pack in packs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selected = pack),
                child: AppCard(
                  color: pack == selected
                      ? AppColors.primarySoft
                      : AppColors.surface,
                  borderColor: pack == selected
                      ? AppColors.primary
                      : AppColors.border,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x26FFC53D),
                        ),
                        child: const Icon(
                          Icons.toll_rounded,
                          color: AppColors.gold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${pack.coins} coins',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_badge(pack) case final badge?) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      badge,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _describe(pack),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${pack.priceUsd}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        pack == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: pack == selected
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: FilledButton(
            onPressed: _busy ? null : () => _buy(selected),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Buy ${selected.coins} coins for \$${selected.priceUsd}',
                  ),
          ),
        ),
      ),
    );
  }
}
