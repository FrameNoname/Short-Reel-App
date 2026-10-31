import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../services/errors.dart';
import '../../controllers/feed_controller.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/text.dart';

const _reasons = [
  'Audio or video problem',
  'Misleading AI label',
  'Stolen content',
  'Harmful content',
];

Future<void> showReportSheet(
  BuildContext context,
  Film film,
  int userId,
) async {
  final feed = context.read<FeedController>();
  final messenger = ScaffoldMessenger.of(context);
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(film: film),
  );
  if (reason == null) return;
  try {
    await feed.reportFilm(userId, film.id, reason);
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    return;
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('Report sent. Thank you.')),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.film});

  final Film film;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report ${widget.film.title}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'An admin reviews every report.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: reason,
            onChanged: (value) => setState(() => _reason = value),
            child: Column(
              children: [
                for (final option in _reasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.link,
                    value: option,
                    title: Text(option),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: reason == null
                ? null
                : () => Navigator.of(context).pop(reason),
            child: const Text('Send report'),
          ),
        ],
      ),
    );
  }
}
