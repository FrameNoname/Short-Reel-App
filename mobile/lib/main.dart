import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/film_search_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/upload_controller.dart';
import 'controllers/wallet_controller.dart';
import 'data/app_repository.dart';
import 'data/mock_repository.dart';
import 'theme/app_theme.dart';
import 'views/app_shell.dart';
import 'views/auth/login_view.dart';

void main() {
  runApp(ShortReelApp(repository: MockRepository()));
}

class ShortReelApp extends StatelessWidget {
  const ShortReelApp({super.key, required this.repository});

  final AppRepository repository;

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
        ChangeNotifierProvider(create: (_) => SettingsController()),
      ],
      child: MaterialApp(
        title: 'ShortReel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (_, child) => _PhoneFrame(child: child!),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
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
