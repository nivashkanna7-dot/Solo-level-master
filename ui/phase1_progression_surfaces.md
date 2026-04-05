# Phase 1 UI Surfaces — Progression

## XP Bar + Level Chip
- Animated XP bar from current projection values.
- Level chip with current level and progress-to-next-level tooltip.
- Handles delayed projection updates with optimistic 'syncing' affordance.

## Stats Panel
- Show base, buffs, debuffs, and final value per stat.
- Highlight recent deltas (last N updates from delta timeline projection).
- Provide cause labels for each recent delta event.

## Rank Badge + Promotion Animation
- Display current rank tier code and badge.
- Trigger promotion animation when new rank transition event is projected.
- Include fallback static transition for low-performance/offline modes.
