# Handoff

Session start from a clean clone. Do not use Obsidian / YalaWiki as SSOT.

## Repo

- **Remote:** `jur211296/Yala`
- **Branch:** `2.1`
- **HEAD:** `f4cf3d2b` — Build 12 para TestFlight de 2.1
- **Product:** MARKETING_VERSION 2.1, CURRENT_PROJECT_VERSION 12

## TestFlight


## SSOT

This repo. Tickets live in `tickets/` (index: `docs/TICKETS.md`). Process: this file and `docs/DECISIONS.md`. There is no state file since 2026-09-30 (ADR-053 in casa): what happened lives in the merged PRs, what is in progress in `tickets/in-progress/`, and what waits for Jürgen on the board (`tablero listar --proyecto yala --asignado jurgen`).

Ticket bodies are now in the tree under `tickets/<status>/`. `docs/DECISIONS.md` is the vault decision log. Source: `jur211296/YalaWiki` @ `1934e8ad`.

## HOLD

Do not ship / do not close these without the owner:

- store
- tag
- A7
- M5

Instagram / Spark / marketing moves are a later PR. Do not delete them here.

## Next session

1. Run `/abrir`, and read `docs/TICKETS.md`.
2. Work from `tickets/<status>/`, not from iCloud.
3. Do not invent PASS or close tickets.
