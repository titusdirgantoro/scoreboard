-- +goose Up
-- Event, lapangan, token PIN, tim, pemain, laga, dan log skor live. Lihat docs/DATA_MODEL.md.

CREATE TABLE events (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          uuid NOT NULL REFERENCES organizations (id),
    slug            text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) <= 60),
    name            text NOT NULL CHECK (length(name) BETWEEN 3 AND 120),
    sports          text[] NOT NULL DEFAULT '{}',
    format          text NOT NULL DEFAULT 'group' CHECK (format IN ('group', 'knockout', 'double_elim', 'league', 'americano')),
    starts_on       date,
    ends_on         date,
    venue           text,
    visibility      text NOT NULL DEFAULT 'link' CHECK (visibility IN ('public', 'link', 'private')),
    viewer_pin_hash text,
    status          text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    reg_open        boolean NOT NULL DEFAULT true,
    reg_closes_at   timestamptz,
    fee_idr         bigint NOT NULL DEFAULT 0 CHECK (fee_idr >= 0),
    team_quota      int NOT NULL DEFAULT 8 CHECK (team_quota > 0),
    theme           jsonb NOT NULL DEFAULT '{}'::jsonb,
    plan            text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pass16', 'pass32', 'pass64', 'pro')),
    pass_expires_at timestamptz,
    published_at    timestamptz,
    deleted_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on)
);
CREATE INDEX events_org_idx ON events (org_id, status);
CREATE INDEX events_public_idx ON events (starts_on) WHERE visibility = 'public' AND status = 'published' AND deleted_at IS NULL;

CREATE TABLE courts (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id     uuid NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    code         text NOT NULL CHECK (code ~ '^[a-z0-9]{1,8}$'),
    name         text NOT NULL,
    sport        text NOT NULL,
    referee_name text,
    pin_hash     text NOT NULL,
    pin_version  int NOT NULL DEFAULT 1,
    sort_order   int NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (event_id, code)
);

CREATE TABLE access_tokens (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id     uuid NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    court_id     uuid REFERENCES courts (id) ON DELETE CASCADE,
    kind         text NOT NULL CHECK (kind IN ('referee', 'desk')),
    token_hash   bytea NOT NULL UNIQUE,
    pin_version  int NOT NULL,
    device_label text,
    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CHECK (kind = 'desk' OR court_id IS NOT NULL)
);
CREATE INDEX access_tokens_court_idx ON access_tokens (court_id) WHERE revoked_at IS NULL;

CREATE TABLE teams (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id           uuid NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    name               text NOT NULL CHECK (length(name) BETWEEN 3 AND 60),
    sport              text NOT NULL,
    captain_name       text NOT NULL,
    captain_phone_e164 text NOT NULL CHECK (captain_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
    manager_user_id    uuid REFERENCES users (id),
    status             text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    reject_reason      text,
    roster_count       int NOT NULL DEFAULT 0,
    registered_at      timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX teams_event_name_uniq ON teams (event_id, lower(name));
CREATE INDEX teams_event_status_idx ON teams (event_id, status);

CREATE TABLE players (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id             uuid NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
    full_name           text NOT NULL,
    jersey_no           int CHECK (jersey_no BETWEEN 0 AND 999),
    position            text,
    birth_date          date,
    photo_key           text,
    emergency_contact   text,
    status              text NOT NULL DEFAULT 'docs_missing' CHECK (status IN ('eligible', 'suspended', 'docs_missing')),
    yellow_cards        int NOT NULL DEFAULT 0,
    red_cards           int NOT NULL DEFAULT 0,
    guardian_consent_at timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX players_team_idx ON players (team_id);

CREATE TABLE matches (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id       uuid NOT NULL REFERENCES events (id) ON DELETE CASCADE,
    stage_id       uuid,
    round          int,
    slot           int,
    court_id       uuid REFERENCES courts (id) ON DELETE SET NULL,
    scheduled_at   timestamptz,
    team_a_id      uuid REFERENCES teams (id),
    team_b_id      uuid REFERENCES teams (id),
    sport          text NOT NULL,
    rules          jsonb NOT NULL DEFAULT '{}'::jsonb,
    status         text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'finished', 'walkover', 'cancelled')),
    score_a        int NOT NULL DEFAULT 0,
    score_b        int NOT NULL DEFAULT 0,
    detail         jsonb NOT NULL DEFAULT '{}'::jsonb,
    winner_team_id uuid REFERENCES teams (id),
    live_version   bigint NOT NULL DEFAULT 0,
    started_at     timestamptz,
    finished_at    timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CHECK (team_a_id IS NULL OR team_b_id IS NULL OR team_a_id <> team_b_id)
);
CREATE INDEX matches_event_idx ON matches (event_id, status, scheduled_at);
CREATE INDEX matches_court_idx ON matches (court_id, status);

CREATE TABLE score_events (
    id        bigserial PRIMARY KEY,
    match_id  uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
    client_id text NOT NULL CHECK (length(client_id) BETWEEN 8 AND 64),
    seq       int NOT NULL CHECK (seq > 0),
    kind      text NOT NULL CHECK (kind IN ('point', 'undo', 'period', 'card', 'timeout', 'finish')),
    payload   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source    text NOT NULL CHECK (source IN ('referee', 'admin')),
    token_id  uuid REFERENCES access_tokens (id),
    user_id   uuid REFERENCES users (id),
    client_ts timestamptz,
    server_ts timestamptz NOT NULL DEFAULT now(),
    UNIQUE (match_id, client_id, seq)
);
CREATE INDEX score_events_match_idx ON score_events (match_id, id);

CREATE TABLE score_corrections (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id      uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
    before        jsonb NOT NULL,
    after         jsonb NOT NULL,
    reason        text NOT NULL CHECK (length(reason) >= 4),
    actor_user_id uuid NOT NULL REFERENCES users (id),
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX score_corrections_match_idx ON score_corrections (match_id, created_at DESC);

-- +goose Down
DROP TABLE score_corrections;
DROP TABLE score_events;
DROP TABLE matches;
DROP TABLE players;
DROP TABLE teams;
DROP TABLE access_tokens;
DROP TABLE courts;
DROP TABLE events;
