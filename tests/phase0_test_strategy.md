# Phase 0 Test Strategy

## Contract tests (Command API)
- Validate required command DTO fields and schema failures.
- Verify idempotency behavior:
  - Same key + same payload => same command result
  - Same key + different payload => `409`

## Migration tests
- Apply migration on clean database.
- Roll forward with seed commands/events.
- Verify all required tables/columns/constraints/triggers exist.

## Event/Projection consistency tests
- Emit deterministic event sequence and assert projected read-model values.
- Replay from zero checkpoint and compare with live projection.
- Validate causality fields (`cause_type`, `cause_id`, `correlation_id`) are present.

## Chaos tests (Outbox retries)
- Inject transient queue failures and verify retry/backoff updates.
- Force permanent failure and ensure dead-letter transition occurs.
- Confirm replay restores expected projection state.

## Definition of done gates
- Every write path tested to pass through command handler.
- Physical separation between event and state tables verified.
- Soft delete and audit log enforcement validated on mutable aggregates.
- Outbox + projection workers green in staging smoke test.
