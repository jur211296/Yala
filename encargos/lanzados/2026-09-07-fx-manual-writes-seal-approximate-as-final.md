# Diez escrituras sellan como definitiva una tasa que fue aproximada

## Contexto
Ticket: `tickets/backlog/fx-manual-writes-seal-approximate-as-final.md` (high).

Hallazgo de camino en fx-presentation-still-shows-1to1: `CurrencyConverter.convert` tira la calidad; diez sitios escriben `amountInPreferredCurrency` a mano con `isExchangeRateProvisional = false` aunque la tasa fuera aproximada. El reparador solo mira `== true` y nunca las toca.

Cola high autónoma (Frank): tras /cerrar-total → unit-suite-nondeterministic-reds → rojo-xcuitest-runner-muere-tras-el-primer-caso → (web DNS solo prep; dead-end owner espera decisión Jürgen).

## Que se pide
Implementar según ticket + AC: que esas escrituras (creación/edición, transferencias, drafts, etc.) preserven/marquen provisionalidad cuando la tasa no es del día; el reparador pueda retocarlas. Board + `docs/TICKETS.md` al día. Device-QA documentado si aplica.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No reabrir fx-partial-rate-rows / fx-presentation salvo colisión real.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
