---
id: 2026-11-23-sankey-distribucion-subcategorias
status: done
priority: medium
area: "statistics, sankey"
created: 2026-11-23
updated: 2026-11-23
source: "pedido de Jürgen (23-nov, pruebas de Yala 2.3 en el iPhone)"
---

# Sankey de Distribución: «Ver subcategorías +» para desplegar la columna de subcategorías

En el iPhone el Sankey de Estadísticas › Distribución llega hasta las categorías (decisión 28, G3) y las subcategorías
solo salían tocando una categoría. Jürgen pidió mantener ese inicio y añadir un botón discreto que despliegue la columna
de subcategorías, con su estado inverso para replegarla.

## Hecho cuando

- Plegado por defecto, hasta categorías, como antes.
- «Ver subcategorías +» bajo la gráfica despliega las subcategorías de todas las categorías; «Ver menos −» las repliega.
- Legible al desplegar: sin solapes, cola larga en «Otros», filtros activos y colores respetados, en claro y oscuro.
- Textos en una tabla propia en los 16 idiomas; tests unitarios del cálculo con y sin despliegue.

## Resolución (2026-11-23)

- `SankeySubcategoryExpansion` (lógica pura, `Views/Statistics/Sankey/`): ordena la columna desplegada por categoría
  madre (orden de la columna de categorías; dentro, por importe) para que los flujos no se crucen, y con más de 8
  subcategorías deja las 7 mayores y un «Otros» con un enlace desde cada categoría que aporta. El «Otros» del
  calculador, que no traía enlace, se suma a ese mismo nodo. No se pierde ningún importe.
- `SankeyChartView`: el botón sale solo donde no caben las cuatro columnas (iPhone), con subcategorías y sin categoría
  elegida (lo elegido ya despliega las suyas). Desplegado, pide las cuatro columnas y desplaza la vista hasta las
  subcategorías; replegado, vuelve al principio. El despliegue se aplica tras el filtro de «Gastos / Diferencia».
  Arranca plegado en cada visita.
- Textos en `SankeySubcategorias.strings` (16 idiomas), leídos con `SankeySubcategoriasText`.
- Pin: `YalaTests/SankeySubcategorias/SankeySubcategoriasTests`.
- Medido en el simulador (iPhone 17 Pro, seed `realista`, oscuro y claro): plegado con el botón, desplegado con
  «Supermercados», «Restaurantes», «Delivery» bajo Alimentación, «Alquiler» y «Servicios» bajo Hogar y «Otros», y
  «Ver menos» devolviendo las tres columnas desde «Salario».

## Fuera

- El iPad no cambia: ahí ya se ven las cuatro columnas.
- El botón flotante de Yala IA puede tapar «Ver menos» en algunas posiciones del scroll (es una capa sobre toda la
  página); al desplazar queda a la vista.
