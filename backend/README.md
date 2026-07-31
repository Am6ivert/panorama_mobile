# Panorama Backend (Dart / shelf)

REST API `/api/v1` поверх PostgreSQL для «Шахматки квартир». Единый источник
правды: приложение ходит сюда, а сервис — в БД. Денежных значений нет (ТЗ 1.3).

## Требования

- Dart SDK 3.5+
- PostgreSQL с накатанной схемой (см. `../db/` — `setup.ps1`)

## Запуск

```powershell
cd backend
dart pub get
dart run bin/server.dart
```

Сервер поднимется на `http://localhost:8080/api/v1`. Проверка:

```powershell
curl http://localhost:8080/api/v1/health
```

Настройки БД берутся из переменных окружения (иначе — значения для локальной
базы из `db/setup.ps1`):

| Переменная  | По умолчанию |
|-------------|--------------|
| `PGHOST`    | localhost    |
| `PGPORT`    | 5432         |
| `PGDATABASE`| panorama     |
| `PGUSER`    | panorama     |
| `PGPASSWORD`| panorama     |
| `PORT`      | 8080         |

## Эндпоинты

- `POST /auth/login` — вход по логину/паролю (проверка bcrypt в БД), выдаёт токен.
- `GET/POST /users`, `/users/{id}/block|role|password` — учётные записи.
- `GET/POST /complexes`, `POST /blocks/bulk` — объекты и массовое создание.
- `GET /units`, `POST /units/{id}` — фонд и редактирование квартиры.
- `POST /units/{id}/take|book|release|design|sell|status|extend|message` — действия.
- `GET/POST /clients` — клиенты.
- `GET /notifications?user_id=`, `/notifications/{id}/read`, `/read-all` — уведомления.
- `GET /audit` — журнал аудита.

## Подключение приложения

В `lib/core/config/app_config.dart`:

```dart
static const useMockData = false;
static const apiBaseUrl = 'http://localhost:8080/api/v1';
```

Для Android-эмулятора вместо `localhost` — `10.0.2.2`. Для реального телефона —
IP компьютера в локальной сети (и PostgreSQL/сервер должны слушать сеть).

## Примечания

- Аутентификация упрощена для локального запуска: логин выдаёт токен и сессию,
  но middleware пока не требует его на каждом запросе (для прод — включить
  проверку Bearer-токена по таблице `sessions`).
- Защита от двойного бронирования — через сверку статуса и `version` в UPDATE
  (409 при конфликте).
