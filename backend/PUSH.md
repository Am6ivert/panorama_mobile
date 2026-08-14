# Push-уведомления

## Что уже работает (без Firebase)

Приложение показывает **системные (мобилка) / браузерные (web) уведомления**,
пока оно открыто:

- сервер пишет уведомления в БД (бронь, освобождение, сообщение по квартире…);
- приложение опрашивает `GET /notifications` и при новом непрочитанном
  показывает уведомление уровня ОС
  (`lib/core/notifications/*`, привязка — в `HomeShell`);
- на web — через браузерный Notification API (Chrome спросит разрешение),
  на Android/iOS — через `flutter_local_notifications`.

Это доставка на уровень ОС **при открытом приложении** — достаточно для показа
и защиты, Firebase не нужен.

## Что нужно для доставки при ЗАКРЫТОМ приложении (FCM/APNs)

Настоящий push, когда приложение выгружено, отправляет сервер через
Firebase Cloud Messaging (Android/web) и APNs (iOS). Это требует твоей
инфраструктуры Firebase — по шагам:

### 1. Firebase-проект (делается один раз, в консоли)

1. https://console.firebase.google.com → создать проект.
2. Добавить приложения:
   - **Android**: package из `android/app/build.gradle` → скачать
     `google-services.json` в `android/app/`.
   - **iOS**: bundle id → `GoogleService-Info.plist` в `ios/Runner/`, загрузить
     APNs-ключ в настройках Cloud Messaging.
   - **Web**: получить web-config и **VAPID key** (Cloud Messaging → Web Push).
3. Сгенерировать `lib/firebase_options.dart`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### 2. Клиент (Flutter)

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
```

- в `main()` — `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
- запросить разрешение, получить токен:
  `final token = await FirebaseMessaging.instance.getToken(vapidKey: '...web...');`
- отправить токен на сервер: `POST /api/v1/devices { user_id, platform, push_token }`
  (таблица `devices` уже есть в схеме);
- обрабатывать `FirebaseMessaging.onMessage` (foreground) и фоновый handler;
- для web положить `web/firebase-messaging-sw.js`.

### 3. Backend (отправка)

- сохранить токен в `devices` (эндпоинт `POST /devices` — добавить в `api.dart`);
- при событии (бронь/освобождение/…), помимо записи в `notifications`,
  отправить сообщение на токены получателей через **FCM HTTP v1 API**:
  - завести сервисный аккаунт Firebase (JSON-ключ), получить OAuth2-токен;
  - `POST https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send`
    с `{ message: { token, notification: { title, body }, data: { unit_id } } }`.

После этого события фонда будут долетать до менеджеров даже при закрытом
приложении (ТЗ FR-11, срок доставки ≤ 5 секунд).
