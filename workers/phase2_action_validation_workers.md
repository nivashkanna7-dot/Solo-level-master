# Phase 2 Workers — Action Ingestion & Validation

## 1) Deferred Validation/Scoring Worker

Purpose:
- Process raw captures asynchronously and compute confidence/fraud signals.

Responsibilities:
- Pull `action_captures` with `ingest_status in ('received','normalized')`.
- Execute active `action_validation_rules` by rule-kind pipeline.
- Emit `action_validation_events` for each stage (normalized/scored/dedup/finalized).
- Update capture `confidence_score`, `fraud_score`, `abuse_signals`, and ingest status.

## 2) Evidence Normalization Worker

Purpose:
- Normalize sensor and context metadata for consistent rule evaluation.

Responsibilities:
- Convert times to canonical UTC + preserve source offset.
- Validate and normalize geo/sensor metadata.
- Attach derived metadata back into evidence records.
- Mark normalization causality in validation events.

## 3) Duplicate/Cheat Detection Pipeline

Purpose:
- Detect replayed or suspicious action submissions before progression impact.

Responsibilities:
- Enforce `dedup_fingerprint` and source event uniqueness constraints.
- Detect burst anomalies and impossible sensor trajectories.
- Raise abuse signals and reject/partial outcomes when thresholds exceeded.
- Route high-risk captures to manual review queue.

## 4) Resolution Command Emitter

Purpose:
- Convert validated outcomes into domain commands (`ResolveActionToProgression`).

Responsibilities:
- Produce `domain_commands` with full causality + correlation metadata.
- Ensure accepted outcomes map deterministically to progression deltas.
- Ensure rejected outcomes produce explainability payload and audit logs.
