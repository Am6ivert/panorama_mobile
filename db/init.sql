-- =============================================================================
-- Инициализация — запускать СУПЕРПОЛЬЗОВАТЕЛЕМ postgres:
--   psql -U postgres -h localhost -f db/init.sql
-- Создаёт роль приложения и ПЕРЕСОЗДАЁТ базу начисто (чтобы schema.sql не падал
-- на уже существующих таблицах). ВНИМАНИЕ: существующая база panorama удаляется.
-- =============================================================================

-- Роль приложения (создаём, только если ещё нет).
SELECT 'CREATE ROLE panorama LOGIN PASSWORD ''panorama'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'panorama')\gexec

-- Пересоздаём базу начисто. WITH (FORCE) закрывает чужие подключения (PG 13+).
DROP DATABASE IF EXISTS panorama WITH (FORCE);
CREATE DATABASE panorama OWNER panorama;

-- Переключаемся в новую базу и готовим её.
\connect panorama

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- для crypt()/gen_salt() в seed.sql
GRANT ALL ON SCHEMA public TO panorama;
ALTER SCHEMA public OWNER TO panorama;
