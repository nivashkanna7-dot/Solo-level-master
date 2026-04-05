# Phase 1 Test Strategy — Progression Kernel

## Property-based tests
- Validate XP->level boundary calculations across broad numeric ranges.
- Ensure monotonicity for non-negative XP grants.
- Verify negative XP adjustments never produce invalid state (`total_xp < 0`).

## Idempotent resubmit tests
- Re-submit `GrantXP` with same idempotency key and payload => same result.
- Re-submit `GrantXP` with same business `sourceRef` => deduplicated ledger entry.
- Re-submit with key collision + payload mismatch => conflict.

## Deterministic replay tests
- Rebuild progression state from `xp_events`, `stat_delta_events`, and `rank_transition_events`.
- Assert replay output exactly matches `progression_state`, `stat_state`, and `rank_state`.
- Repeat replay with formula version pinning to ensure stable historical continuity.

## Projection freshness tests
- Validate HUD projections update after event emission within target SLA.
- Confirm delta timeline ordering and cursor pagination correctness.

## Integrity checker tests
- Inject malformed rows violating non-negative assumptions and verify anomaly capture.
- Simulate sync conflict duplications and ensure duplicate-application detection.
