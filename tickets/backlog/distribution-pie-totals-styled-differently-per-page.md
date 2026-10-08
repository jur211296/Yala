---
id: distribution-pie-totals-styled-differently-per-page
status: backlog
priority: very-low
area: "statistics, design-system"
created: 2026-10-04
source: hallazgo de distribution-subviews-miss-the-new-panel-hero (2026-10-04)
updated: 2026-10-08
---

# El total de cada página del carrusel de Distribución se pinta distinto

## Qué le pasa al usuario

En Estadísticas → Distribución → Gráficas, con un período sin comparativa («Todo el tiempo», o con las
variaciones apagadas), al deslizar el carrusel el total de la cabecera cambia de estilo:

| página | cómo sale el total |
|---|---|
| Categorías | `S/ 206,970 .00` — símbolo y decimales en pequeño (`AmountText`) |
| Subcategorías | `S/ 206,970.00` — todo del mismo tamaño |
| Etiquetas | `S/ 101,041.00` — todo del mismo tamaño |

Capturas: `capturas/despues-2-distribucion.png`, `despues-4-distribucion-subcategorias.png` y
`despues-5-distribucion-etiquetas.png` del PR de `distribution-subviews-miss-the-new-panel-hero`.

## Dónde, medido

Rama «Original header without comparison» de cada widget:

- `Yala/App/Views/Panel/CategoriesPieWidget.swift` (~L545): `AmountText(...)`.
- `Yala/App/Views/Panel/SubcategoriesPieWidget.swift` (~L532): `Text(formattedCurrency(filteredTotalExpense))`.
- `Yala/App/Views/Panel/TagsPieWidget.swift` (~L492): `Text(formattedCurrency(filteredTotalExpense))`.

Con comparativa los tres usan `PieChartVariationHeader` y no se nota.

## Relacionados

- [[pie-header-total-unmarked]] — mismo hueco, la marca de aproximado. Arreglarlos juntos: si
  subcategorías y etiquetas pasan a `AmountText`, el `isEstimate:` va en la misma línea.

## Medido en 2.1 (triage 2026-10-08)

- Rama «Original header without comparison»: `CategoriesPieWidget.swift` usa `AmountText(` (~L545) y `SubcategoriesPieWidget.swift` (~L533) y `TagsPieWidget.swift` (~L492) siguen con `Text(formattedCurrency(filteredTotalExpense))`. Sin commits en esos dos ficheros desde el 2026-10-04.
- Se arregla en la misma línea que `pie-header-total-unmarked` (medium): si los dos pasan a `AmountText`, el `isEstimate:` va con él.

Triage 2026-10-08: abierto · low → very-low · subcategorías y etiquetas siguen pintando el total con `Text` y no con `AmountText`; inconsistencia visual sin efecto sobre los números.
