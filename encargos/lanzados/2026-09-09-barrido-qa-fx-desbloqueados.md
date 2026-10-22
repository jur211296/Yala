# Tanda /qa: cosechar el seed foreign-account (#114) — FX desbloqueados en simulador

## Contexto
Jürgen 2026-09-09: tras #114 (`-uitest-seed-foreign-account <ISO>`), cosechar los tickets de FX que ya no esperan montaje.

ESTADO (2026-09-09):
- Salen enteros (simulador): `fx-presentation-still-shows-1to1` (+ lo que #114 diga cerrable del todo; verificar board — `fx-approximate-mark-missing-on-secondary-surfaces` puede ya estar en done/qa).
- Necesitan **más seed, no teléfono**: `bridge-de-grupos-pierde-la-marca-de-sus-patas` (dos patas con coberturas distintas), `chat-rows-sealed-before-the-fix-have-no-repair-path` (fila envenenada `exchangeRate = 1.0`).
- Siguen fuera del simulador por causa propia (red / LLM real): no los fuerces a PASS; déjalos en «requiere red/LLM» o documenta el bloqueo.
- Highs aún en qa/ relacionados: `fx-manual-writes-seal-approximate-as-final`, `fx-partial-rate-rows-silent-1to1`, `approximate-mark-ors-over-whole-period` — intenta con el seed nuevo; si no alcanzan, seed más rico o lista «necesita X».

Skill: `/qa` (`.claude/commands/qa.md`). Launch arg nuevo: `-uitest-seed-foreign-account <ISO>` (p.ej. JPY). Regla #114: fixtures de marca deben pasar por `recalculatePreferredCurrency`; peso de marca es proporción derivada de preferida.

## Que se pide
1. Disco: `bash qa/scripts/disk-report.sh --guard`.
2. Barrido `/qa` centrado en la familia FX desbloqueada (lista arriba + cualquier otro en `tickets/qa/` que diga bloqueado por foreign account / falta divisa fuera de fila).
3. PASS solo con evidencia en pantalla. FAIL → `in-progress` + notas; no arreglar producto dentro de `/qa` salvo seeds/hooks de test necesarios para el veredicto.
4. Si hace falta **seed más rico** (bridge patas, chat sealed): impleméntalo en esta sesión (DEBUG / launch args), documenta, y vuelve a verificar — eso sí es el trabajo.
5. Tabla final: ticket · veredicto · qué se vio. Separar «requiere red/LLM/device físico / Jürgen».
6. Board + `docs/TICKETS.md` + capturas.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No uses `agent-device`.
- No declares PASS por inferencia de código.

## Como se sabe que esta bien
- Familia FX recorrida; PASS con evidencia / FAIL reabiertos / bloqueos claros; seeds extra si hacían falta; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario (tabla + qué queda); (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
