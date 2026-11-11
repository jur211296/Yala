---
id: report-comparative-exact-range-and-first-week-income-2-3
status: done
priority: medium
area: "reportes, flujo-de-caja"
created: 2026-11-11
updated: 2026-11-11
source: revisión 2.3, decisiones 32 y 33 del 9-nov (docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md; ficha docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md, problemas 6 y 7), card tablero-2-3-flujo-de-caja-la-comparativa-a-media-d7c8
---
# Comparativa con el tramo exacto y primera semana sin «Te faltan»

Los dos seguían vivos en `origin/2.3` el 2026-11-11, y 2.2 no los tocó (`git log origin/2.3..origin/2.2` sin cambios en
Reportes ni en Flujo de caja).

## 1 · La Comparativa (decisión 32, opción A + B)

Antes, el día 7 la frase decía «Noviembre comparado con el 1–7 de octubre» y la columna se llamaba «Noviembre», aunque
las cifras eran del 1 al 7. Las variaciones mezclaban «= +0 %» y «N/A», y la tabla abría con dos filas.

- Con el período en curso («Este mes», «Esta semana», «Este año»), el período se nombra por el tramo que entra: la
  columna dice «1–7 nov», la frase «1–7 de noviembre comparado con el 1–7 de octubre» y el pie del neto «El 1–7 de
  octubre te quedaron…». El tramo acaba el último día con movimientos, igual que el anterior con el que se compara
  (`ComparativeLabelsLogic.elapsedInterval`, misma puerta que `DateAlignmentHelper`). Mes pasado, rodantes y rango propio
  no cambian.
- El chip de cambio de esta tabla dice «igual» y «nuevo» (`VariationChip(usesWords:)`); el resto de la app sigue igual.
- Abre desglosada por categoría (`ReportGroupingState.defaultDimensions`) y, con algo con qué comparar, las filas van por
  cambio en soles de más a menos (`PivotTableCalculator.buildTree(sortsByChange:)`); «Ingresos» sigue arriba.

## 2 · La primera semana sin ingresos (decisión 33, opción A)

Antes, con una semana de datos, el armado no tenía «Lo que entra» y el resumen terminaba en «Te faltan al mes S/ 2,573».

- Sin ninguna línea de ingreso que sugerir, el armado pregunta «¿Cuánto recibes al mes?» y ofrece «Aún no lo sé». Hasta
  contestar no hay resumen ni «Crear mi plan».
- La cifra se escribe en la hoja de monto del saldo inicial. Entra en el plan como línea de ingreso manual atada a la
  categoría de ingresos de la persona (`CashFlowSetupLogic.typedIncomeCategory`): sin categoría, el sueldo real se
  habría sumado dos veces, en esa línea y en «otros ingresos».
- Con «Aún no lo sé», el resumen dice «Gastos al mes» y «Falta tu ingreso», sin cifra.

## Fuera, a propósito

- Debajo de cada monto sigue «en 1–7 oct.», decisión L18-3 de 2.2; la maqueta decía «antes», la decisión 32 no.
- «−100 %» no estaba en la decisión.
- «Te sobran al mes» del resumen no se tocó (el vocabulario lo cambia el lote de la decisión 30).

## Pruebas

- Unit: `YalaTests/Revision23FlujoComparativaTests` (rótulos con fechas fijas, orden por cambio con el caso de la
  maqueta y su control por monto, agrupación por defecto, la pregunta del ingreso y la línea al crear el plan).
- XCUITest: `YalaUITests/Revision23FlujoComparativaUITests`, un caso por punto, rojo en la base y verde con el arreglo.
