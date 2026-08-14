-- =============================================================================
-- 007 — Настройки становятся пер-компанийными
-- =============================================================================
-- В settings лежат лимиты (booking_limit, work_limit) и срок брони по
-- умолчанию, но сервер их не читал: значения были зашиты в код числом 5.
--
-- Просто начать читать глобальную таблицу нельзя: компаний в базе несколько,
-- и лимиты у разных застройщиков разные. Поэтому ключ становится составным:
-- (org_id, key).
--
-- Существующие глобальные строки размножаются на каждую компанию, так что
-- текущее поведение не меняется.
--
-- Накатывать:
--   psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 \
--        -f db/migrations/007_settings_per_org.sql
--
-- Идемпотентна: повторный запуск безопасен.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- 1. Колонка и снятие старого первичного ключа -------------------------------
ALTER TABLE settings ADD COLUMN IF NOT EXISTS org_id uuid;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint
              WHERE conname = 'settings_pkey' AND conrelid = 'settings'::regclass
                AND array_length(conkey, 1) = 1) THEN
    ALTER TABLE settings DROP CONSTRAINT settings_pkey;
  END IF;
END $$;

-- 2. Копируем глобальные значения каждой компании ----------------------------
--    Первичного ключа сейчас нет, поэтому временные дубликаты допустимы.
INSERT INTO settings (org_id, key, value)
SELECT o.id, s.key, s.value
FROM organizations o
CROSS JOIN (SELECT key, value FROM settings WHERE org_id IS NULL) s
WHERE NOT EXISTS (
    SELECT 1 FROM settings x WHERE x.org_id = o.id AND x.key = s.key
);

DELETE FROM settings WHERE org_id IS NULL;

-- 3. Если компания появилась без настроек — добиваем значениями по умолчанию --
INSERT INTO settings (org_id, key, value)
SELECT o.id, d.key, d.value
FROM organizations o
CROSS JOIN (VALUES
    ('booking_days',       '3'),
    ('booking_limit',      '5'),
    ('work_limit',         '5'),
    ('min_client_version', '1.0.0')
) AS d(key, value)
WHERE NOT EXISTS (
    SELECT 1 FROM settings x WHERE x.org_id = o.id AND x.key = d.key
);

-- 4. Ограничения --------------------------------------------------------------
ALTER TABLE settings ALTER COLUMN org_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'settings_pkey' AND conrelid = 'settings'::regclass) THEN
    ALTER TABLE settings ADD CONSTRAINT settings_pkey PRIMARY KEY (org_id, key);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'settings_org_fk') THEN
    ALTER TABLE settings ADD CONSTRAINT settings_org_fk
      FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE RESTRICT;
  END IF;
END $$;

COMMIT;

-- Контроль: у каждой компании должен быть полный набор настроек
SELECT o.code AS "компания", count(s.key) AS "настроек"
FROM organizations o
LEFT JOIN settings s ON s.org_id = o.id
WHERE o.deleted_at IS NULL
GROUP BY o.code
ORDER BY o.code;
