# Phase 2 — Action Ingestion & Validation Engine

## Purpose
Convert real-world actions into validated domain actions (not raw habit logs).

## Domain entities covered
- ActionCapture (`action_captures`)
- ActionEvidence (`action_evidence`)
- ActionValidationRule (`action_validation_rules`)
- ActionResolution (`action_resolutions`)

## APIs and commands
- Offline-first action capture API
- Validation service outputs (confidence + fraud metadata)
- Command: `ResolveActionToProgression`

## Primary risks
1. Over-rejection harms motivation.
2. Over-acceptance invites exploitation.

## Controls
- Thresholded confidence/fraud scoring with explicit reason codes.
- Dedup fingerprints + source event uniqueness.
- Explainable accepted/rejected/partial outcomes with audit trail.
