import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';

/// The latest comments across every film, newest first.
class AdminCommentsView extends StatelessWidget {
  const AdminCommentsView({super.key});

  Future<void> _delete(BuildContext context, AdminComment comment) async {
    final admin = context.read<AdminController>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this comment?',
      message: 'It will be removed for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await admin.deleteComment(comment);
      messenger.showSnackBar(
        const SnackBar(content: Text('Comment deleted.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  String _when(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    return OnInit(
      run: () => context.read<AdminController>().loadComments(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: RefreshIndicator(
          onRefresh: admin.loadComments,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            children: [
              if (admin.commentsLoading) const LinearProgressIndicator(),
              if (admin.commentsError != null)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(child: Text(admin.commentsError!)),
                      TextButton(
                        onPressed: admin.loadComments,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              if (!admin.commentsLoading &&
                  admin.commentsError == null &&
                  admin.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No comments yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final c in admin.comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${c.username} · ${c.filmTitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(c.body),
                              const SizedBox(height: 4),
                              Text(
                                _when(c.createdAt),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _delete(context, c),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
