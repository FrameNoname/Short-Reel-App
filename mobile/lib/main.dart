import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/film_search_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/upload_controller.dart';
import 'controllers/wallet_controller.dart';
import 'data/app_repository.dart';
import 'data/mock_repository.dart';
import 'l10n/app_language.dart';
import 'services/api_client.dart';
import 'services/catalog_service.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';
import 'views/app_shell.dart';
import 'views/auth/login_view.dart';
import 'views/onboarding/onboarding_view.dart';

void main() {
  final catalog = catalogEnabled
      ? CatalogService(ApiClient(tokens: SecureTokenStore()))
      : null;
  final repository = MockRepository();
  if (catalog != null) repository.useCatalog(catalog);
  runApp(
    ShortReelApp(
      repository: repository,
      catalog: catalog,
      showOnboarding: true,
    ),
  );
}

class ShortReelApp extends StatelessWidget {
  const ShortReelApp({
    super.key,
    required this.repository,
    this.showOnboarding = false,
    this.catalog,
  });

  final AppRepository repository;

  /// Reads the Series Jeen catalog; null when the catalog is turned off.
  final CatalogService? catalog;

  /// Shows the first-run slides before the login screen.
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(repository)),
        ChangeNotifierProvider(create: (_) => FeedController(repository)),
        ChangeNotifierProvider(create: (_) => FilmSearchController(repository)),
        ChangeNotifierProvider(
          create: (context) =>
              WalletController(repository, context.read<AuthController>()),
        ),
        ChangeNotifierProvider(create: (_) => ProfileController(repository)),
        ChangeNotifierProvider(create: (_) => UploadController(repository)),
        ChangeNotifierProvider(create: (_) => AdminController(repository)),
        ChangeNotifierProvider(
          create: (_) => SettingsController(onboarded: !showOnboarding),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsController(repository),
        ),
        if (catalog != null)
          ChangeNotifierProvider(create: (_) => CatalogController(catalog!)),
      ],
      child: MaterialApp(
        title: 'ShortReel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => LanguageScope(
          language: context.watch<SettingsController>().language,
          child: _PhoneFrame(child: child!),
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsController>().onboarded) {
      return const OnboardingView();
    }
    final hasEntered = context.watch<AuthController>().hasEntered;
    return hasEntered ? const AppShell() : const LoginView();
  }
}

/// Shows the app at phone size when it runs in a wide browser window.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  static const _width = 390.0;
  static const _maxHeight = 844.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!kIsWeb || media.size.width <= 500) return child;
    final height = media.size.height < _maxHeight
        ? media.size.height
        : _maxHeight;
    return ColoredBox(
      color: const Color(0xFF050507),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: _width,
            height: height,
            child: MediaQuery(
              data: media.copyWith(size: Size(_width, height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
