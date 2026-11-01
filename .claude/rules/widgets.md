---
paths:
  - "YalaWidgets/**"
  - "qa/widget-render/**"
  - "Yala/App/Logic/Helpers/Widget*.swift"
---

# Widgets de la pantalla de inicio (WidgetKit)

Desde el rediseño 2.2 (S35f, `docs/widgets/AUDITORIA-WIDGETS-2-2.md`). Lo que el yo-futuro no debe romper:

- **Tokens: solo `WidgetDS` y `WidgetColors`.** `WidgetDS` es el espejo de `DS` (mismos nombres y valores) y lo fija
  `WidgetDesignSystemParityTests`; `WidgetDS.Chart` es lo único propio del widget. El `WDS` viejo se retiró en la tanda 3
  (S35f2) y `elWDSViejoNoVuelve` lo vigila en todo el target. Un widget nuevo usa `WidgetDS`, rellenos sólidos y el fondo
  por token, y entra en la lista de `losRedisenadosSoloUsanWidgetDS`.
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
- **Un `Link` dentro del widget es `WidgetPlainLink`.** `Link` pinta su contenido con el tinte y los estilos jerárquicos
  de dentro (`.secondary`) derivan de él: los nombres y títulos del Resumen del mes salían azules. `WidgetPlainLink` fija
  `Color.primary` (no el `.primary` jerárquico, que también deriva).
- **Una variación nueva obedece «Comparar con el período anterior»** (`WidgetDataService.showsVariations`, ausente =
  activada): con ella apagada no sale, como `VariationChip` en la app. Hoy la miran Saldo, Gastos y Entradas y salidas
  en su proveedor; la copia al App Group la hacen el `didSet` de `AppPreferences.showVariations` y `saveSnapshot`, y se
  borra con las demás en `DataWipeService` y `GroupsOnlySignUpPreferenceReset` (`WidgetShowVariationsMirrorTests`).
- **Una gráfica de barras sin ejes fija su escala con lo que APILA cada día** (`WidgetInsightsLogic.flowChartRange`):
  una devolución da un lado negativo y su barra va al otro lado; con el máximo de cada lado se salía de la gráfica.
- **Una tarta con leyenda agrupa con `WidgetInsightsLogic.pieLegend`** (hasta 5 filas; con más, 4 y «Otros») y el aro
  pinta las MISMAS filas: si el aro lee los trozos sueltos y la leyenda los agrupados, no dicen lo mismo. **Lo que los
  trozos no cubren del total del centro también va a «Otros»**: las subcategorías de la foto solo cuentan lo que tiene
  subcategoría, y sin eso cinco filas sumaban el 95 % del centro y ningún arco medía su porcentaje (review de S35f2). Si
  los trozos suman MÁS que el total (una devolución resta del total y no de su trozo), el aro normaliza y los porcentajes
  pasan del 100: es de la foto, card `widget-category-percentages-use-the-signed-total`. Una fila que no
  sale de un hex de la foto lleva su color en `WidgetBreakdownItem.fixedColor`: con el hex vacío, `WidgetColors.fill`
  devuelve el índigo de marca (así salió «Otros» índigo en el aro y gris en la leyenda, lo cazó el banco).
- **Una acción nueva del Centro de Control** escribe su valor en `pendingControlAction` (`Yala/Shared/ControlCenterIntents.swift`)
  y necesita su `case` en `AppBootstrapper.checkForPendingControlAction`: un valor sin caso se borra sin hacer nada.
  Lo fija `ControlCenterNewRecordWiringTests`.
- **Refresco**: `WidgetRefresh.nextDate(after:)` (medianoche o +4 h). Los datos nuevos llegan antes: la app recarga
  todos los widgets en cada `WidgetDataCache.updateCache`.
- **Movimiento**: las cifras cambian con `widgetNumericTransition`, que respeta Reducir movimiento.
- **Capturas antes/después**: `qa/widget-render/` (ver su README). Un cambio visual de un widget se pinta con la foto
  congelada de `fixtures/` antes y después; el tintado del banco es aproximado. Mira también el tamaño del iPhone SE
  (`m-se`, `l-se`): es donde se corta. Un widget con una pieza de alto fijo (un aro) deja que la leyenda pida su alto y
  la pieza encoja (`WidgetPieBreakdown`).
