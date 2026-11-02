import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/upload_controller.dart';
import '../../data/app_repository.dart';
import '../../data/lookups.dart';
import '../../l10n/app_language.dart';
import '../../models/film.dart';
import '../../services/errors.dart';
import '../../services/video_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

/// Uploads a new film, or edits [film] when one is given.
class UploadView extends StatefulWidget {
  const UploadView({super.key, this.film});

  final Film? film;

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  late final _title = TextEditingController(text: widget.film?.title);
  late final _prompt = TextEditingController(text: widget.film?.promptCredit);
  late String _genre = widget.film?.genreName ?? genreNames.first;
  late String _tool = widget.film?.aiToolName ?? aiToolNames.first;
  late List<bool> _episodeFree = [];
  late List<TextEditingController> _priceFields = [];

  /// The videos picked from the device, one per new episode.
  List<PickedVideo> _videos = const [];

  /// Ids of the episodes being edited, in the same order as the price cards.
  List<int> _episodeIds = const [];
  bool _aiLabel = false;
  bool _busy = false;

  /// While editing, the episodes are read from the server first. Saving stays
  /// off until they are all here, so an empty price list can never pass.
  bool _episodesLoading = false;
  String? _episodesError;

  bool get _isEditing => widget.film != null;

  bool get _videosChosen => _videos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    final repository = context.read<UploadController>().repository;
    setState(() {
      _episodesLoading = true;
      _episodesError = null;
    });
    try {
      final episodes = await repository.episodes(widget.film!.id);
      if (!mounted) return;
      for (final field in _priceFields) {
        field.dispose();
      }
      setState(() {
        _episodesLoading = false;
        _episodeIds = [for (final e in episodes) e.id];
        _episodeFree = [for (final e in episodes) e.isFree];
        _priceFields = [
          for (final e in episodes)
            TextEditingController(text: e.isFree ? '20' : '${e.priceCoins}'),
        ];
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _episodesLoading = false;
        _episodesError = errorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    for (final field in _priceFields) {
      field.dispose();
    }
    super.dispose();
  }

  /// Opens the file picker; each video becomes one episode. The first is free
  /// as a preview and the rest cost coins; the creator can change any of them.
  Future<void> _chooseVideos() async {
    final controller = context.read<UploadController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await controller.pickVideos();
      if (!mounted || picked.isEmpty) return;
      if (picked.any((v) => v.bytes.length > maxVideoBytes)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Each video must be 200 MB or less.')),
        );
        return;
      }
      for (final field in _priceFields) {
        field.dispose();
      }
      setState(() {
        _videos = picked;
        _episodeFree = [for (var i = 0; i < picked.length; i++) i == 0];
        _priceFields = [
          for (final _ in picked) TextEditingController(text: '20'),
        ];
      });
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  // The same limits the API enforces, so the form never promises more.
  static const _maxTitle = 100;
  static const _maxPrompt = 500;

  bool get _hasDetails =>
      _title.text.trim().isNotEmpty &&
      _title.text.trim().length <= _maxTitle &&
      _prompt.text.trim().isNotEmpty &&
      _prompt.text.trim().length <= _maxPrompt;

  /// A paid episode needs a whole number of coins from 1 to [_maxPrice]
  /// (the API refuses more than 500).
  static const _maxPrice = 500;

  int? _priceOf(int i) {
    if (_episodeFree[i]) return 0;
    final value = int.tryParse(_priceFields[i].text.trim());
    return value != null && value >= 1 && value <= _maxPrice ? value : null;
  }

  bool get _pricesValid =>
      List.generate(_episodeFree.length, _priceOf).every((p) => p != null);

  bool get _episodesReady =>
      !_isEditing ||
      (!_episodesLoading && _episodesError == null && _episodeIds.isNotEmpty);

  bool get _ready =>
      _hasDetails &&
      _pricesValid &&
      _episodesReady &&
      (_isEditing || (_aiLabel && _videosChosen));

  String get _submitLabel {
    if (_isEditing) {
      return widget.film!.status == 'rejected'
          ? 'Resubmit for review'
          : 'Save changes';
    }
    if (!_aiLabel) return 'Tick the AI label to submit';
    if (!_pricesValid) return 'Set a price for every paid episode';
    return _ready ? 'Submit for review' : 'Fill in every field to submit';
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = context.read<UploadController>();
    final messenger = ScaffoldMessenger.of(context);
    final film = widget.film;
    try {
      if (film != null) {
        await controller.update(
          film.id,
          title: _title.text.trim(),
          genre: _genre,
          aiTool: _tool,
          promptCredit: _prompt.text.trim(),
          episodePrices: {
            for (var i = 0; i < _episodeIds.length; i++)
              _episodeIds[i]: _priceOf(i)!,
          },
        );
      } else {
        await controller.submit(
          creatorId: context.read<AuthController>().user!.id,
          title: _title.text.trim(),
          genre: _genre,
          aiTool: _tool,
          promptCredit: _prompt.text.trim(),
          episodes: [
            for (var i = 0; i < _videos.length; i++)
              EpisodeDraft(
                fileName: _videos[i].name,
                bytes: _videos[i].bytes,
                priceCoins: _priceOf(i)!,
              ),
          ],
        );
      }
    } on Object catch (e) {
      // Nothing is reported as done unless the server accepted every file.
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          film?.status == 'approved'
              ? 'Changes saved.'
              : 'Submitted. Waiting for admin review.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit film' : 'Upload film')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (!_isEditing) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _chooseVideos,
              child: AppCard(
                color: _videosChosen
                    ? const Color(0x1F3DD68C)
                    : AppColors.primarySoft,
                borderColor: _videosChosen
                    ? AppColors.green
                    : const Color(0x667C5CFF),
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Icon(
                      _videosChosen
                          ? Icons.check_circle_rounded
                          : Icons.video_call_rounded,
                      size: 38,
                      color: _videosChosen ? AppColors.green : AppColors.link,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _videosChosen
                          ? '${_videos.length} video${_videos.length == 1 ? '' : 's'} selected'
                          : 'Choose episode videos',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _videosChosen
                          ? _videos.map((v) => v.name).join(', ')
                          : 'MP4, vertical 9:16, up to 200 MB each',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const FieldLabel('Title'),
          TextField(
            key: const Key('upload-title'),
            controller: _title,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Genre'),
          DropdownButtonFormField<String>(
            initialValue: _genre,
            dropdownColor: AppColors.surfaceHigh,
            items: [
              for (final genre in genreNames)
                DropdownMenuItem(value: genre, child: Text(genre)),
            ],
            onChanged: (value) => setState(() => _genre = value!),
          ),
          const SizedBox(height: 14),
          const FieldLabel('AI tool used'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tool in aiToolNames)
                _ToolChip(
                  label: tool,
                  selected: tool == _tool,
                  onTap: () => setState(() => _tool = tool),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const FieldLabel('Prompt credit'),
          TextField(
            key: const Key('upload-prompt'),
            controller: _prompt,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          if (_isEditing && _episodesLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(key: Key('episodes-loading')),
          ],
          if (_isEditing && _episodesError != null) ...[
            const SizedBox(height: 14),
            Text(
              _episodesError!,
              key: const Key('episodes-error'),
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 160,
              child: OutlinedButton(
                key: const Key('episodes-retry'),
                onPressed: _loadEpisodes,
                child: const Text('Try again'),
              ),
            ),
          ],
          if (_episodeFree.isNotEmpty) ...[
            const SizedBox(height: 14),
            const FieldLabel('Episode pricing'),
            for (var i = 0; i < _episodeFree.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EpisodePriceCard(
                  number: i + 1,
                  isFree: _episodeFree[i],
                  controller: _priceFields[i],
                  invalid: !_episodeFree[i] && _priceOf(i) == null,
                  maxPrice: _maxPrice,
                  onFreeChanged: (free) =>
                      setState(() => _episodeFree[i] = free),
                  onPriceChanged: () => setState(() {}),
                ),
              ),
          ],
          if (!_isEditing) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              value: _aiLabel,
              onChanged: (value) => setState(() => _aiLabel = value ?? false),
              title: const Text('This film is AI-generated'),
            ),
            const SizedBox(height: 6),
            _Checklist(
              items: [
                ('Episode videos chosen', _videosChosen),
                ('Title added', _title.text.trim().isNotEmpty),
                ('Prompt credit added', _prompt.text.trim().isNotEmpty),
                ('Episode prices set', _pricesValid),
                ('AI label confirmed', _aiLabel),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: FilledButton(
            onPressed: _ready && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(_submitLabel),
          ),
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// What is still missing before the film can be submitted.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.items});

  final List<(String, bool)> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, done) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: done ? AppColors.green : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? AppColors.text : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One episode's price: free, or any whole number of coins the creator picks.
class _EpisodePriceCard extends StatelessWidget {
  const _EpisodePriceCard({
    required this.number,
    required this.isFree,
    required this.controller,
    required this.invalid,
    required this.maxPrice,
    required this.onFreeChanged,
    required this.onPriceChanged,
  });

  static const _quickPrices = [10, 20, 50, 100];

  final int number;
  final bool isFree;
  final TextEditingController controller;
  final bool invalid;
  final int maxPrice;
  final ValueChanged<bool> onFreeChanged;
  final VoidCallback onPriceChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Episode $number',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SegmentedButton<bool>(
                key: Key('episode-$number-kind'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Free')),
                  ButtonSegment(value: false, label: Text('Paid')),
                ],
                selected: {isFree},
                onSelectionChanged: (value) => onFreeChanged(value.first),
              ),
            ],
          ),
          if (!isFree) ...[
            const SizedBox(height: 8),
            TextField(
              key: Key('episode-$number-price'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3, // 500 at most, see _maxPrice
              onChanged: (_) => onPriceChanged(),
              decoration: InputDecoration(
                counterText: '',
                hintText: context.tr('Coins'),
                prefixIcon: const Icon(
                  Icons.toll_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
                suffixText: context.tr('coins'),
                errorText: invalid
                    ? context.tr('Enter 1 to $maxPrice coins.')
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final price in _quickPrices)
                  ActionChip(
                    label: Text('$price'),
                    onPressed: () {
                      controller.text = '$price';
                      onPriceChanged();
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
