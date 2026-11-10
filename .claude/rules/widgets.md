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
  barras y gráficas. En una lista solo el ingreso lleva color. **Excepción: el widget de Grupos** pinta «debes» y «te
  deben» con `groupOweText` / `groupOwedText`, espejos de los tokens de la lista de Grupos (los fija el mismo test), y
  pone una flecha a cada lado para que no dependa del color.
- **Fondo**: `.containerBackground(for: .widget) { WidgetCardBackground() }` (card c0nl, 2026-11-03): degradado
  vertical de un solo tono y borde fino iluminado arriba, con colores FIJOS (`cardTop`/`cardBottom`/`cardEdge*`). No el
  gris de sistema: en oscuro el widget resuelve el nivel «elevado» y `secondarySystemGroupedBackground` sube a #3A3A3C,
  el gris plano que Jürgen comparó con el de batería. Es la **excepción de los widgets** a «sin degradados» de la marca:
  un tono, sin brillos ni glows. En iOS no hay glass real para un widget de terceros (`WidgetTexture.glass` es de
  visionOS; un `Material` no ve el fondo de pantalla). Los extremos del degradado están medidos contra los textos de
  color: aclarar el oscuro o agrisar el claro baja el rosa y el índigo de 4,5:1, y lo caza
  `elFondoConProfundidadMantieneElContrasteDeLosTextos`. **El iPhone aclara la parte de arriba** del fondo de un widget
  de terceros en el estilo «Original» (medido en el simulador de iOS 27.2: #121320 sale #2E2F3B, #191A25 salía #35353F, y
  un rojo puro, #F42725); el banco no lo imita. Por eso los extremos son más oscuros de lo que parecen en el banco: un
  fondo que en el banco «ya se ve bien» sale gris en la pantalla de inicio. Entrada rápida pequeña lleva su relleno de marca
  (`WidgetCardBackground(fill:)`), que solo OSCURECE hacia abajo para que el blanco de encima gane contraste.
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
  subcategoría, y sin eso cinco filas sumaban el 95 % del centro y ningún arco medía su porcentaje (review de S35f2). **El
  total de una tarta de categorías es el del desglose, no el gasto con signo (card znu5, 2026-11-03)**: cada trozo es el
  neto de su categoría (`WidgetInsightsLogic.netExpenseSlices`, como la tarta de Estadísticas: la devolución resta de su
  trozo), y centro, «Otros» y porcentajes se miden contra la suma de TODOS los trozos (`expenseBreakdownTotal` de la
  foto, que la extensión lee con `breakdownTotal`). Antes un gasto de 100 y su devolución de 30 daban un trozo de 130
  contra un centro de 70. Las subcategorías tienen SU total (`expenseSubcategoryBreakdownTotal`, leído con
  `subcategoryBreakdownTotal`): sus filas más el neto de lo que no tiene subcategoría, por categoría. Con el de categorías,
  un gasto de 100 en Restaurante y una devolución de 80 en Comida sin subcategoría daban una fila del 500 %. Una cifra
  nueva de una tarta lee el total de su desglose; el «Gastado» de un widget sigue siendo `totalExpense`. Una fila que no
  sale de un hex de la foto lleva su color en `WidgetBreakdownItem.fixedColor`: con el hex vacío, `WidgetColors.fill`
  devuelve el índigo de marca (así salió «Otros» índigo en el aro y gris en la leyenda, lo cazó el banco).
- **Una acción nueva del Centro de Control** escribe su valor en `pendingControlAction` (`Yala/Shared/ControlCenterIntents.swift`)
  y necesita su `case` en `AppBootstrapper.checkForPendingControlAction`: un valor sin caso se borra sin hacer nada.
  Lo fija `ControlCenterNewRecordWiringTests`.
- **Refresco**: `WidgetRefresh.nextDate(after:)` (medianoche o +4 h). Los datos nuevos llegan antes: la app recarga
  todos los widgets en cada `WidgetDataCache.updateCache`.
- **`updateCache` PIDE la foto, no la hace (2026-11-04, card 1hcz)**: las peticiones de 1 s (`rebuildDelay`) se funden
  en una reconstrucción, que cuesta ~0,27 s de hilo principal con 2.337 movimientos. La foto es la misma
  (`updateCacheNow`, el cuerpo de siempre con la puerta del borrado armado). Quien la necesita escrita antes de seguir
  llama a `updateCacheNow` (las tareas de fondo de `BackgroundTaskManager`) o a `flushPendingUpdate()` (el paso a
  segundo plano, en `YalaApp.handleScenePhase`). `clearCache` y la suelta del contenedor en un swap la cancelan, y el
  contexto pendiente va en `weak`: una referencia fuerte retendría el contenedor que el swap comprueba que muere. Un
  lector EN PROCESO de la foto (Siri) puede ver la de hace un segundo; lo fija `WidgetCacheCoalescingTests`.
- **Los grupos de la foto los calcula `WidgetGroupsSnapshotBuilder` con las funciones de la app**, nunca una cuenta
  propia: el resumen y los archivados con `globalSummary`, como arriba de la lista; cada fila, con la cabecera del
  detalle de su grupo (`computeGroupHeaderBalance`), que es lo que abre al tocarla, porque la tarjeta de la lista va por
  persona; y solo los grupos cuya tarjeta enseña saldos (`GroupCardDisplayLogic`). Lo fija `WidgetGroupsSnapshotTests`
  contra `GroupsViewModel` y `GroupDetailViewModel`. Lee con el `context` que recibe, no por `GroupService.shared` (el paso 9 del arranque va
  antes de que los servicios de grupos tengan contexto). **Los escritores de Grupos no llaman a `updateCache`**: la
  foto se rehace por `WidgetGroupsRefresh.requestCheck()`, colgado de `SessionState.incrementDataVersion`, que solo
  la reconstruye si la parte de grupos cambió (y no recalcula si un `updateCache` posterior a la petición ya la cubrió).
  Tras `clearCache` el primer cambio la rehace: «Vaciar datos» conserva los grupos. No llega con un push silencioso en
  segundo plano (iOS suspende antes de la espera). Un dato nuevo del widget que cambie sin pasar por `updateCache` sigue
  ese molde, no añade llamadas en cada escritor.
- **Movimiento**: las cifras cambian con `widgetNumericTransition`, que respeta Reducir movimiento.
- **Capturas antes/después**: `qa/widget-render/` (ver su README). Un cambio visual de un widget se pinta con la foto
  congelada de `fixtures/` antes y después; el tintado del banco es aproximado. Mira también el tamaño del iPhone SE
  (`m-se`, `l-se`): es donde se corta. Un widget con una pieza de alto fijo (un aro) deja que la leyenda pida su alto y
  la pieza encoja (`WidgetPieBreakdown`).
- **Pocos datos no deja huecos (card dz6c, 2026-11-04).** Un widget se mira con la matriz de estados del banco
  (`qa/widget-render/estados.py` + `matriz.sh`: vacío, pocos, sin ingresos, sin presupuestos, sin gastos, completo), no
  solo con la foto completa. Tres moldes: (1) **una lista reparte puestos, no filas**: los que no tienen fila llevan una
  copia `.hidden()` de la primera (`WidgetRankingList.slots`, `LatestRecordsWidgetView`), o con dos filas la segunda se
  iba al fondo; (2) **nunca `Spacer` entre bloques para repartir el alto**: las secciones van con aire fijo y el alto que
  sobra lo toma la pieza que puede crecer (el aro: `WidgetPieBreakdown.maxDiameter`, `MonthSummaryCategories(layout:)`
  con `ViewThatFits` en el extragrande vertical); (3) **un bloque de gráfica sin datos pinta su forma vacía**
  (`WidgetEmptyRing`, la línea de cero de `CashFlowBarsChart`), no un texto suelto. Una lista corta deja lo que sobra
  DEBAJO, como fin de lista: no se rellena con un pie.
