# Commit de notas de encargos ya lanzados que quedaron sin commitear en 2.1

## Contexto
Tras el merge de PR #336 (fix CI pure-logic), el árbol principal de Yala en `2.1` tiene ~14 paths sin commitear, todos untracked. No hay cambios de app pendientes aquí: son notas de `encargos/lanzados/` de sesiones ya cerradas (2026-09-30 → 2026-10-03) y una copia vieja del ticket de investigación del ajuste en `tickets/backlog/` aunque ese ticket ya está en `tickets/done/` vía PR #334.

Cola autónoma de Frank (orden Jürgen 2026-10-02 noche): este es el paso (2) después del fix CI. Después vendrá Cola B `floating-buttons-cover-row-amounts-on-ipad-landscape`. Una sola sesión a la vez.

Base: origin/2.1 (fetch ya lo hace lanzar-sesion). Mini limpia: 0 sesiones Yala vivas, 0 sims booteados, ~34 GB libres.

## Que se pide
1. En el worktree del encargo, sobre origin/2.1: añadir SOLO los ficheros untracked de `encargos/lanzados/` que existan en el árbol principal y no estén ya en git (los de 2026-09-30 liberar-disco-mini-r3, 2026-10-01 groups-purge / list-column, 2026-10-02 a-failed-snapshot / adjustment / ai-chat / associate-cta / ipad-large-widgets / needsrelaunch / onboarding-login / settings-redesign / step-flows, 2026-10-03 fix-ci-pure-logic). Comprueba con `git status` en el checkout principal o copia esos paths al worktree si el lanzamiento no los trajo.
2. Del ticket `adjustment-hides-new-month-activity-from-available-and-widget`: NO lo vuelvas a meter en backlog. Ya está en `tickets/done/` por #334. Si en el árbol principal sigue una copia en `tickets/backlog/`, bórrala en este PR (deja solo `done`). No toques el correo personal ni inventes reply de soporte.
3. Commit claro (docs/chore) + PR a 2.1 con auto-merge si el repo lo permite. Sin cambios de código de app, sin tests nuevos, sin gate de UI.
4. `/cerrar-total` autónomo al terminar. Mini limpia: sin sim (este encargo no necesita sim), quitar worktree si el PR mergea, matar tmux al cierre.

## Que NO hay que tocar
Código de la app, marketing, Cola B de producto, otros tickets de backlog, Secrets, correo de soporte, merges a mano si auto-merge basta. No abras simulador. No commits que mezclen basura de `.DS_Store` u otros paths ajenos.

## Como se sabe que esta bien
- `git status` del principal (o del worktree mergeado) ya no lista esos `encargos/lanzados/` untracked ni el adjustment duplicado en backlog.
- PR abierto a 2.1 (o mergeado) solo con docs de encargos + limpieza del ticket duplicado.
- Mini limpia al cerrar.
