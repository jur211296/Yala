---
name: el-regimen-del-test-decide-que-mutante-caza
description: Un test escrito en el régimen del bug (reloj adelantado) no distingue variantes que ese régimen iguala — el mutante «estampar con ahora» sobrevivía; hace falta un caso en el régimen normal
metadata:
  type: feedback
---

Al fijar una propiedad (aquí: el HLC sale de la fecha de la transacción, que hace determinista el re-drain), el caso
tiene que vivir en un régimen donde las variantes DIVERGEN. Escribí el test de «re-drain no duplica» solo con el reloj
lógico un día por delante: ahí `max(l, pt)` da `l` sea `pt` la transacción o la hora de ahora, así que el mutante
`sendLocal(eventTime: now())` —justo la alternativa descartada en el Paso 0— salía verde. Lo cazó la lente de
regresión de la review (2026-09-26, `groups-clock-rollback-wedges-the-drain-forever`), no mis 5 mutantes.

**Why:** los mutantes que elegí atacaban lo que yo había escrito, no la alternativa que yo mismo había descartado; y el
régimen del bug es precisamente el que más colapsa el espacio de salidas.

**How to apply:** por cada alternativa que el Paso 0 descarta, un mutante que la implemente; y si sobrevive, un caso en
el régimen normal con la entrada que la separa (aquí: el `now` inyectado tres días por delante y que avanza en cada
lectura). Familia de [[la-asercion-que-no-puede-fallar]] y [[el-mutante-muere-y-el-termino-sobra]].
