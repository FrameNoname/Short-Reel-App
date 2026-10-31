import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/upload_controller.dart';
import '../../data/mock_data.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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
  late String _genre = widget.film?.genreName ?? mockGenres.first;
  late String _tool = widget.film?.aiToolName ?? mockAiTools.first;
  final List<bool> _episodeFree = [true, false];
  bool _aiLabel = false;
  bool _videosChosen = false;

  bool get _isEditing => widget.film != null;

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  bool get _hasDetails =>
      _title.text.trim().isNotEmpty && _prompt.text.trim().isNotEmpty;

  bool get _ready => _hasDetails && (_isEditing || (_aiLabel && _videosChosen));

  String get _submitLabel {
    if (_isEditing) {
      return widget.film!.status == 'rejected'
          ? 'Resubmit for review'
          : 'Save changes';
    }
    if (!_aiLabel) return 'Tick the AI label to submit';
    return _ready ? 'Submit for review' : 'Fill in every field to submit';
  }

  Future<void> _submit() async {
    final controller = context.read<UploadController>();
    final messenger = ScaffoldMessenger.of(context);
    final film = widget.film;
    if (film != null) {
      controller.update(
        film.id,
        title: _title.text.trim(),
        genre: _genre,
        aiTool: _tool,
        promptCredit: _prompt.text.trim(),
      );
    } else {
      await controller.submit(
        creatorId: context.read<AuthController>().user!.id,
        title: _title.text.trim(),
        genre: _genre,
        aiTool: _tool,
        promptCredit: _prompt.text.trim(),
        episodeFree: _episodeFree,
      );
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
              onTap: () => setState(() => _videosChosen = true),
              child: AppCard(
                color: AppColors.primarySoft,
                borderColor: const Color(0x667C5CFF),
                child: Column(
                  children: [
                    Icon(
                      _videosChosen
                          ? Icons.check_circle
                          : Icons.upload_outlined,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _videosChosen
                          ? '${_episodeFree.length} demo videos selected'
                          : 'Choose episode videos',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'MP4, vertical 9:16, up to 200 MB each',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
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
              for (final genre in mockGenres)
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
              for (final tool in mockAiTools)
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
          if (!_isEditing) ...[
            const SizedBox(height: 14),
            const FieldLabel('Episode pricing'),
            for (var i = 0; i < _episodeFree.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Episode ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, label: Text('Free')),
                          ButtonSegment(value: false, label: Text('20 coins')),
                        ],
                        selected: {_episodeFree[i]},
                        onSelectionChanged: (value) =>
                            setState(() => _episodeFree[i] = value.first),
                      ),
                    ],
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              value: _aiLabel,
              onChanged: (value) => setState(() => _aiLabel = value ?? false),
              title: const Text('This film is AI-generated'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: FilledButton(
            onPressed: _ready ? _submit : null,
            child: Text(_submitLabel),
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
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
