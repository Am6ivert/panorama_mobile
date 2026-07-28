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
import '../../../shared/widgets/initials_avatar.dart';

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
                      onBlock: () => _toggleBlock(ref, user),
                      onRole: () => _toggleRole(ref, user),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock(WidgetRef ref, ManagerModel user) async {
    await ref
        .read(panoramaRepositoryProvider)
        .setUserBlocked(userId: user.id, blocked: !user.blocked);
    ref.invalidate(usersProvider);
  }

  Future<void> _toggleRole(WidgetRef ref, ManagerModel user) async {
    final next = user.role == UserRole.admin
        ? UserRole.manager
        : UserRole.admin;
    await ref
        .read(panoramaRepositoryProvider)
        .setUserRole(userId: user.id, role: next);
    ref.invalidate(usersProvider);
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
  });

  final ManagerModel user;
  final VoidCallback onBlock;
  final VoidCallback onRole;

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
                onPressed: onRole,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.ink2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Text(
                  user.role == UserRole.admin ? 'Сделать менеджером' : 'Сделать админом',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 9),
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
    await ref
        .read(panoramaRepositoryProvider)
        .createUser(
          name: _name.text.trim(),
          login: _login.text.trim(),
          phone: _phone.text.trim(),
          role: _role,
        );
    if (mounted) Navigator.of(context).pop(true);
  }
}
