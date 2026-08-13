-- =============================================================================
-- 004 — Индексы под реально выполняемые запросы
-- =============================================================================
-- Два места, где сервер регулярно читает таблицу без подходящего индекса:
--
--   * devices (user_id) — выбирается при КАЖДОМ push-уведомлении
--     (_pushFcm: SELECT push_token FROM devices WHERE user_id = ...);
--   * apartments (held_until) при status='hold' — проверка истечения броней
--     выполняется раз в минуту по всему фонду (runExpiryChecks).
--
-- На демо-фонде из 96 квартир разницы не видно, но на реальном объекте это
-- превращается в постоянное последовательное сканирование.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/004_indexes.sql
--
-- Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

CREATE INDEX IF NOT EXISTS devices_user_idx ON devices (user_id);

CREATE INDEX IF NOT EXISTS apartments_hold_expiry_idx ON apartments (held_until)
    WHERE status = 'hold' AND deleted_at IS NULL;

-- Контроль
SELECT indexname AS "индекс", tablename AS "таблица"
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('devices_user_idx', 'apartments_hold_expiry_idx')
ORDER BY indexname;
