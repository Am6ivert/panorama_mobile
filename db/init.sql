-- =============================================================================
-- Инициализация — запускать СУПЕРПОЛЬЗОВАТЕЛЕМ postgres:
--   psql -U postgres -h localhost -f db/init.sql
-- Создаёт роль приложения, базу и расширение pgcrypto. Идемпотентно.
-- =============================================================================

-- Роль приложения (создаём, только если ещё нет).
SELECT 'CREATE ROLE panorama LOGIN PASSWORD ''panorama'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'panorama')\gexec

-- База (CREATE DATABASE нельзя в транзакции — \gexec выполняет отдельной командой).
SELECT 'CREATE DATABASE panorama OWNER panorama'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'panorama')\gexec

-- Переключаемся в новую базу и готовим её.
\connect panorama

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- для crypt()/gen_salt() в seed.sql
GRANT ALL ON SCHEMA public TO panorama;
ALTER SCHEMA public OWNER TO panorama;
