import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../models/film.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/login_prompt.dart';
import '../auth/login_view.dart';
import '../search/search_view.dart';
import 'creator_dashboard_view.dart';

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
        appBar: AppBar(title: const Text('Profile')),
        body: LoginPrompt(onLogin: () => _open(context, const LoginView())),
      );
    }
    final repository = context.watch<ProfileController>().repository;
    final following = repository.followingOf(user.id);
    final isCreator = user.role != UserRole.viewer;
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
                          (user.displayName ?? user.username)[0].toUpperCase(),
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
                          Text(
                            user.displayName ?? user.username,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '@${user.username}',
                                style: const TextStyle(color: AppColors.muted),
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
                  ],
                ),
                const SizedBox(height: 14),
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
                                    title: Text(
                                      creator.displayName ?? creator.username,
                                    ),
                                    subtitle: Text('@${creator.username}'),
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: auth.logout,
                  child: const Text('Log out'),
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
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: films.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) =>
              SizedBox(width: 118, child: FilmCard(film: films[i])),
        ),
      ),
    );
  }
}
