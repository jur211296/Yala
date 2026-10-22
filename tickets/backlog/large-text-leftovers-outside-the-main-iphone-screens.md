---
id: large-text-leftovers-outside-the-main-iphone-screens
status: backlog
priority: low
area: "a11y, design-system, iphone, adaptativo"
created: 2026-09-28
updated: 2026-10-08
source: "iphone-large-text-sizes-break-layouts (carril adaptativo, paso 2), capturas a AX5 del 2026-09-28"
---

# Con el texto muy grande, lo que quedó fuera de las diez pantallas principales

**Sale del paso 2 del carril adaptativo** ([[iphone-large-text-sizes-break-layouts]]). Ese ticket arregló las diez
pantallas principales con un contenedor que pasa de fila a columna a los tamaños de accesibilidad
(`AdaptiveRowStack`, en `Yala/App/Views/Shared/`). Aquí va lo que se vio por el camino y no entraba, porque cada
cambio visible pide su captura antes y después y estas pantallas no estaban en el guion.

## Qué le pasa al usuario

Con el texto en los tamaños de accesibilidad, en estas pantallas un importe o un rótulo se sigue cortando.
**Medido** donde dice «visto a AX5»; lo demás es la misma forma de código que ya se cortaba en las pantallas
arregladas, **inferido** sin captura.

## Lo que hay

1. **Filas etiqueta–valor con la misma forma** que las ya arregladas en el detalle de registro y de presupuesto
   (icono + etiqueta, `Spacer()`, valor): `detailRow` en `InboxApproveSuccessView`, `TransactionSuccessView`,
   `GroupExpenseSuccessView`, `ScheduledPaymentDetailView`, `GroupExpenseDetailSheet` y
   `GroupOpeningBalanceDetailSheet`; los `accountRow` de las dos pantallas de éxito; y `detailRow` de
   `CashFlowCellDetailSheet`. Inferido. El arreglo es el mismo: envolver en `AdaptiveRowStack`.
2. **Ingresos y gastos de la cabecera de Estadísticas**: `incomeExpenseChips` en `TrendsTabView` e
   `InsightsTabView` tienen la forma de la de Registros, que a AX5 cortaba los dos importes. Inferido.
3. **Nuevo registro**: a AX5 el selector Gasto / Ingreso / Transferencia corta sus rótulos («Ingr…», «Tran…») y la
   fila de acciones también («Calcul…», «Favori…», «Recurr…»). Visto a AX5. La solución nativa es pasar a solo icono
   o a dos filas a esos tamaños; toca un formulario con mucho uso, y por eso no entró aquí.
   **Corrección del 2026-09-28** ([[iphone-small-screens-and-safe-areas-audit]]): «no tapa ningún botón» valía para
   el ProMax. En el SE a AX5 el formulario no cabía y «Guardar» y los chips quedaban fuera de la pantalla; ese
   ticket le dio scroll. Los rótulos cortados siguen aquí.
4. **Bandeja**: los filtros «Pendientes / Archivados» se parten en sílabas («Pe / n…») a AX5. Visto.
5. **Panel**: el widget pequeño de presupuestos corta su título («Pre…») y el eje del gráfico de Tendencias solapa
   las fechas («2122 24 2628»). Visto a AX5. Las tarjetas pequeñas tienen alto fijo (`WidgetSize.smallHeight`,
   192 pt); el de pagos planificados ya se topa en AX1 con su motivo escrito, y aquí toca decidir si el de
   presupuestos hace lo mismo o si a esos tamaños las tarjetas pequeñas pasan a ocupar la fila entera.
6. **La píldora «Nuevo registro» del Panel** se sale por la derecha en el SE a AX5. No tapa nada —la fila es un
   scroll horizontal a propósito (`PanelQuickActionsRow`)— pero con el texto cortado contra el borde no invita a
   deslizar, que es lo que el propio comentario del fichero quiere evitar. Visto.
7. **Tipo de cambio de la transferencia**: se queda con tope en AX1 sobre su fila, porque sin él se corta en el SE.
   Lo nativo sería apilar «1 USD =» encima de la tasa a esos tamaños.
8. **Tutorial**: se queda con tope en AX1 porque sus páginas no tienen scroll (motivo escrito en
   `TutorialDetailView`). Quitarlo pide dar scroll a cada página.
9. **Código muerto**: `TransactionAmountInputView` no tiene ningún llamador (medido con `grep` el 2026-09-28).

## Qué hacer

Lo mismo que el paso 2: capturas antes y después en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`,
a tamaño por defecto y a AX5, con el guion temporal que usó el paso 2 (se describe en su ticket). Los puntos 1 y
2 son baratos; el 3 y el 5 piden una decisión de diseño pequeña, que se toma con la práctica nativa de Apple.

Triage 2026-10-08: abierto · medium → low · ninguna de las 11 vistas citadas usa `AdaptiveRowStack`; `incomeExpenseChips` sigue en `TrendsTabView.swift:288` e `InsightsTabView.swift:254`, y `TransactionAmountInputView` sigue sin llamadores.
