-- =============================================================================
-- Panorama В«РЁР°С…РјР°С‚РєР° РєРІР°СЂС‚РёСЂВ» вЂ” СЃС…РµРјР° PostgreSQL 14+
-- =============================================================================
-- РЎРѕРѕС‚РІРµС‚СЃС‚РІСѓРµС‚ РўР—, СЂР°Р·РґРµР» 4:
--   * РІСЃРµ РІСЂРµРјРµРЅРЅС‹Рµ РјРµС‚РєРё вЂ” timestamptz РІ UTC;
--   * Р”Р•РќР•Р–РќР«РҐ РљРћР›РћРќРћРљ РќР•Рў РЅРё РІ РѕРґРЅРѕР№ С‚Р°Р±Р»РёС†Рµ (РўР— 1.3);
--   * РјСЏРіРєРѕРµ СѓРґР°Р»РµРЅРёРµ (deleted_at), РІРЅРµС€РЅРёРµ РєР»СЋС‡Рё ON DELETE RESTRICT;
--   * С‡Р°СЃС‚РёС‡РЅС‹Рµ СѓРЅРёРєР°Р»СЊРЅС‹Рµ РёРЅРґРµРєСЃС‹ СЃ СѓСЃР»РѕРІРёРµРј deleted_at IS NULL;
--   * СЃС‚Р°С‚СѓСЃС‹ вЂ” text + CHECK (С‚РёРї ENUM РЅРµ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ);
--   * РѕС‚РґРµР»СЊРЅРѕР№ С‚Р°Р±Р»РёС†С‹ СЌС‚Р°Р¶РµР№ РЅРµС‚ вЂ” СЌС‚Р°Р¶ СЌС‚Рѕ Р°С‚СЂРёР±СѓС‚ РєРІР°СЂС‚РёСЂС‹.
-- РћР±С‰РёРµ РїРѕР»СЏ РІРѕ РІСЃРµС… РїСЂРёРєР»Р°РґРЅС‹С… С‚Р°Р±Р»РёС†Р°С…:
--   id, created_at, updated_at, deleted_at, created_by, updated_by, version.
-- =============================================================================

-- РўСЂРµР±СѓРµС‚ СЂР°СЃС€РёСЂРµРЅРёСЏ pgcrypto РІ СЌС‚РѕР№ Р‘Р” (РґР»СЏ crypt() РІ seed.sql). Р•РіРѕ СЃРѕР·РґР°С‘С‚
-- СЃСѓРїРµСЂРїРѕР»СЊР·РѕРІР°С‚РµР»СЊ С‡РµСЂРµР· db/init.sql вЂ” РґРѕ Р·Р°РїСѓСЃРєР° СЌС‚РѕРіРѕ С„Р°Р№Р»Р°.
-- gen_random_uuid() РІСЃС‚СЂРѕРµРЅР° РІ PostgreSQL 13+ Рё СЂР°СЃС€РёСЂРµРЅРёСЏ РЅРµ С‚СЂРµР±СѓРµС‚.

BEGIN;

-- =============================================================================
-- 1. РџРѕР»СЊР·РѕРІР°С‚РµР»Рё Рё РґРѕСЃС‚СѓРї
-- =============================================================================

CREATE TABLE roles (
    code        text PRIMARY KEY CHECK (code IN ('manager', 'admin')),
    title       text NOT NULL
);

CREATE TABLE users (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name             text NOT NULL,
    login                 text NOT NULL,
    phone                 text NOT NULL,
    password_hash         text NOT NULL,             -- Argon2id/bcrypt, С‚РѕР»СЊРєРѕ С…РµС€
    must_change_password  boolean NOT NULL DEFAULT true,
    blocked               boolean NOT NULL DEFAULT false,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    deleted_at            timestamptz,
    created_by            uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by            uuid REFERENCES users(id) ON DELETE RESTRICT,
    version               integer NOT NULL DEFAULT 1
);

-- Р›РѕРіРёРЅ Рё С‚РµР»РµС„РѕРЅ СѓРЅРёРєР°Р»СЊРЅС‹ СЃСЂРµРґРё В«Р¶РёРІС‹С…В» Р·Р°РїРёСЃРµР№ (РјСЏРіРєРѕРµ СѓРґР°Р»РµРЅРёРµ РЅРµ Р»РѕРјР°РµС‚).
CREATE UNIQUE INDEX users_login_uniq ON users (lower(login)) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_phone_uniq ON users (phone)        WHERE deleted_at IS NULL;

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

CREATE TABLE devices (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    platform    text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    push_token  text NOT NULL,               -- FCM / APNs
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX devices_token_uniq ON devices (push_token);

-- =============================================================================
-- 2. РќРµРґРІРёР¶РёРјРѕСЃС‚СЊ: РћР±СЉРµРєС‚ в†’ Р‘Р»РѕРє в†’ РљРІР°СЂС‚РёСЂР°
-- =============================================================================

CREATE TABLE complexes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text NOT NULL,
    address     text NOT NULL,
    deadline    text,                         -- В«СЃРґР°С‡Р° 2 РєРІ. 2027В» / В«СЃРґР°РЅВ»
    segment     text,                         -- Р±РёР·РЅРµСЃ / РєРѕРјС„РѕСЂС‚ / РїСЂРµРјРёСѓРј
    cover_start integer,                       -- С†РІРµС‚ РіСЂР°РґРёРµРЅС‚Р°-РѕР±Р»РѕР¶РєРё (ARGB)
    cover_end   integer,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz,
    created_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by  uuid REFERENCES users(id) ON DELETE RESTRICT,
    version     integer NOT NULL DEFAULT 1
);

CREATE TABLE blocks (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    complex_id      uuid NOT NULL REFERENCES complexes(id) ON DELETE RESTRICT,
    name            text NOT NULL,
    floors          integer NOT NULL CHECK (floors > 0),
    units_per_floor integer NOT NULL CHECK (units_per_floor > 0),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz,
    created_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    version         integer NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX blocks_name_uniq
    ON blocks (complex_id, lower(name)) WHERE deleted_at IS NULL;

CREATE TABLE clients (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       text NOT NULL,
    phone           text NOT NULL,
    seller_id       uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rooms           integer,                   -- СЃРєРѕР»СЊРєРѕ РєРѕРјРЅР°С‚ РёС‰РµС‚ (0 вЂ” СЃС‚СѓРґРёСЏ)
    source          text,                      -- РёСЃС‚РѕС‡РЅРёРє РѕР±СЂР°С‰РµРЅРёСЏ
    request         text,                      -- С‚РµРєСЃС‚РѕРІС‹Р№ Р·Р°РїСЂРѕСЃ (Р±РµР· Р±СЋРґР¶РµС‚Р°!)
    stage           text NOT NULL DEFAULT 'show'
                        CHECK (stage IN ('show','negotiation','booking',
                                         'design','done','rejected')),
    note            text,
    next_action_at  timestamptz,               -- РґР°С‚Р° СЃР»РµРґСѓСЋС‰РµРіРѕ РґРµР№СЃС‚РІРёСЏ
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz,
    created_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by      uuid REFERENCES users(id) ON DELETE RESTRICT,
    version         integer NOT NULL DEFAULT 1
);
-- РџСЂРѕРІРµСЂРєР° РґСѓР±Р»РёРєР°С‚Р° С‚РµР»РµС„РѕРЅР° РІ РїСЂРµРґРµР»Р°С… РјРµРЅРµРґР¶РµСЂР° (FR-07.3).
CREATE UNIQUE INDEX clients_seller_phone_uniq
    ON clients (seller_id, phone) WHERE deleted_at IS NULL;
CREATE INDEX clients_seller_idx ON clients (seller_id) WHERE deleted_at IS NULL;

CREATE TABLE apartments (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    block_id     uuid NOT NULL REFERENCES blocks(id) ON DELETE RESTRICT,
    complex_id   uuid NOT NULL REFERENCES complexes(id) ON DELETE RESTRICT,
    floor        integer NOT NULL CHECK (floor > 0),   -- СЌС‚Р°Р¶ вЂ” Р°С‚СЂРёР±СѓС‚ РєРІР°СЂС‚РёСЂС‹
    position     integer NOT NULL CHECK (position > 0),-- РїРѕР·РёС†РёСЏ РЅР° СЌС‚Р°Р¶Рµ (РєРѕР»РѕРЅРєР°)
    number       integer NOT NULL,                     -- СЃРєРІРѕР·РЅРѕР№ РЅРѕРјРµСЂ РІ Р±Р»РѕРєРµ
    rooms        integer NOT NULL,                     -- 0 вЂ” СЃС‚СѓРґРёСЏ
    area         numeric(6,1) NOT NULL,                -- РїР»РѕС‰Р°РґСЊ, РјВІ (РќР• РґРµРЅСЊРіРё)
    status       text NOT NULL DEFAULT 'free'
                    CHECK (status IN ('free','work','hold',
                                      'design','sold','off_market')),
    kitchen      text,
    view         text,
    finish       text,
    bathrooms    integer NOT NULL DEFAULT 1,
    -- С‚РµРєСѓС‰РёР№ РґРµСЂР¶Р°С‚РµР»СЊ (РґРµРЅРѕСЂРјР°Р»РёР·Р°С†РёСЏ Р°РєС‚РёРІРЅРѕР№ Р±СЂРѕРЅРё/РїРѕРєР°Р·Р° РґР»СЏ СЃРєРѕСЂРѕСЃС‚Рё)
    held_by_id   uuid REFERENCES users(id) ON DELETE RESTRICT,
    held_until   timestamptz,
    client_id    uuid REFERENCES clients(id) ON DELETE RESTRICT,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    created_by   uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by   uuid REFERENCES users(id) ON DELETE RESTRICT,
    version      integer NOT NULL DEFAULT 1   -- РѕРїС‚РёРјРёСЃС‚РёС‡РЅР°СЏ Р±Р»РѕРєРёСЂРѕРІРєР° (FR-06.4)
);
-- РЈРЅРёРєР°Р»СЊРЅРѕСЃС‚СЊ РЅРѕРјРµСЂР° РєРІР°СЂС‚РёСЂС‹ РІ Р±Р»РѕРєРµ (FR-02.4).
CREATE UNIQUE INDEX apartments_number_uniq
    ON apartments (block_id, number) WHERE deleted_at IS NULL;
-- Р Р°Р±РѕС‡РёРµ РёРЅРґРµРєСЃС‹ (РўР— 4).
CREATE INDEX apartments_grid_idx   ON apartments (block_id, floor, position);
CREATE INDEX apartments_status_idx ON apartments (status);
CREATE INDEX apartments_held_idx   ON apartments (held_by_id) WHERE held_by_id IS NOT NULL;

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
    apartment_id  uuid REFERENCES apartments(id) ON DELETE RESTRICT,
    complex_id    uuid REFERENCES complexes(id) ON DELETE RESTRICT,
    kind          text NOT NULL CHECK (kind IN ('photo','plan','cover','doc')),
    url           text NOT NULL,               -- S3-РїСѓС‚СЊ, РІС‹РґР°С‘С‚СЃСЏ РїРѕ РїРѕРґРїРёСЃР°РЅРЅРѕР№ СЃСЃС‹Р»РєРµ
    thumb_url     text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz,
    created_by    uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by    uuid REFERENCES users(id) ON DELETE RESTRICT,
    version       integer NOT NULL DEFAULT 1
);

-- =============================================================================
-- 3. РџСЂРѕРґР°Р¶Рё: РєР»РёРµРЅС‚С‹, СЃРґРµР»РєРё, Р±СЂРѕРЅРё
-- =============================================================================

CREATE TABLE deals (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
    version        integer NOT NULL DEFAULT 1
);
CREATE INDEX deals_seller_stage_idx ON deals (seller_id, stage) WHERE deleted_at IS NULL;
-- РќРµ Р±РѕР»РµРµ РѕРґРЅРѕР№ Р°РєС‚РёРІРЅРѕР№ СЃРґРµР»РєРё РЅР° РєРІР°СЂС‚РёСЂСѓ (FR-08.4).
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
    apartment_id   uuid NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    client_id      uuid NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    manager_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    expires_at     timestamptz NOT NULL,       -- СЃСЂРѕРє Р±СЂРѕРЅРё (РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ +3 РґРЅСЏ)
    released_at    timestamptz,                -- РєРѕРіРґР° СЃРЅСЏС‚Р° (Р°РІС‚Рѕ/РІСЂСѓС‡РЅСѓСЋ)
    released_reason text CHECK (released_reason IN ('expired','manual','admin','sold')),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    created_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    updated_by     uuid REFERENCES users(id) ON DELETE RESTRICT,
    version        integer NOT NULL DEFAULT 1
);
CREATE INDEX reservations_expires_idx ON reservations (expires_at) WHERE released_at IS NULL;
-- Р’С‚РѕСЂРѕР№ СЂСѓР±РµР¶ Р·Р°С‰РёС‚С‹ РѕС‚ РґРІРѕР№РЅРѕРіРѕ Р±СЂРѕРЅРёСЂРѕРІР°РЅРёСЏ (РўР— 4): РјР°РєСЃРёРјСѓРј РѕРґРЅР° Р°РєС‚РёРІРЅР°СЏ
-- Р±СЂРѕРЅСЊ РЅР° РєРІР°СЂС‚РёСЂСѓ.
CREATE UNIQUE INDEX reservations_active_uniq
    ON reservations (apartment_id)
    WHERE released_at IS NULL AND deleted_at IS NULL;

-- =============================================================================
-- 4. РЎР»СѓР¶РµР±РЅС‹Рµ
-- =============================================================================

CREATE TABLE notifications (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id  uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    kind          text NOT NULL,               -- booked / expiring / released / ...
    title         text NOT NULL,
    body          text NOT NULL,               -- Р±РµР· РґР°РЅРЅС‹С… РєР»РёРµРЅС‚Р° (FR-11.10)
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

CREATE TABLE settings (
    key         text PRIMARY KEY,
    value       text NOT NULL,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid REFERENCES users(id) ON DELETE RESTRICT
);

CREATE TABLE bulk_operations (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key  text NOT NULL,            -- РїРѕРІС‚РѕСЂРЅР°СЏ РѕС‚РїСЂР°РІРєР° РЅРµ РґСѓР±Р»РёСЂСѓРµС‚ (FR-03.7)
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
    user_id      uuid REFERENCES users(id) ON DELETE RESTRICT,
    action       text NOT NULL,               -- Р’С…РѕРґ / Р‘СЂРѕРЅСЊ / РР·РјРµРЅРµРЅРёРµ СЃС‚Р°С‚СѓСЃР° / ...
    entity_type  text,
    entity_id    text,
    before       jsonb,
    after        jsonb,
    ip           inet,
    at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_at_idx   ON audit_logs (at DESC);
CREATE INDEX audit_logs_user_idx ON audit_logs (user_id, at DESC);

COMMIT;
