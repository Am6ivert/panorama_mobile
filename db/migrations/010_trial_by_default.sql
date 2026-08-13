-- =============================================================================
-- 010. Пробный период по умолчанию.
--
-- Раньше пробные 3 дня выдавал скрипт new_org.ps1 — то есть компания получала
-- их только если про это не забыли при вставке. Компания, заведённая любым
-- другим способом (тесты, ручной INSERT, будущая форма регистрации),
-- оставалась с plan_until = NULL и с первой же секунды попадала в режим
-- «только чтение».
--
-- Теперь пробный период описан в самой таблице:
--   plan_kind  = 'trial'
--   plan_until = создание + 3 дня
--   grace_days = 0        (льготные дни — привилегия платной подписки)
--
-- Платную подписку выдаёт суперадминистратор: она ставит plan_kind='paid' и
-- grace_days=3.
--
-- Идемпотентна: можно накатывать повторно.
-- =============================================================================
\set ON_ERROR_STOP on
BEGIN;

-- 1. Компании без срока: считаем, что пробный период начинается сейчас.
--    Иначе шаг с SET NOT NULL упадёт.
UPDATE organizations
   SET plan_until = now() + interval '3 days',
       plan_kind  = COALESCE(plan_kind, 'trial'),
       grace_days = 0
 WHERE plan_until IS NULL;

-- 2. Значения по умолчанию.
ALTER TABLE organizations ALTER COLUMN plan_until SET DEFAULT now() + interval '3 days';
ALTER TABLE organizations ALTER COLUMN plan_until SET NOT NULL;
ALTER TABLE organizations ALTER COLUMN plan_kind  SET DEFAULT 'trial';

-- Пробному периоду льготные дни не полагаются, платной подписке их ставит
-- сервер при продлении. Меняем только умолчание — у существующих компаний
-- срок не трогаем.
ALTER TABLE organizations ALTER COLUMN grace_days SET DEFAULT 0;

COMMIT;

\echo ''
\echo 'Миграция 010 применена: новая компания получает 3 пробных дня автоматически.'

SELECT o.code AS "компания", o.plan_kind AS "тип",
       to_char(o.plan_until, 'YYYY-MM-DD HH24:MI') AS "оплачено до",
       o.grace_days AS "льготных дней", o.is_blocked AS "приостановлена"
FROM organizations o
WHERE o.deleted_at IS NULL
ORDER BY o.created_at;
