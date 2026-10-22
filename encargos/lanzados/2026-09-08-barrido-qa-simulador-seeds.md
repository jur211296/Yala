# Barrido QA: drenar tickets/qa/ en simulador + seeds — Jürgen solo si es imprescindible

## Contexto
Cola (Jürgen 2026-09-08 ~20:46): tras sealed #108, **antes** de retomar mediums (`bulk-update` → `fx-approx` → `bridge`).

Hay ~59 tickets en `tickets/qa/`. El skill existe: comando `/qa` (`.claude/commands/qa.md`). Modo lote por defecto.

## Que se pide
Ejecuta `/qa` (lote) sobre `tickets/qa/`:
1. Disco: `bash qa/scripts/disk-report.sh --guard` antes de empezar.
2. Simulador integrado Claude Code + XcodeBuildMCP (`Yala Dev`, iPhone 17 Pro). Seeds/launch args de `UITestHooks` (`-uitest-seed`, `-uitest-skip-onboarding`, …).
3. Ticket a ticket: leer, preparar estado, reproducir, capturar evidencia en pantalla. **PASS solo si lo viste.** FAIL → documentar, mover a `in-progress`, **no arreglar dentro de `/qa`**.
4. Actualizar frontmatter, `## QA Visual`, `docs/TICKETS.md`, coverage si aplica.
5. Al cerrar el lote: tabla ticket · veredicto · qué se vio.
6. Separar explícitamente lo que **requiere device físico / Jürgen imprescindible** (CloudKit multi-device, APNs, SIWA/Google, StoreKit real, dos teléfonos, etc.) — esa lista es la cola que él toca; no mezclarla con FAIL.
7. Objetivo de producto: **reducir al máximo el Device-QA de Jürgen**. Si es simulable con seeds, lo cierras tú.

## MODO AUTÓNOMO HASTA TERMINAR
Board, `docs/TICKETS.md`, commits de evidencia/estado, merge si hay PR de docs/board, `/cerrar-total` sin preguntar. Bugs encontrados → ticket propio en backlog (no arreglar en esta sesión salvo higiene del board). Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Cola siguiente (no la lances tú)
Tras `/cerrar-total` Frank retoma mediums: `bulk-update-account-leaves-converted-amount-stale`.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No uses `agent-device`.
- No declares PASS por inferencia de código.

## Como se sabe que esta bien
- Lote recorrido; PASS con evidencia; FAIL reabiertos; lista «requiere device / Jürgen» clara; board + índice al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario (tabla del lote + cola física); (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
