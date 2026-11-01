---
esfuerzo: high
release: no
depende: PR #721 (S35f widgets-auditoria-rediseno, tanda 1 de los widgets)
---
# Widgets tanda 2: Entradas y salidas y Resumen del mes con el lenguaje nuevo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-tanda-2-flujo-resumen` · Sesión cola **S35f1** · al cerrar → **S35f2** (`widgets-tanda-3-categorias`).

## Contexto
Segunda tanda del rediseño de los widgets de la pantalla de inicio (WidgetKit) que pidió Jürgen el 31-oct («están horribles… que se vean bien, dinámicos, modernos, que den valor», «gráficas agradables, fondo adecuado, respetando el design system»). La tanda 1 (S35f, PR #721) dejó la base y la auditoría completa:
- Auditoría con la tabla por widget: `docs/widgets/AUDITORIA-WIDGETS-2-2.md` (filas de tanda **2**).
- Reglas: `.claude/rules/widgets.md` (tokens `WidgetDS`, colores AA, tintado/StandBy, lógica en `WidgetInsightsLogic`).
- Piezas: `YalaWidgets/Views/WidgetCardComponents.swift` (cabecera con insignia, cifra héroe, píldora, barra con ritmo, frescura, refresco).
- Banco de capturas: `qa/widget-render/` (README), foto congelada `fixtures/realista-2026-10-31.plist`.

**Antes de empezar**: comprueba que el PR #721 está en `origin/2.2` (`git log origin/2.2 --oneline | grep -i widgets`). Si aún no entró, rebasa tu rama sobre la suya y dilo en el PR.

Cards:
- `tablero ver tablero-widgets-tanda-2-entradas-y-salidas-y-res-wvoj`

## Qué se pide
1. **Entradas y salidas** (S/M/L/XLV, `YalaWidgets/Widgets/CashFlowWidget.swift` y `CashFlowPortraitView.swift`): fuera la «cascada» de barras con degradado y los ejes de 8 pt. Ingreso y gasto con barras sólidas (turquesa y rosa de marca como relleno), neto como cifra héroe, comparación con el período anterior donde la foto lo permita (`WidgetInsightsLogic`). Mantén lo que fijan los source-scans: `ExpensesOnlyAuditTests` (rótulo «Gastado» y exactamente tres `entry.kpiTitle(fallbackKey:` en el fichero) y `ApproximateMarkWiringTests` (`isEstimate: entry.netCashFlowIsApproximate`).
2. **Resumen del mes** (XL de iPad y XLV del iPhone, `MonthSummaryWidget.swift` y `MonthSummaryPortraitView.swift`): los `Link` tiñen de azul los nombres y títulos (auditoría); recomponer con las piezas de la tanda 1, donut con importes en la leyenda y enlaces sin tinte.
3. **«Mostrar variaciones» llega a los widgets**: la preferencia de la app no se copia al App Group, así que la comparación de Gastos (tanda 1) sale aunque esté apagada. Cópiala como las demás que ya viajan (`defaultPeriod`, `firstWeekday`, `expensesOnlyMode`): escritor en la app, entrada en las listas de borrado (`DataWipeService`, `GroupsOnlySignUpPreferenceReset`) y lectura en `WidgetDataService`. Con la variación apagada, Gastos enseña el promedio diario.
4. Capturas antes/después con el banco (claro, oscuro, StandBy, tintado aprox.) en `capturas/widgets/` y el par de cada widget en el digest; comprobación real en la pantalla de inicio del simulador (Teñido incluido).
5. Pasa los widgets tocados a `WidgetDS` y añádelos a la lista de `WidgetDesignSystemParityTests.losRedisenadosSoloUsanWidgetDS`.

## Qué NO hay que tocar
Lógica de datos de la app más allá de copiar la preferencia al App Group. Ni `marketing/` ni `Web/`. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Los dos widgets rediseñados, la preferencia respetada, tests verdes (incluidos los source-scans de arriba), review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en el digest. La card pasa a «in qa» de Jürgen si hay algo que mirar en el iPhone o el iPad.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen: card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra. Si sale algo que no cabe, cards 2.2 «ready to launch», `cierra-sola`, alta, de frank, listadas en el PR.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-10-31, autocontestado)

- **Base**: PR #721 aún en cola (tests corriendo). La rama se rebasa sobre `encargo/2026-10-31-widgets-auditoria-rediseno` y el PR lo dice.
- **Entradas y salidas** — cifra héroe = neto (con signo; en «Solo gastos», lo gastado). S: héroe + dos barras finas proporcionales (entró / salió); en «Solo gastos», héroe + promedio diario. M: héroe + comparación a la izquierda, dos barras sólidas con importe a la derecha. L y XLV: lo mismo arriba y, debajo, barras por día (o por mes en año/todo) de ingreso hacia arriba en turquesa y gasto hacia abajo en rosa, sin ejes, sobre el período entero; XLV además el reparto por cuenta. Se retira la fila «Neto» del XLV (ya es la cifra héroe).
- **Comparación** del flujo: neto de ahora contra el neto del período anterior **a la misma fecha** (solo «Este mes» y «Este año», como Gastos). Píldora con la diferencia en importe (subir = índigo, bajar = rosa) y «vs. setiembre». La cuenta va a `WidgetInsightsLogic.flowComparison` con tests. Sin movimientos en el anterior, no hay comparación.
- **Resumen del mes** — XL y XLV con `WidgetCardHeader`, cifras en `title2`, donut sólido con el gastado en el centro y leyenda con importe y %, presupuestos con la fila de la tanda 1 (`BudgetRowView`). Los enlaces pasan por un `Link` que fija `Color.primary` (el `.secondary` dentro de un `Link` deriva del tinte: por eso salían azules). Se retira `MonthSummaryBudgetRow`.
- **«Mostrar variaciones» (`showVariations`)** — escritor doble: el `didSet` de `AppPreferences` lo copia al App Group y recarga los widgets (solo con el almacén real, no en tests aislados) y `WidgetDataCache.saveSnapshot` lo copia como `defaultPeriod`. Ausente = activado (su default). Se borra en `DataWipeService` y `GroupsOnlySignUpPreferenceReset`, y entra en `TestProcessGuard.protectedKeys`. **Alcance**: apaga TODAS las comparaciones de los widgets, también la píldora de Saldo (tanda 1), porque en la app la preferencia apaga todo chip de variación (`VariationChip`, `HeroHeader`). Opción reversible; anotada en el PR.
- Tokens nuevos: `WidgetDS.Typography.title2/title3` (espejo de DS) y `WidgetDS.Chart.donut*`/`flowBar*` (propios).
