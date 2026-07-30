# База данных Panorama (PostgreSQL 14+)

Схема БД для «Шахматки квартир». Полностью **money-free** (ТЗ 1.3): денежных
колонок нет ни в одной таблице.

Файлы:
- [`init.sql`](init.sql) — роль приложения, база, расширение `pgcrypto` (запускать суперпользователем);
- [`schema.sql`](schema.sql) — таблицы, индексы, ограничения;
- [`seed.sql`](seed.sql) — роли, справочники, настройки, демо-учётки и пример объекта;
- [`setup.ps1`](setup.ps1) — всё сразу одним скриптом.

---

## 1. Установка PostgreSQL

Если PostgreSQL 14+ уже установлен — пропусти этот шаг. Иначе на Windows:

```powershell
winget install --id PostgreSQL.PostgreSQL.17 -e
```

или установщик с https://www.postgresql.org/download/windows/. При установке
задаётся пароль суперпользователя `postgres` — он понадобится ниже.

## 2. Настройка одним скриптом (рекомендуется)

Из корня проекта:

```powershell
powershell -ExecutionPolicy Bypass -File db\setup.ps1
```

Скрипт сам найдёт `psql`, спросит пароль суперпользователя `postgres` (нужен
только для создания роли и базы, нигде не сохраняется) и накатит `init.sql`,
`schema.sql`, `seed.sql`, затем покажет проверку.

## 3. Либо вручную (три шага)

```powershell
# 1) роль + база + pgcrypto — суперпользователем
psql -U postgres -h localhost -f db\init.sql
# 2) схема и данные — под ролью приложения (пароль panorama)
psql -U panorama -h localhost -d panorama -f db\schema.sql
psql -U panorama -h localhost -d panorama -f db\seed.sql
```

> `pgcrypto` создаётся в `init.sql` суперпользователем (обычной роли это не
> разрешено). `seed.sql` хеширует пароль `0000` алгоритмом bcrypt — пароли
> хранятся **только в виде хеша** (ТЗ 5.2).

## 4. Проверка

```powershell
psql -U panorama -h localhost -d panorama -c "SELECT count(*) FROM apartments;"  # 96
psql -U panorama -h localhost -d panorama -c "SELECT login, full_name FROM users;"
```

Логины демо-учёток: `admin`, `azamat`, `elvira`, `nurlan`, `bekzat` — пароль `0000`.

## 5. Резервные копии (ТЗ 4)

Ежесуточный дамп с хранением 30 суток:

```bash
pg_dump -U panorama -Fc panorama > panorama_$(date +%F).dump
```

Восстановление:

```bash
pg_restore -U panorama -d panorama --clean panorama_2026-07-30.dump
```

Миграции в проде вести инструментом с откатом (Flyway / Liquibase / sqitch) —
не править схему руками.

---

## 6. Как это связано с приложением и «синхронизацией между аккаунтами»

Важно понимать архитектуру (ТЗ 1.2):

```
Мобильное приложение (Flutter)
        │  HTTPS, REST /api/v1/
        ▼
   Backend-сервис (REST API)   ◄── единый источник правды
        │
        ▼
   PostgreSQL (эта БД)
```

**Мобильный клиент не подключается к PostgreSQL напрямую** — это делает
backend-сервис (REST API). Приложение уже готово к нему:

- `lib/core/config/app_config.dart` → `useMockData = false` и правильный `apiBaseUrl`;
- `lib/core/data/api_panorama_repository.dart` — реализация на REST (пути сверить
  с реальным API).

Пока `useMockData = true`, данные лежат **в памяти каждого экземпляра приложения**.
Поэтому две вкладки/два устройства не видят действий друг друга — у каждого своя
копия. Это и есть причина, почему «синхронизация между аккаунтами не работает»
на моках.

**Настоящая синхронизация появляется, когда есть общий источник правды** — этот
backend + БД. Тогда бронь, сделанная одним менеджером, сразу видна остальным:
через опрос (`watchUnits()` перечитывает фонд раз в 15 сек) или, в v2.0, через
WebSocket. Push-уведомления (FCM/APNs) доставляют события даже при закрытом
приложении.

Итого для полноценной работы нужно поднять **три компонента**:
1. эту БД (готово этим каталогом);
2. backend-сервис REST API поверх неё (отдельный репозиторий/сервис);
3. в приложении переключить `useMockData = false`.
