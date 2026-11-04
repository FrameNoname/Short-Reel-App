import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/catalog_controller.dart';
import '../l10n/app_language.dart';
import '../models/user.dart';
import '../widgets/tab_active.dart';
import 'admin/admin_view.dart';
import 'catalog/catalog_view.dart';
import 'feed/feed_view.dart';
import 'profile/profile_view.dart';
import 'search/search_view.dart';
import 'wallet/wallet_view.dart';

enum AppTab { feed, search, catalog, wallet, profile, admin }

List<AppTab> tabsFor(UserRole role) {
  return switch (role) {
    UserRole.guest || UserRole.viewer => const [
      AppTab.feed,
      AppTab.search,
      AppTab.wallet,
      AppTab.profile,
    ],
    UserRole.admin => const [
      AppTab.feed,
      AppTab.search,
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
    AppTab.catalog => const CatalogView(),
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
    AppTab.catalog => NavigationDestination(
      icon: Icon(Icons.video_library_outlined),
      selectedIcon: Icon(Icons.video_library),
      label: context.tr('Catalog'),
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

  void _onSelected(AppTab tab) => setState(() => _selected = tab);

  @override
  Widget build(BuildContext context) {
    final base = tabsFor(context.watch<AuthController>().role);
    // The catalog sits right after search, when the app has one.
    final hasCatalog = context.read<CatalogController?>() != null;
    final tabs = List.of(base);
    if (hasCatalog) {
      tabs.insert(base.indexOf(AppTab.search) + 1, AppTab.catalog);
    }
    // A tab can disappear when an admin logs out.
    final index = max(tabs.indexOf(_selected), 0);
    // The feed runs full screen; its bar floats over the video on a scrim.
    final overVideo = tabs[index] == AppTab.feed;
    return Scaffold(
      extendBody: overVideo,
      body: IndexedStack(
        index: index,
        children: [
          for (final tab in tabs)
            TabActive(active: tab == tabs[index], child: _viewFor(tab)),
        ],
      ),
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
