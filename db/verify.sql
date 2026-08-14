-- =============================================================================
-- Проверка изоляции данных по компаниям.
--   psql -U panorama -h localhost -d panorama -f db/verify.sql
-- Запускается сам в конце db/migrate.ps1.
-- =============================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

\echo ''
\echo '--- Компании и их данные ---'
SELECT o.code AS "код", o.name AS "компания",
       (SELECT count(*) FROM users      u WHERE u.org_id = o.id) AS "сотрудников",
       (SELECT count(*) FROM complexes  c WHERE c.org_id = o.id) AS "объектов",
       (SELECT count(*) FROM apartments a WHERE a.org_id = o.id) AS "квартир",
       (SELECT count(*) FROM clients    k WHERE k.org_id = o.id) AS "клиентов"
FROM organizations o
WHERE o.deleted_at IS NULL
ORDER BY o.code;

\echo ''
\echo '--- Строк без компании (везде должно быть 0) ---'
SELECT 'users' AS "таблица", count(*) AS "без org_id" FROM users      WHERE org_id IS NULL
UNION ALL SELECT 'complexes',  count(*) FROM complexes  WHERE org_id IS NULL
UNION ALL SELECT 'blocks',     count(*) FROM blocks     WHERE org_id IS NULL
UNION ALL SELECT 'apartments', count(*) FROM apartments WHERE org_id IS NULL
UNION ALL SELECT 'clients',    count(*) FROM clients    WHERE org_id IS NULL
UNION ALL SELECT 'deals',      count(*) FROM deals      WHERE org_id IS NULL
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs WHERE org_id IS NULL;

\echo ''
\echo '--- Составные внешние ключи (должно быть 12) ---'
SELECT count(*) AS "связей внутри компании"
FROM pg_constraint
WHERE contype = 'f' AND conname LIKE '%\_org\_fk' AND array_length(conkey, 1) = 2;

\echo ''
\echo '--- Ссылки между компаниями (везде должно быть 0) ---'
SELECT 'квартира в чужом ЖК' AS "нарушение", count(*) AS "штук"
  FROM apartments a JOIN complexes c ON c.id = a.complex_id WHERE c.org_id <> a.org_id
UNION ALL
SELECT 'квартира в чужом блоке', count(*)
  FROM apartments a JOIN blocks b ON b.id = a.block_id WHERE b.org_id <> a.org_id
UNION ALL
SELECT 'квартиру держит чужой сотрудник', count(*)
  FROM apartments a JOIN users u ON u.id = a.held_by_id WHERE u.org_id <> a.org_id
UNION ALL
SELECT 'клиент у чужого менеджера', count(*)
  FROM clients k JOIN users u ON u.id = k.seller_id WHERE u.org_id <> k.org_id
UNION ALL
SELECT 'сделка по чужой квартире', count(*)
  FROM deals d JOIN apartments a ON a.id = d.apartment_id WHERE a.org_id <> d.org_id;

\echo ''
\echo '--- Legacy-механизм companies (должно быть 0 и "удалена") ---'
SELECT count(*) AS "колонок company_id"
FROM information_schema.columns
WHERE table_schema='public' AND column_name='company_id';
SELECT CASE WHEN to_regclass('public.companies') IS NULL
            THEN 'таблица companies удалена'
            ELSE 'ВНИМАНИЕ: companies ещё существует' END AS "результат";

\echo ''
\echo '--- Токены сессий: 64 hex-символа = SHA-256 (не открытый токен) ---'
SELECT count(*) AS "всего", count(*) FILTER (WHERE length(token_hash) = 64) AS "в виде хеша",
       count(*) FILTER (WHERE revoked_at IS NULL AND expires_at > now()) AS "действующих"
FROM sessions;
\echo ''
