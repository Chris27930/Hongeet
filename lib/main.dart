import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/permission_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PermissionManager.requestStartupPermissions();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MusicApp(),
    ),
  );
}
