---
id: group-split-lines-recipe-lost-on-payer-or-currency-change
status: done
priority: low
area: "grupos, puente"
created: 2026-11-01
updated: 2026-11-02
source: "review del encargo 2026-11-01-grupos-b-puente-y-estadisticas (Grupos B · card 2)"
---

# Las líneas de tu parte se pierden si el gasto cambia de pagador o de divisa

La receta de líneas (`TransactionItem.splitLinesRaw`) vive en la pata que el puente conserva: la real si pagaste tú
(Caso A), la virtual de «Grupos» si pagó otro (Caso B). Cuando el gasto cambia de pagador, el puente borra esa pata y crea
la del otro caso, y la receta se va con ella. Con un cambio de divisa del gasto, el Caso A también borra la pata real
(borrador «la moneda cambió»); el Caso B la conserva y la receta deja de cuadrar, con su aviso en la Bandeja.

Hoy no muerde: ninguna pantalla escribe la receta hasta las cards 4-6. Cuando las haya, la persona tendría que volver a
partir su parte tras un cambio de pagador. Opciones: trasplantar la receta a la pata nueva en la misma pasada, o avisar en
la Bandeja como con el cambio de importe (D6 del ticket `grupos-tu-parte-en-lineas`).

## Hecho (2026-11-02, encargo `2026-11-02-grupos-b-cabos-sueltos`, card sbvw)

La receta se trasplanta a la pata nueva en la misma pasada (`GroupSplitLinesTransplantLogic`, en `bridgeExpense`): de la
real a la de «Grupos» al pasar a pagar otro con el puente activo, y de la de «Grupos» a la real al pasar a pagar tú con una
cuenta. Las recargas se conservan con su entrada. En el Caso B la divisa ya no cierra la puerta: la pata se rehace en la
divisa nueva con la receta y, si no cuadra, la Bandeja avisa en la misma pasada. Tests:
`YalaTests/CloudSync/GroupBridgeSplitLinesTransplantTests.swift`.

Lo que queda: `group-split-lines-recipe-lost-when-the-new-leg-is-not-born-in-the-pass`.
