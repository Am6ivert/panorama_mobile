import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/models/manager_model.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/api_action.dart';

/// Вход по логину и паролю (FR-01.1).
///
/// Отсюда же начинается регистрация: застройщик заводит компанию сам, а
/// менеджеров внутри неё создаёт уже её администратор.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
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
              const _Label('ЛОГИН'),
              const SizedBox(height: 8),
              _Input(
                controller: _login,
                hint: 'Логин',
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
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
              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Впервые здесь?',
                  style: TextStyle(fontSize: 13, color: AppColors.onDarkSub),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context)
                        .pushNamed(AppRoutes.register),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Text('Зарегистрироваться'),
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
        .login(login: _login.text.trim(), password: _password.text);
    if (!mounted) return;
    switch (result) {
      case LoginOk(:final user):
        // Гасим индикатор входа до показа модалки смены пароля, иначе
        // крутящийся спиннер остаётся под ней.
        setState(() => _loading = false);
        // Обязательная смена временного пароля при первом входе (FR-01.3).
        final effective = user.mustChangePassword
            ? await _forceChangePassword(user)
            : user;
        if (effective == null || !mounted) return;
        // Чужие данные из прошлой сессии не должны пережить смену входа.
        resetCompanyData(ref.invalidate);
        ref.read(currentUserProvider.notifier).state = effective;
        // Суперадминистратору шахматка и клиенты не нужны — у него своя панель.
        Navigator.of(context).pushReplacementNamed(
          effective.isSuperadmin ? AppRoutes.superadmin : AppRoutes.home,
        );
      case LoginFailed(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  /// Показывает обязательную форму смены пароля. Возвращает обновлённого
  /// пользователя или null, если отменили.
  Future<ManagerModel?> _forceChangePassword(ManagerModel user) =>
      showModalBottomSheet<ManagerModel>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        builder: (_) => _ChangePasswordSheet(user: user),
      );

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

/// Обязательная смена временного пароля при первом входе (FR-01.3).
class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet({required this.user});

  final ManagerModel user;

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Смена пароля', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          const Text(
            'Это первый вход. Задайте новый пароль вместо временного.',
            style: AppTextStyles.secondary,
          ),
          const SizedBox(height: 18),
          _field(_password, 'Новый пароль'),
          const SizedBox(height: 12),
          _field(_confirm, 'Повторите пароль'),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Сохранить и войти'),
          ),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    obscureText: true,
    style: AppTextStyles.body,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.secondary,
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.brand),
      ),
    ),
  );

  Future<void> _submit() async {
    if (_password.text.length < 4) {
      setState(() => _error = 'Пароль не короче 4 символов');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final updated = await runApi(
      context,
      () => ref
          .read(panoramaRepositoryProvider)
          .changePassword(userId: widget.user.id, newPassword: _password.text),
    );
    if (!mounted) return;
    if (updated == null) {
      setState(() => _saving = false); // без этого форму было не закрыть
      return;
    }
    Navigator.of(context).pop(updated);
  }
}
