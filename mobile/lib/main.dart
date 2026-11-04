import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/catalog_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/film_search_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/upload_controller.dart';
import 'controllers/wallet_controller.dart';
import 'data/app_repository.dart';
import 'data/api_repository.dart';
import 'l10n/app_language.dart';
import 'services/api_client.dart';
import 'services/catalog_service.dart';
import 'services/token_store.dart';
import 'services/video_picker.dart';
import 'theme/app_theme.dart';
import 'views/app_shell.dart';
import 'views/auth/login_view.dart';
import 'widgets/loading_view.dart';

void main() {
  final tokens = SecureTokenStore();
  final api = ApiClient(tokens: tokens);
  // Series Jeen is an optional extra: without it the app works as before.
  final catalog = catalogEnabled ? CatalogService(api) : null;
  final repository = ApiRepository(client: api, tokens: tokens);
  if (catalog != null) repository.useCatalog(catalog);
  runApp(
    ShortReelApp(
      repository: repository,
      catalog: catalog,
      api: api,
      restoreSession: true,
    ),
  );
}

class ShortReelApp extends StatelessWidget {
  const ShortReelApp({
    super.key,
    required this.repository,
    this.catalog,
    this.api,
    this.restoreSession = false,
    this.pickVideos = pickVideosFromDevice,
  });

  final AppRepository repository;

  /// Reads the Series Jeen catalog; null when the catalog is turned off.
  final CatalogService? catalog;

  /// Logs the person out when the server rejects their token.
  final ApiClient? api;

  /// Signs in again from the token kept on the device when the app starts.
  final bool restoreSession;

  /// Opens the video picker on the Upload screen; tests pass a fake.
  final VideoPicker pickVideos;

  /// Lets a logout or an expired session close every screen pushed on top of
  /// the root, so none of them is left showing (or reading) the old account.
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final auth = AuthController(repository);
            api?.onUnauthorized = auth.sessionExpired;
            auth.addLogoutListener(
              () => navigatorKey.currentState?.popUntil((r) => r.isFirst),
            );
            if (restoreSession) auth.restoreSession();
            return auth;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final feed = FeedController(repository);
            context.read<AuthController>().addLogoutListener(feed.reset);
            return feed;
          },
        ),
        ChangeNotifierProvider(create: (_) => FilmSearchController(repository)),
        ChangeNotifierProvider(
          create: (context) =>
              WalletController(repository, context.read<AuthController>()),
        ),
        ChangeNotifierProvider(create: (_) => ProfileController(repository)),
        ChangeNotifierProvider(
          create: (_) => UploadController(repository, pickVideos: pickVideos),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final admin = AdminController(repository);
            context.read<AuthController>().addLogoutListener(admin.reset);
            return admin;
          },
        ),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        if (catalog != null)
          ChangeNotifierProvider(create: (_) => CatalogController(catalog!)),
      ],
      child: MaterialApp(
        title: 'ShortReel',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.dark,
        builder: (context, child) => LanguageScope(
          // The app is shown in Thai only.
          language: AppLanguage.thai,
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
    final auth = context.watch<AuthController>();
    if (auth.isRestoring) {
      return const Scaffold(body: LoadingView());
    }
    return auth.hasEntered ? const AppShell() : const LoginView();
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
