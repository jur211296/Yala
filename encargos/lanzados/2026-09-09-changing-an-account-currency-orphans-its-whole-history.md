# Cambiar la divisa de una cuenta deja todo su histórico en la divisa vieja

## Contexto
Ticket: `tickets/backlog/changing-an-account-currency-orphans-its-whole-history.md` (high).
Cola high autónoma (Jürgen 2026-09-09): este → luego `ci-avisador-de-rojos-advisory-tiene-la-clave-mal` → luego `el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo`. Frank lanza el siguiente al /cerrar-total; tú no lances el siguiente.

## Que se pide
AC del ticket. Si necesitas decisión de producto, pregúntala en la sesión (Frank avisa a Jürgen). Board + `docs/TICKETS.md`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- AC; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini cuando: (1) decisión/acceso; (2) PR abierto; (3) /cerrar-total con resumen; (4) sin siguiente — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
