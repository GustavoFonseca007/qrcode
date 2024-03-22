import 'package:qrcode/analytics.dart';
import 'package:qrcode/home.dart';
import 'package:qrcode/menu.dart';
import 'package:qrcode/perfil.dart';
import 'package:qrcode/theme_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'splash.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GetStorage.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = GetStorage().read('isLoggedIn') ?? false;

    return GetMaterialApp(
      theme: ThemeService().LightTheme,
      darkTheme: ThemeService().darkTheme,
      themeMode: ThemeService().getThemeMode(),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<void>(
        future: _requestPermissions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return isLoggedIn ? const Menu() : Splash();
          } else {
            return CircularProgressIndicator();
          }
        },
      ),
    );
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.storage] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {}
  }
}
