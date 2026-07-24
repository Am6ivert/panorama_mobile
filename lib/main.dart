import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: PanoramaApp()));
}

class PanoramaApp extends StatelessWidget {
  const PanoramaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Panorama',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    initialRoute: AppRoutes.managerPick,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
