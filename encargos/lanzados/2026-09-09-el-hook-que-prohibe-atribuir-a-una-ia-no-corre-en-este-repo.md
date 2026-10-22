# El candado que prohíbe atribuir un commit a una IA no está puesto en Yala

## Contexto
Ticket: `tickets/backlog/el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo.md` (high).
Cola high (Jürgen): tras ci-avisador #123. ADR-013 / hook global sustituido por `core.hooksPath` local en Yala — commits de Claude salieron con trailer y nadie los paró.

## Que se pide
AC del ticket. Si toca decisión de producto/infra de todos los agentes, pregúntala en la sesión (Frank avisa). Board + `docs/TICKETS.md`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket. Solo parar ante decisión/acceso real de Jürgen.

## Cola siguiente
Tras este high, cola high de backlog pedida: vacía (salvo nuevos). Frank avisa.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No rompas hooks de Casa/otros repos sin decisión explícita.

## Como se sabe que esta bien
- AC; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook Avisos Claude cuando: (1) decisión; (2) PR; (3) /cerrar-total con resumen; (4) idle — una vez.
