-- =============================================================================
-- Диагностика: что на самом деле в базе, и чем она отличается от db/schema.sql
--   psql -U panorama -h localhost -d panorama -f db/inspect.sql
-- Ничего не меняет, только читает.
-- =============================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
\pset pager off

\echo ''
\echo '=== 1. Таблицы в базе ==='
SELECT table_name AS "таблица",
       (SELECT count(*) FROM information_schema.columns c
         WHERE c.table_schema='public' AND c.table_name=t.table_name) AS "колонок"
FROM information_schema.tables t
WHERE table_schema='public' AND table_type='BASE TABLE'
ORDER BY table_name;

\echo ''
\echo '=== 2. Все колонки, похожие на признак компании ==='
SELECT table_name AS "таблица", column_name AS "колонка",
       data_type AS "тип", is_nullable AS "null?",
       COALESCE(column_default,'-') AS "по умолчанию"
FROM information_schema.columns
WHERE table_schema='public'
  AND (column_name LIKE '%company%' OR column_name LIKE '%org%'
       OR column_name LIKE '%tenant%')
ORDER BY column_name, table_name;

\echo ''
\echo '=== 3. Полный состав таблицы users (в порядке колонок) ==='
SELECT ordinal_position AS "№", column_name AS "колонка",
       data_type AS "тип", is_nullable AS "null?",
       COALESCE(column_default,'-') AS "по умолчанию"
FROM information_schema.columns
WHERE table_schema='public' AND table_name='users'
ORDER BY ordinal_position;

\echo ''
\echo '=== 4. Содержимое organizations (моя таблица) ==='
SELECT id, code, name FROM organizations ORDER BY code;

\echo ''
\echo '=== 5. Legacy-механизм: таблица companies и её содержимое ==='
SET client_min_messages = notice;
DO $$
DECLARE r record; n int;
BEGIN
  IF to_regclass('public.companies') IS NULL THEN
    RAISE NOTICE 'таблицы companies НЕТ';
  ELSE
    EXECUTE 'SELECT count(*) FROM companies' INTO n;
    RAISE NOTICE 'таблица companies ЕСТЬ, строк: %', n;
    FOR r IN EXECUTE 'SELECT * FROM companies' LOOP
      RAISE NOTICE '  %', r;
    END LOOP;
  END IF;
END $$;

\echo ''
\echo '=== 5b. Сколько РАЗНЫХ company_id в каждой таблице ==='
\echo '(1 - значит компания одна и перенос тривиален; больше 1 - нужен маппинг)'
DO $$
DECLARE t text; n int; nulls int;
BEGIN
  FOR t IN SELECT table_name FROM information_schema.columns
            WHERE table_schema='public' AND column_name='company_id'
            ORDER BY table_name
  LOOP
    EXECUTE format('SELECT count(DISTINCT company_id), count(*) FILTER (WHERE company_id IS NULL) FROM %I', t)
      INTO n, nulls;
    RAISE NOTICE '  %: различных company_id = %, пустых = %', t, n, nulls;
  END LOOP;
END $$;
SET client_min_messages = warning;

\echo ''
\echo '=== 6. Совпадают ли company_id и org_id у пользователей? ==='
SELECT login,
       company_id::text AS "company_id",
       org_id::text     AS "org_id",
       (company_id = org_id) AS "совпадают"
FROM users ORDER BY login;

\echo ''
\echo '=== 7. Какие ещё таблицы имеют company_id и заполнен ли он ==='
SELECT c.table_name AS "таблица"
FROM information_schema.columns c
WHERE c.table_schema='public' AND c.column_name='company_id'
ORDER BY c.table_name;

\echo ''
\echo '=== 8. Внешние ключи, ссылающиеся на companies/organizations ==='
SELECT tc.table_name AS "таблица", tc.constraint_name AS "ограничение",
       ccu.table_name AS "ссылается на"
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
     ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type='FOREIGN KEY'
  AND ccu.table_name IN ('companies','organizations')
ORDER BY tc.table_name;
\echo ''
