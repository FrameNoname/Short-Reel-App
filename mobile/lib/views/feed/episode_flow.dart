import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../data/app_repository.dart';
import '../../models/coin_pack.dart';
import '../../models/episode.dart';
import '../../models/film.dart';
import '../../widgets/dialogs.dart';
import '../wallet/plus_view.dart';
import '../wallet/top_up_view.dart';
import 'episodes_sheet.dart';
import 'login_gate_view.dart';
import 'unlock_sheets.dart';
import 'unlock_success_view.dart';

Future<void> showEpisodes(BuildContext context, Film film) async {
  final feed = context.read<FeedController>();
  final episodes = await feed.repository.episodes(film.id);
  if (!context.mounted) return;
  final selected = await showModalBottomSheet<Episode>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EpisodesSheet(film: film, episodes: episodes),
  );
  if (selected != null && context.mounted) {
    await _open(context, film, selected, episodes);
  }
}

Future<void> _open(
  BuildContext context,
  Film film,
  Episode episode,
  List<Episode> episodes,
) async {
  final feed = context.read<FeedController>();
  final user = context.read<AuthController>().user;
  if (feed.repository.accessOf(user?.id, episode) != EpisodeAccess.locked) {
    feed.play(episode, userId: user?.id);
    return;
  }
  if (user == null) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginGateView(film: film, episode: episode),
      ),
    );
    return;
  }

  if (context.read<WalletController>().balance < episode.priceCoins) {
    await _topUpThenUnlock(context, film, episode, episodes);
    return;
  }

  final choice = await showModalBottomSheet<UnlockChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UnlockSheet(film: film, episode: episode),
  );
  if (!context.mounted) return;
  switch (choice) {
    case UnlockChoice.unlock:
      await _unlock(context, film, episode, episodes);
    case UnlockChoice.plus:
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PlusView()));
    case null:
      break;
  }
}

Future<void> _topUpThenUnlock(
  BuildContext context,
  Film film,
  Episode episode,
  List<Episode> episodes,
) async {
  final selected = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => NotEnoughCoinsSheet(episode: episode),
  );
  if (!context.mounted) return;
  if (selected is CoinPack) {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm purchase',
      message:
          'Buy ${selected.coins} coins for \$${selected.priceUsd}, then spend '
          '${episode.priceCoins} coins on Episode ${episode.episodeNo}. '
          'This is a demo, so no real money is charged.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !context.mounted) return;
    final wallet = context.read<WalletController>();
    await wallet.buy(coins: selected.coins, priceUsd: selected.priceUsd);
    if (context.mounted) await _unlock(context, film, episode, episodes);
  } else if (selected == NotEnoughCoinsSheet.openWallet) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TopUpView()));
  }
}

Future<void> _unlock(
  BuildContext context,
  Film film,
  Episode episode,
  List<Episode> episodes,
) async {
  final wallet = context.read<WalletController>();
  final before = wallet.balance;
  await wallet.unlock(episode.id);
  if (!context.mounted) return;
  context.read<FeedController>().play(
    episode,
    userId: context.read<AuthController>().user?.id,
  );
  final next = episodes.where((e) => e.episodeNo == episode.episodeNo + 1);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UnlockSuccessView(
        film: film,
        episode: episode,
        balanceBefore: before,
        balanceAfter: wallet.balance,
        nextEpisode: next.isEmpty ? null : next.first,
      ),
    ),
  );
}
