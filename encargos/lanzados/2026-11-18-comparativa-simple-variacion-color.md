Yala
# Comparativa de Reportes más simple y visual: % de variación e indicador de color por fila
---
toca: Yala/App/Views/Reports/ReportComparisonViews.swift,Yala/App/Views/Reports/PivotRowView.swift,Yala/App/Views/Reports/FinancialReportView.swift,Yala/App/Logic/ComparisonPhraseLogic.swift,Yala/Resources/de.lproj/ComparativaSimple.strings,Yala/Resources/en-GB.lproj/ComparativaSimple.strings,Yala/Resources/en.lproj/ComparativaSimple.strings,Yala/Resources/es-419.lproj/ComparativaSimple.strings,Yala/Resources/es-AR.lproj/ComparativaSimple.strings,Yala/Resources/es-ES.lproj/ComparativaSimple.strings,Yala/Resources/es.lproj/ComparativaSimple.strings,Yala/Resources/fr.lproj/ComparativaSimple.strings,Yala/Resources/it.lproj/ComparativaSimple.strings,Yala/Resources/ja.lproj/ComparativaSimple.strings,Yala/Resources/nl.lproj/ComparativaSimple.strings,Yala/Resources/pl.lproj/ComparativaSimple.strings,Yala/Resources/pt-BR.lproj/ComparativaSimple.strings,Yala/Resources/pt-PT.lproj/ComparativaSimple.strings,Yala/Resources/pt.lproj/ComparativaSimple.strings,Yala/Resources/zh-Hans.lproj/ComparativaSimple.strings,YalaTests/ComparativaSimple/,YalaUITests/ComparativaSimple/,tickets/done/2026-11-17-comparativa-simple-variacion-color.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen del 17-nov (20:48 Lima), con captura de su iPhone de Reportes financieros, pestaña Comparativa. Base 2.3, un PR. Sesión enfocada solo en la vista Comparativa (una vista por sesión). No toques Flujo de caja.

## Problema
Hoy cada fila (Ingresos, Gastos y cada categoría) muestra el monto actual grande y debajo, en gris, «en 1–17 de oct. S/ X». Es difícil de leer y de sacar insights rápido: no se ve de un vistazo si estás mejor o peor que antes.

## Lo que quiere
- Que se lea como una tabla dinámica: por fila, monto actual, monto del periodo anterior y **% de variación** con un **indicador de color** (y flecha o signo, no solo color, por accesibilidad).
- El color depende de si el cambio es bueno o malo: más ingresos es verde; más gasto es rojo y menos gasto verde. El «Te quedó» (ingresos menos gastos) igual: más es verde.
- Casos borde claros: sin dato anterior (p. ej. Mascotas) muestra «nuevo» o «—» en vez de un % infinito; variación 0 o mínima en neutro.
- Más simple y visual: menos texto gris repetido, columnas alineadas y fáciles de escanear; si ayuda, una barra o marca de magnitud discreta. Mantén Desglosar, los chips de agrupación y el bloque «Te quedó».
- Debe caber en iPhone SE y con letra grande sin romperse (si no cabe, prioriza monto actual y %; el monto anterior puede pasar debajo o a un toque). Nunca un botón debajo del otro. iPad con ancho legible.
- VoiceOver lee «Gastos, 12.642 soles, subió 27 % frente a octubre» o equivalente.

## Cómo entregar
- Propón 2 o 3 variantes en maquetas, elige la recomendada e impleméntala. Lo menor, con la opción recomendada, anotado en «Decidido sin consultar».
- Tests de la lógica del % y del color (bueno o malo según ingreso o gasto, sin dato anterior, cero) en `YalaTests/ComparativaSimple/`; prueba de UI en `YalaUITests/ComparativaSimple/`.
- Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después lado a lado y las variantes.
- Commits y PR sin firma de IA. Toca solo lo declarado; textos nuevos en `ComparativaSimple.strings` de cada `.lproj`, nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

1. **Variante**: A · dos líneas por celda (monto actual y anterior debajo, sin «en …»; la cabecera nombra los dos períodos una vez) + marca de cambio con flecha y color. En ventana ancha el anterior va en su columna. B (4 columnas en iPhone) no cabe: el nombre quedaba en ~50 pt. C (barras por fila) dobla el alto.
2. **Colores**: bueno = verde `groupOwedAmount`; malo = rosa de marca `groupOweAmount` (el «rojo» que Jürgen eligió el 3-nov). Ambos AA como texto.
3. **Marca**: ▲/▼ + % sin signo; 0 decimales desde 10 %, 1 por debajo; «> 999 %» arriba.
4. **Neutro**: «igual» si redondea a 0 %; flecha gris por debajo del 1 %.
5. **Sin anterior**: «nuevo»; sin anterior ni actual: «—».
6. **«Te quedó»**: misma marca (NetFlowSummaryView, una línea fuera del `toca:`, declarado en el PR) para no tener dos lenguajes de cambio en la misma pantalla.
7. **Sin barra de magnitud**: la marca de color ya da el escaneo.
8. **«Mostrar variaciones» apagado** sigue escondiendo la marca.
9. **VoiceOver**: «Gastos, S/ 12,642, subió 27 % frente a octubre, antes S/ 9,976».
10. **Capturas SE/iPad**: en la Mini solo un simulador; se cambia de device en serie, nunca dos arrancados.
