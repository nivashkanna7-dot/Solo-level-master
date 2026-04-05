# Phase 0 — Platform Skeleton & Guardrails

## Purpose
Establish immutable and auditable write architecture with command-first flows, event/state separation, and projection consistency.

## Dependencies
- Identity provider integration (or local auth fallback)
- SQL migration framework (e.g., Flyway/Liquibase/DbMate)
- Queue/worker runtime for outbox dispatch and projection processing

## Primary risks
1. Incomplete causality metadata, making incident tracing impossible.
2. Event schema drift between command handlers and consumers.
3. Projection race conditions causing stale or divergent read models.

## Risk controls
- Make causality fields mandatory in command/event contracts.
- Version all event schemas and enforce compatibility tests.
- Use ordered event consumption and checkpoint writes with row-level locking.
