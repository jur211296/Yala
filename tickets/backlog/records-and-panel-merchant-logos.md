---
id: records-and-panel-merchant-logos
status: backlog
priority: medium
area: "records, panel, statistics"
created: 2026-11-17
updated: 2026-11-17
source: "encargo logos reales y banco amplio de comercios (2026-11-17), punto «si el mismo catálogo serviría para los registros»"
---

# Registros y Panel: el logo del comercio en cada movimiento

## Propuesta

El banco de comercios de los pagos planificados (`MerchantCatalog`, 666 comercios con logo empaquetado, PR de logos
reales) sirve tal cual para los movimientos: la descripción de un registro («Recibo Luz del Sur», «Rappi», «Yape a
Juan») pasa por el mismo casado tolerante y, si casa, la fila enseña el logo del comercio en lugar del icono de la
subcategoría.

Dónde se vería: filas de Registros (también en Estadísticas › Registros), «Últimos registros» del Panel y el detalle de
un registro. Sin campo nuevo: se decide al pintar, por la descripción, como en los pagos.

## Lo que hay que decidir antes de construir

1. **¿Logo o icono de la subcategoría?** En Registros el icono dice la CATEGORÍA (comida, transporte); el logo dice el
   COMERCIO. Opciones: (a) logo en lugar del icono; (b) logo pequeño superpuesto en la esquina del icono; (c) un ajuste.
   Recomendado: (b), no pierde la categoría.
2. **Coste**: el casado recorre ~2.000 formas por nombre. En una lista de miles de filas hay que cachearlo por
   descripción (diccionario en memoria) antes de pintarlo.
3. **Falsos positivos**: la descripción de un movimiento es más libre que el nombre de un pago («Almuerzo con Claro y
   Ana»). El casado actual solo mira el principio del texto, pero conviene medir sobre el corpus `realista` cuántas filas
   casan y revisar una muestra.

## Hecho cuando

Decidido el punto 1 con Jürgen, medido el 3 sobre el corpus, y las filas de Registros y del Panel enseñan el logo donde
casa, sin coste visible al desplazar una lista larga.
