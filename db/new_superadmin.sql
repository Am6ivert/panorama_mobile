-- =============================================================================
-- Создание суперадминистратора
-- =============================================================================
-- Суперадминистратор видит все компании, их администраторов и подписки, может
-- продлевать и блокировать. Через приложение его завести нельзя — только
-- отсюда, с доступом к базе.
--
-- Живёт в служебной компании с кодом 'system': колонка users.org_id объявлена
-- NOT NULL, и заводить исключение ради одной учётной записи дороже, чем
-- создать компанию. Своих объектов и сотрудников у неё нет.
--
-- Запуск — через обёртку, она передаёт кириллицу корректно:
--   powershell -File db\new_superadmin.ps1
--
-- Пароль — 0000, приложение потребует сменить его при первом входе.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

\if :{?admin_name}
\else
  \echo 'ОШИБКА: не задан -v admin_name=<ФИО>'
  \quit
\endif
\if :{?admin_login}
\else
  \echo 'ОШИБКА: не задан -v admin_login=<логин>'
  \quit
\endif
\if :{?admin_phone}
\else
  \echo 'ОШИБКА: не задан -v admin_phone=<телефон>'
  \quit
\endif

BEGIN;

SELECT set_config('panorama.admin_login', :'admin_login', true),
       set_config('panorama.admin_phone', :'admin_phone', true);

DO $$
DECLARE
  v_login text := current_setting('panorama.admin_login');
  v_phone text := current_setting('panorama.admin_phone');
BEGIN
  IF to_regclass('public.organizations') IS NULL THEN
    RAISE EXCEPTION 'Сначала накатите миграции: db\\migrate.ps1';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM organizations WHERE code = 'system') THEN
    RAISE EXCEPTION 'Нет служебной компании. Накатите 009_subscriptions.sql.';
  END IF;

  IF EXISTS (SELECT 1 FROM users
              WHERE lower(login) = lower(v_login) AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Логин "%" уже занят. Логины уникальны во всей базе.', v_login;
  END IF;

  IF EXISTS (SELECT 1 FROM users
              WHERE phone = v_phone AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Телефон "%" уже занят другой учётной записью', v_phone;
  END IF;
END $$;

WITH su AS (
    INSERT INTO users (org_id, full_name, login, phone,
                       password_hash, must_change_password)
    SELECT o.id, :'admin_name', lower(:'admin_login'), :'admin_phone',
           crypt('0000', gen_salt('bf')), true
    FROM organizations o WHERE o.code = 'system'
    RETURNING id
)
INSERT INTO user_roles (user_id, role_code)
SELECT id, 'superadmin' FROM su;

COMMIT;

\echo ''
\echo '=== Суперадминистратор создан ==='

SELECT u.full_name AS "ФИО", u.login AS "логин", '0000' AS "временный пароль"
FROM users u
WHERE lower(u.login) = lower(:'admin_login');

\echo 'Пароль нужно сменить при первом входе.'
\echo ''
