import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../l10n/app_language.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';

/// Comments across every film, newest first, a page at a time. The search box
/// finds loaded comments by film title; tapping a film title narrows the list
/// to that film on the server.
class AdminCommentsView extends StatefulWidget {
  const AdminCommentsView({super.key});

  @override
  State<AdminCommentsView> createState() => _AdminCommentsViewState();
}

class _AdminCommentsViewState extends State<AdminCommentsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final admin = context.read<AdminController>();
    // A search left over from the last visit would hide comments.
    _search.text = admin.commentsQuery;
    await admin.loadComments();
  }

  void _clearSearch() {
    _search.clear();
    context.read<AdminController>().searchComments('');
  }

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
      messenger.showSnackBar(const SnackBar(content: Text('Comment deleted.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  /// Loads the next page once the list is scrolled near its end.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 300) {
      context.read<AdminController>().loadMoreComments();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final visible = admin.visibleComments;
    final searching = admin.commentsQuery.isNotEmpty;
    return OnInit(
      run: _init,
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: RefreshIndicator(
          onRefresh: admin.loadComments,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: admin.searchComments,
                    decoration: InputDecoration(
                      hintText: context.tr('Search by film title'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searching
                          ? IconButton(
                              tooltip: context.tr('Clear search'),
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                  ),
                ),
                if (admin.commentsFilmId != null)
                  _FilmChip(
                    title: admin.commentsFilmTitle ?? '',
                    onClear: () => admin.filterCommentsByFilm(null),
                  ),
                if (admin.commentsLoading) const LinearProgressIndicator(),
                if (admin.commentsError != null)
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(child: Text(admin.commentsError!)),
                        TextButton(
                          onPressed: admin.comments.isEmpty
                              ? admin.loadComments
                              : admin.loadMoreComments,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                if (searching && !admin.commentsLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      admin.commentsHasMore
                          ? '${visible.length} found in ${admin.comments.length} loaded'
                          : '${visible.length} found',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (!admin.commentsLoading &&
                    admin.commentsError == null &&
                    visible.isEmpty)
                  _Note(
                    searching
                        ? 'No comments match your search.'
                        : admin.commentsFilmId != null
                        ? 'No comments on this film yet'
                        : 'No comments yet',
                  ),
                for (final c in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CommentRow(
                      comment: c,
                      onFilm: admin.commentsFilmId == null && c.filmId != 0
                          ? () => admin.filterCommentsByFilm(
                              c.filmId,
                              title: c.filmTitle,
                            )
                          : null,
                      onDelete: () => _delete(context, c),
                    ),
                  ),
                if (admin.commentsLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (admin.commentsHasMore && !admin.commentsLoading)
                  Center(
                    child: TextButton(
                      onPressed: admin.loadMoreComments,
                      child: const Text('Load more'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows which film the list is narrowed to, with a way back to every film.
class _FilmChip extends StatelessWidget {
  const _FilmChip({required this.title, required this.onClear});

  final String title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: InputChip(
        avatar: const Icon(Icons.movie_outlined, size: 18),
        label: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        deleteButtonTooltipMessage: context.tr('Show all films'),
        onDeleted: onClear,
      ),
    ),
  );
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.onDelete,
    this.onFilm,
  });

  final AdminComment comment;
  final VoidCallback onDelete;

  /// Narrows the list to this comment's film; null when already narrowed.
  final VoidCallback? onFilm;

  String _when(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(color: AppColors.muted, fontSize: 12);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${comment.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                    ),
                    const Text(' · ', style: meta),
                    Flexible(
                      child: InkWell(
                        onTap: onFilm,
                        child: Text(
                          comment.filmTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: onFilm == null
                              ? meta
                              : meta.copyWith(
                                  color: AppColors.link,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.link,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.body),
                const SizedBox(height: 4),
                Text(
                  _when(comment.createdAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Delete'),
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}
