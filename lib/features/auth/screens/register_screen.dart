import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/router/app_router.dart';
import '../widgets/auth_fields.dart';

/// Регистрация застройщика.
///
/// Создаёт компанию и первого пользователя в ней — администратора. Менеджеров
/// он заводит сам уже внутри приложения, поэтому выбора роли здесь нет.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _company, _phone, _login, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Регистрация',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Компания получит 3 пробных дня. Вы станете её '
                'администратором и сможете завести менеджеров.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.onDarkSub,
                ),
              ),
              const SizedBox(height: 28),

              const AuthLabel('ФАМИЛИЯ, ИМЯ, ОТЧЕСТВО'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              const AuthLabel('КОМПАНИЯ'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _company,
                hint: 'ОсОО «Панорама»',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              const AuthLabel('ТЕЛЕФОН'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 6),
              const Text(
                'Иностранный номер — с кодом страны',
                style: TextStyle(fontSize: 12, color: AppColors.ink3),
              ),
              const SizedBox(height: 18),

              const AuthLabel('ЛОГИН (ЛАТИНИЦЕЙ)'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _login,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              const AuthLabel('ПАРОЛЬ (ОТ 6 СИМВОЛОВ)'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),

              const AuthLabel('ПОВТОРИТЕ ПАРОЛЬ'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _confirm,
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                AuthError(_error!),
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
                    : const Text('Создать компанию'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.onDarkSub),
                  child: const Text('У меня уже есть аккаунт'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Проверки дублируют серверные, чтобы не гонять заведомо плохую форму
  /// туда-обратно. Последнее слово всё равно за сервером.
  String? _validate() {
    if (_name.text.trim().length < 3) return 'Укажите фамилию, имя и отчество';
    if (_company.text.trim().length < 2) return 'Укажите название компании';
    var digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length < 7 || digits.length > 15) {
      return 'Укажите номер телефона';
    }
    final login = _login.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(login)) {
      return 'Логин: латинские буквы и цифры, от 3 символов';
    }
    if (_password.text.length < 6) {
      return 'Пароль должен быть не короче 6 символов';
    }
    if (_password.text != _confirm.text) return 'Пароли не совпадают';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(panoramaRepositoryProvider).register(
          name: _name.text.trim(),
          company: _company.text.trim(),
          phone: _phone.text.trim(),
          login: _login.text.trim().toLowerCase(),
          password: _password.text,
        );
    if (!mounted) return;

    switch (result) {
      case LoginOk(:final user):
        // Данные прошлой сессии не должны пережить смену компании.
        resetCompanyData(ref.invalidate);
        ref.read(currentUserProvider.notifier).state = user;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      case LoginFailed(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }
}
