import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';

/// Первый экран запуска: пробует восстановить сессию сохранённым токеном.
///
/// Токен проверяется на сервере (`GET /auth/me`), поэтому отозванная сессия
/// или заблокированная учётка сразу отправляют на экран входа.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final user = await ref.read(panoramaRepositoryProvider).restoreSession();
    if (!mounted) return;
    if (user != null) {
      ref.read(currentUserProvider.notifier).state = user;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.brandDark,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white24,
            ),
          ),
        ),
      );
}
