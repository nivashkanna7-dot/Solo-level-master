-- Phase 0: Platform Skeleton & Guardrails
-- PostgreSQL 15+

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Shared trigger: maintain updated_at for mutable rows
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Command ledger + idempotency
-- -----------------------------------------------------------------------------
CREATE TABLE domain_commands (
  command_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  command_type TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id UUID,
  payload JSONB NOT NULL,
  validation_errors JSONB,
  status TEXT NOT NULL CHECK (status IN ('accepted', 'rejected', 'executed', 'failed')),
  correlation_id UUID NOT NULL,
  causation_id UUID,
  idempotency_key TEXT NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_domain_commands_idem UNIQUE (idempotency_key)
);

CREATE TRIGGER trg_domain_commands_updated_at
BEFORE UPDATE ON domain_commands
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE idempotency_keys (
  idempotency_key TEXT PRIMARY KEY,
  command_id UUID NOT NULL REFERENCES domain_commands(command_id),
  command_hash TEXT NOT NULL,
  response_code INTEGER,
  response_body JSONB,
  expires_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_idempotency_keys_updated_at
BEFORE UPDATE ON idempotency_keys
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- User aggregate: state + events
-- -----------------------------------------------------------------------------
CREATE TABLE users_state (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  password_hash TEXT,
  auth_provider TEXT NOT NULL DEFAULT 'local',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_users_state_email UNIQUE (email)
);

CREATE TRIGGER trg_users_state_updated_at
BEFORE UPDATE ON users_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE users_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_payload JSONB NOT NULL,
  event_version INTEGER NOT NULL,
  command_id UUID REFERENCES domain_commands(command_id),
  cause_type TEXT NOT NULL,
  cause_id UUID,
  correlation_id UUID NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_users_events_user_id_created_at ON users_events (user_id, created_at);
CREATE INDEX idx_users_events_correlation_id ON users_events (correlation_id);

-- -----------------------------------------------------------------------------
-- Actor Profile aggregate: state + events
-- -----------------------------------------------------------------------------
CREATE TABLE actor_profiles_state (
  actor_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  display_name TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  xp BIGINT NOT NULL DEFAULT 0,
  rank_tier TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_actor_profiles_state_user UNIQUE (user_id)
);

CREATE TRIGGER trg_actor_profiles_state_updated_at
BEFORE UPDATE ON actor_profiles_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE actor_profiles_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_profile_id UUID NOT NULL,
  user_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_payload JSONB NOT NULL,
  event_version INTEGER NOT NULL,
  command_id UUID REFERENCES domain_commands(command_id),
  cause_type TEXT NOT NULL,
  cause_id UUID,
  correlation_id UUID NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_actor_profiles_events_profile_created_at
  ON actor_profiles_events (actor_profile_id, created_at);
CREATE INDEX idx_actor_profiles_events_correlation_id
  ON actor_profiles_events (correlation_id);

-- -----------------------------------------------------------------------------
-- Audit + outbox + projections
-- -----------------------------------------------------------------------------
CREATE TABLE audit_logs (
  audit_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  before_state JSONB,
  after_state JSONB,
  command_id UUID REFERENCES domain_commands(command_id),
  event_id UUID,
  correlation_id UUID,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_audit_logs_entity ON audit_logs (entity_type, entity_id, created_at);
CREATE INDEX idx_audit_logs_correlation_id ON audit_logs (correlation_id);

CREATE TABLE outbox_messages (
  outbox_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic TEXT NOT NULL,
  key TEXT,
  payload JSONB NOT NULL,
  headers JSONB,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'dispatched', 'failed', 'dead_letter')),
  retries INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 10,
  next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_error TEXT,
  command_id UUID REFERENCES domain_commands(command_id),
  event_id UUID,
  cause_type TEXT,
  cause_id UUID,
  correlation_id UUID,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_outbox_messages_dispatch
  ON outbox_messages (status, next_attempt_at, created_at)
  WHERE deleted_at IS NULL;

CREATE TRIGGER trg_outbox_messages_updated_at
BEFORE UPDATE ON outbox_messages
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE projection_checkpoints (
  projection_name TEXT PRIMARY KEY,
  last_event_created_at TIMESTAMPTZ,
  last_event_id UUID,
  lag_ms BIGINT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_projection_checkpoints_updated_at
BEFORE UPDATE ON projection_checkpoints
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE dead_letter_events (
  dead_letter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL,
  source_id UUID,
  payload JSONB NOT NULL,
  failure_reason TEXT NOT NULL,
  retries INTEGER NOT NULL DEFAULT 0,
  correlation_id UUID,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_dead_letter_events_updated_at
BEFORE UPDATE ON dead_letter_events
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
