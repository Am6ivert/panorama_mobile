-- =============================================================================
-- Panorama «Шахматка квартир» — начальные данные (money-free)
-- Запускать после schema.sql. Пароль всех демо-учёток: 0000 (bcrypt через pgcrypto).
-- =============================================================================

BEGIN;

-- Роли -----------------------------------------------------------------------
-- Компания по умолчанию ------------------------------------------------------
-- Демо-данные ниже принадлежат ей. Вторую компанию заводит db/new_org.sql.
INSERT INTO organizations (code, name, plan_kind, plan_until, grace_days)
VALUES ('panorama', 'Панорама', 'paid', now() + interval '1 month', 3)
ON CONFLICT DO NOTHING;

-- Служебная компания: в ней живёт суперадминистратор. Своих объектов и
-- сотрудников у неё нет, подписка бессрочная.
INSERT INTO organizations (code, name, plan_kind, plan_until, grace_days)
VALUES ('system', 'Служебная', 'paid', now() + interval '100 years', 0)
ON CONFLICT DO NOTHING;

INSERT INTO roles (code, title) VALUES
    ('manager',    'Менеджер'),
    ('admin',      'Администратор'),
    ('superadmin', 'Суперадминистратор')
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
INSERT INTO settings (org_id, key, value)
SELECT o.id, d.key, d.value
FROM organizations o
CROSS JOIN (VALUES
    ('booking_days',          '3'),    -- срок брони по умолчанию (FR-07.6)
    ('booking_limit',         '5'),    -- активных броней на менеджера (FR-07.9)
    ('work_limit',            '5'),    -- квартир «в работе» на менеджера
    ('min_client_version',    '1.0.0') -- принудительное обновление клиента
) AS d(key, value)
WHERE o.code = 'panorama'
ON CONFLICT (org_id, key) DO NOTHING;

-- Пользователи (пароль 0000, хеш bcrypt через pgcrypto) ----------------------
-- Администратор должен создать реальные учётки и сменить пароли.
WITH new_users AS (
    INSERT INTO users (org_id, full_name, login, phone, password_hash, must_change_password)
    SELECT o.id, v.full_name, v.login, v.phone, crypt('0000', gen_salt('bf')), false
    FROM organizations o,
         (VALUES
            ('Динара Ибраимова',    'admin',  '+996 555 00-11-22'),
            ('Азамат Кубанычбеков', 'azamat', '+996 555 10-22-30'),
            ('Эльвира Садыкова',    'elvira', '+996 700 41-08-19'),
            ('Нурлан Осмонов',      'nurlan', '+996 559 77-13-04'),
            ('Бекзат Жумалиев',     'bekzat', '+996 772 60-55-21')
         ) AS v(full_name, login, phone)
    WHERE o.code = 'panorama'
    ON CONFLICT DO NOTHING
    RETURNING id, login
)
INSERT INTO user_roles (user_id, role_code)
SELECT id, CASE WHEN login = 'admin' THEN 'admin' ELSE 'manager' END
FROM new_users;

-- Пример объекта, блока и фонда квартир --------------------------------------
-- Показывает генерацию как в мастере массового создания (FR-03).
WITH admin AS (
    SELECT id, org_id FROM users WHERE login = 'admin'
),
cx AS (
    INSERT INTO complexes (org_id, name, address, deadline, segment, created_by)
    SELECT org_id, 'Панорама Сити', 'ул. Ахунбаева, 121', 'сдача 2 кв. 2027',
           'бизнес', id
    FROM admin
    RETURNING id, org_id
),
bl AS (
    INSERT INTO blocks (org_id, complex_id, name, floors, units_per_floor, created_by)
    SELECT cx.org_id, cx.id, 'А', 16, 6, admin.id FROM cx, admin
    RETURNING id, complex_id, org_id
)
INSERT INTO apartments
    (org_id, block_id, complex_id, floor, position, number, rooms, area, status, created_by)
SELECT
    bl.org_id,
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
