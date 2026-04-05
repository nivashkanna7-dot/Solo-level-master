# Phase 0 Workers & Background Processing

## 1) Outbox Dispatcher

Responsibilities:
- Poll `outbox_messages` where `status='pending'` and `next_attempt_at <= now()`.
- Acquire row lock (`FOR UPDATE SKIP LOCKED`) to avoid duplicate dispatch.
- Publish message to queue/topic.
- Update status:
  - `dispatched` on success
  - `failed` with exponential backoff on transient error
  - `dead_letter` when retries exceed `max_retries`

Safety guardrails:
- Keep dispatch idempotent by using `outbox_message_id` as delivery key.
- Emit audit row for all state transitions.

## 2) Projection Updater

Responsibilities:
- Consume domain events in causal/time order.
- Update read models from append-only events only.
- Persist progress in `projection_checkpoints`.

Consistency rules:
- Never read directly from `*_state` to derive projections (event-first).
- On projection failure, move event to dead-letter channel with correlation metadata.
- Support deterministic replay from checkpoint or from origin.

## 3) Dead-Letter Handler + Replay Tooling

Responsibilities:
- Inspect `dead_letter_events` and classify root cause.
- Allow selective replay by `correlation_id`, aggregate, or time window.
- Write replay commands/events with explicit replay causality (`cause_type='replay'`).

Operational SLIs:
- Outbox lag (`now - oldest pending created_at`)
- Projection lag (`lag_ms` in `projection_checkpoints`)
- Dead-letter growth rate and replay success rate
