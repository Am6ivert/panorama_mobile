import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../data/panorama_repository.dart';
import '../network/api_client.dart';

/// Выполняет запрос к серверу и показывает пользователю понятную ошибку.
///
/// Возвращает результат запроса либо `null`, если он не удался. Без этого
/// любой ответ 4xx выглядел в приложении как зависший спиннер: исключение
/// уходило в никуда, а флаг «сохраняю» так и оставался поднятым.
///
/// ```dart
/// final complex = await runApi(context, () => repo.createComplex(...));
/// if (complex == null) return;            // ошибку пользователь уже увидел
/// ```
Future<T?> runApi<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await action();
  } on LimitExceeded catch (e) {
    showApiError(messenger, 'Лимит достигнут', e.message);
  } on ApiException catch (e) {
    showApiError(messenger, _titleFor(e.statusCode), e.message);
  } catch (e) {
    showApiError(messenger, 'Не удалось выполнить', '$e');
  }
  return null;
}

String _titleFor(int? status) => switch (status) {
      401 => 'Сессия истекла',
      402 => 'Подписка истекла',
      403 => 'Недостаточно прав',
      404 => 'Не найдено',
      409 => 'Данные изменились',
      422 => 'Проверьте данные',
      503 => 'Сервис недоступен',
      _ => 'Ошибка',
    };

/// Показывает ошибку одинаково во всём приложении.
void showApiError(
  ScaffoldMessengerState messenger,
  String title,
  String message,
) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
