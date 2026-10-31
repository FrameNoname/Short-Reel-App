import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/app_language.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'admin/admin_view.dart';
import 'feed/feed_view.dart';
import 'profile/profile_view.dart';
import 'search/search_view.dart';
import 'upload/upload_view.dart';
import 'wallet/wallet_view.dart';

enum AppTab { feed, search, upload, wallet, profile, admin }

List<AppTab> tabsFor(UserRole role) {
  return switch (role) {
    UserRole.guest || UserRole.viewer => const [
      AppTab.feed,
      AppTab.search,
      AppTab.wallet,
      AppTab.profile,
    ],
    UserRole.creator => const [
      AppTab.feed,
      AppTab.search,
      AppTab.upload,
      AppTab.wallet,
      AppTab.profile,
    ],
    UserRole.admin => const [
      AppTab.feed,
      AppTab.search,
      AppTab.upload,
      AppTab.wallet,
      AppTab.profile,
      AppTab.admin,
    ],
  };
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _selected = AppTab.feed;

  Widget _viewFor(AppTab tab) => switch (tab) {
    AppTab.feed => FeedView(
      onSearch: () => setState(() => _selected = AppTab.search),
    ),
    AppTab.search => const SearchView(),
    // Upload opens as its own screen, so the tab has no body.
    AppTab.upload => const SizedBox.shrink(),
    AppTab.wallet => const WalletView(),
    AppTab.profile => const ProfileView(),
    AppTab.admin => const AdminView(),
  };

  NavigationDestination _destinationFor(AppTab tab) => switch (tab) {
    AppTab.feed => NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: context.tr('Home'),
    ),
    AppTab.search => NavigationDestination(
      icon: Icon(Icons.search),
      label: context.tr('Search'),
    ),
    AppTab.upload => NavigationDestination(
      icon: Container(
        width: 46,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      label: '',
      tooltip: context.tr('Upload'),
    ),
    AppTab.wallet => NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: context.tr('Wallet'),
    ),
    AppTab.profile => NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: context.tr('Profile'),
    ),
    AppTab.admin => NavigationDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: context.tr('Admin'),
    ),
  };

  void _onSelected(AppTab tab) {
    if (tab == AppTab.upload) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const UploadView()));
    } else {
      setState(() => _selected = tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = tabsFor(context.watch<AuthController>().role);
    // A tab can disappear when a creator or admin logs out.
    final index = max(tabs.indexOf(_selected), 0);
    // The feed runs full screen; its bar floats over the video on a scrim.
    final overVideo = tabs[index] == AppTab.feed;
    return Scaffold(
      extendBody: overVideo,
      body: IndexedStack(index: index, children: tabs.map(_viewFor).toList()),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          gradient: overVideo
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xE6000000)],
                )
              : null,
        ),
        child: NavigationBar(
          backgroundColor: overVideo ? Colors.transparent : null,
          elevation: 0,
          selectedIndex: index,
          onDestinationSelected: (i) => _onSelected(tabs[i]),
          destinations: tabs.map(_destinationFor).toList(),
        ),
      ),
    );
  }
}
