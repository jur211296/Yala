# La marca de aproximado no llega a las superficies secundarias

## Contexto
Cola mediums (Jürgen 2026-09-08, bypass autónomo). Tras #110 (bulk-update-account, mergeado a 2.1) sigue éste → `bridge-de-grupos-pierde-la-marca-de-sus-patas`.

Ticket: `tickets/backlog/fx-approximate-mark-missing-on-secondary-surfaces.md` (medium; currency). Sale de review adversarial de `fx-presentation-still-shows-1to1`: los cuatro totales grandes ya llevan «≈»; otras pantallas pintan los mismos importes sin la marca.

Quien recibe ARRANCA EN CONTEXTO LIMPIO.

## Que se pide
1. Leer el ticket (tabla de superficies, ficheros y fuentes del número).
2. Cablear la marca en las superficies de la tabla, o dejar escrito por qué una no debe llevarla. Empezar por `CashFlowWidget` (su summary ya trae la señal).
3. Source-scan al molde de `ApproximateMarkWiringTests` que falle si alguna pierde el cableado.
4. Board + `docs/TICKETS.md` al día; hallazgos → ticket propio.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No uses `agent-device`.
- No ensanches a `fx-manual-writes-seal-approximate-as-final` ni a `fx-widget-drops-missing-currency` (son otros tickets / decisiones).

## Como se sabe que esta bien
- AC del ticket en verde (superficies con marca o justificación + CashFlowWidget primero + source-scan).
- Board e índice al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni ruido de CI advisory.
