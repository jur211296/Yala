# Yala

<!-- INDICE:inicio — generado por scripts/indice_readme.py, no editar a mano -->

## Índice — dónde se responde cada pregunta

| Pregunta | Dónde |
|---|---|
| ¿Dónde quedó todo? ¿Qué sigue? | [`docs/ESTADO.md`](./docs/ESTADO.md) |
| ¿Por qué se decidió X? ¿Qué manda hoy? | [`docs/DECISIONS.md`](./docs/DECISIONS.md) |
| ¿Qué pasó el día X? | — *(pendiente)* |
| ¿Qué hitos y fechas hay? | — *(pendiente)* |
| ¿Cómo se trabaja aquí? Reglas duras | [`CLAUDE.md`](./CLAUDE.md) |
| ¿Esto ya nos mordió antes? | [`docs/aprendizajes-tecnicos.md`](./docs/aprendizajes-tecnicos.md) |
| ¿Qué hago si se cae en producción? | — *(pendiente)* |
| ¿Qué credenciales y dependencias hay? | — *(pendiente)* |
| ¿Qué significa este término? | [`docs/glosario.md`](./docs/glosario.md) |
| ¿Cómo arranco de cero en otra máquina? | [`docs/HANDOFF.md`](./docs/HANDOFF.md) |

> **Ficheros de más de 60 KB** — `✓` = lleva índice arriba, entra por ahí:
> ✓ `docs/DECISIONS.md` (231 KB) · ✓ `docs/aprendizajes-tecnicos.md` (172 KB) · ✓ `qa/cloud/README.md` (117 KB) · ✓ `docs/modo-nube/MODO-NUBE-DIFERIDOS.md` (113 KB) · ✓ `tickets/qa/groups-consent-door-spec.md` (96 KB) · ✓ `docs/audit/AUDIT-UI-patterns.md` (94 KB) · ✓ `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md` (93 KB) · ✓ `docs/modo-nube/_archive/groups-backend-v1.md` (72 KB) · ✓ `docs/modo-nube/_archive/fase3-medicion/fase3-REMEDICION-2026-08-04.md` (64 KB) · ✓ `docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md` (61 KB)

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
2. [`docs/ESTADO.md`](docs/ESTADO.md) — what is in progress right now

Process docs: [`docs/HANDOFF.md`](docs/HANDOFF.md) · [`docs/DECISIONS.md`](docs/DECISIONS.md) · [`docs/TICKETS.md`](docs/TICKETS.md)

Tickets live in [`tickets/`](tickets/) (folder = status).

## Marketing

Living marketing assets live in [`marketing/`](marketing/). The Yala website stays at [`Web/`](Web/).
