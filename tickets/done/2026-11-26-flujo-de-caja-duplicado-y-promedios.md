---
id: 2026-11-26-flujo-de-caja-duplicado-y-promedios
status: done
priority: medium
area: cash-flow
created: 2026-11-26
updated: 2026-11-27
source: encargo 2026-11-27-flujo-de-caja-duplicado-y-promedios (decisión de Jürgen del 26-nov 17:55 sobre los hallazgos de cierres: «D. Ok»)
---
# Flujo de caja: duplicado al agregar línea y desplazamiento mensual de las líneas por promedio

Hallazgos que dejaron las sesiones del replanteo de Flujo de caja:

- «Agregar línea» deja crear dos líneas sobre lo mismo (anotado en las sesiones 4 y 5).
- Las líneas por promedio de planes ya creados siguen moviéndose cada mes, y «Agregar a mi plan» desde «Otros» todavía
  crea líneas por promedio (pendiente de la «sesión 6 del replanteo»).
- El armado del plan y «Agregar línea» todavía pueden crear líneas por categoría.

## Qué se midió en `2.3` (27-nov-2026)

1. **Duplicado: seguía pasando.** «Agregar línea › Desde mis gastos» no miraba las líneas del plan: elegir una
   subcategoría que ya tenía línea creaba otra. Las cifras no se doblaban (el motor deja la segunda «repetida» y no la
   proyecta), pero la tabla enseñaba dos filas. Evidencia: `capturas/antes-*` del PR.
2. **Promedios que se mueven: es lo decidido, no un bug.** El pendiente venía de la S5 del replanteo (18-nov). Al día
   siguiente, Jürgen decidió «límites móviles» (`docs/DECISIONS.md`, 19-nov 10:21): Promedio 6 meses, Promedio 3 meses
   y Último mes se recalculan cada mes y solo «Monto fijo» deja un número quieto. Lo aplicó el encargo
   `2026-11-19-flujo-aislados-promedio-y-detalle-mes` (`tickets/done/2026-11-19-flujo-aislados-promedio-y-detalle-mes.md`),
   que además devolvió a su promedio las líneas que el P4 había congelado. Que «Otros» cree la línea por promedio es
   coherente con eso. Sin código; una prueba lo fija.
3. **Líneas por categoría: ya resuelto en la S5** (`FlujoCrearPlanLogica.porSubcategoria` en el armado y
   `awaitsSubcategory` en «Agregar línea»), con pruebas en `YalaTests/FlujoCrearPlan/`.

## Qué cambia para quien usa Yala

- En «Agregar línea › Desde mis gastos», una subcategoría (o una categoría sin subcategorías) que ya tiene su línea dice
  «En tu plan» y no se puede elegir otra vez.
- «Agregar a mi plan» desde «Otros» tampoco crea una segunda línea sobre lo mismo (también con dos toques seguidos).

## Criterio de «lo mismo»

El del motor al repartir cada movimiento (`FlujoMotorMes.Dueños`): el mismo lado (gasto o ingreso) y, en este orden, el
mismo pago planificado (en una línea de método «Pagos planificados»), la misma subcategoría, o la misma categoría sin
subcategoría. Una subcategoría junto a otra de su categoría, o junto a la categoría entera, no choca. Una línea
personalizada (sin categoría ni pago) nunca choca. Lógica en `Yala/App/Logic/FlujoLineasSinDuplicar/`; la guarda va en
`CashFlowPlanViewModel.addLine`, `promoteFromOthers` y `promoteSubcategory`.

## Pruebas

- `YalaTests/FlujoDuplicadoYPromedios/FlujoLineaDuplicadaTests`: cada camino de alta (subcategoría, categoría sin
  subcategorías, pago planificado, personalizada, «Otros» por subcategoría y por categoría) y lo que no choca.
- `YalaTests/FlujoDuplicadoYPromedios/FlujoPromediosSiguenMoviendoseTests`: un plan de noviembre que cruza a diciembre
  recalcula su promedio; «Monto fijo» no se mueve; «Otros» crea promedio.
- `YalaTests/FlujoDuplicadoYPromedios/FlujoLineasSinDuplicarTextosTests`: «En tu plan» en los 16 idiomas.
- `YalaUITests/FlujoDuplicadoYPromedios/FlujoLineaDuplicadaUITests`: la misma subcategoría dos veces; la segunda dice
  «En tu plan» y «Guardar» sigue apagado. Rojo con la build de antes.
- `YalaUITests/FlujoCrearPlan/FlujoCrearPlanUITests` (y su gemela de capturas) tocaba la primera subcategoría de la
  lista, que con la semilla ya está en el plan: ahora elige la primera que no lo está.

## Qué quedó fuera

- Abrir la línea existente desde «Agregar línea» (se avisa en la fila en vez de navegar).
- Congelar los promedios: haría falta una decisión nueva de Jürgen que sustituya la del 19-nov.
