# Yala

<!-- INDICE:inicio — generado por scripts/indice_readme.py, no editar a mano -->

## Índice — dónde se responde cada pregunta

| Pregunta | Dónde |
|---|---|
| ¿Dónde quedó todo? ¿Qué sigue? | — *(pendiente)* |
| ¿Por qué se decidió X? ¿Qué manda hoy? | [`docs/DECISIONS.md`](./docs/DECISIONS.md) |
| ¿Qué pasó el día X? | — *(pendiente)* |
| ¿Qué hitos y fechas hay? | [`docs/ROADMAP.md`](./docs/ROADMAP.md) |
| ¿Cómo se trabaja aquí? Reglas duras | [`CLAUDE.md`](./CLAUDE.md) |
| ¿Esto ya nos mordió antes? | [`docs/aprendizajes-tecnicos.md`](./docs/aprendizajes-tecnicos.md) |
| ¿Qué hago si se cae en producción? | — *(pendiente)* |
| ¿Qué credenciales y dependencias hay? | — *(pendiente)* |
| ¿Qué significa este término? | [`docs/glosario.md`](./docs/glosario.md) |
| ¿Cómo arranco de cero en otra máquina? | [`docs/HANDOFF.md`](./docs/HANDOFF.md) |

> **Ficheros de más de 60 KB** — `✓` = lleva índice arriba, entra por ahí:
> ✓ `.claude/rules/swiftdata-cloudkit.md` (340 KB) · ✓ `docs/DECISIONS.md` (280 KB) · ✓ `docs/aprendizajes-tecnicos.md` (218 KB) · ✓ `qa/cloud/README.md` (174 KB) · ✗ `docs/TICKETS.md` (154 KB) · ✗ `.claude/rules/swiftui-ds.md` (115 KB) · ✓ `docs/modo-nube/MODO-NUBE-DIFERIDOS.md` (113 KB) · ✓ `tickets/done/groups-consent-door-spec.md` (99 KB) · ✓ `docs/audit/AUDIT-UI-patterns.md` (94 KB) · ✓ `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md` (94 KB) · ✗ `docs/ux/mapa-de-flujos-2.2.md` (92 KB) · ✓ `docs/modo-nube/_archive/groups-backend-v1.md` (72 KB)

<!-- INDICE:fin -->

Personal finance app for iOS.

## Stack

- Swift, SwiftUI, SwiftData
- **Target iOS 26+**
- Simulator: iPhone 17 Pro

## Schemes

| Scheme | Use |
|--------|-----|
| **Yala** | Production |
| **Yala Dev** | Development (`DEV_BUILD`, Pro toggle) |
| **YalaTests** | Unit tests (Swift Testing) |

## Start here

1. [`CLAUDE.md`](CLAUDE.md) — agent contract, inviolable rules, workflow
2. `/abrir` — what is in progress right now. There is no state file since 2026-09-30: `/abrir` rebuilds it from the last merged PRs, `tickets/in-progress/` and Jürgen's cards on the board

Process docs: [`docs/HANDOFF.md`](docs/HANDOFF.md) · [`docs/DECISIONS.md`](docs/DECISIONS.md) · [`docs/TICKETS.md`](docs/TICKETS.md)

Tickets live in [`tickets/`](tickets/) (folder = status).

## Marketing

Living marketing assets live in [`marketing/`](marketing/). The Yala website stays at [`Web/`](Web/).
