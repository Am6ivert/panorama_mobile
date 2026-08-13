-- =============================================================================
-- 005 — Цвет обложки объекта не помещался в integer
-- =============================================================================
-- Сервер подставляет ARGB-цвета вида 0xFF1E3A8A. Альфа 0xFF выставляет старший
-- бит, поэтому число получается больше 2^31-1:
--
--   0xFF1E3A8A = 4 280 171 146,  максимум integer = 2 147 483 647
--
-- Колонки cover_start / cover_end были integer, и КАЖДОЕ создание объекта
-- падало с ошибкой 22003 «значение вне диапазона для типа integer».
-- Незаметно это было только потому, что seed.sql создаёт объект без обложки.
--
-- Приложение читает цвет как число (num.toInt()), поэтому bigint оно принимает
-- без изменений.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/005_cover_bigint.sql
--
-- Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

ALTER TABLE complexes
    ALTER COLUMN cover_start TYPE bigint,
    ALTER COLUMN cover_end   TYPE bigint;

-- Контроль: обе колонки должны стать bigint
SELECT column_name AS "колонка", data_type AS "тип"
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'complexes'
  AND column_name IN ('cover_start', 'cover_end')
ORDER BY column_name;
