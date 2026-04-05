# Phase 2 Test Strategy — Action Ingestion & Validation

## Rule engine matrix tests
- Validate each `action_validation_rule` kind across pass/fail/warn outcomes.
- Verify confidence threshold behavior around boundary values.
- Verify explainability payload completeness for every rejection/partial.

## Adversarial input tests
- Submit duplicated payloads with altered metadata to probe dedup.
- Simulate spoofed geo/time/sensor combinations.
- Validate cheat-detection signals and escalation behavior.

## Idempotency and dedup tests
- Repeat offline uploads with same `dedupFingerprint` and source IDs.
- Ensure no double resolution into progression commands.
- Ensure replayed submissions preserve original resolution.

## Offline burst latency tests
- Ingest high-volume sync burst and measure capture->resolution latency.
- Validate worker backpressure and queue drain behavior under spikes.
- Ensure SLAs for inbox freshness and result card availability.

## Auditability tests
- Verify accepted/rejected/partial paths all persist actionable reason codes.
- Verify manual overrides require reason and identity, and produce audit logs.
- Verify end-to-end causality linkage from capture to resulting command/event.
