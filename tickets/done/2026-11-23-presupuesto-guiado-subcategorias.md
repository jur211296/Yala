---
id: 2026-11-23-presupuesto-guiado-subcategorias
status: done
priority: medium
area: "planning, budgets, asistente"
created: 2026-11-23
updated: 2026-11-24
source: "Jürgen, pruebas de Yala 2.3 en iPhone sobre «Nuevo presupuesto» (23-nov)"
---

# «Nuevo presupuesto» por pasos: subcategorías debajo al tocar una categoría

En el paso «¿Cuáles?» solo había categorías y no se podía quitar una subcategoría que no se quisiera contar. Jürgen pidió
el patrón del filtro de categoría de Registros: al tocar una categoría, debajo salen sus subcategorías para afinar.
Además, vio «S/ 3,707» en la tarjeta de Compras y «El mes pasado gastaste S/ 16,541» en el paso del tope, y pidió
comprobar si el cálculo ignoraba lo elegido.

## Hecho cuando

- Tocar una categoría la elige con todas sus subcategorías marcadas, que salen debajo en el mismo paso.
- Desmarcar una subcategoría la deja fuera del cálculo y del presupuesto; desmarcarlas todas desmarca la categoría.
- El paso del tope y el presupuesto creado usan exactamente las subcategorías marcadas.

## Resolución (2026-11-24)

- `AsistentePresupuestoLogica` gana las reglas de la selección (`alternarCategoria`, `alternarSubcategoria`,
  `subcategoriasDelPresupuesto`), genéricas y sin vista. El estado guarda las subcategorías marcadas.
- El paso «¿Cuáles?» pinta debajo un bloque por categoría elegida con sus subcategorías en círculos (el dibujo del filtro
  de Registros), con el texto de ayuda que ya existía en los 16 idiomas.
- El resumen nombra la categoría entera o, a medias, las subcategorías que quedaron (la regla del chip de Registros).
- **Las dos cifras eran reales**: la tarjeta de la categoría dice lo gastado ESTE mes y el paso del tope, el mes PASADO.
  El cálculo ya filtraba por las categorías elegidas; lo fijan pruebas con un control sin filtro.
- Pruebas: `YalaTests/PresupuestoGuiadoSubcategorias/` (reglas, gastado del mes pasado, paso al formulario, cableado) y
  `YalaUITests/PresupuestoGuiadoSubcategorias/` (aparecen, se desmarcan, la categoría se apaga; capturas claro y oscuro).
