# Solo Level Master — Platform Foundation

This repository contains production-safe scaffolding for a command/event-driven platform.

## Phase 0 guardrails (implemented)
- **All writes are command-only** (no direct mutable state writes from UI/read APIs)
- **State and events are physically separated** (`*_state` vs `*_events`)
- **Auditability and causality** are first-class (`AuditLog`, command ledger, event causality)
- **Soft-deletes are enforced consistently** (`deleted_at` columns on mutable state)
- **Outbox pattern is mandatory** for side effects and projections
- **Projection consistency pipeline is explicit and replay-friendly**

## Phase 1 progression kernel (implemented scaffold)
- XP / level / rank / stat persistence model with immutable deltas
- Versioned formula tables for level curves and rank requirements
- Command/query API contracts for progression operations
- Replay-safe progression ledger and integrity constraints

## Phase 2 action ingestion & validation (implemented scaffold)
- Immutable raw action capture + evidence model
- Validation rules and result event history with confidence/fraud metadata
- Resolution model for accepted/rejected/partial outcomes with explainability
- Offline-first capture and auditable resolution-to-progression command contracts

## Repository layout

- `db/migrations/0001_phase0_foundation.sql`: core OLTP schema and guardrails
- `db/migrations/0002_phase1_progression_kernel.sql`: progression domain schema
- `db/migrations/0003_phase2_action_ingestion_validation.sql`: action ingestion/validation schema
- `api/openapi/command-gateway.yaml`: command gateway + progression/action endpoints
- `workers/phase0_pipeline.md`: outbox/projection/dead-letter baseline
- `workers/phase1_progression_workers.md`: progression workers and integrity checks
- `workers/phase2_action_validation_workers.md`: deferred validation, normalization, anti-abuse pipeline
- `ui/phase0_surfaces.md`: phase 0 shell/onboarding surfaces
- `ui/phase1_progression_surfaces.md`: progression HUD surface definitions
- `ui/phase2_action_surfaces.md`: action inbox/results/admin override surfaces
- `tests/phase0_test_strategy.md`: phase 0 validation plan
- `tests/phase1_test_strategy.md`: progression kernel test plan
- `tests/phase2_test_strategy.md`: action validation test plan

## Non-negotiable invariants
1. Every externally initiated write must create a `domain_commands` row.
2. A command may emit one or more immutable domain events.
3. Current state tables may only change inside command handlers or projection workers.
4. Every mutable state change must include actor and version metadata.
5. Side effects leave through `outbox_messages` only.
6. All projection progress is checkpointed and replayable.
7. Progression changes must emit immutable delta history with causality.
8. Action resolutions must be explainable, auditable, and deduplicated.
