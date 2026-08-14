-- =============================================================================
-- 003 — Удаление legacy-механизма компаний (companies / company_id)
-- =============================================================================
-- В базе оказались ДВА параллельных механизма арендности:
--
--   * companies + company_id — более ранняя попытка, сделанная прямо в БД.
--     В репозитории её нет: ни в schema.sql, ни в миграциях, ни в коде Dart.
--     Ни один запрос сервера к company_id не обращается.
--   * organizations + org_id — рабочий механизм из миграции 002. На нём
--     построены все запросы api.dart и составные внешние ключи (id, org_id).
--
-- Держать оба нельзя: company_id объявлен NOT NULL без значения по умолчанию,
-- поэтому сервер физически не может создать пользователя, клиента или квартиру
-- (INSERT падает на нарушении NOT NULL). Легаси удаляем.
--
-- БЕЗОПАСНОСТЬ: миграция сначала проверяет, что через company_id заведена
-- РОВНО ОДНА компания. Если их несколько, значит данные уже разведены по
-- разным арендаторам, слепое удаление потеряло бы эту привязку — тогда
-- миграция останавливается и ничего не трогает.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/003_drop_legacy_company.sql
--
-- Требует накатанной 002. Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- 1. Предохранитель ------------------------------------------------------------
DO $$
DECLARE
  t          text;
  distinct_n int;
  companies_n int;
  max_n      int := 0;
BEGIN
  IF to_regclass('public.companies') IS NULL
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema='public' AND column_name='company_id') THEN
    RAISE NOTICE 'Legacy-механизм уже удалён - делать нечего.';
    RETURN;
  END IF;

  IF to_regclass('public.organizations') IS NULL THEN
    RAISE EXCEPTION 'Сначала накатите 002_multi_tenant.sql - таблицы organizations нет.';
  END IF;

  -- Сколько разных компаний реально используется в данных?
  FOR t IN SELECT table_name FROM information_schema.columns
            WHERE table_schema='public' AND column_name='company_id'
  LOOP
    EXECUTE format('SELECT count(DISTINCT company_id) FROM %I', t) INTO distinct_n;
    IF distinct_n > max_n THEN max_n := distinct_n; END IF;
  END LOOP;

  IF to_regclass('public.companies') IS NOT NULL THEN
    EXECUTE 'SELECT count(*) FROM companies' INTO companies_n;
  ELSE
    companies_n := 0;
  END IF;

  IF max_n > 1 THEN
    RAISE EXCEPTION
      'ОСТАНОВЛЕНО: через company_id заведено % разных компаний. Данные уже '
      'разведены по арендаторам, и удаление колонки потеряло бы эту привязку. '
      'Нужен перенос company_id -> org_id, а не удаление.', max_n;
  END IF;

  IF companies_n > 1 THEN
    RAISE EXCEPTION
      'ОСТАНОВЛЕНО: в таблице companies % записей. Прежде чем удалять, решите, '
      'какие из них должны стать записями organizations.', companies_n;
  END IF;

  RAISE NOTICE 'Проверка пройдена: компания одна, переносить нечего.';
END $$;

-- 2. Удаление колонок company_id ----------------------------------------------
-- DROP COLUMN сам убирает висящие на колонке внешние ключи и индексы.
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT table_name FROM information_schema.columns
            WHERE table_schema='public' AND column_name='company_id'
            ORDER BY table_name
  LOOP
    EXECUTE format('ALTER TABLE %I DROP COLUMN company_id', t);
    RAISE NOTICE 'удалена колонка company_id из таблицы %', t;
  END LOOP;
END $$;

-- 3. Удаление самой таблицы ----------------------------------------------------
DROP TABLE IF EXISTS companies;

COMMIT;

-- 4. Контроль ------------------------------------------------------------------
SELECT count(*) AS "осталось колонок company_id (должно быть 0)"
FROM information_schema.columns
WHERE table_schema='public' AND column_name='company_id';

SELECT CASE WHEN to_regclass('public.companies') IS NULL
            THEN 'таблица companies удалена'
            ELSE 'ВНИМАНИЕ: таблица companies всё ещё существует' END
       AS "результат";
