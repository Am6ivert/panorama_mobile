-- =============================================================================
-- Заведение новой строительной компании и её первого администратора
-- =============================================================================
-- Через API компанию создать нельзя — такого эндпоинта не существует. Это
-- единственный путь, и он требует доступа к базе.
--
-- Запуск (Windows PowerShell, обратная кавычка ` переносит строку):
--
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 `
--        -v code=elitstroy -v name='ЭлитСтрой' `
--        -v admin_name='Иванов Иван' -v admin_login='elit.admin' `
--        -v admin_phone='+996 555 12-34-56' `
--        -f db/new_org.sql
--
-- Пароль администратора — 0000, при первом входе приложение потребует его
-- сменить (must_change_password = true).
--
-- ВАЖНО: логин и телефон уникальны во всей базе, а не внутри компании. Если
-- логин занят — скрипт остановится с понятной ошибкой. Практика: делайте
-- логин с префиксом компании (elit.admin) либо используйте номер телефона.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?code}
\else
  \echo 'ОШИБКА: не задан -v code=<код компании>'
  \quit
\endif
\if :{?name}
\else
  \echo 'ОШИБКА: не задан -v name=<название компании>'
  \quit
\endif
\if :{?admin_name}
\else
  \echo 'ОШИБКА: не задан -v admin_name=<ФИО администратора>'
  \quit
\endif
\if :{?admin_login}
\else
  \echo 'ОШИБКА: не задан -v admin_login=<логин администратора>'
  \quit
\endif
\if :{?admin_phone}
\else
  \echo 'ОШИБКА: не задан -v admin_phone=<телефон администратора>'
  \quit
\endif

BEGIN;

-- psql НЕ подставляет свои переменные внутрь $$...$$, поэтому кладём их в
-- настройки сессии — блок проверок читает их через current_setting().
SELECT set_config('panorama.code',        :'code',        true),
       set_config('panorama.admin_login', :'admin_login', true),
       set_config('panorama.admin_phone', :'admin_phone', true);

-- Понятные ошибки вместо нарушения уникального индекса ------------------------
DO $$
DECLARE
  v_code  text := current_setting('panorama.code');
  v_login text := current_setting('panorama.admin_login');
  v_phone text := current_setting('panorama.admin_phone');
BEGIN
  IF EXISTS (SELECT 1 FROM organizations
              WHERE lower(code) = lower(v_code) AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Компания с кодом "%" уже существует', v_code;
  END IF;

  IF EXISTS (SELECT 1 FROM users
              WHERE lower(login) = lower(v_login) AND deleted_at IS NULL) THEN
    RAISE EXCEPTION
      'Логин "%" уже занят. Логины уникальны во всей базе — возьмите другой, '
      'например с префиксом компании.', v_login;
  END IF;

  IF EXISTS (SELECT 1 FROM users
              WHERE phone = v_phone AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Телефон "%" уже занят другой учётной записью', v_phone;
  END IF;
END $$;

-- Компания + её первый администратор ------------------------------------------
WITH org AS (
    -- Пробный период: 3 дня без льготных дней. Дальше компания переходит в
    -- режим «только чтение», пока суперадминистратор не выдаст подписку.
    INSERT INTO organizations (code, name, plan_kind, plan_until, grace_days)
    VALUES (lower(:'code'), :'name', 'trial', now() + interval '3 days', 0)
    RETURNING id
), admin AS (
    INSERT INTO users (org_id, full_name, login, phone,
                       password_hash, must_change_password)
    SELECT org.id, :'admin_name', lower(:'admin_login'), :'admin_phone',
           crypt('0000', gen_salt('bf')), true
    FROM org
    RETURNING id
)
INSERT INTO user_roles (user_id, role_code)
SELECT id, 'admin' FROM admin;

-- Журнал подписок: пробный период тоже фиксируем, чтобы у суперадминистратора
-- была полная история по компании.
INSERT INTO subscriptions (org_id, kind, ends_at, note)
SELECT o.id, 'trial', o.plan_until, 'Пробный период при создании компании'
FROM organizations o
WHERE lower(o.code) = lower(:'code');

-- Настройки компании: без них сервер возьмёт значения по умолчанию из кода,
-- но администратору удобнее иметь строки, которые можно поправить.
INSERT INTO settings (org_id, key, value)
SELECT o.id, d.key, d.value
FROM organizations o
CROSS JOIN (VALUES
    ('booking_days',       '3'),
    ('booking_limit',      '5'),
    ('work_limit',         '5'),
    ('min_client_version', '1.0.0')
) AS d(key, value)
WHERE lower(o.code) = lower(:'code')
ON CONFLICT (org_id, key) DO NOTHING;

COMMIT;

\echo ''
\echo '=== Компания создана ==='

SELECT o.code   AS "код компании",
       o.name   AS "название",
       u.login  AS "логин администратора",
       '0000'   AS "временный пароль",
       to_char(o.plan_until, 'DD.MM.YYYY HH24:MI') AS "пробный период до"
FROM organizations o
JOIN users u ON u.org_id = o.id
WHERE lower(o.code) = lower(:'code');

\echo 'Пароль нужно сменить при первом входе.'
\echo ''
