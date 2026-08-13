-- =============================================================================
-- СГЕНЕРИРОВАНО из db/schema.sql скриптом db/tools/gen_drift.py.
-- Руками не править: правка потеряется при следующей пересборке.
--
-- Сверяет фактическую базу с тем, что описано в репозитории: таблицы, колонки,
-- индексы и именованные ограничения.
--
--   psql -U panorama -h localhost -d panorama -f db/drift.sql
--
-- Все восемь разделов пусты - база совпадает с репозиторием.
-- =============================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
\pset pager off

-- Без ON COMMIT DROP: psql выполняет файл без явной транзакции, и таблица
-- удалялась бы сразу после CREATE, до первого INSERT. Временные таблицы и так
-- живут только внутри сессии.
CREATE TEMP TABLE expected(table_name text, column_name text, is_nullable text,
                           has_default boolean, data_type text);
INSERT INTO expected VALUES
  ('apartment_status_history','apartment_id','NO',false,'uuid'),
  ('apartment_status_history','at','NO',true,'timestamp with time zone'),
  ('apartment_status_history','changed_by','YES',false,'uuid'),
  ('apartment_status_history','client_id','YES',false,'uuid'),
  ('apartment_status_history','comment','YES',false,'text'),
  ('apartment_status_history','from_status','YES',false,'text'),
  ('apartment_status_history','id','NO',true,'uuid'),
  ('apartment_status_history','to_status','NO',false,'text'),
  ('apartments','area','NO',false,'numeric'),
  ('apartments','bathrooms','NO',true,'integer'),
  ('apartments','block_id','NO',false,'uuid'),
  ('apartments','client_id','YES',false,'uuid'),
  ('apartments','complex_id','NO',false,'uuid'),
  ('apartments','created_at','NO',true,'timestamp with time zone'),
  ('apartments','created_by','YES',false,'uuid'),
  ('apartments','deleted_at','YES',false,'timestamp with time zone'),
  ('apartments','finish','YES',false,'text'),
  ('apartments','floor','NO',false,'integer'),
  ('apartments','held_by_id','YES',false,'uuid'),
  ('apartments','held_until','YES',false,'timestamp with time zone'),
  ('apartments','id','NO',true,'uuid'),
  ('apartments','kitchen','YES',false,'text'),
  ('apartments','number','NO',false,'integer'),
  ('apartments','org_id','NO',false,'uuid'),
  ('apartments','position','NO',false,'integer'),
  ('apartments','rooms','NO',false,'integer'),
  ('apartments','status','NO',true,'text'),
  ('apartments','updated_at','NO',true,'timestamp with time zone'),
  ('apartments','updated_by','YES',false,'uuid'),
  ('apartments','version','NO',true,'integer'),
  ('apartments','view','YES',false,'text'),
  ('audit_logs','action','NO',false,'text'),
  ('audit_logs','after','YES',false,'jsonb'),
  ('audit_logs','at','NO',true,'timestamp with time zone'),
  ('audit_logs','before','YES',false,'jsonb'),
  ('audit_logs','entity_id','YES',false,'text'),
  ('audit_logs','entity_type','YES',false,'text'),
  ('audit_logs','id','NO',true,'bigint'),
  ('audit_logs','ip','YES',false,'inet'),
  ('audit_logs','org_id','NO',false,'uuid'),
  ('audit_logs','user_id','YES',false,'uuid'),
  ('blocks','complex_id','NO',false,'uuid'),
  ('blocks','created_at','NO',true,'timestamp with time zone'),
  ('blocks','created_by','YES',false,'uuid'),
  ('blocks','deleted_at','YES',false,'timestamp with time zone'),
  ('blocks','floors','NO',false,'integer'),
  ('blocks','id','NO',true,'uuid'),
  ('blocks','name','NO',false,'text'),
  ('blocks','org_id','NO',false,'uuid'),
  ('blocks','units_per_floor','NO',false,'integer'),
  ('blocks','updated_at','NO',true,'timestamp with time zone'),
  ('blocks','updated_by','YES',false,'uuid'),
  ('blocks','version','NO',true,'integer'),
  ('bulk_operations','affected_count','NO',true,'integer'),
  ('bulk_operations','block_name','YES',false,'text'),
  ('bulk_operations','complex_id','YES',false,'uuid'),
  ('bulk_operations','created_at','NO',true,'timestamp with time zone'),
  ('bulk_operations','created_by','YES',false,'uuid'),
  ('bulk_operations','id','NO',true,'uuid'),
  ('bulk_operations','idempotency_key','NO',false,'text'),
  ('bulk_operations','org_id','NO',false,'uuid'),
  ('bulk_operations','params','NO',false,'jsonb'),
  ('clients','created_at','NO',true,'timestamp with time zone'),
  ('clients','created_by','YES',false,'uuid'),
  ('clients','deleted_at','YES',false,'timestamp with time zone'),
  ('clients','full_name','NO',false,'text'),
  ('clients','id','NO',true,'uuid'),
  ('clients','next_action_at','YES',false,'timestamp with time zone'),
  ('clients','note','YES',false,'text'),
  ('clients','org_id','NO',false,'uuid'),
  ('clients','phone','NO',false,'text'),
  ('clients','request','YES',false,'text'),
  ('clients','rooms','YES',false,'integer'),
  ('clients','seller_id','NO',false,'uuid'),
  ('clients','source','YES',false,'text'),
  ('clients','stage','NO',true,'text'),
  ('clients','updated_at','NO',true,'timestamp with time zone'),
  ('clients','updated_by','YES',false,'uuid'),
  ('clients','version','NO',true,'integer'),
  ('complexes','address','NO',false,'text'),
  ('complexes','cover_end','YES',false,'bigint'),
  ('complexes','cover_start','YES',false,'bigint'),
  ('complexes','created_at','NO',true,'timestamp with time zone'),
  ('complexes','created_by','YES',false,'uuid'),
  ('complexes','deadline','YES',false,'text'),
  ('complexes','deleted_at','YES',false,'timestamp with time zone'),
  ('complexes','id','NO',true,'uuid'),
  ('complexes','name','NO',false,'text'),
  ('complexes','org_id','NO',false,'uuid'),
  ('complexes','segment','YES',false,'text'),
  ('complexes','updated_at','NO',true,'timestamp with time zone'),
  ('complexes','updated_by','YES',false,'uuid'),
  ('complexes','version','NO',true,'integer'),
  ('deal_stage_history','at','NO',true,'timestamp with time zone'),
  ('deal_stage_history','changed_by','YES',false,'uuid'),
  ('deal_stage_history','deal_id','NO',false,'uuid'),
  ('deal_stage_history','from_stage','YES',false,'text'),
  ('deal_stage_history','id','NO',true,'uuid'),
  ('deal_stage_history','to_stage','NO',false,'text'),
  ('deals','apartment_id','NO',false,'uuid'),
  ('deals','client_id','NO',false,'uuid'),
  ('deals','created_at','NO',true,'timestamp with time zone'),
  ('deals','created_by','YES',false,'uuid'),
  ('deals','deleted_at','YES',false,'timestamp with time zone'),
  ('deals','id','NO',true,'uuid'),
  ('deals','next_action_at','YES',false,'timestamp with time zone'),
  ('deals','org_id','NO',false,'uuid'),
  ('deals','seller_id','NO',false,'uuid'),
  ('deals','stage','NO',true,'text'),
  ('deals','updated_at','NO',true,'timestamp with time zone'),
  ('deals','updated_by','YES',false,'uuid'),
  ('deals','version','NO',true,'integer'),
  ('devices','created_at','NO',true,'timestamp with time zone'),
  ('devices','id','NO',true,'uuid'),
  ('devices','platform','NO',false,'text'),
  ('devices','push_token','NO',false,'text'),
  ('devices','updated_at','NO',true,'timestamp with time zone'),
  ('devices','user_id','NO',false,'uuid'),
  ('dictionaries','code','NO',false,'text'),
  ('dictionaries','group','NO',false,'text'),
  ('dictionaries','id','NO',true,'uuid'),
  ('dictionaries','sort','NO',true,'integer'),
  ('dictionaries','title','NO',false,'text'),
  ('files','apartment_id','YES',false,'uuid'),
  ('files','complex_id','YES',false,'uuid'),
  ('files','created_at','NO',true,'timestamp with time zone'),
  ('files','created_by','YES',false,'uuid'),
  ('files','deleted_at','YES',false,'timestamp with time zone'),
  ('files','id','NO',true,'uuid'),
  ('files','kind','NO',false,'text'),
  ('files','org_id','NO',false,'uuid'),
  ('files','thumb_url','YES',false,'text'),
  ('files','updated_at','NO',true,'timestamp with time zone'),
  ('files','updated_by','YES',false,'uuid'),
  ('files','url','NO',false,'text'),
  ('files','version','NO',true,'integer'),
  ('notifications','apartment_id','YES',false,'uuid'),
  ('notifications','body','NO',false,'text'),
  ('notifications','created_at','NO',true,'timestamp with time zone'),
  ('notifications','id','NO',true,'uuid'),
  ('notifications','kind','NO',false,'text'),
  ('notifications','read_at','YES',false,'timestamp with time zone'),
  ('notifications','recipient_id','NO',false,'uuid'),
  ('notifications','title','NO',false,'text'),
  ('organizations','code','NO',false,'text'),
  ('organizations','created_at','NO',true,'timestamp with time zone'),
  ('organizations','deleted_at','YES',false,'timestamp with time zone'),
  ('organizations','id','NO',true,'uuid'),
  ('organizations','name','NO',false,'text'),
  ('organizations','updated_at','NO',true,'timestamp with time zone'),
  ('reservations','apartment_id','NO',false,'uuid'),
  ('reservations','client_id','NO',false,'uuid'),
  ('reservations','created_at','NO',true,'timestamp with time zone'),
  ('reservations','created_by','YES',false,'uuid'),
  ('reservations','deleted_at','YES',false,'timestamp with time zone'),
  ('reservations','expires_at','NO',false,'timestamp with time zone'),
  ('reservations','id','NO',true,'uuid'),
  ('reservations','manager_id','NO',false,'uuid'),
  ('reservations','org_id','NO',false,'uuid'),
  ('reservations','released_at','YES',false,'timestamp with time zone'),
  ('reservations','released_reason','YES',false,'text'),
  ('reservations','updated_at','NO',true,'timestamp with time zone'),
  ('reservations','updated_by','YES',false,'uuid'),
  ('reservations','version','NO',true,'integer'),
  ('roles','code','NO',false,'text'),
  ('roles','title','NO',false,'text'),
  ('sessions','created_at','NO',true,'timestamp with time zone'),
  ('sessions','expires_at','NO',false,'timestamp with time zone'),
  ('sessions','id','NO',true,'uuid'),
  ('sessions','ip','YES',false,'inet'),
  ('sessions','revoked_at','YES',false,'timestamp with time zone'),
  ('sessions','token_hash','NO',false,'text'),
  ('sessions','user_id','NO',false,'uuid'),
  ('settings','key','NO',false,'text'),
  ('settings','org_id','NO',false,'uuid'),
  ('settings','updated_at','NO',true,'timestamp with time zone'),
  ('settings','updated_by','YES',false,'uuid'),
  ('settings','value','NO',false,'text'),
  ('user_roles','role_code','NO',false,'text'),
  ('user_roles','user_id','NO',false,'uuid'),
  ('users','blocked','NO',true,'boolean'),
  ('users','created_at','NO',true,'timestamp with time zone'),
  ('users','created_by','YES',false,'uuid'),
  ('users','deleted_at','YES',false,'timestamp with time zone'),
  ('users','full_name','NO',false,'text'),
  ('users','id','NO',true,'uuid'),
  ('users','login','NO',false,'text'),
  ('users','must_change_password','NO',true,'boolean'),
  ('users','org_id','NO',false,'uuid'),
  ('users','password_hash','NO',false,'text'),
  ('users','phone','NO',false,'text'),
  ('users','updated_at','NO',true,'timestamp with time zone'),
  ('users','updated_by','YES',false,'uuid'),
  ('users','version','NO',true,'integer');

CREATE TEMP TABLE expected_idx(index_name text, table_name text);
INSERT INTO expected_idx VALUES
  ('apartment_status_history_pkey','apartment_status_history'),
  ('apartments_grid_idx','apartments'),
  ('apartments_held_idx','apartments'),
  ('apartments_hold_expiry_idx','apartments'),
  ('apartments_id_org_uniq','apartments'),
  ('apartments_number_uniq','apartments'),
  ('apartments_org_idx','apartments'),
  ('apartments_org_updated_idx','apartments'),
  ('apartments_pkey','apartments'),
  ('apartments_status_idx','apartments'),
  ('apt_status_hist_idx','apartment_status_history'),
  ('audit_logs_at_idx','audit_logs'),
  ('audit_logs_pkey','audit_logs'),
  ('audit_logs_user_idx','audit_logs'),
  ('blocks_id_org_uniq','blocks'),
  ('blocks_name_uniq','blocks'),
  ('blocks_pkey','blocks'),
  ('bulk_idempotency_uniq','bulk_operations'),
  ('bulk_operations_pkey','bulk_operations'),
  ('clients_id_org_uniq','clients'),
  ('clients_org_idx','clients'),
  ('clients_pkey','clients'),
  ('clients_seller_idx','clients'),
  ('clients_seller_phone_uniq','clients'),
  ('complexes_id_org_uniq','complexes'),
  ('complexes_org_idx','complexes'),
  ('complexes_pkey','complexes'),
  ('deal_stage_history_pkey','deal_stage_history'),
  ('deals_active_apartment_uniq','deals'),
  ('deals_id_org_uniq','deals'),
  ('deals_org_idx','deals'),
  ('deals_pkey','deals'),
  ('deals_seller_stage_idx','deals'),
  ('devices_pkey','devices'),
  ('devices_token_uniq','devices'),
  ('devices_user_idx','devices'),
  ('dictionaries_group_code_key','dictionaries'),
  ('dictionaries_pkey','dictionaries'),
  ('files_pkey','files'),
  ('notifications_inbox_idx','notifications'),
  ('notifications_pkey','notifications'),
  ('notifications_unread_idx','notifications'),
  ('organizations_code_uniq','organizations'),
  ('organizations_pkey','organizations'),
  ('reservations_active_uniq','reservations'),
  ('reservations_expires_idx','reservations'),
  ('reservations_pkey','reservations'),
  ('roles_pkey','roles'),
  ('sessions_pkey','sessions'),
  ('sessions_token_hash_uniq','sessions'),
  ('sessions_user_idx','sessions'),
  ('settings_pkey','settings'),
  ('user_roles_pkey','user_roles'),
  ('users_id_org_uniq','users'),
  ('users_login_uniq','users'),
  ('users_org_idx','users'),
  ('users_phone_uniq','users'),
  ('users_pkey','users');

CREATE TEMP TABLE expected_con(con_name text, table_name text);
INSERT INTO expected_con VALUES
  ('apartments_block_id_org_fk','apartments'),
  ('apartments_client_id_org_fk','apartments'),
  ('apartments_complex_id_org_fk','apartments'),
  ('apartments_held_by_id_org_fk','apartments'),
  ('apartments_id_org_uniq','apartments'),
  ('apartments_org_fk','apartments'),
  ('audit_logs_org_fk','audit_logs'),
  ('blocks_complex_id_org_fk','blocks'),
  ('blocks_id_org_uniq','blocks'),
  ('blocks_org_fk','blocks'),
  ('bulk_operations_org_fk','bulk_operations'),
  ('clients_id_org_uniq','clients'),
  ('clients_org_fk','clients'),
  ('clients_seller_id_org_fk','clients'),
  ('complexes_id_org_uniq','complexes'),
  ('complexes_org_fk','complexes'),
  ('deals_apartment_id_org_fk','deals'),
  ('deals_client_id_org_fk','deals'),
  ('deals_id_org_uniq','deals'),
  ('deals_org_fk','deals'),
  ('deals_seller_id_org_fk','deals'),
  ('files_org_fk','files'),
  ('reservations_apartment_id_org_fk','reservations'),
  ('reservations_client_id_org_fk','reservations'),
  ('reservations_manager_id_org_fk','reservations'),
  ('reservations_org_fk','reservations'),
  ('settings_org_fk','settings'),
  ('settings_pkey','settings'),
  ('users_id_org_uniq','users'),
  ('users_org_fk','users');

CREATE TEMP VIEW actual AS
SELECT table_name, column_name, is_nullable,
       (column_default IS NOT NULL) AS has_default, data_type
FROM information_schema.columns WHERE table_schema='public';

\echo ''
\echo '=== 1. Таблицы в базе, которых нет в репозитории ==='
SELECT table_name AS "лишняя таблица"
FROM information_schema.tables
WHERE table_schema='public' AND table_type='BASE TABLE'
  AND table_name NOT IN (SELECT DISTINCT table_name FROM expected)
ORDER BY 1;

\echo ''
\echo '=== 2. Таблицы из репозитория, которых нет в базе ==='
SELECT DISTINCT e.table_name AS "недостающая таблица" FROM expected e
WHERE e.table_name NOT IN (SELECT table_name FROM information_schema.tables
                            WHERE table_schema='public' AND table_type='BASE TABLE')
ORDER BY 1;

\echo ''
\echo '=== 3. Лишние колонки в базе ==='
SELECT a.table_name AS "таблица", a.column_name AS "лишняя колонка", a.data_type AS "тип"
FROM actual a
WHERE a.table_name IN (SELECT DISTINCT table_name FROM expected)
  AND NOT EXISTS (SELECT 1 FROM expected e
                   WHERE e.table_name=a.table_name AND e.column_name=a.column_name)
ORDER BY 1,2;

\echo ''
\echo '=== 4. Недостающие колонки в базе ==='
SELECT e.table_name AS "таблица", e.column_name AS "недостающая колонка", e.data_type AS "тип"
FROM expected e
WHERE e.table_name IN (SELECT table_name FROM information_schema.tables WHERE table_schema='public')
  AND NOT EXISTS (SELECT 1 FROM actual a
                   WHERE a.table_name=e.table_name AND a.column_name=e.column_name)
ORDER BY 1,2;

\echo ''
\echo '=== 5. Колонки отличаются (NOT NULL / DEFAULT / тип) ==='
SELECT e.table_name AS "таблица", e.column_name AS "колонка",
       e.is_nullable || ' -> ' || a.is_nullable AS "null: ждём -> есть",
       e.has_default::text || ' -> ' || a.has_default::text AS "default: ждём -> есть",
       e.data_type || ' -> ' || a.data_type AS "тип: ждём -> есть"
FROM expected e JOIN actual a
  ON a.table_name=e.table_name AND a.column_name=e.column_name
WHERE e.is_nullable IS DISTINCT FROM a.is_nullable
   OR e.has_default IS DISTINCT FROM a.has_default
   OR e.data_type   IS DISTINCT FROM a.data_type
ORDER BY 1,2;

\echo ''
\echo '=== 6. Недостающие индексы ==='
SELECT e.index_name AS "нет индекса", e.table_name AS "таблица"
FROM expected_idx e
WHERE NOT EXISTS (SELECT 1 FROM pg_indexes i
                   WHERE i.schemaname='public' AND i.indexname=e.index_name)
ORDER BY 1;

\echo ''
\echo '=== 7. Лишние индексы в базе ==='
SELECT i.indexname AS "лишний индекс", i.tablename AS "таблица"
FROM pg_indexes i
WHERE i.schemaname='public'
  AND i.tablename IN (SELECT DISTINCT table_name FROM expected)
  AND i.indexname NOT IN (SELECT index_name FROM expected_idx)
ORDER BY 1;

\echo ''
\echo '=== 8. Недостающие именованные ограничения ==='
SELECT e.con_name AS "нет ограничения", e.table_name AS "таблица"
FROM expected_con e
WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = e.con_name)
ORDER BY 1;

\echo ''
\echo '=== ИТОГ ==='
SET client_min_messages = notice;
DO $$
DECLARE total int := 0; n int;
BEGIN
  SELECT count(*) INTO n FROM information_schema.tables
   WHERE table_schema='public' AND table_type='BASE TABLE'
     AND table_name NOT IN (SELECT DISTINCT table_name FROM expected);
  total := total + n;

  SELECT count(DISTINCT e.table_name) INTO n FROM expected e
   WHERE e.table_name NOT IN (SELECT table_name FROM information_schema.tables
                               WHERE table_schema='public' AND table_type='BASE TABLE');
  total := total + n;

  SELECT count(*) INTO n FROM actual a
   WHERE a.table_name IN (SELECT DISTINCT table_name FROM expected)
     AND NOT EXISTS (SELECT 1 FROM expected e
                      WHERE e.table_name=a.table_name AND e.column_name=a.column_name);
  total := total + n;

  SELECT count(*) INTO n FROM expected e
   WHERE e.table_name IN (SELECT table_name FROM information_schema.tables
                           WHERE table_schema='public')
     AND NOT EXISTS (SELECT 1 FROM actual a
                      WHERE a.table_name=e.table_name AND a.column_name=e.column_name);
  total := total + n;

  SELECT count(*) INTO n FROM expected e JOIN actual a
    ON a.table_name=e.table_name AND a.column_name=e.column_name
   WHERE e.is_nullable IS DISTINCT FROM a.is_nullable
      OR e.has_default IS DISTINCT FROM a.has_default
      OR e.data_type   IS DISTINCT FROM a.data_type;
  total := total + n;

  SELECT count(*) INTO n FROM expected_idx e
   WHERE NOT EXISTS (SELECT 1 FROM pg_indexes i
                      WHERE i.schemaname='public' AND i.indexname=e.index_name);
  total := total + n;

  SELECT count(*) INTO n FROM pg_indexes i
   WHERE i.schemaname='public'
     AND i.tablename IN (SELECT DISTINCT table_name FROM expected)
     AND i.indexname NOT IN (SELECT index_name FROM expected_idx);
  total := total + n;

  SELECT count(*) INTO n FROM expected_con e
   WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = e.con_name);
  total := total + n;

  IF total > 0 THEN
    -- Ненулевой код возврата нужен, чтобы расхождение ловил check_all.ps1.
    RAISE EXCEPTION 'Расхождений со схемой репозитория: % (подробности в разделах выше)', total;
  END IF;
  RAISE NOTICE 'Расхождений нет: база совпадает с репозиторием.';
END $$;
\echo ''
