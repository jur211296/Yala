---
paths:
  - "YalaWidgets/**"
  - "qa/widget-render/**"
  - "Yala/App/Logic/Helpers/Widget*.swift"
---

# Widgets de la pantalla de inicio (WidgetKit)

Desde el rediseño 2.2 (S35f, `docs/widgets/AUDITORIA-WIDGETS-2-2.md`). Lo que el yo-futuro no debe romper:

- **Tokens: solo `WidgetDS` y `WidgetColors`.** `WidgetDS` es el espejo de `DS` (mismos nombres y valores) y lo fija
  `WidgetDesignSystemParityTests`; `WidgetDS.Chart` es lo único propio del widget. El `WDS` viejo queda en los widgets
  que aún no se rediseñaron (Entradas y salidas, Resumen del mes, Categorías y Subcategorías); un widget que se toque
  pasa entero a `WidgetDS`, con rellenos sólidos y el fondo por token, y entra en la lista del mismo test.
- **Color de texto, solo los tres AA**: `incomeText`, `alertText`, `accentText` (espejos de `Color.incomeAmount`,
  `overBudgetText` e índigo/`indigoTextOnDark`). La paleta (`hotPink`, `yalaTeal`, colores de categoría) va en rellenos,
  barras y gráficas. En una lista solo el ingreso lleva color.
- **Fondo**: `.containerBackground(WidgetColors.cardBackground, for: .widget)` (el `card` del tema por defecto). Entrada
  rápida pequeña es la excepción: relleno sólido (`indigoFill`/`pinkFill`/`tealFill`) con blanco encima.
- **Tintado y transparente** (`widgetRenderingMode == .accented`): el sistema pinta todo en blanco conservando la
  opacidad. Un relleno opaco con un icono blanco encima se vuelve un círculo blanco sin icono: `WidgetBadge`, el «+» de
  Últimos registros, los botones de Entrada rápida y los días del calendario de Pagos pasan a translúcidos en ese modo.
  Una pieza nueva con relleno sólido hace lo mismo. Se tiñe (`widgetAccentable()`) UNA cosa por widget, la que manda:
  la cifra (Saldo, Gastos), las barras (Presupuestos), los días pendientes (calendario de Pagos); las gráficas que
  acompañan a una cifra no se tiñen.
- **StandBy** quita el fondo (`showsWidgetContainerBackground == false`) y pinta sobre negro: un blanco fijo que solo se
  lee sobre un relleno pasa al primario (`QuickEntryTileView`).
- **Lo que el widget deduce de la foto vive en `WidgetInsightsLogic`** (`Yala/App/Logic/Helpers/`, membership de la
  extensión por exception set del pbxproj, como `WidgetAmountSplitter`), con sus tests en `YalaTests`. Una cuenta nueva
  de un widget va ahí, no en la vista: `YalaTests` no compila `YalaWidgets`. Lo que copie una cuenta de la app
  (`budgetRemaining` = `BudgetRemainingLogic.remaining`) lleva su test de paridad.
- **Las cuentas se miden a la hora de la FOTO** (`lastUpdated`), no a la del reloj: las cifras de la foto se calcularon
  entonces. Período, días transcurridos, comparación y ritmo van con `dateInterval(now: asOf)` y
  `getTrendData(for:asOf:)`; con el reloj, una foto de ayer cruzaba meses a medianoche (lo cazó la review de S35f). Lo
  que habla de HOY («Hoy», «Mañana», «En 3 días», «Ayer») sí usa el reloj, con `WidgetRefresh.dayAwareTimeline`: una
  entrada más a medianoche, porque la recarga pedida es solo una petición.
- **Refresco**: `WidgetRefresh.nextDate(after:)` (medianoche o +4 h). Los datos nuevos llegan antes: la app recarga
  todos los widgets en cada `WidgetDataCache.updateCache`.
- **Movimiento**: las cifras cambian con `widgetNumericTransition`, que respeta Reducir movimiento.
- **Capturas antes/después**: `qa/widget-render/` (ver su README). Un cambio visual de un widget se pinta con la foto
  congelada de `fixtures/` antes y después; el tintado del banco es aproximado.
