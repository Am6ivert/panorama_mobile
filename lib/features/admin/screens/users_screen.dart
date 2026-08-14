import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/manager_model.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../core/utils/api_action.dart';

/// Управление учётными записями (FR-01): создание, роли, блокировка.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Пользователи',
            subtitle: 'Учётные записи отдела продаж',
            gradient: false,
            onBack: () => Navigator.of(context).pop(),
            trailing: _AddButton(onTap: () => _create(context, ref)),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (users) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  for (final user in users)
                    _UserCard(
                      user: user,
                      onBlock: () => _toggleBlock(context, ref, user),
                      onRole: () => _toggleRole(context, ref, user),
                      onEdit: () => _editUser(context, ref, user),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock(
    BuildContext context,
    WidgetRef ref,
    ManagerModel user,
  ) async {
    if (!user.blocked) {
      final ok = await confirmDialog(
        context,
        title: 'Заблокировать',
        message: '${user.name} потеряет доступ, все сессии будут завершены.',
        confirmLabel: 'Заблокировать',
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }
    final updated = await runApi(
      context,
      () => ref
          .read(panoramaRepositoryProvider)
          .setUserBlocked(userId: user.id, blocked: !user.blocked),
    );
    if (updated != null) ref.invalidate(usersProvider);
  }

  Future<void> _toggleRole(
    BuildContext context,
    WidgetRef ref,
    ManagerModel user,
  ) async {
    final next = user.role == UserRole.admin
        ? UserRole.manager
        : UserRole.admin;
    final updated = await runApi(
      context,
      () => ref
          .read(panoramaRepositoryProvider)
          .setUserRole(userId: user.id, role: next),
    );
    if (updated != null) ref.invalidate(usersProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateUserSheet(),
    );
    if (created == true) ref.invalidate(usersProvider);
  }

  Future<void> _editUser(BuildContext context, WidgetRef ref, ManagerModel user) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditUserSheet(user: user),
    );
    if (updated == true) ref.invalidate(usersProvider);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        children: [
          Icon(Icons.add, size: 17, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'Создать',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onBlock,
    required this.onRole,
    required this.onEdit,
  });

  final ManagerModel user;
  final VoidCallback onBlock;
  final VoidCallback onRole;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppTheme.shadow,
    ),
    child: Column(
      children: [
        Row(
          children: [
            InitialsAvatar(
              initials: user.initials,
              color: user.blocked ? AppColors.ink3 : user.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: AppTextStyles.bodyStrong,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RoleBadge(role: user.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.blocked ? '${user.phone} · заблокирован' : user.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: user.blocked ? AppColors.error : AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text(
                  'Редактировать',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 9),
            if (user.role != UserRole.admin)
              Expanded(
                child: OutlinedButton(
                  onPressed: onRole,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    side: const BorderSide(color: AppColors.line),
                    foregroundColor: AppColors.ink2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text(
                    'Сделать админом',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (user.role != UserRole.admin) const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton(
                onPressed: onBlock,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(
                    color: user.blocked ? AppColors.free : AppColors.error,
                  ),
                  foregroundColor: user.blocked ? AppColors.free : AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Text(
                  user.blocked ? 'Разблокировать' : 'Заблокировать',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = role.isAdmin ? AppColors.design : AppColors.ink3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _phone = TextEditingController(text: '+996 ');
  UserRole _role = UserRole.manager;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Новая учётная запись', style: AppTextStyles.h1),
            const SizedBox(height: 4),
            const Text(
              'Временный пароль уйдёт по SMS, сотрудник сменит его при входе',
              style: AppTextStyles.secondary,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('ФИО'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите ФИО' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _login,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              decoration: _dec('Логин'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Логин от 3 символов' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
              ],
              decoration: _dec('Телефон'),
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 9
                  ? 'Похоже, номер неполный'
                  : null,
            ),
            const SizedBox(height: 18),
            const Text('РОЛЬ', style: AppTextStyles.section),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final role in UserRole.values) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _role = role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _role == role
                              ? AppColors.brand
                              : AppColors.surface,
                          border: Border.all(
                            color: _role == role
                                ? AppColors.brand
                                : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          role.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _role == role
                                ? Colors.white
                                : AppColors.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (role != UserRole.values.last) const SizedBox(width: 9),
                ],
              ],
            ),
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
                  : const Text('Создать учётную запись'),
            ),
          ],
        ),
      ),
    ),
  );

  InputDecoration _dec(String label) => InputDecoration(
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
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final created = await runApi(
      context,
      () => ref.read(panoramaRepositoryProvider).createUser(
            name: _name.text.trim(),
            login: _login.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
          ),
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class _EditUserSheet extends ConsumerStatefulWidget {
  const _EditUserSheet({required this.user});

  final ManagerModel user;

  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Редактировать ${widget.user.name}', style: AppTextStyles.h1),
            const SizedBox(height: 4),
            Text(
              widget.user.role.label,
              style: AppTextStyles.secondary,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('ФИО'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите ФИО' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
              ],
              decoration: _dec('Телефон'),
              validator: (v) =>
                  (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 9
                  ? 'Похоже, номер неполный'
                  : null,
            ),
            const SizedBox(height: 18),
            const Text('ИЗМЕНИТЬ ПАРОЛЬ (необязательно)', style: AppTextStyles.section),
            const SizedBox(height: 10),
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
                  : const Text('Сохранить изменения'),
            ),
          ],
        ),
      ),
    ),
  );

  InputDecoration _dec(String label) => InputDecoration(
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
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newPwd = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    // Проверяем пароль, если он заполнен
    if (newPwd.isNotEmpty || confirm.isNotEmpty) {
      if (newPwd != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароли не совпадают')),
        );
        return;
      }
      if (newPwd.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пароль должен быть минимум 4 символа')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    // Обновляем профиль через API
    final updated = await runApi(
      context,
      () => ref.read(panoramaRepositoryProvider).updateUserProfile(
            userId: widget.user.id,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
          ),
    );

    if (updated == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    // Если задан новый пароль, обновляем его отдельно
    if (newPwd.isNotEmpty) {
      if (!mounted) return;
      final passwordUpdated = await runApi(
        context,
        () => ref.read(panoramaRepositoryProvider).changePassword(
              userId: widget.user.id,
              newPassword: newPwd,
            ),
      );
      if (passwordUpdated == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
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
