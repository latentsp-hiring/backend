-- Tidewater database contract (SQLite).
--
-- The grader creates the database from this file, then seed.sql, then runs your
-- /app/migrate. You may extend it through migrations: new tables, columns, indexes
-- and constraints are all fine. Never remove or retype the columns the grader reads:
--   paystubs:       external_id, user_id, gross_pay (REAL)
--   sync_runs:      id, user_id, status, created_at
--   webhook_events: failed_at, error
--   incomes:        external_account_id, and the seeded rows in users and incomes
--
-- Timestamps are TEXT in ISO 8601 UTC. Ids are TEXT; the defaults below generate one
-- if you do not supply your own.

PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id             TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  email          TEXT NOT NULL UNIQUE,
  name           TEXT,
  argyle_user_id TEXT UNIQUE,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE user_tokens (
  id                     TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id                TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider               TEXT NOT NULL,
  external_connection_id TEXT,
  provider_metadata      TEXT,
  created_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX user_tokens_user_id_idx ON user_tokens(user_id);
CREATE INDEX user_tokens_provider_external_connection_id_idx ON user_tokens(provider, external_connection_id);

CREATE TABLE incomes (
  id                  TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name                TEXT,
  source              TEXT,
  provider_id         TEXT,
  external_source_id  TEXT,
  external_account_id TEXT,
  status              TEXT NOT NULL DEFAULT 'IN_PROGRESS',
  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE (user_id, external_source_id)
);
CREATE INDEX incomes_user_id_idx ON incomes(user_id);
CREATE INDEX incomes_external_account_id_idx ON incomes(external_account_id);

CREATE TABLE paystubs (
  id            TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  income_id     TEXT NOT NULL REFERENCES incomes(id) ON DELETE CASCADE,
  external_id   TEXT NOT NULL,
  gross_pay     REAL,
  net_pay       REAL,
  deductions    REAL,
  taxes         REAL,
  hours         REAL,
  pay_date      TEXT,
  period_start  TEXT,
  period_end    TEXT,
  employer_name TEXT,
  provider      TEXT NOT NULL DEFAULT 'argyle',
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE (user_id, external_id)
);
CREATE INDEX paystubs_user_id_idx ON paystubs(user_id);
CREATE INDEX paystubs_income_id_idx ON paystubs(income_id);

CREATE TABLE webhook_events (
  id           TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  provider     TEXT NOT NULL,
  event        TEXT,
  payload      TEXT,
  received_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  processed_at TEXT,
  failed_at    TEXT,
  error        TEXT
);

-- One row per sync dispatch. Write it (status 'pending') before you acknowledge the
-- webhook, then move it to 'running' and finally 'succeeded' or 'failed'.
-- webhook_event_id is NULL for syncs started through POST /internal/sync.
CREATE TABLE sync_runs (
  id               TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id       TEXT NOT NULL,
  webhook_event_id TEXT REFERENCES webhook_events(id),
  status           TEXT NOT NULL
                   CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
  created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  started_at       TEXT,
  finished_at      TEXT,
  error            TEXT
);
CREATE INDEX sync_runs_status_idx ON sync_runs(status);
