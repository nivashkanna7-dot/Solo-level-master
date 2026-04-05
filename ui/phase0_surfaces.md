# Phase 0 UI Surfaces

## App Shell
- Dark cinematic base theme
- Global top bar:
  - Sync status pill (`Synced` / `Syncing` / `Offline`)
  - Connection/offline icon

## Login + Onboarding
- Login form with local or provider-based auth entry point.
- Onboarding step for RPG display name capture.
- All actions submit command DTOs through command gateway.

## Minimal Profile HUD
- Display name
- Level placeholder (defaults to `1`)
- Last sync timestamp

## Offline UX Baseline
- Queue commands client-side when offline.
- Show pending command count.
- Attempt refresh token policy before forcing re-auth.
