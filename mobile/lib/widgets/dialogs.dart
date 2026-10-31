import 'package:flutter/material.dart' hide Text;

import '../theme/app_theme.dart';
import '../widgets/text.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: AppColors.text),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Asks for a reason and returns it, or null when the person backs out.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _ReasonDialog(title: title, hint: hint, confirmLabel: confirmLabel),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason.text.trim();
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(widget.title),
      content: TextField(
        key: const Key('reason-input'),
        controller: _reason,
        autofocus: true,
        maxLines: 2,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go back', style: TextStyle(color: AppColors.text)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: reason.isEmpty
              ? null
              : () => Navigator.of(context).pop(reason),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
