# Phase 2 UI Surfaces — Action Validation

## Action Inbox (Pending Validation)
- Queue of captures awaiting validation or review.
- Shows action type, capture timestamp, confidence/fraud indicators, and current ingest status.
- Supports offline sync burst indicators when many captures arrive together.

## Result Cards (Accepted / Rejected / Partial)
- Card view of resolved actions with explainability reasons.
- Displays awarded XP/stat deltas for accepted or partial resolutions.
- Shows clear rejection rationale to preserve trust and motivation.

## Manual Review / Override (Admin/Internal)
- Internal panel for high-risk or ambiguous captures.
- Allows override with mandatory reason and audit trail.
- Emits explicit override resolution command with causality.
