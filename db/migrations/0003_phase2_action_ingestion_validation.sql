-- Phase 2: Action Ingestion & Validation Engine
-- Depends on: 0001_phase0_foundation.sql, 0002_phase1_progression_kernel.sql

BEGIN;

-- -----------------------------------------------------------------------------
-- Rule definitions for validation/scoring
-- -----------------------------------------------------------------------------
CREATE TABLE action_validation_rules (
  action_validation_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_code TEXT NOT NULL,
  rule_name TEXT NOT NULL,
  rule_kind TEXT NOT NULL CHECK (rule_kind IN ('eligibility', 'anti_fraud', 'confidence', 'dedup')),
  version_tag TEXT NOT NULL,
  threshold NUMERIC(8,4),
  config JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_action_validation_rules UNIQUE (rule_code, version_tag)
);

CREATE TRIGGER trg_action_validation_rules_updated_at
BEFORE UPDATE ON action_validation_rules
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Raw action capture (immutable, source-tagged)
-- -----------------------------------------------------------------------------
CREATE TABLE action_captures (
  action_capture_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  actor_profile_id UUID REFERENCES actor_profiles_state(actor_profile_id),
  source_type TEXT NOT NULL,
  source_device_id TEXT,
  source_event_id TEXT,
  captured_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  action_type TEXT NOT NULL,
  action_payload JSONB NOT NULL,
  dedup_fingerprint TEXT NOT NULL,
  ingest_status TEXT NOT NULL DEFAULT 'received'
    CHECK (ingest_status IN ('received', 'normalized', 'validated', 'resolved', 'rejected')),
  fraud_score NUMERIC(8,4) NOT NULL DEFAULT 0,
  abuse_signals JSONB,
  confidence_score NUMERIC(8,4),
  sync_batch_id UUID,
  correlation_id UUID NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_action_captures_source UNIQUE (source_type, source_event_id),
  CONSTRAINT uq_action_captures_fingerprint UNIQUE (dedup_fingerprint)
);

CREATE INDEX idx_action_captures_user_received_at ON action_captures (user_id, received_at DESC);
CREATE INDEX idx_action_captures_status_next ON action_captures (ingest_status, received_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_action_captures_correlation_id ON action_captures (correlation_id);

CREATE TRIGGER trg_action_captures_updated_at
BEFORE UPDATE ON action_captures
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Evidence attached to capture (immutable append-only)
CREATE TABLE action_evidence (
  action_evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_capture_id UUID NOT NULL REFERENCES action_captures(action_capture_id),
  evidence_type TEXT NOT NULL,
  evidence_uri TEXT,
  evidence_hash TEXT,
  metadata JSONB,
  sensor_time TIMESTAMPTZ,
  geo_lat NUMERIC(9,6),
  geo_lng NUMERIC(9,6),
  geo_accuracy_m NUMERIC(10,2),
  timezone_offset_minutes INTEGER,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_action_evidence_capture_id ON action_evidence (action_capture_id, created_at);

CREATE TRIGGER trg_action_evidence_updated_at
BEFORE UPDATE ON action_evidence
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Validation result events (immutable history)
-- -----------------------------------------------------------------------------
CREATE TABLE action_validation_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_capture_id UUID NOT NULL REFERENCES action_captures(action_capture_id),
  rule_code TEXT,
  validation_stage TEXT NOT NULL CHECK (validation_stage IN ('normalized', 'scored', 'dedup_checked', 'finalized')),
  outcome TEXT NOT NULL CHECK (outcome IN ('pass', 'fail', 'warn')),
  confidence_score NUMERIC(8,4),
  fraud_score NUMERIC(8,4),
  reasons JSONB,
  event_payload JSONB NOT NULL,
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

CREATE INDEX idx_action_validation_events_capture_created ON action_validation_events (action_capture_id, created_at);
CREATE INDEX idx_action_validation_events_correlation ON action_validation_events (correlation_id);

-- -----------------------------------------------------------------------------
-- Final resolution of action into progression or rejection
-- -----------------------------------------------------------------------------
CREATE TABLE action_resolutions (
  action_resolution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_capture_id UUID NOT NULL UNIQUE REFERENCES action_captures(action_capture_id),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  actor_profile_id UUID REFERENCES actor_profiles_state(actor_profile_id),
  resolution TEXT NOT NULL CHECK (resolution IN ('accepted', 'rejected', 'partial')),
  reason_codes JSONB,
  explainability JSONB NOT NULL,
  awarded_xp BIGINT NOT NULL DEFAULT 0,
  awarded_stat_deltas JSONB,
  resolved_by_type TEXT NOT NULL CHECK (resolved_by_type IN ('system', 'admin')),
  resolved_by UUID,
  resolved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resulting_command_id UUID REFERENCES domain_commands(command_id),
  manual_override BOOLEAN NOT NULL DEFAULT FALSE,
  correlation_id UUID NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_action_resolutions_user_resolved_at ON action_resolutions (user_id, resolved_at DESC);
CREATE INDEX idx_action_resolutions_correlation ON action_resolutions (correlation_id);

CREATE TRIGGER trg_action_resolutions_updated_at
BEFORE UPDATE ON action_resolutions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
