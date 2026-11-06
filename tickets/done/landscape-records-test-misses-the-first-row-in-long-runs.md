---
id: landscape-records-test-misses-the-first-row-in-long-runs
status: done
priority: low
area: "testing, records"
created: 2026-10-14
updated: 2026-11-05
source: "gate del lote 9 de la auditoría UX 2.2 (presupuestos), 2026-10-14"
---

# `IPhoneLandscapeUITests#test_shortHeight_recordsHeaderLeavesTheFirstRowInView` falla a veces en su primer paso

Medido el 2026-10-14 (iPhone 17 Pro, iOS 27.0, centinela en 0, solo en el simulador): en una corrida de 53 casos de
13 suites cayó con «No hay filas de registro» —la primera fila de Registros no apareció en 15 s tras el deeplink
`records` con el corpus `realista`—, y aislado pasó 2 de 2 (13,9 s y 14,7 s). El cambio del lote no toca Registros. El
plazo de 15 s va justo para el corpus `realista` en una corrida larga.

## Hecho cuando

El caso pasa 5 de 5 dentro de una corrida larga (por ejemplo, con `waitForUITestReady` antes de buscar la fila, o un
plazo acorde al corpus), o se explica por qué no.

## 2026-11-05 · cerrado en el lote T3

El plazo de la primera fila con el corpus `realista` pasa de 15 a 30 s (`firstRowTimeout`), en los tres casos del fichero
que lo esperaban, no solo en este. En el iPhone SE girado el caso caía siempre por otra cosa —la fila no asoma bajo la
fila de acciones—; Jürgen decidió el 5-nov dejarlo así y el caso se salta en el SE citando
`records-landscape-first-row-only-peeks`. Verde 3 de 3 en el 17 Pro y en el lote (que incluye el fichero entero).
