# Un gasto de grupo puede salir «exacto» aunque el 90 % venga de tasa dudosa

## Contexto
Cola mediums (Jürgen 2026-09-08, bypass autónomo). Tras #111/#112 (fx-approximate-mark en superficies secundarias, mergeados a 2.1) cierra la familia de la marca: éste.

Ticket: `tickets/backlog/bridge-de-grupos-pierde-la-marca-de-sus-patas.md` (medium; groups, currency, fx). Sale de review adversarial de `approximate-mark-ors-over-whole-period`: `GroupBridgeStatsAdjustment` sintetiza `preferred = pata real + Σ patas de préstamo` y las patas de préstamo están suprimidas del recorrido, así que su `isExchangeRateProvisional` no lo lee nadie. Con el umbral (cociente) esto no solo pierde la marca: desplaza el umbral del bucket entero.

Quien recibe ARRANCA EN CONTEXTO LIMPIO: no ve nuestra conversación.

## Que se pide
1. Leer el ticket (caso −1000 exacto + +900 provisional → −100 contado 100 % exacto).
2. Que la síntesis del bridge propague la marca de **todas** las patas que contribuyen al importe (hermano de `amountInPreferredCurrency(_:)` que también diga si alguna pata era provisional); los calculadores deben usarlo cuando hay `adjustment`.
3. Test con `adjustment` distinto de `.none` en `ApproximateAmountMarkTests` (hoy no hay ninguno).
4. Board + `docs/TICKETS.md` al día; hallazgos → ticket propio (`--solo-crear` / fichero en tickets/).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice = disco), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No uses `agent-device`.
- No ensanches a `fx-historical-balance-curve-unmarked` ni a `records-summary-mixes-preferred-currencies` (son otros tickets; quedan en backlog).
- No cambies el importe mostrado, solo su marca.

## Como se sabe que esta bien
- AC del ticket: gasto de grupo con pata real exacta + pata de préstamo provisional cuenta como aproximado en el numerador del umbral; test con `adjustment` ≠ `.none`; importe igual.
- Board e índice al día; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
