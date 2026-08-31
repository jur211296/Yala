---
updated: 2026-08-29
tags: [now, punto-de-retomada]
---

# NOW — 2026-08-22 (Lima)

**Rama** `2.1` · **HEAD** `f4cf3d2b` — En TestFlight build **12** (CPV 12). asc VALID `e961a77b`. El bump a `origin/2.1` lo empuja Claude (decisión 2026-08-29).
**Campo.** MARKETING 2.1. Build 11 = corte 18-ago / HEAD `af1b7350` entonces.

## Decisión (Jurgen, 17–18 ago)
- 2.0.5 no se lanza.
- Release = 2.1. A7 y M5 van en 2.1. HOLD, no flip.
- TF de 2.1 autorizado. Cada rama reinicia builds en 1.
- **Subida Yala (TF/store) = solo Mini.**

## TestFlight 2.1
- En TF: build **12** = CPV 12 = HEAD `f4cf3d2b`. asc VALID `e961a77b` (Tim/Frank 22-ago).
- A7 / M5: HOLD, no flip.

## Sesión
- Device-QA / guion: `planning/DEVICE-QA-SESION-OWNER-2026-08-18.md` (si sigue vivo).
- Cero `ok_` inventado. D-R1 sigue no ok_ sin QA device.

## Prod
- CLOUD_MODE 100
- GROUPS_BACKEND 100
- CLOUD_ONBOARDING_CHOICE 0 — A7 HOLD
- SECONDARY_SESSION 0 — M5 HOLD

## Ya en el árbol (evidencia PR / Mini)
- p20-15: merged-in-tree PR 15 @ `4bf4ead`. No `ok_` (QA visual desconocido).
- Cola A A1–A3: READY Mini 17 ago. Tickets padre siguen `qa_` (mixtos).
- Cola B: PR 17 y PR 18 merged a 2.0.5; corte 2.1. No reabrir.
- D-R1: merged-in-tree PR 19 @ `b9526c8e`. No `ok_` (QA device pendiente).

## Abierto (escrito)
- Cola C: 9 ACs owner/device, no corrida.
- A7 / M5: no flip.

## Siguiente
Sin flip A7/M5. No inventar ok_. Bump `origin/2.1` a cargo de Claude.
