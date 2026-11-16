---
id: personal-to-group-conversion-uitest-taps-the-loan-leg-bus-off-screen
status: backlog
priority: medium
area: grupos
created: 2026-11-10
updated: 2026-11-10
source: gate del lote 02 de mejoras necesarias de 2.3 (Max, simulador iPhone 17 Pro iOS 27.2)
---
# `PersonalToGroupConversionUITests.test_convertingTheBus_toAGroup` cae al buscar el «Bus»

**Medido el 2026-11-10** en la Max, corrida aislada (centinela: solo). Cae en la línea 57 (`openBusEditor`):
`Failed to not hittable: Button {{16.0, -235.3}, {370.0, 64.0}}, identifier 'record_row', label 'Bus, Ingreso, S/ 8.00,
Préstamo a grupos, Grupos PEN'`.

**No es del lote 02:** cae igual con `origin/2.3` sin sus cambios (build aparte del commit `d0360697d`, misma
máquina, mismo simulador). El otro caso de la suite (`test_cancellingTheReview_changesNothing`) pasa.

**Lo que se ve (inferido, sin aislar):** `busRow` toma el primer `record_row` cuyo texto contiene «Bus», y ese primero es
la pata «Préstamo a grupos» de un «Bus» ya convertido (ingreso de la cuenta de Grupos), que queda por encima de la
pantalla; el bucle de `swipeUp` lo aleja más en vez de traerlo. Puede depender del día (el seed fecha el «Bus» hoy) o
de lo que dejó el caso anterior de la suite.

**Para cerrarlo:** filtrar el «Bus» que no es pata de grupo (p. ej. excluir `label CONTAINS 'Préstamo a grupos'`) y
desplazar hacia donde esté la fila, no siempre hacia arriba; confirmar en la nocturna de `qa.yml` desde qué día cae.
