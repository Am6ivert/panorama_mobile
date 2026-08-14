-- =============================================================================
-- Что на самом деле создано: компании, объекты, блоки и квартиры в них.
--
--   powershell -ExecutionPolicy Bypass -File db\blocks.ps1
--
-- Ничего не меняет, только читает. Нужен, когда интерфейс показывает одно,
-- а ощущение, что в базе другое: здесь видно, есть ли у блока квартиры.
-- =============================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
\pset pager off

\echo ''
\echo '=== Компании и их подписки ==='
SELECT o.code AS "компания", o.name AS "название", o.plan_kind AS "тип",
       to_char(o.plan_until, 'YYYY-MM-DD HH24:MI') AS "оплачено до",
       o.is_blocked AS "приостановлена",
       (SELECT count(*) FROM users u
         WHERE u.org_id = o.id AND u.deleted_at IS NULL) AS "сотрудников",
       (SELECT count(*) FROM apartments a WHERE a.org_id = o.id) AS "квартир"
FROM organizations o
WHERE o.deleted_at IS NULL
ORDER BY o.created_at;

\echo ''
\echo '=== Блоки и квартиры в них ==='
\echo 'Пустой блок (0 квартир) - тот самый случай, который надо объяснить.'
SELECT o.code AS "компания",
       c.name AS "объект",
       b.name AS "блок",
       b.floors AS "этажей",
       b.units_per_floor AS "на этаже",
       count(a.id) AS "квартир создано",
       to_char(b.created_at, 'DD.MM HH24:MI') AS "блок создан"
FROM blocks b
JOIN complexes c ON c.id = b.complex_id
JOIN organizations o ON o.id = b.org_id
LEFT JOIN apartments a ON a.block_id = b.id
WHERE b.deleted_at IS NULL
GROUP BY o.code, c.name, b.name, b.floors, b.units_per_floor, b.created_at
ORDER BY b.created_at;

\echo ''
\echo '=== Запуски мастера массового создания ==='
\echo 'affected_count = 0 или NULL означает, что операция не довела дело до конца.'
SELECT o.code AS "компания", bo.block_name AS "блок",
       bo.affected_count AS "создано квартир",
       to_char(bo.created_at, 'DD.MM HH24:MI:SS') AS "когда"
FROM bulk_operations bo
JOIN organizations o ON o.id = bo.org_id
ORDER BY bo.created_at DESC
LIMIT 20;

\echo ''
\echo '=== Квартиры без блока или с чужой компанией (такого быть не должно) ==='
SELECT count(*) FILTER (WHERE b.id IS NULL)            AS "без блока",
       count(*) FILTER (WHERE b.org_id <> a.org_id)    AS "блок чужой компании",
       count(*) FILTER (WHERE c.org_id <> a.org_id)    AS "объект чужой компании"
FROM apartments a
LEFT JOIN blocks b ON b.id = a.block_id
LEFT JOIN complexes c ON c.id = a.complex_id;
