import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/film_search_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/upload_controller.dart';
import 'controllers/wallet_controller.dart';
import 'services/api_client.dart';
import 'services/token_store.dart';
import 'theme/app_theme.dart';
import 'views/app_shell.dart';

void main() {
  final api = ApiClient(tokens: SecureTokenStore());
  runApp(ShortReelApp(api: api));
}

class ShortReelApp extends StatelessWidget {
  const ShortReelApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => FeedController(api)),
        ChangeNotifierProvider(create: (_) => FilmSearchController(api)),
        ChangeNotifierProvider(create: (_) => WalletController(api)),
        ChangeNotifierProvider(create: (_) => ProfileController(api)),
        ChangeNotifierProvider(create: (_) => UploadController(api)),
        ChangeNotifierProvider(create: (_) => AdminController(api)),
      ],
      child: MaterialApp(
        title: 'ShortReel',
        theme: AppTheme.dark,
        home: const AppShell(),
      ),
    );
  }
}
