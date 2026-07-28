import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';

/// Вход по номеру телефона и паролю (FR-01.1). Экрана регистрации нет —
/// учётные записи создаёт администратор.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(text: '+996 ');
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              const Text(
                'Panorama',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Шахматка квартир · отдел продаж',
                style: TextStyle(fontSize: 14, color: AppColors.onDarkSub),
              ),
              const SizedBox(height: 44),
              const _Label('НОМЕР ТЕЛЕФОНА'),
              const SizedBox(height: 8),
              _Input(
                controller: _phone,
                hint: '+996 555 00-11-22',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                ],
              ),
              const SizedBox(height: 18),
              const _Label('ПАРОЛЬ'),
              const SizedBox(height: 8),
              _Input(
                controller: _password,
                hint: '••••',
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Войти'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _loading ? null : _recover,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onDarkSub,
                ),
                child: const Text('Забыли пароль?'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(panoramaRepositoryProvider)
        .login(phone: _phone.text.trim(), password: _password.text);
    if (!mounted) return;
    switch (result) {
      case LoginOk(:final user):
        ref.read(currentUserProvider.notifier).state = user;
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      case LoginFailed(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  void _recover() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Код для восстановления отправлен по SMS'),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.onDarkSub,
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    onSubmitted: onSubmitted,
    style: const TextStyle(fontSize: 15, color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.ink3),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.brand),
      ),
    ),
  );
}
