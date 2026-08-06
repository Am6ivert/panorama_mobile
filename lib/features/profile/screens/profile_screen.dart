import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/data/panorama_repository.dart';
import '../../../core/providers/data_providers.dart';
import '../../../shared/widgets/app_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _changingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не найден')),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Профиль',
            subtitle: user.role.label,
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  label: 'ФИО',
                  value: user.name,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  label: 'Телефон',
                  value: user.phone,
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  label: 'Логин',
                  value: user.login,
                  icon: Icons.account_circle_outlined,
                ),
                const SizedBox(height: 24),
                Text(
                  'ИЗМЕНИТЬ ПАРОЛЬ',
                  style: AppTextStyles.section,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _currentPassword,
                  label: 'Текущий пароль',
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _newPassword,
                  label: 'Новый пароль',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _confirmPassword,
                  label: 'Подтвердите пароль',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Изменить пароль'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final current = _currentPassword.text.trim();
    final newPwd = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      _showSnack('Заполните все поля');
      return;
    }

    if (newPwd != confirm) {
      _showSnack('Пароли не совпадают');
      return;
    }

    if (newPwd.length < 4) {
      _showSnack('Пароль должен быть минимум 4 символа');
      return;
    }

    setState(() => _changingPassword = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Сначала проверяем текущий пароль через login
      final result = await ref.read(panoramaRepositoryProvider).login(
            login: user.login,
            password: current,
          );

      if (result is! LoginOk) {
        _showSnack('Неверный текущий пароль');
        setState(() => _changingPassword = false);
        return;
      }

      // Меняем пароль
      final updated = await ref.read(panoramaRepositoryProvider).changePassword(
            userId: user.id,
            newPassword: newPwd,
          );

      ref.read(currentUserProvider.notifier).state = updated;

      if (mounted) {
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
        _showSnack('Пароль успешно изменён');
      }
    } catch (e) {
      _showSnack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.brand, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(fontSize: 15, color: AppColors.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.ink3,
                ),
                onPressed: onToggle,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brand),
              ),
            ),
          ),
        ],
      );
}
