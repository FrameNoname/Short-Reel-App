import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wallet_controller.dart';
import '../../models/coin_pack.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'wallet_view.dart';

class TopUpView extends StatefulWidget {
  const TopUpView({super.key});

  @override
  State<TopUpView> createState() => _TopUpViewState();
}

class _TopUpViewState extends State<TopUpView> {
  CoinPack? _selected;

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
    await context.read<WalletController>().buy(
      coins: pack.coins,
      priceUsd: pack.priceUsd,
    );
    if (mounted) Navigator.of(context).pop();
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
                      const Icon(Icons.toll, color: AppColors.gold, size: 30),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
            onPressed: () => _buy(selected),
            child: Text(
              'Buy ${selected.coins} coins for \$${selected.priceUsd}',
            ),
          ),
        ),
      ),
    );
  }
}
