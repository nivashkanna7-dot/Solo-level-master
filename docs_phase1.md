# Phase 1 — Progression Kernel (XP, Levels, Stats, Rank)

## Purpose
Create deterministic progression math and immutable history for all growth changes.

## Domain entities covered
- ProgressionProfile (`progression_state`)
- XpLedgerEntry (`xp_ledger`)
- StatProfile (`stat_state`)
- StatDelta (`stat_delta_events`)
- RankTier (`rank_state` + `rank_transition_events`)
- LevelCurve (`level_curve_rules`)

## Commands
- `GrantXP`
- `AdjustStat`
- `PromoteRank`

## Query surfaces
- Current XP/level/rank/stats
- Delta timeline across XP/stat/rank changes

## Primary risks
1. Formula patching may break historical continuity.
2. Double-application of XP on sync conflicts.

## Controls
- Versioned rules with effective windows and replay pinning.
- Unique XP ledger guards on both `command_id` and business `source_ref`.
