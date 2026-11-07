import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

/// Every episode of one film, with its free flag and coin price.
class AdminEpisodesView extends StatefulWidget {
  const AdminEpisodesView({super.key, required this.film});

  final AdminFilm film;

  @override
  State<AdminEpisodesView> createState() => _AdminEpisodesViewState();
}

class _AdminEpisodesViewState extends State<AdminEpisodesView> {
  List<AdminEpisode> _episodes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AdminController>().episodesOf(
        widget.film.id,
      );
      if (mounted) setState(() => _episodes = list);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit(AdminEpisode episode) async {
    final result = await showDialog<(bool, int)>(
      context: context,
      builder: (_) => _EpisodeDialog(episode: episode),
    );
    if (result == null || !mounted) return;
    final (isFree, price) = result;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await context.read<AdminController>().updateEpisode(
        episode,
        isFree: isFree,
        priceCoins: price,
      );
      setState(() {
        _episodes = [
          for (final e in _episodes) e.id == saved.id ? saved : e,
        ];
      });
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.film.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: Text(_error!)),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null && _episodes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This film has no episodes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (final e in _episodes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(
                      'Episode ${e.episodeNo}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${e.unlockCount} unlocks',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        e.isFree
                            ? const Text(
                                'Free',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : CoinAmount(e.priceCoins),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 18),
                      ],
                    ),
                    onTap: () => _edit(e),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeDialog extends StatefulWidget {
  const _EpisodeDialog({required this.episode});

  final AdminEpisode episode;

  @override
  State<_EpisodeDialog> createState() => _EpisodeDialogState();
}

class _EpisodeDialogState extends State<_EpisodeDialog> {
  late bool _free = widget.episode.isFree;
  late final _price = TextEditingController(
    text: widget.episode.isFree ? '10' : '${widget.episode.priceCoins}',
  );
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (!_free && (price < 1 || price > 10000)) {
      setState(() => _error = 'A price must be 1 to 10000 coins.');
      return;
    }
    Navigator.of(context).pop((_free, price));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Episode ${widget.episode.episodeNo}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Free episode'),
            value: _free,
            onChanged: (v) => setState(() => _free = v),
          ),
          if (!_free) ...[
            const SizedBox(height: 8),
            const FieldLabel('Price (coins)'),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (_error != null) FieldError(_error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
