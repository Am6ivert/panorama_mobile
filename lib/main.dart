import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

/// Фоновый обработчик push (приложение свёрнуто/закрыто). Notification-payload
/// система показывает сама; здесь можно дообработать data при необходимости.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase не обязателен: если не поднялся — приложение работает на поллинге.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  } catch (_) {}
  runApp(const ProviderScope(child: PanoramaApp()));
}

class PanoramaApp extends StatelessWidget {
  const PanoramaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Panorama',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    navigatorKey: AppRouter.navigatorKey,
    initialRoute: AppRoutes.splash,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
