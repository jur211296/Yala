---
id: cash-flow-month-vs-empty-and-contrast-necessary-08-2-3
status: done
priority: medium
area: "reportes, flujo de caja, l10n, accesibilidad"
created: 2026-11-12
updated: 2026-11-12
source: "lote 08 de la consolidación de necesarias 2.3 (card tablero-mejoras-necesarias-2-3-flujo-de-caja-mes-tyuj), ficha docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md"
qa-status: passed
qa-date: 2026-11-12
qa-notes: XCUITest FlujoNecesariasLote08UITests rojo en la base y verde con el arreglo, capturas antes y despues en el simulador
---

# Flujo de caja: mes equivocado, «vs» sin traducir, vacío y contraste

1. **«Gastos no considerados» enseñaba siempre el mes en curso.** Ahora lee el mes elegido en la tira
   (`CashFlowOthersSheet.otherResult`). Medido en la base: abierta desde octubre enseñaba los importes de noviembre.
2. **«vs» escrito a mano en el detalle de una línea de un mes pasado.** Ahora una frase traducida en los 16 idiomas:
   «Gastaste X; el estimado era Y.» / «Recibiste X; el estimado era Y.»
3. **El vacío de Flujo de caja decía «No hay registros en este período».** Ahora tiene su mensaje: «Aquí verás tu flujo
   de caja cuando tengas tus primeros registros.» La Comparativa conserva el suyo.
4. **«Te quedó» / «Te faltó» y su variación en índigo o rosa como texto.** Ahora `Color.incomeAmount` y
   `Color.groupOweAmount`, los tokens de texto que pasan AA en claro y oscuro. El chip compartido gana un modo AA que
   solo enciende este resumen.

Y dos decisiones de Jürgen del 9-nov que la card asignó a este lote (registro
`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`, decisiones 2 y 35):

5. **El flujo de caja avanzado es gratis a propósito.** Fuera `ProFeature.cashFlowAdvanced`, su recorte (3 meses
   adelante, ninguno atrás) que nunca actuaba, el candado de la hoja de configurar una línea y los textos «El flujo de
   caja avanzado es de Yala Pro», «El flujo de caja de siempre sigue gratis.» y «Ya puedes usar el flujo de caja
   avanzado.» en los 16 idiomas.
6. **Gráficas dice el período del promedio.** La frase de «Gastos por revisar» pasa de «En Bares gastaste S/ 47.00 más
   de lo planeado» a «En promedio, últimos 4 meses: en Bares te pasaste por S/ 47.00 al mes.»; con un solo mes, «Este
   mes: …».

Tests: `YalaUITests/Flows/FlujoNecesariasLote08UITests` (puntos 1-3, con capturas) y
`YalaTests/FlujoNecesariasLote08Tests` (los cuatro).

Hallazgos con ticket propio: `vs-hardcoded-in-statistics-and-panel-comparisons`,
`palette-pink-and-indigo-still-used-as-text-color`.
