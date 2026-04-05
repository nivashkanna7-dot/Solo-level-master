# Phase 1 Workers — Progression Kernel

## 1) Formula Recalculation Worker

Purpose:
- Recompute derived progression totals when level/rank formulas are updated.

Responsibilities:
- Detect active rule version changes in `level_curve_rules` / `rank_tier_rules`.
- Recalculate `progression_state` fields (`current_level`, `xp_into_level`, `xp_to_next_level`) deterministically.
- Emit compensating progression events and enqueue outbox notifications.
- Mark all recalculation events with `cause_type='formula_recalculation'`.

Safety:
- Batch by actor profile with checkpoint commits.
- Avoid non-deterministic math; pin rule version per batch.

## 2) Progression Projection Builder

Purpose:
- Build near-real-time HUD read models (XP bar, level chip, stats panel, rank badge).

Responsibilities:
- Consume `xp_events`, `stat_delta_events`, and `rank_transition_events` in order.
- Update projection stores for current progression and delta timeline.
- Track lag and position in `projection_checkpoints`.

## 3) Progression Integrity Checker

Purpose:
- Detect data invariants drift and replay hazards.

Checks:
- `total_xp >= 0`, `current_level >= 1`, `xp_to_next_level > 0`.
- XP ledger uniqueness (`command_id`, `source_ref`) remains intact.
- Running totals in `xp_events` align with `progression_state.total_xp`.
- No duplicate command application across sync retries.

Failure handling:
- Publish anomaly events to dead-letter with correlation metadata.
- Open replay task scoped by aggregate/correlation window.
