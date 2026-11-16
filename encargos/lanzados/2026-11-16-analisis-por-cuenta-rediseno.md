Yala
# Rediseñar por completo el análisis de cada cuenta con las gráficas de los widgets del Panel
---
toca: Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift, Yala/App/Logic/Calculators/AccountDetailCalculator.swift, Yala/App/Views/Accounts/AnalisisCuenta/, Yala/Utils/L10n+AnalisisCuenta.swift, Yala/Resources/*.lproj/Localizable.strings, YalaTests/AnalisisCuenta/, tickets/done/2026-11-15-analisis-por-cuenta.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (15-nov)
Al entrar a una cuenta desde el Panel, la vista de análisis se queda corta. Las gráficas no siguen el design system de la app: la línea del saldo y las barras de «En qué se fue» no se parecen a las de los widgets del Panel. Quiere rediseñarla por completo, con gráficas muy parecidas o idénticas a las de los widgets, para ver lo más posible de esa cuenta.

## Qué construir
- Rehaz la hoja de detalle de la cuenta (`Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift`) reutilizando los mismos componentes de gráficas de los widgets del Panel (Tendencias, saldo con proyección, distribución por categorías, flujo de caja y lo que corresponda). No copies estilos a mano. Si un componente de widget necesita un parámetro para filtrar por cuenta y está fuera de `toca`, envuélvelo desde `Yala/App/Views/Accounts/AnalisisCuenta/` sin modificarlo, o anótalo como pendiente en el cierre.
- Muestra lo más posible de la cuenta sin que abrume. Entre lo que vale la pena: la evolución del saldo con el mismo estilo de Tendencias, entró y salió por periodo, en qué se fue, comercios o registros más grandes, la comparación con el periodo anterior y, en tarjetas de crédito, lo que hay por pagar y el ciclo. Elige y ordena con jerarquía clara.
- Mantén lo que ya funciona: el resumen «Así se forma tu saldo», el selector de moneda (PEN y USD), «Filtrar por esta cuenta», «Últimos registros» y Editar.
- Aplica el design system y el brand voice (`docs/planning/BRAND-VOICE.md`), en lenguaje simple. Una sesión paralela cambia el vocabulario del saldo del Panel (`panel-saldo-y-tu-dinero`): usa «Saldo» y nunca «Debes».
- Textos nuevos en `Yala/Utils/L10n+AnalisisCuenta.swift` y en todos los `Localizable.strings`; el español, neutro latinoamericano.
- Comprueba que se vea bien en el iPhone SE, en modo claro y en modo oscuro, y con VoiceOver en las gráficas.

## Pruebas
- Tests en `YalaTests/AnalisisCuenta/` para los cálculos nuevos: periodos, varias monedas y tarjeta de crédito con saldo negativo.
- Prueba de punta a punta en el iPhone 14 por DeviceMCP (o en un simulador) con una cuenta bancaria y una tarjeta de crédito, con capturas de antes y después. En la Max puedes abrir un segundo simulador si otra sesión ocupa el primero.

## Entrega y cierre
- El antes y después va como artifact visual de Claude (nunca Markdown ni PDF).
- PR a 2.3, sin firma de IA.
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`. En nocturno, lo vital va a checkpoint con card para Jürgen, sin mergear lo incompleto.
- En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Resueltas por Frank en modo semi sin consultar (decisiones menores y reversibles dentro del encargo). Se discuten en el PR.

**D1 · ¿Qué componentes de los widgets se reutilizan?** → `TrendChartView` (la gráfica de Tendencias) para la evolución del saldo, `CashFlowWidget` para «entró y salió» por período y `CategoriesPieWidget` para «En qué se fue». Se usan tal cual, sin tocarlos, envueltos desde `Yala/App/Views/Accounts/AnalisisCuenta/`, y sin acciones (callbacks `nil`): en la ficha un toque no cambia los filtros del Panel.
Por qué: es el design system que pide Jürgen y no hay que copiar estilos. Alternativa descartada: añadir un parámetro «por cuenta» a los widgets del Panel (fuera de `toca` y acoplado a `PanelViewModel`).

**D2 · ¿De dónde salen los números?** → La curva del saldo sale de `AccountDetailCalculator.dailyBalances` (la misma suma que la tarjeta), muestreada con la agrupación del Panel (`chartGrouping`). El flujo y las categorías salen de `CashFlowCalculator` y `TopSpendingCategoriesCalculator`, los mismos del Panel, aplicados a los movimientos de la cuenta y en la divisa de la línea elegida.
Por qué: la gráfica y la cifra de la tarjeta tienen que acabar en el mismo número, y el flujo y las categorías tienen que decir lo mismo que el Panel filtrado por esta cuenta (con el trozo «Sin categoría» de la regla del repo). Alternativa descartada: `TrendDataProcessor` para el saldo (valora por tasa de cierre y deja fuera la cuenta archivada; la de una sola cuenta no es un agregado).

**D3 · ¿Comparación con el período anterior?** → Sí: gasto y neto contra el período anterior HASTA HOY (`DateAlignmentHelper.alignedPreviousInterval`, la regla de Estadísticas), pintada con el encabezado de variación que ya traen los widgets. Con «Todo el tiempo» no se compara.
Por qué: es la regla vigente de comparación. Alternativa descartada: período anterior entero (compara parcial contra completo).

**D4 · ¿Qué se enseña y en qué orden?** → Cabecera y saldo · estado de cuenta de la tarjeta · selector de divisa · «Así se forma tu saldo» · «Filtrar por esta cuenta» · Evolución del saldo · Entró y salió · En qué se fue · Tus gastos más grandes (3) · Últimos registros. Editar sigue en la barra.
Por qué: lo de arriba responde «¿cuánto tengo y cómo llegué?»; las gráficas, «¿qué pasó?»; las listas, el detalle. Alternativa descartada: comercios más grandes (no hay comercio fiable por movimiento; los registros más grandes responden lo mismo).

**D5 · Modo «solo gastos».** → La curva pasa a gasto acumulado (`TrendType.expense`) y el flujo enseña solo gastos (`isExpensesOnlyMode` del widget), como el Panel.

**D6 · Tarjeta de crédito con saldo negativo.** → La curva enseña el saldo con su signo (la deuda queda por debajo de cero), como la curva del Panel; la cabecera sigue con «Por pagar» y el estado de cuenta. Ningún texto nuevo dice «Debes».

**D7 · Textos.** → Nuevos en `Yala/Utils/L10n+AnalisisCuenta.swift` y en los 16 `Localizable.strings`; español neutro latinoamericano.

**D8 · Decisión de Jürgen pendiente (plan de publicaciones del 16 al 22-nov).** → No aplica a este encargo: es de marketing (`marketing/`, territorio de Lola) y no se toca aquí; se dice en el cierre.

**D9 · Evidencia.** → Conductor XCUITest temporal (`ZZAnalisisCuentaCapturasUITests`, se retira antes del gate) con el seed `ficha` (cuenta bancaria y tarjeta de crédito), en claro y en oscuro; el después también en un simulador iPhone SE (3.ª gen.) temporal.

**D10 · Ticket.** → `tickets/done/2026-11-15-analisis-por-cuenta.md` no existe: se crea con el qué y el porqué.
