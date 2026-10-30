import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/user.dart';
import 'admin/admin_view.dart';
import 'feed/feed_view.dart';
import 'profile/profile_view.dart';
import 'search/search_view.dart';
import 'upload/upload_view.dart';
import 'wallet/wallet_view.dart';

enum AppTab { feed, search, wallet, profile, upload, admin }

List<AppTab> tabsFor(UserRole role) {
  const base = [AppTab.feed, AppTab.search, AppTab.wallet, AppTab.profile];
  return switch (role) {
    UserRole.guest || UserRole.viewer => base,
    UserRole.creator => [...base, AppTab.upload],
    UserRole.admin => [...base, AppTab.upload, AppTab.admin],
  };
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  static Widget _viewFor(AppTab tab) => switch (tab) {
    AppTab.feed => const FeedView(),
    AppTab.search => const SearchView(),
    AppTab.wallet => const WalletView(),
    AppTab.profile => const ProfileView(),
    AppTab.upload => const UploadView(),
    AppTab.admin => const AdminView(),
  };

  static NavigationDestination _destinationFor(AppTab tab) => switch (tab) {
    AppTab.feed => const NavigationDestination(
      icon: Icon(Icons.play_circle_outline),
      label: 'Feed',
    ),
    AppTab.search => const NavigationDestination(
      icon: Icon(Icons.search),
      label: 'Search',
    ),
    AppTab.wallet => const NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      label: 'Wallet',
    ),
    AppTab.profile => const NavigationDestination(
      icon: Icon(Icons.person_outline),
      label: 'Profile',
    ),
    AppTab.upload => const NavigationDestination(
      icon: Icon(Icons.upload_outlined),
      label: 'Upload',
    ),
    AppTab.admin => const NavigationDestination(
      icon: Icon(Icons.admin_panel_settings_outlined),
      label: 'Admin',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tabs = tabsFor(context.watch<AuthController>().role);
    // The list shrinks when an admin or creator logs out.
    final index = min(_selected, tabs.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: tabs.map(_viewFor).toList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _selected = i),
        destinations: tabs.map(_destinationFor).toList(),
      ),
    );
  }
}
