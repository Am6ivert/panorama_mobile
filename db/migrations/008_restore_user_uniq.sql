-- =============================================================================
-- 008 — Возврат уникальности логина и телефона, уборка чужих колонок
-- =============================================================================
-- Сверка db/drift.sql показала, что в рабочей базе НЕТ индексов
-- users_login_uniq и users_phone_uniq, хотя в db/schema.sql они есть.
-- Скорее всего их сняли при той же заброшенной попытке мультиарендности,
-- что оставила после себя company_id (см. миграцию 003).
--
-- Это дыра в целостности: ничто не мешает завести двух пользователей с одним
-- логином, а вход (`SELECT ... WHERE lower(login) = ...`) возьмёт произвольного
-- из них. Восстанавливаем.
--
-- Заодно убираем колонки apartments.held_from и apartments.is_penthouse: их нет
-- ни в схеме репозитория, ни в коде сервера, ни в приложении.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/008_restore_user_uniq.sql
--
-- Идемпотентна. Если в базе уже есть дубликаты логинов или телефонов,
-- миграция ОСТАНОВИТСЯ и ничего не изменит — сначала нужно решить, какую из
-- записей оставить.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = notice;

BEGIN;

-- 1. Предохранитель: уникальный индекс не создастся поверх дубликатов --------
DO $$
DECLARE
  dup_logins int;
  dup_phones int;
BEGIN
  SELECT count(*) INTO dup_logins FROM (
      SELECT lower(login) FROM users WHERE deleted_at IS NULL
      GROUP BY lower(login) HAVING count(*) > 1) t;

  SELECT count(*) INTO dup_phones FROM (
      SELECT phone FROM users WHERE deleted_at IS NULL
      GROUP BY phone HAVING count(*) > 1) t;

  IF dup_logins > 0 THEN
    RAISE EXCEPTION 'ОСТАНОВЛЕНО: % повторяющихся логинов в users. '
      'Найти их: SELECT lower(login), count(*) FROM users '
      'WHERE deleted_at IS NULL GROUP BY 1 HAVING count(*) > 1;', dup_logins;
  END IF;

  IF dup_phones > 0 THEN
    RAISE EXCEPTION 'ОСТАНОВЛЕНО: % повторяющихся телефонов в users.', dup_phones;
  END IF;

  RAISE NOTICE 'Дубликатов нет, восстанавливаю уникальность.';
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS users_login_uniq
    ON users (lower(login)) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_phone_uniq
    ON users (phone) WHERE deleted_at IS NULL;

-- 2. Колонки, которых нет ни в схеме, ни в коде -------------------------------
DO $$
DECLARE n int;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='apartments'
                AND column_name='held_from') THEN
    EXECUTE 'SELECT count(*) FROM apartments WHERE held_from IS NOT NULL' INTO n;
    RAISE NOTICE 'Удаляю apartments.held_from (заполненных значений: %)', n;
    ALTER TABLE apartments DROP COLUMN held_from;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='apartments'
                AND column_name='is_penthouse') THEN
    EXECUTE 'SELECT count(*) FROM apartments WHERE is_penthouse IS TRUE' INTO n;
    RAISE NOTICE 'Удаляю apartments.is_penthouse (значений TRUE: %)', n;
    ALTER TABLE apartments DROP COLUMN is_penthouse;
  END IF;
END $$;

COMMIT;

SET client_min_messages = warning;

-- Контроль
SELECT indexname AS "индекс"
FROM pg_indexes
WHERE schemaname='public' AND indexname IN ('users_login_uniq','users_phone_uniq')
ORDER BY 1;

SELECT count(*) AS "лишних колонок в apartments (должно быть 0)"
FROM information_schema.columns
WHERE table_schema='public' AND table_name='apartments'
  AND column_name IN ('held_from','is_penthouse');
