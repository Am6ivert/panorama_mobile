-- =============================================================================
-- Panorama «Шахматка квартир» — схема PostgreSQL 14+
-- =============================================================================
-- Соответствует ТЗ, раздел 4:
--   * все временные метки — timestamptz в UTC;
--   * ДЕНЕЖНЫХ КОЛОНОК НЕТ ни в одной таблице (ТЗ 1.3);
--   * мягкое удаление (deleted_at), внешние ключи ON DELETE RESTRICT;
--   * частичные уникальные индексы с условием deleted_at IS NULL;
--   * статусы — text + CHECK (тип ENUM не используется);
--   * отдельной таблицы этажей нет — этаж это атрибут квартиры.
-- Общие поля во всех прикладных таблицах:
--   id, created_at, updated_at, deleted_at, created_by, updated_by, version.
-- =============================================================================

-- Требует расширения pgcrypto в этой БД (для crypt() в seed.sql). Его создаёт
-- суперпользователь через db/init.sql — до запуска этого файла.
-- gen_random_uuid() встроена в PostgreSQL 13+ и расширения не требует.

BEGIN;

-- =============================================================================
-- 0. Компании (арендаторы). Данные разных застройщиков в одной базе не
--    пересекаются: у каждой прикладной строки есть org_id, а составные внешние
--    ключи (id, org_id) физически запрещают связать сущности разных компаний.
-- =============================================================================

CREATE TABLE organizations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code        text NOT NULL,        -- короткий код: panorama, elitstroy
    name        text NOT NULL,        -- отображаемое название застройщика
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz
);
CREATE UNIQUE INDEX organizations_code_uniq
    ON organizations (lower(code)) WHERE deleted_at IS NULL;

-- =============================================================================
-- 1. Пользователи и доступ
-- =============================================================================

CREATE TABLE roles (
    code        text PRIMARY KEY CHECK (code IN ('manager', 'admin')),
    title       text NOT NULL
);

CREATE TABLE users (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                uuid NOT NULL CONSTRAINT users_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    full_name             text NOT NULL,
    login                 text NOT NULL,
    phone                 text NOT NULL,
    password_hash         text NOT NULL,             -- Argon2id/bcrypt, только хеш
    must_change_password  boolean NOT NULL DEFAULT true,
    blocked               boolean NOT NULL DEFAULT false,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    deleted_at            timestamptz,
    created_by            uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by            uuid REFERENCES users(id) ON DELETE RESTRICT,
    version               integer NOT NULL DEFAULT 1,
    -- Мишень для составных внешних ключей «сущность из той же компании».
    CONSTRAINT users_id_org_uniq UNIQUE (id, org_id)
);

-- Логин и телефон уникальны ГЛОБАЛЬНО, а не внутри компании: экран входа
-- спрашивает только логин и пароль, компания определяется по учётной записи.
CREATE UNIQUE INDEX users_login_uniq ON users (lower(login)) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_phone_uniq ON users (phone)        WHERE deleted_at IS NULL;
CREATE INDEX users_org_idx ON users (org_id) WHERE deleted_at IS NULL;

CREATE TABLE user_roles (
    user_id   uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    role_code text NOT NULL REFERENCES roles(code) ON DELETE RESTRICT,
    PRIMARY KEY (user_id, role_code)
);

CREATE TABLE sessions (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    token_hash  text NOT NULL,
    ip          inet,
    created_at  timestamptz NOT NULL DEFAULT now(),
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz
);
CREATE INDEX sessions_user_idx ON sessions (user_id) WHERE revoked_at IS NULL;
-- Токен разрешается в личность на каждом запросе — ищем строго по хешу.
CREATE UNIQUE INDEX sessions_token_hash_uniq ON sessions (token_hash);

CREATE TABLE devices (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    platform    text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    push_token  text NOT NULL,               -- FCM / APNs
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX devices_token_uniq ON devices (push_token);
-- Пуши выбираются по владельцу устройства при каждом уведомлении.
CREATE INDEX devices_user_idx ON devices (user_id);

-- =============================================================================
-- 2. Недвижимость: Объект → Блок → Квартира
-- =============================================================================

CREATE TABLE complexes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      uuid NOT NULL CONSTRAINT complexes_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    address     text NOT NULL,
    deadline    text,                         -- «сдача 2 кв. 2027» / «сдан»
    segment     text,                         -- бизнес / комфорт / премиум
    -- ARGB-цвет обложки. Именно bigint, а не integer: альфа 0xFF выставляет
    -- старший бит, и любое значение вида 0xFF...... больше 2^31-1.
    cover_start bigint,
    cover_end   bigint,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz,
    created_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    version     integer NOT NULL DEFAULT 1,
    CONSTRAINT complexes_id_org_uniq UNIQUE (id, org_id)
);
CREATE INDEX complexes_org_idx ON complexes (org_id) WHERE deleted_at IS NULL;

CREATE TABLE blocks (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          uuid NOT NULL CONSTRAINT blocks_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    complex_id      uuid NOT NULL REFERENCES complexes(id) ON DELETE RESTRICT,
    name            text NOT NULL,
    floors          integer NOT NULL CHECK (floors > 0),
    units_per_floor integer NOT NULL CHECK (units_per_floor > 0),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz,
    created_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    version         integer NOT NULL DEFAULT 1,
    CONSTRAINT blocks_id_org_uniq UNIQUE (id, org_id),
    -- Блок может принадлежать только ЖК своей компании.
    CONSTRAINT blocks_complex_id_org_fk FOREIGN KEY (complex_id, org_id)
        REFERENCES complexes (id, org_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX blocks_name_uniq
    ON blocks (complex_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE clients (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          uuid NOT NULL CONSTRAINT clients_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    full_name       text NOT NULL,
    phone           text NOT NULL,
    seller_id       uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rooms           integer,                   -- сколько комнат ищет (0 — студия)
    source          text,                      -- источник обращения
    request         text,                      -- текстовый запрос (без бюджета!)
    stage           text NOT NULL DEFAULT 'show'
                        CHECK (stage IN ('show','negotiation','booking',
                                         'design','done','rejected')),
    note            text,
    next_action_at  timestamptz,               -- дата следующего действия
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz,
    created_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    version         integer NOT NULL DEFAULT 1,
    CONSTRAINT clients_id_org_uniq UNIQUE (id, org_id),
    -- Продавец клиента — сотрудник той же компании.
    CONSTRAINT clients_seller_id_org_fk FOREIGN KEY (seller_id, org_id)
        REFERENCES users (id, org_id) ON DELETE RESTRICT
);
CREATE INDEX clients_org_idx ON clients (org_id) WHERE deleted_at IS NULL;
-- Проверка дубликата телефона в пределах менеджера (FR-07.3).
CREATE UNIQUE INDEX clients_seller_phone_uniq
    ON clients (seller_id, phone) WHERE deleted_at IS NULL;
CREATE INDEX clients_seller_idx ON clients (seller_id) WHERE deleted_at IS NULL;

CREATE TABLE apartments (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       uuid NOT NULL CONSTRAINT apartments_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    block_id     uuid NOT NULL REFERENCES blocks(id) ON DELETE RESTRICT,
    complex_id   uuid NOT NULL REFERENCES complexes(id) ON DELETE RESTRICT,
    floor        integer NOT NULL CHECK (floor > 0),   -- этаж — атрибут квартиры
    position     integer NOT NULL CHECK (position > 0),-- позиция на этаже (колонка)
    number       integer NOT NULL,                     -- сквозной номер в блоке
    rooms        integer NOT NULL,                     -- 0 — студия
    area         numeric(6,1) NOT NULL,                -- площадь, м² (НЕ деньги)
    status       text NOT NULL DEFAULT 'free'
                    CHECK (status IN ('free','work','hold',
                                      'design','sold','off_market')),
    kitchen      text,
    view         text,
    finish       text,
    bathrooms    integer NOT NULL DEFAULT 1,
    -- текущий держатель (денормализация активной брони/показа для скорости)
    held_by_id   uuid REFERENCES users(id) ON DELETE RESTRICT,
    held_until   timestamptz,
    client_id    uuid REFERENCES clients(id) ON DELETE RESTRICT,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    created_by   uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by   uuid REFERENCES users(id) ON DELETE RESTRICT,
    version      integer NOT NULL DEFAULT 1,  -- оптимистичная блокировка (FR-06.4)
    CONSTRAINT apartments_id_org_uniq UNIQUE (id, org_id),
    -- Квартира, её блок и ЖК — из одной компании; держатель и клиент тоже.
    -- Для nullable-колонок проверка включается, только когда значение задано.
    CONSTRAINT apartments_block_id_org_fk FOREIGN KEY (block_id, org_id)   REFERENCES blocks   (id, org_id) ON DELETE RESTRICT,
    CONSTRAINT apartments_complex_id_org_fk FOREIGN KEY (complex_id, org_id) REFERENCES complexes(id, org_id) ON DELETE RESTRICT,
    CONSTRAINT apartments_held_by_id_org_fk FOREIGN KEY (held_by_id, org_id) REFERENCES users    (id, org_id) ON DELETE RESTRICT,
    CONSTRAINT apartments_client_id_org_fk FOREIGN KEY (client_id, org_id)  REFERENCES clients  (id, org_id) ON DELETE RESTRICT
);
CREATE INDEX apartments_org_idx ON apartments (org_id) WHERE deleted_at IS NULL;
-- Уникальность номера квартиры в блоке (FR-02.4).
CREATE UNIQUE INDEX apartments_number_uniq
    ON apartments (block_id, number) WHERE deleted_at IS NULL;
-- Рабочие индексы (ТЗ 4).
CREATE INDEX apartments_grid_idx   ON apartments (block_id, floor, position);
CREATE INDEX apartments_status_idx ON apartments (status);
CREATE INDEX apartments_held_idx   ON apartments (held_by_id) WHERE held_by_id IS NOT NULL;
-- Проверка истечения броней выполняется раз в минуту по всему фонду.
CREATE INDEX apartments_hold_expiry_idx ON apartments (held_until)
    WHERE status = 'hold' AND deleted_at IS NULL;
-- Инкрементальная выдача фонда: приложение просит только изменившееся.
CREATE INDEX apartments_org_updated_idx ON apartments (org_id, updated_at)
    WHERE deleted_at IS NULL;

CREATE TABLE apartment_status_history (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id  uuid NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    from_status   text,
    to_status     text NOT NULL,
    changed_by    uuid REFERENCES users(id) ON DELETE RESTRICT,
    client_id     uuid REFERENCES clients(id) ON DELETE RESTRICT,
    comment       text,
    at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX apt_status_hist_idx ON apartment_status_history (apartment_id, at DESC);

CREATE TABLE files (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        uuid NOT NULL CONSTRAINT files_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    apartment_id  uuid REFERENCES apartments(id) ON DELETE RESTRICT,
    complex_id    uuid REFERENCES complexes(id) ON DELETE RESTRICT,
    kind          text NOT NULL CHECK (kind IN ('photo','plan','cover','doc')),
    url           text NOT NULL,               -- S3-путь, выдаётся по подписанной ссылке
    thumb_url     text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz,
    created_by    uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by    uuid REFERENCES users(id) ON DELETE RESTRICT,
    version       integer NOT NULL DEFAULT 1
);

-- =============================================================================
-- 3. Продажи: клиенты, сделки, брони
-- =============================================================================

CREATE TABLE deals (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         uuid NOT NULL CONSTRAINT deals_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    client_id      uuid NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    apartment_id   uuid NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    seller_id      uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    stage          text NOT NULL DEFAULT 'show'
                       CHECK (stage IN ('show','negotiation','booking',
                                        'design','done','rejected')),
    next_action_at timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    created_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    version        integer NOT NULL DEFAULT 1,
    CONSTRAINT deals_id_org_uniq UNIQUE (id, org_id),
    CONSTRAINT deals_client_id_org_fk FOREIGN KEY (client_id, org_id)    REFERENCES clients   (id, org_id) ON DELETE RESTRICT,
    CONSTRAINT deals_apartment_id_org_fk FOREIGN KEY (apartment_id, org_id) REFERENCES apartments(id, org_id) ON DELETE RESTRICT,
    CONSTRAINT deals_seller_id_org_fk FOREIGN KEY (seller_id, org_id)    REFERENCES users     (id, org_id) ON DELETE RESTRICT
);
CREATE INDEX deals_seller_stage_idx ON deals (seller_id, stage) WHERE deleted_at IS NULL;
CREATE INDEX deals_org_idx ON deals (org_id) WHERE deleted_at IS NULL;
-- Не более одной активной сделки на квартиру (FR-08.4).
CREATE UNIQUE INDEX deals_active_apartment_uniq
    ON deals (apartment_id)
    WHERE deleted_at IS NULL AND stage NOT IN ('done', 'rejected');

CREATE TABLE deal_stage_history (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    deal_id     uuid NOT NULL REFERENCES deals(id) ON DELETE RESTRICT,
    from_stage  text,
    to_stage    text NOT NULL,
    changed_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE reservations (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         uuid NOT NULL CONSTRAINT reservations_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    apartment_id   uuid NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    client_id      uuid NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    manager_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    expires_at     timestamptz NOT NULL,       -- срок брони (по умолчанию +3 дня)
    released_at    timestamptz,                -- когда снята (авто/вручную)
    released_reason text CHECK (released_reason IN ('expired','manual','admin','sold')),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    created_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    version        integer NOT NULL DEFAULT 1,
    CONSTRAINT reservations_apartment_id_org_fk FOREIGN KEY (apartment_id, org_id) REFERENCES apartments(id, org_id) ON DELETE RESTRICT,
    CONSTRAINT reservations_client_id_org_fk FOREIGN KEY (client_id, org_id)    REFERENCES clients   (id, org_id) ON DELETE RESTRICT,
    CONSTRAINT reservations_manager_id_org_fk FOREIGN KEY (manager_id, org_id)   REFERENCES users     (id, org_id) ON DELETE RESTRICT
);
CREATE INDEX reservations_expires_idx ON reservations (expires_at) WHERE released_at IS NULL;
-- Второй рубеж защиты от двойного бронирования (ТЗ 4): максимум одна активная
-- бронь на квартиру.
CREATE UNIQUE INDEX reservations_active_uniq
    ON reservations (apartment_id)
    WHERE released_at IS NULL AND deleted_at IS NULL;

-- =============================================================================
-- 4. Служебные
-- =============================================================================

CREATE TABLE notifications (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id  uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kind          text NOT NULL,               -- booked / expiring / released / ...
    title         text NOT NULL,
    body          text NOT NULL,               -- без данных клиента (FR-11.10)
    apartment_id  uuid REFERENCES apartments(id) ON DELETE RESTRICT,  -- deep link
    read_at       timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_inbox_idx
    ON notifications (recipient_id, created_at DESC);
CREATE INDEX notifications_unread_idx
    ON notifications (recipient_id) WHERE read_at IS NULL;

CREATE TABLE dictionaries (
    id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "group" text NOT NULL,                     -- 'apartment_status', 'source', ...
    code    text NOT NULL,
    title   text NOT NULL,
    sort    integer NOT NULL DEFAULT 0,
    UNIQUE ("group", code)
);

-- Настройки у каждой компании свои: лимиты броней и срок брони застройщики
-- выставляют по-разному, поэтому ключ составной.
CREATE TABLE settings (
    org_id      uuid NOT NULL CONSTRAINT settings_org_fk
                    REFERENCES organizations(id) ON DELETE RESTRICT,
    key         text NOT NULL,
    value       text NOT NULL,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT settings_pkey PRIMARY KEY (org_id, key)
);

CREATE TABLE bulk_operations (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           uuid NOT NULL CONSTRAINT bulk_operations_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    idempotency_key  text NOT NULL,            -- повторная отправка не дублирует (FR-03.7)
    complex_id       uuid REFERENCES complexes(id) ON DELETE RESTRICT,
    block_name       text,
    params           jsonb NOT NULL,
    affected_count   integer NOT NULL DEFAULT 0,
    created_by       uuid REFERENCES users(id) ON DELETE RESTRICT,
    created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX bulk_idempotency_uniq ON bulk_operations (idempotency_key);

CREATE TABLE audit_logs (
    id           bigserial PRIMARY KEY,
    org_id       uuid NOT NULL CONSTRAINT audit_logs_org_fk REFERENCES organizations(id) ON DELETE RESTRICT,
    user_id      uuid REFERENCES users(id) ON DELETE RESTRICT,
    action       text NOT NULL,               -- Вход / Бронь / Изменение статуса / ...
    entity_type  text,
    entity_id    text,
    before       jsonb,
    after        jsonb,
    ip           inet,
    at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_at_idx   ON audit_logs (org_id, at DESC);
CREATE INDEX audit_logs_user_idx ON audit_logs (user_id, at DESC);

COMMIT;
