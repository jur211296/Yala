---
id: personal-to-group-conversion-uitest-taps-the-loan-leg-bus-off-screen
status: done
priority: medium
area: grupos
created: 2026-11-10
updated: 2026-11-22
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

## Cierre (2026-11-22)

Medido el 2026-11-22 (sesión nocturna «pruebas de interfaz rojas de 2.3», Max): **verde en la nocturna de 2.3 del 22-nov** (run 44991989046, sobre b27dcc084, runner del CI iOS 27.0) y **verde en local** sobre origin/2.3 = ea35c1234 (iPhone 17 Pro, iOS 27.2, `Yala Dev`, cola del simulador; 9 casos de los 8 tickets en una corrida, 9/9).

Los dos casos de la suite caían en la nocturna del 22-nov (3 de 3); el arreglo del mismo día (commit 407e1a91f, ticket `2026-11-22-pruebas-interfaz-tandas-5-6-rojo`: tocar la fila quieta y reintentar una vez) es posterior a esa nocturna. En local, con él: los dos verdes (52 s y 35 s). La confirmación en el runner del CI es la próxima nocturna. Sin cambios en este lote.
