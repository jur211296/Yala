---
id: palette-pink-and-indigo-still-used-as-text-color
status: backlog
priority: low
area: "design-system, accesibilidad"
created: 2026-11-12
updated: 2026-11-12
source: "lote 08 de las necesarias 2.3 (Flujo de caja), al buscar todas las instancias del índigo y el rosa como texto"
---

# El índigo y el rosa de la paleta siguen pintando texto fuera de «Te quedó»

La regla de color de `swiftui-ds.md` dice que `hotPink` (3,77:1) y `electricIndigo` (4,46:1 sobre `#FAFBFF`) no valen
para texto sobre tarjeta, y `AmountText` aún los baja más en símbolo y decimales. El lote 08 lo arregló solo en
`NetFlowSummaryView` («Te quedó» / «Te faltó» y su variación), con `Color.incomeAmount` y `Color.groupOweAmount`.
Quedan, medidos en `origin/2.3` el 2026-11-12:

- `VariationChip`: el texto del chip de variación usa la paleta en sus 33 usos. El lote 08 le añadió
  `usesAccessibleTextTone`, que hoy solo enciende el resumen de la Comparativa. Pasarlo a todos cambia el color de los
  chips en toda la app: decisión de diseño.
- `CashFlowCellDetailSheet.swift` (detalle de una línea de mes pasado): la línea de diferencia y la fila «Diferencia».
- `PivotRowView.swift:217`: importe de la tabla de la Comparativa.
- `CashFlowLineConfigSheet.swift:193`: la tendencia (hoja inalcanzable hoy, ver la ficha de la zona 36).

Molde: los tokens de texto que mide `ThemeTokenContrastTests` en los diez temas.
