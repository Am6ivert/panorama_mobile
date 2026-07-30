-- =============================================================================
-- Panorama «Шахматка квартир» — начальные данные (money-free)
-- Запускать после schema.sql. Пароль всех демо-учёток: 0000 (bcrypt через pgcrypto).
-- =============================================================================

BEGIN;

-- Роли -----------------------------------------------------------------------
INSERT INTO roles (code, title) VALUES
    ('manager', 'Менеджер'),
    ('admin',   'Администратор')
ON CONFLICT (code) DO NOTHING;

-- Справочники (статусы — text + CHECK в таблицах, тут — витрина для UI) -------
INSERT INTO dictionaries ("group", code, title, sort) VALUES
    ('apartment_status','free',      'Свободна',      1),
    ('apartment_status','work',      'В работе',      2),
    ('apartment_status','hold',      'Бронь',         3),
    ('apartment_status','design',    'Оформление',    4),
    ('apartment_status','sold',      'Продана',       5),
    ('apartment_status','off_market','Не для продажи',6),
    ('deal_stage','show',       'Показ',       1),
    ('deal_stage','negotiation','Переговоры',  2),
    ('deal_stage','booking',    'Бронь',       3),
    ('deal_stage','design',     'Оформление',  4),
    ('deal_stage','done',       'Завершена',   5),
    ('deal_stage','rejected',   'Отказ',       6),
    ('client_source','instagram','Реклама Instagram',1),
    ('client_source','referral', 'Рекомендация',     2),
    ('client_source','site',     'Сайт',             3)
ON CONFLICT ("group", code) DO NOTHING;

-- Настройки ------------------------------------------------------------------
INSERT INTO settings (key, value) VALUES
    ('booking_days',          '3'),   -- срок брони по умолчанию (FR-07.6)
    ('booking_limit',         '5'),   -- активных броней на менеджера (FR-07.9)
    ('work_limit',            '5'),   -- квартир «в работе» на менеджера
    ('min_client_version',    '1.0.0')-- принудительное обновление клиента
ON CONFLICT (key) DO NOTHING;

-- Пользователи (пароль 0000, хеш bcrypt через pgcrypto) ----------------------
-- Администратор должен создать реальные учётки и сменить пароли.
WITH new_users AS (
    INSERT INTO users (full_name, login, phone, password_hash, must_change_password)
    VALUES
      ('Динара Ибраимова',    'admin',  '+996 555 00-11-22', crypt('0000', gen_salt('bf')), false),
      ('Азамат Кубанычбеков', 'azamat', '+996 555 10-22-30', crypt('0000', gen_salt('bf')), false),
      ('Эльвира Садыкова',    'elvira', '+996 700 41-08-19', crypt('0000', gen_salt('bf')), false),
      ('Нурлан Осмонов',      'nurlan', '+996 559 77-13-04', crypt('0000', gen_salt('bf')), false),
      ('Бекзат Жумалиев',     'bekzat', '+996 772 60-55-21', crypt('0000', gen_salt('bf')), false)
    ON CONFLICT DO NOTHING
    RETURNING id, login
)
INSERT INTO user_roles (user_id, role_code)
SELECT id, CASE WHEN login = 'admin' THEN 'admin' ELSE 'manager' END
FROM new_users;

-- Пример объекта, блока и фонда квартир --------------------------------------
-- Показывает генерацию как в мастере массового создания (FR-03).
WITH admin AS (
    SELECT id FROM users WHERE login = 'admin'
),
cx AS (
    INSERT INTO complexes (name, address, deadline, segment, created_by)
    SELECT 'Панорама Сити', 'ул. Ахунбаева, 121', 'сдача 2 кв. 2027', 'бизнес', id
    FROM admin
    RETURNING id
),
bl AS (
    INSERT INTO blocks (complex_id, name, floors, units_per_floor, created_by)
    SELECT cx.id, 'А', 16, 6, admin.id FROM cx, admin
    RETURNING id, complex_id
)
INSERT INTO apartments
    (block_id, complex_id, floor, position, number, rooms, area, status, created_by)
SELECT
    bl.id,
    bl.complex_id,
    f.floor,
    p.position,
    (f.floor - 1) * 6 + p.position                        AS number,
    (ARRAY[1,2,2,3,1,0])[p.position]                      AS rooms,
    (ARRAY[42.0,60.0,60.0,84.0,42.0,31.0])[p.position]    AS area,
    'free',
    admin.id
FROM bl, admin,
     generate_series(1, 16) AS f(floor),
     generate_series(1, 6)  AS p(position);

COMMIT;

-- Проверка: сколько квартир создано
-- SELECT count(*) FROM apartments;  -- ожидаем 96
