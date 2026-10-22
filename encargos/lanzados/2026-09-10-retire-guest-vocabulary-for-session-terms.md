# Implementar ticket paso 0: retire-guest-vocabulary-for-session-terms

## Contexto
Cola autónoma del rediseño de sesiones (Jürgen 2026-09-10). Orden: runbook `tickets/backlog/session-redesign-implementation-order.md`. Este es el **paso 0**.

Decisiones YA tomadas: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** al final del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan** sobre el cuerpo del ticket y el ADR.

MODO AUTÓNOMO HASTA TERMINAR: gate/commit/docs/board/`docs/TICKETS.md`/merge y `/cerrar-total` sin preguntar. Bugs o decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Ambigüedad NUEVA de producto: elige la opción más segura alineada con esas Decisiones, regístrala en el ticket, y sigue — no pares a preguntar a Jürgen salvo credencial/DDL/acceso real o destrucción de datos de prod.

Avisos a Frank (webhook): (1) decisión/acceso real de Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de producto; (4) idle sin siguiente paso — una vez. No avises por test rojo a reclasificar ni CI advisory.

## Que se pide
1. Lee ANTES: Decisiones del ticket → ADR sesiones dos ejes → runbook (solo este paso) → ticket entero.
2. Implementa SOLO este ticket (docs/glosario/rules según alcance). Docs puro: sin gate si el ticket lo dice; un PR a `2.1`.
3. No toques los strings ES de WelcomeGroupsGateView (van con el barrido del paso 12).
4. Al cerrar: board + `docs/TICKETS.md` al día; matriz/coverage solo si aplica a este paso; `/cerrar-total`.

## Que NO hay que tocar
Código de producto del rediseño (pasos 1–13). marketing/. Identificadores Swift (van con shell-derives). Otros tickets en paralelo.

## Como se sabe que esta bien
Checklist del ticket cumplido; glosario con los dos vocabularios + [I][P][G] + históricos; PR mergeado a `2.1`; worktree limpio vía `/cerrar-total`.
