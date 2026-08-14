-- =============================================================================
-- 002 — Изоляция данных по компаниям (мультиарендность)
-- =============================================================================
-- Появляется таблица organizations и колонка org_id во всех прикладных
-- таблицах. Составные внешние ключи (id, org_id) физически запрещают связать
-- сущности разных компаний: квартиру нельзя привязать к чужому ЖК, клиента —
-- к чужому менеджеру, сделку — к чужой квартире.
--
-- Все существующие данные переносятся в одну компанию — её код задаётся
-- переменными ниже (по умолчанию panorama / «Панорама»).
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 ^
--        -f db/migrations/002_multi_tenant.sql
--
-- Своё название компании:
--   psql ... -v org_code=elitstroy -v org_name=ElitStroy -f ...
--
-- ВНИМАНИЕ: в Windows PowerShell 5.1 аргументы внешних программ кодируются в
-- ANSI, а psql здесь работает в UTF-8 — кириллица в -v приедет мусором
-- («неверный многобайтный символ»). Если название нужно на русском, задайте
-- его потом запросом:
--   UPDATE organizations SET name = 'ЭлитСтрой' WHERE code = 'elitstroy';
--
-- Требует накатанной миграции 001. Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?org_code}
\else
  \set org_code 'panorama'
\endif
\if :{?org_name}
\else
  \set org_name 'Панорама'
\endif

-- Без этого psql печатает десятки NOTICE вида
-- "ограничение ... не существует, пропускается" от DROP IF EXISTS.
SET client_min_messages = warning;

BEGIN;

-- 1. Таблица компаний ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code        text NOT NULL,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS organizations_code_uniq
    ON organizations (lower(code)) WHERE deleted_at IS NULL;

INSERT INTO organizations (code, name)
SELECT :'org_code', :'org_name'
WHERE NOT EXISTS (
    SELECT 1 FROM organizations WHERE lower(code) = lower(:'org_code')
                                 AND deleted_at IS NULL
);

-- 2. Колонки org_id (сначала nullable, чтобы заполнить существующие строки) ----
ALTER TABLE users           ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE complexes       ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE blocks          ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE clients         ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE apartments      ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE files           ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE deals           ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE reservations    ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE bulk_operations ADD COLUMN IF NOT EXISTS org_id uuid;
ALTER TABLE audit_logs      ADD COLUMN IF NOT EXISTS org_id uuid;

-- 3. Все существующие данные — в компанию по умолчанию ------------------------
UPDATE users           SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND users.org_id           IS NULL;
UPDATE complexes       SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND complexes.org_id       IS NULL;
UPDATE blocks          SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND blocks.org_id          IS NULL;
UPDATE clients         SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND clients.org_id         IS NULL;
UPDATE apartments      SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND apartments.org_id      IS NULL;
UPDATE files           SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND files.org_id           IS NULL;
UPDATE deals           SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND deals.org_id           IS NULL;
UPDATE reservations    SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND reservations.org_id    IS NULL;
UPDATE bulk_operations SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND bulk_operations.org_id IS NULL;
UPDATE audit_logs      SET org_id = o.id FROM organizations o
    WHERE lower(o.code) = lower(:'org_code') AND audit_logs.org_id      IS NULL;

-- 4. NOT NULL + ссылка на компанию -------------------------------------------
ALTER TABLE users           ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE complexes       ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE blocks          ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE clients         ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE apartments      ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE files           ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE deals           ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE reservations    ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE bulk_operations ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE audit_logs      ALTER COLUMN org_id SET NOT NULL;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['users','complexes','blocks','clients','apartments',
                           'files','deals','reservations','bulk_operations',
                           'audit_logs']
  LOOP
    EXECUTE format(
      'ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', t, t || '_org_fk');
    EXECUTE format(
      'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (org_id)
         REFERENCES organizations(id) ON DELETE RESTRICT', t, t || '_org_fk');
  END LOOP;
END $$;

-- 5. Мишени для составных внешних ключей --------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['users','complexes','blocks','clients','apartments','deals']
  LOOP
    EXECUTE format(
      'ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I', t, t || '_id_org_uniq');
    EXECUTE format(
      'ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (id, org_id)', t, t || '_id_org_uniq');
  END LOOP;
END $$;

-- 6. «Связывать можно только внутри своей компании» ---------------------------
-- Для nullable-колонок (held_by_id, client_id) проверка включается только
-- когда значение задано — это поведение MATCH SIMPLE, оно нам и нужно.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('blocks',       'complex_id',   'complexes'),
      ('clients',      'seller_id',    'users'),
      ('apartments',   'block_id',     'blocks'),
      ('apartments',   'complex_id',   'complexes'),
      ('apartments',   'held_by_id',   'users'),
      ('apartments',   'client_id',    'clients'),
      ('deals',        'client_id',    'clients'),
      ('deals',        'apartment_id', 'apartments'),
      ('deals',        'seller_id',    'users'),
      ('reservations', 'apartment_id', 'apartments'),
      ('reservations', 'client_id',    'clients'),
      ('reservations', 'manager_id',   'users')
    ) AS v(child, col, parent)
  LOOP
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I',
                   r.child, r.child || '_' || r.col || '_org_fk');
    EXECUTE format(
      'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I, org_id)
         REFERENCES %I (id, org_id) ON DELETE RESTRICT',
      r.child, r.child || '_' || r.col || '_org_fk', r.col, r.parent);
  END LOOP;
END $$;

-- 7. Индексы под фильтр по компании -------------------------------------------
CREATE INDEX IF NOT EXISTS users_org_idx      ON users      (org_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS complexes_org_idx  ON complexes  (org_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS clients_org_idx    ON clients    (org_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS apartments_org_idx ON apartments (org_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS deals_org_idx      ON deals      (org_id) WHERE deleted_at IS NULL;

DROP INDEX IF EXISTS audit_logs_at_idx;
CREATE INDEX audit_logs_at_idx ON audit_logs (org_id, at DESC);

COMMIT;

-- Проверка:
--   SELECT code, name FROM organizations;
--   SELECT count(*) FROM apartments WHERE org_id IS NULL;   -- ожидаем 0
--   SELECT o.code, count(u.id) FROM organizations o
--     LEFT JOIN users u ON u.org_id = o.id GROUP BY o.code;
