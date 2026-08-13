-- =============================================================================
-- 006 — Индекс под инкрементальную выдачу фонда
-- =============================================================================
-- Приложение опрашивает фонд каждые 15 секунд. Раньше каждый опрос выкачивал
-- весь фонд целиком вместе с историей по каждой квартире; теперь список идёт
-- без истории, а при повторных опросах запрашиваются только изменившиеся
-- квартиры:
--
--   ... WHERE org_id = $1 AND updated_at >= $2 ...
--
-- Без индекса это последовательное сканирование всех квартир компании каждые
-- 15 секунд на каждого подключённого сотрудника.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/006_units_delta.sql
--
-- Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

CREATE INDEX IF NOT EXISTS apartments_org_updated_idx
    ON apartments (org_id, updated_at)
    WHERE deleted_at IS NULL;

-- Контроль
SELECT indexname AS "индекс", tablename AS "таблица"
FROM pg_indexes
WHERE schemaname = 'public' AND indexname = 'apartments_org_updated_idx';
