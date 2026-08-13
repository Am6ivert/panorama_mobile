-- =============================================================================
-- 009 — Подписки компаний и роль суперадминистратора
-- =============================================================================
-- Модель доступа
-- --------------
-- В organizations появляются три поля:
--
--   plan_until  — дата, до которой оплачено (её показываем клиенту, от неё
--                 считаем предупреждение за 3 дня);
--   grace_days  — сколько дней сверх plan_until доступ ещё полный;
--   is_blocked  — ручная блокировка суперадминистратором.
--
-- Доступ полный, пока  now() <= plan_until + grace_days  и не is_blocked.
-- Дальше компания переходит в режим «только чтение»: данные видно, изменить
-- ничего нельзя.
--
--   пробный период: plan_until = создание + 3 дня, grace_days = 0
--   платная подписка: plan_until = +1 месяц, grace_days = 3
--
-- Одно правило вместо двух: «сколько ещё работает» всегда считается одинаково,
-- а разница между пробным и платным — только в grace_days.
--
-- Поля денормализованы намеренно: middleware и так соединяет organizations при
-- разборе токена, поэтому проверка подписки не стоит ни одного лишнего запроса.
-- История операций живёт в таблице subscriptions.
--
-- Суперадминистратор
-- ------------------
-- Живёт в служебной компании с кодом 'system' и бессрочной подпиской: колонка
-- users.org_id объявлена NOT NULL, и заводить исключение ради одной учётной
-- записи дороже, чем создать компанию.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/009_subscriptions.sql
--
-- Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- 1. Поля подписки ------------------------------------------------------------
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS plan_until  timestamptz;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS plan_kind   text;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS grace_days  integer;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS is_blocked  boolean;

UPDATE organizations SET grace_days = 3  WHERE grace_days IS NULL;
UPDATE organizations SET is_blocked = false WHERE is_blocked IS NULL;
UPDATE organizations SET plan_kind  = 'paid' WHERE plan_kind IS NULL;

-- Уже работающим компаниям выдаём месяц с этого момента, чтобы миграция никого
-- не отключила посреди рабочего дня.
UPDATE organizations
   SET plan_until = now() + interval '1 month'
 WHERE plan_until IS NULL;

ALTER TABLE organizations ALTER COLUMN grace_days SET NOT NULL;
ALTER TABLE organizations ALTER COLUMN grace_days SET DEFAULT 3;
ALTER TABLE organizations ALTER COLUMN is_blocked SET NOT NULL;
ALTER TABLE organizations ALTER COLUMN is_blocked SET DEFAULT false;
ALTER TABLE organizations ALTER COLUMN plan_kind  SET NOT NULL;
ALTER TABLE organizations ALTER COLUMN plan_kind  SET DEFAULT 'trial';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'organizations_plan_kind_check') THEN
    ALTER TABLE organizations ADD CONSTRAINT organizations_plan_kind_check
      CHECK (plan_kind IN ('trial', 'paid'));
  END IF;
END $$;

-- 2. История подписок ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      uuid NOT NULL CONSTRAINT subscriptions_org_fk
                    REFERENCES organizations(id) ON DELETE RESTRICT,
    kind        text NOT NULL CHECK (kind IN ('trial', 'paid')),
    starts_at   timestamptz NOT NULL DEFAULT now(),
    ends_at     timestamptz NOT NULL,
    note        text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid REFERENCES users(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS subscriptions_org_idx ON subscriptions (org_id, ends_at DESC);

-- 3. Роль суперадминистратора -------------------------------------------------
DO $$
BEGIN
  ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_code_check;
  ALTER TABLE roles ADD CONSTRAINT roles_code_check
    CHECK (code IN ('manager', 'admin', 'superadmin'));
END $$;

INSERT INTO roles (code, title) VALUES ('superadmin', 'Суперадминистратор')
ON CONFLICT (code) DO NOTHING;

-- 4. Служебная компания для суперадминистратора -------------------------------
INSERT INTO organizations (code, name, plan_kind, plan_until, grace_days)
SELECT 'system', 'Служебная', 'paid', now() + interval '100 years', 0
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE code = 'system');

COMMIT;

-- Контроль
SELECT o.code AS "компания", o.plan_kind AS "тип",
       to_char(o.plan_until, 'YYYY-MM-DD') AS "оплачено до",
       o.grace_days AS "льготных дней", o.is_blocked AS "заблокирована"
FROM organizations o
WHERE o.deleted_at IS NULL
ORDER BY o.code;
