import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<void> requestStartupPermissions() async {
    if (!Platform.isAndroid) return;

    // Audio access for Android 13+
    if (await Permission.audio.isDenied) {
      await Permission.audio.request();
    }

    // Notifications for Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}
