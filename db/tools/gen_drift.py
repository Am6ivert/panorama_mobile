#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Пересобирает db/drift.sql из db/schema.sql.

drift.sql — сгенерированный файл: он сверяет фактическую базу с тем, что
описано в репозитории (таблицы, колонки, индексы, именованные ограничения).
Руками его не правят, иначе правка потеряется при следующей пересборке.

Запуск после любого изменения схемы (из корня проекта):

    pip install pglast
    python db/tools/gen_drift.py

Требует pglast — это настоящий парсер PostgreSQL, поэтому эталон берётся из
разобранного дерева, а не из регулярных выражений.
"""
import io
import os
import sys

try:
    import pglast
    from pglast import ast, enums
except ImportError:
    sys.exit('Нужен пакет pglast:  pip install pglast')

CT = enums.parsenodes.ConstrType

# Типы приводим к тому виду, в котором их отдаёт information_schema.
TYPE_MAP = {
    'int4': 'integer', 'int8': 'bigint', 'int2': 'smallint', 'bool': 'boolean',
    'timestamptz': 'timestamp with time zone',
    'timestamp': 'timestamp without time zone',
    'text': 'text', 'uuid': 'uuid', 'numeric': 'numeric', 'jsonb': 'jsonb',
    'inet': 'inet', 'serial8': 'bigint', 'bigserial': 'bigint',
    'serial4': 'integer', 'varchar': 'character varying', 'date': 'date',
    'float8': 'double precision',
}
AUTO_DEFAULT = {'bigserial', 'serial8', 'serial4', 'serial'}

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCHEMA = os.path.join(ROOT, 'db', 'schema.sql')
TARGET = os.path.join(ROOT, 'db', 'drift.sql')


def collect(schema_sql):
    """Возвращает ожидаемые колонки, индексы и именованные ограничения."""
    columns, indexes, constraints = [], set(), set()
    for statement in pglast.parse_sql(schema_sql):
        node = statement.stmt
        if isinstance(node, ast.CreateStmt):
            table = node.relation.relname
            for element in (node.tableElts or []):
                if isinstance(element, ast.ColumnDef):
                    kinds = [c.contype for c in (element.constraints or [])]
                    not_null = CT.CONSTR_NOTNULL in kinds or CT.CONSTR_PRIMARY in kinds
                    has_default = CT.CONSTR_DEFAULT in kinds
                    raw = [x.sval for x in element.typeName.names
                           if isinstance(x, ast.String)][-1]
                    if raw in AUTO_DEFAULT:
                        has_default = True
                    columns.append((table, element.colname,
                                    'NO' if not_null else 'YES',
                                    'true' if has_default else 'false',
                                    TYPE_MAP.get(raw, raw)))
                    if CT.CONSTR_PRIMARY in kinds:
                        indexes.add((table + '_pkey', table))
                    for c in (element.constraints or []):
                        if c.conname:
                            constraints.add((c.conname, table))
                elif isinstance(element, ast.Constraint):
                    if element.contype == CT.CONSTR_PRIMARY:
                        indexes.add((table + '_pkey', table))
                    if element.conname:
                        constraints.add((element.conname, table))
                        if element.contype in (CT.CONSTR_UNIQUE, CT.CONSTR_PRIMARY):
                            indexes.add((element.conname, table))
                    elif element.contype == CT.CONSTR_UNIQUE:
                        # UNIQUE без имени: PostgreSQL сам создаёт индекс
                        # <таблица>_<колонки>_key. Без этого он попадал в
                        # раздел «лишние индексы».
                        cols = [k.sval for k in (element.keys or [])]
                        indexes.add(('_'.join([table] + cols + ['key']), table))
        elif isinstance(node, ast.IndexStmt):
            indexes.add((node.idxname, node.relation.relname))
    return columns, indexes, constraints


def quote(value):
    return "'" + value.replace("'", "''") + "'"


HEADER = """\
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
\\set ON_ERROR_STOP on
SET client_min_messages = warning;
\\pset pager off

-- Без ON COMMIT DROP: psql выполняет файл без явной транзакции, и таблица
-- удалялась бы сразу после CREATE, до первого INSERT. Временные таблицы и так
-- живут только внутри сессии.
CREATE TEMP TABLE expected(table_name text, column_name text, is_nullable text,
                           has_default boolean, data_type text);
INSERT INTO expected VALUES
  %s;

CREATE TEMP TABLE expected_idx(index_name text, table_name text);
INSERT INTO expected_idx VALUES
  %s;

CREATE TEMP TABLE expected_con(con_name text, table_name text);
INSERT INTO expected_con VALUES
  %s;

CREATE TEMP VIEW actual AS
SELECT table_name, column_name, is_nullable,
       (column_default IS NOT NULL) AS has_default, data_type
FROM information_schema.columns WHERE table_schema='public';

\\echo ''
\\echo '=== 1. Таблицы в базе, которых нет в репозитории ==='
SELECT table_name AS "лишняя таблица"
FROM information_schema.tables
WHERE table_schema='public' AND table_type='BASE TABLE'
  AND table_name NOT IN (SELECT DISTINCT table_name FROM expected)
ORDER BY 1;

\\echo ''
\\echo '=== 2. Таблицы из репозитория, которых нет в базе ==='
SELECT DISTINCT e.table_name AS "недостающая таблица" FROM expected e
WHERE e.table_name NOT IN (SELECT table_name FROM information_schema.tables
                            WHERE table_schema='public' AND table_type='BASE TABLE')
ORDER BY 1;

\\echo ''
\\echo '=== 3. Лишние колонки в базе ==='
SELECT a.table_name AS "таблица", a.column_name AS "лишняя колонка", a.data_type AS "тип"
FROM actual a
WHERE a.table_name IN (SELECT DISTINCT table_name FROM expected)
  AND NOT EXISTS (SELECT 1 FROM expected e
                   WHERE e.table_name=a.table_name AND e.column_name=a.column_name)
ORDER BY 1,2;

\\echo ''
\\echo '=== 4. Недостающие колонки в базе ==='
SELECT e.table_name AS "таблица", e.column_name AS "недостающая колонка", e.data_type AS "тип"
FROM expected e
WHERE e.table_name IN (SELECT table_name FROM information_schema.tables WHERE table_schema='public')
  AND NOT EXISTS (SELECT 1 FROM actual a
                   WHERE a.table_name=e.table_name AND a.column_name=e.column_name)
ORDER BY 1,2;

\\echo ''
\\echo '=== 5. Колонки отличаются (NOT NULL / DEFAULT / тип) ==='
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

\\echo ''
\\echo '=== 6. Недостающие индексы ==='
SELECT e.index_name AS "нет индекса", e.table_name AS "таблица"
FROM expected_idx e
WHERE NOT EXISTS (SELECT 1 FROM pg_indexes i
                   WHERE i.schemaname='public' AND i.indexname=e.index_name)
ORDER BY 1;

\\echo ''
\\echo '=== 7. Лишние индексы в базе ==='
SELECT i.indexname AS "лишний индекс", i.tablename AS "таблица"
FROM pg_indexes i
WHERE i.schemaname='public'
  AND i.tablename IN (SELECT DISTINCT table_name FROM expected)
  AND i.indexname NOT IN (SELECT index_name FROM expected_idx)
ORDER BY 1;

\\echo ''
\\echo '=== 8. Недостающие именованные ограничения ==='
SELECT e.con_name AS "нет ограничения", e.table_name AS "таблица"
FROM expected_con e
WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = e.con_name)
ORDER BY 1;

\\echo ''
\\echo '=== ИТОГ ==='
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
    RAISE EXCEPTION 'Расхождений со схемой репозитория: %% (подробности в разделах выше)', total;
  END IF;
  RAISE NOTICE 'Расхождений нет: база совпадает с репозиторием.';
END $$;
\\echo ''
"""


def main():
    schema = io.open(SCHEMA, encoding='utf-8-sig').read()
    columns, indexes, constraints = collect(schema)

    body = HEADER % (
        ',\n  '.join('(%s,%s,%s,%s,%s)' % (quote(a), quote(b), quote(c), d, quote(e))
                     for a, b, c, d, e in sorted(columns)),
        ',\n  '.join('(%s,%s)' % (quote(a), quote(b)) for a, b in sorted(indexes)),
        ',\n  '.join('(%s,%s)' % (quote(a), quote(b)) for a, b in sorted(constraints)),
    )
    io.open(TARGET, 'w', encoding='utf-8', newline='\n').write(body)
    print('db/drift.sql пересобран: колонок %d, индексов %d, ограничений %d'
          % (len(columns), len(indexes), len(constraints)))


if __name__ == '__main__':
    main()
