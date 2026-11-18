-- +goose Up
-- Identitas, organisasi, dan log audit. Lihat docs/DATA_MODEL.md.
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name             text NOT NULL CHECK (length(name) BETWEEN 1 AND 120),
    email            citext UNIQUE,
    phone_e164       text UNIQUE CHECK (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
    avatar_key       text,
    status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
    suspended_reason text,
    last_seen_at     timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL)
);

CREATE TABLE auth_identities (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    provider   text NOT NULL CHECK (provider IN ('google', 'email', 'whatsapp')),
    subject    text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider, subject)
);
CREATE INDEX auth_identities_user_idx ON auth_identities (user_id);

CREATE TABLE sessions (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash bytea NOT NULL UNIQUE,
    user_agent text,
    ip         inet,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_idx ON sessions (user_id);

CREATE TABLE otp_codes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel     text NOT NULL CHECK (channel IN ('email', 'whatsapp')),
    destination text NOT NULL,
    code_hash   bytea NOT NULL,
    purpose     text NOT NULL DEFAULT 'login' CHECK (purpose IN ('login', 'verify_phone')),
    attempts    int NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
    expires_at  timestamptz NOT NULL,
    consumed_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX otp_codes_destination_idx ON otp_codes (destination, created_at DESC);

CREATE TABLE organizations (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  text NOT NULL CHECK (length(name) BETWEEN 1 AND 120),
    slug                  text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    owner_user_id         uuid NOT NULL REFERENCES users (id),
    xendit_sub_account_id text,
    payout_bank_code      text,
    payout_account_masked text,
    payout_account_name   text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE org_members (
    org_id     uuid NOT NULL REFERENCES organizations (id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role       text NOT NULL CHECK (role IN ('owner', 'admin', 'treasurer')),
    invited_by uuid REFERENCES users (id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id)
);
CREATE INDEX org_members_user_idx ON org_members (user_id);

CREATE TABLE audit_log (
    id            bigserial PRIMARY KEY,
    actor_user_id uuid REFERENCES users (id),
    actor_kind    text NOT NULL CHECK (actor_kind IN ('user', 'staff', 'system', 'pin')),
    org_id        uuid REFERENCES organizations (id),
    event_id      uuid,
    action        text NOT NULL,
    target_type   text,
    target_id     text,
    reason        text,
    meta          jsonb NOT NULL DEFAULT '{}'::jsonb,
    ip            inet,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_log_org_idx ON audit_log (org_id, created_at DESC);
CREATE INDEX audit_log_event_idx ON audit_log (event_id, created_at DESC);

-- +goose Down
DROP TABLE audit_log;
DROP TABLE org_members;
DROP TABLE organizations;
DROP TABLE otp_codes;
DROP TABLE sessions;
DROP TABLE auth_identities;
DROP TABLE users;
