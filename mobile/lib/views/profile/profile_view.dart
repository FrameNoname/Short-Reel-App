import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../data/app_repository.dart';
import '../../l10n/app_language.dart';
import '../../models/film.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/login_prompt.dart';
import '../../widgets/on_init.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_view.dart';
import '../search/search_view.dart';
import 'creator_dashboard_view.dart';
import 'creator_profile_view.dart';
import 'edit_profile_view.dart';
import 'settings_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  void _open(BuildContext context, Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              tooltip: context.tr('Settings'),
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => _open(context, const SettingsView()),
            ),
          ],
        ),
        body: LoginPrompt(onLogin: () => _open(context, const LoginView())),
      );
    }
    final repository = context.watch<ProfileController>().repository;
    final following = repository.followingOf(user.id);
    final isCreator = user.role != UserRole.viewer;
    return OnActivated(
      run: () => context.read<ProfileController>().load(user.id),
      child: _scaffold(context, user, repository, following, isCreator),
    );
  }

  Widget _scaffold(
    BuildContext context,
    User user,
    AppRepository repository,
    List<User> following,
    bool isCreator,
  ) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          user.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChannelName(
                            user.displayName ?? user.username,
                            verified: user.isVerified,
                            badgeSize: 20,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@${user.username}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user.role.name[0].toUpperCase() +
                                      user.role.name.substring(1),
                                  style: const TextStyle(
                                    color: AppColors.link,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Settings'),
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => _open(context, const SettingsView()),
                    ),
                  ],
                ),
                if ((user.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user.bio!,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _open(context, const EditProfileView()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit profile'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${following.length}',
                        label: 'Following',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        value: '${repository.followerCount(user.id)}',
                        label: 'Followers',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        value: '${user.coinBalance}',
                        label: 'Coins',
                        valueColor: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                if (isCreator) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _open(context, const CreatorDashboardView()),
                    child: AppCard(
                      color: AppColors.primarySoft,
                      borderColor: const Color(0x667C5CFF),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bar_chart, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Creator studio',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Earnings and review status',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const TabBar(
                  tabs: [
                    Tab(text: 'Watchlist'),
                    Tab(text: 'Unlocked'),
                    Tab(text: 'Following'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _FilmRow(
                        films: repository.watchlistOf(user.id),
                        emptyMessage: 'Saved films appear here.',
                      ),
                      _FilmRow(
                        films: repository.unlockedFilmsOf(user.id),
                        emptyMessage: 'Unlocked films appear here.',
                      ),
                      following.isEmpty
                          ? const EmptyView(
                              message: 'Creators you follow appear here.',
                            )
                          : ListView(
                              children: [
                                for (final creator in following)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.surfaceHigh,
                                      child: Text(
                                        creator.username[0].toUpperCase(),
                                      ),
                                    ),
                                    onTap: () =>
                                        openCreatorProfile(context, creator.id),
                                    title: ChannelName(
                                      creator.displayName ?? creator.username,
                                      verified: creator.isVerified,
                                    ),
                                    subtitle: Text('@${creator.username}'),
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: context.read<AuthController>().logout,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilmRow extends StatelessWidget {
  const _FilmRow({required this.films, required this.emptyMessage});

  final List<Film> films;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) return EmptyView(message: emptyMessage);
    return GridView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: films.length,
      itemBuilder: (_, i) => FilmCard(film: films[i]),
    );
  }
}
