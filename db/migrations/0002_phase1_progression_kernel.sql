-- Phase 1: Progression Kernel (XP, Levels, Stats, Rank)
-- Depends on: 0001_phase0_foundation.sql

BEGIN;

-- -----------------------------------------------------------------------------
-- Rules tables (versioned formulas for deterministic replay)
-- -----------------------------------------------------------------------------
CREATE TABLE level_curve_rules (
  level_curve_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT NOT NULL,
  version_tag TEXT NOT NULL,
  formula_type TEXT NOT NULL,
  formula_payload JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_level_curve_rules_version UNIQUE (rule_name, version_tag)
);

CREATE TRIGGER trg_level_curve_rules_updated_at
BEFORE UPDATE ON level_curve_rules
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE rank_tier_rules (
  rank_tier_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_code TEXT NOT NULL,
  tier_name TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  promotion_requirements JSONB NOT NULL,
  demotion_policy JSONB,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  effective_to TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_rank_tier_rules_tier UNIQUE (tier_code, effective_from)
);

CREATE TRIGGER trg_rank_tier_rules_updated_at
BEFORE UPDATE ON rank_tier_rules
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Progression profile (current derived state)
-- -----------------------------------------------------------------------------
CREATE TABLE progression_state (
  progression_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_profile_id UUID NOT NULL REFERENCES actor_profiles_state(actor_profile_id),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  total_xp BIGINT NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
  current_level INTEGER NOT NULL DEFAULT 1 CHECK (current_level >= 1),
  xp_into_level BIGINT NOT NULL DEFAULT 0 CHECK (xp_into_level >= 0),
  xp_to_next_level BIGINT NOT NULL DEFAULT 100 CHECK (xp_to_next_level > 0),
  level_curve_rule_id UUID REFERENCES level_curve_rules(level_curve_rule_id),
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_progression_state_actor UNIQUE (actor_profile_id)
);

CREATE INDEX idx_progression_state_user_id ON progression_state (user_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_progression_state_updated_at
BEFORE UPDATE ON progression_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- XP immutable history
-- -----------------------------------------------------------------------------
CREATE TABLE xp_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  progression_profile_id UUID NOT NULL REFERENCES progression_state(progression_profile_id),
  actor_profile_id UUID NOT NULL,
  user_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_payload JSONB NOT NULL,
  delta_xp BIGINT NOT NULL,
  running_total_xp BIGINT NOT NULL CHECK (running_total_xp >= 0),
  level_before INTEGER NOT NULL CHECK (level_before >= 1),
  level_after INTEGER NOT NULL CHECK (level_after >= 1),
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

CREATE INDEX idx_xp_events_profile_created_at ON xp_events (progression_profile_id, created_at);
CREATE INDEX idx_xp_events_correlation_id ON xp_events (correlation_id);

-- Canonical ledger for idempotent XP accounting
CREATE TABLE xp_ledger (
  xp_ledger_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  progression_profile_id UUID NOT NULL REFERENCES progression_state(progression_profile_id),
  actor_profile_id UUID NOT NULL,
  user_id UUID NOT NULL,
  command_id UUID NOT NULL REFERENCES domain_commands(command_id),
  source_ref TEXT NOT NULL,
  delta_xp BIGINT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cause_type TEXT NOT NULL,
  cause_id UUID,
  correlation_id UUID NOT NULL,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_xp_ledger_command UNIQUE (command_id),
  CONSTRAINT uq_xp_ledger_source_ref UNIQUE (source_ref)
);

CREATE INDEX idx_xp_ledger_profile_applied_at ON xp_ledger (progression_profile_id, applied_at);

CREATE TRIGGER trg_xp_ledger_updated_at
BEFORE UPDATE ON xp_ledger
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- Stat profiles and immutable deltas
-- -----------------------------------------------------------------------------
CREATE TABLE stat_state (
  stat_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_profile_id UUID NOT NULL REFERENCES actor_profiles_state(actor_profile_id),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  stat_key TEXT NOT NULL,
  base_value NUMERIC(18,4) NOT NULL DEFAULT 0,
  buff_value NUMERIC(18,4) NOT NULL DEFAULT 0,
  debuff_value NUMERIC(18,4) NOT NULL DEFAULT 0,
  final_value NUMERIC(18,4) GENERATED ALWAYS AS (base_value + buff_value - debuff_value) STORED,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_stat_state_actor_stat UNIQUE (actor_profile_id, stat_key)
);

CREATE INDEX idx_stat_state_user_id ON stat_state (user_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_stat_state_updated_at
BEFORE UPDATE ON stat_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE stat_delta_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stat_profile_id UUID NOT NULL REFERENCES stat_state(stat_profile_id),
  actor_profile_id UUID NOT NULL,
  user_id UUID NOT NULL,
  stat_key TEXT NOT NULL,
  delta_type TEXT NOT NULL CHECK (delta_type IN ('base', 'buff', 'debuff')),
  delta_value NUMERIC(18,4) NOT NULL,
  value_before NUMERIC(18,4) NOT NULL,
  value_after NUMERIC(18,4) NOT NULL,
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

CREATE INDEX idx_stat_delta_events_profile_created_at ON stat_delta_events (stat_profile_id, created_at);
CREATE INDEX idx_stat_delta_events_correlation_id ON stat_delta_events (correlation_id);

-- -----------------------------------------------------------------------------
-- Rank current state + immutable transitions
-- -----------------------------------------------------------------------------
CREATE TABLE rank_state (
  rank_state_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_profile_id UUID NOT NULL REFERENCES actor_profiles_state(actor_profile_id),
  user_id UUID NOT NULL REFERENCES users_state(user_id),
  current_tier_code TEXT NOT NULL,
  rank_tier_rule_id UUID REFERENCES rank_tier_rules(rank_tier_rule_id),
  promoted_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  version BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT uq_rank_state_actor UNIQUE (actor_profile_id)
);

CREATE INDEX idx_rank_state_user_id ON rank_state (user_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_rank_state_updated_at
BEFORE UPDATE ON rank_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE rank_transition_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rank_state_id UUID NOT NULL REFERENCES rank_state(rank_state_id),
  actor_profile_id UUID NOT NULL,
  user_id UUID NOT NULL,
  from_tier_code TEXT,
  to_tier_code TEXT NOT NULL,
  transition_reason TEXT,
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

CREATE INDEX idx_rank_transition_events_state_created_at ON rank_transition_events (rank_state_id, created_at);
CREATE INDEX idx_rank_transition_events_correlation_id ON rank_transition_events (correlation_id);

COMMIT;
