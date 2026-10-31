import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wallet_controller.dart';
import '../../models/coin_pack.dart';
import '../../models/episode.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum UnlockChoice { unlock, plus }

class UnlockSheet extends StatelessWidget {
  const UnlockSheet({super.key, required this.film, required this.episode});

  final Film film;
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final balance = wallet.balance;
    final price = episode.priceCoins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 84,
                child: FilmPoster(film: film, showBadge: false),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      film.title,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      'Unlock Episode ${episode.episodeNo}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Yours to rewatch anytime',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                _CoinRow(label: 'Price', coins: price),
                const SizedBox(height: 8),
                _CoinRow(label: 'Your balance', coins: balance),
                const Divider(height: 22, color: AppColors.border),
                _CoinRow(
                  label: 'After unlock',
                  coins: balance - price,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(UnlockChoice.unlock),
            child: Text('Unlock for $price coins'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(UnlockChoice.plus),
            child: Text(
              'Or get Plus — watch everything for ${wallet.planPrice}/mo',
              style: const TextStyle(color: AppColors.link),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinRow extends StatelessWidget {
  const _CoinRow({required this.label, required this.coins, this.bold = false});

  final String label;
  final int coins;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: bold ? AppColors.text : AppColors.muted),
        ),
        Row(
          children: [
            const Icon(Icons.toll_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              '$coins coins',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NotEnoughCoinsSheet extends StatefulWidget {
  const NotEnoughCoinsSheet({super.key, required this.episode});

  /// Popped when the person prefers the full wallet screen.
  static const openWallet = 'open-wallet';

  final Episode episode;

  @override
  State<NotEnoughCoinsSheet> createState() => _NotEnoughCoinsSheetState();
}

class _NotEnoughCoinsSheetState extends State<NotEnoughCoinsSheet> {
  CoinPack? _selected;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final packs = wallet.coinPacks;
    final selected = _selected ?? packs[1];
    final price = widget.episode.priceCoins;
    final missing = price - wallet.balance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not enough coins',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: AppColors.muted),
              children: [
                TextSpan(text: 'Episode ${widget.episode.episodeNo} costs '),
                TextSpan(
                  text: '$price coins',
                  style: const TextStyle(color: AppColors.gold),
                ),
                TextSpan(text: '. You have ${wallet.balance} — you need '),
                TextSpan(text: '$missing more.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wallet.balance / price,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Top up'),
          Row(
            children: [
              for (final pack in packs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        child: Column(
                          children: [
                            Text(
                              '${pack.coins}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'coins',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${pack.priceUsd}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(
              'Buy ${selected.coins} coins · \$${selected.priceUsd} & unlock',
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(NotEnoughCoinsSheet.openWallet),
              child: const Text(
                'Open wallet',
                style: TextStyle(color: AppColors.link),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
