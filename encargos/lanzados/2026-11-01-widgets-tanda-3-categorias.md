---
esfuerzo: high
release: no
depende: PR #721 (S35f widgets-auditoria-rediseno, tanda 1 de los widgets)
---
# Widgets tanda 3: Categorías y Subcategorías, el control «Nuevo registro» y adiós al WDS viejo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-tanda-3-categorias` · Sesión cola **S35f2** · al cerrar → **S35f3** (`widget-grupos`).

## Contexto
Tercera tanda del rediseño de los widgets de la pantalla de inicio que pidió Jürgen el 31-oct. La base, la auditoría y las reglas son las de la tanda 1 (S35f, PR #721):
- `docs/widgets/AUDITORIA-WIDGETS-2-2.md` (filas de tanda **3** y la del control).
- `.claude/rules/widgets.md`, `YalaWidgets/Views/WidgetCardComponents.swift`, banco `qa/widget-render/`.

**Antes de empezar**: comprueba que los PR de S35f y de S35f1 están en `origin/2.2`; si no, rebasa sobre sus ramas y dilo en el PR.

Cards:
- `tablero ver tablero-widgets-tanda-3-categorias-y-subcategori-fhya`

## Qué se pide
1. **Categorías y Subcategorías que más gastas** (M, `TopCategoriesWidget.swift`, `TopSubcategoriesWidget.swift`): título que no se trunque, ranking con insignia sólida, barra sólida e importe legible; el porcentaje deja de ir en el color de la categoría (no pasa AA).
2. **Categorías y Subcategorías en tarta** (L, `CategoriesPieWidget.swift`, `SubcategoriesPieWidget.swift`, `Views/WidgetSectorChart.swift`): fuera las burbujas que se solapan y se cortan; donut con el total en el centro y leyenda con importe y porcentaje. Mantén `isEstimate: entry.expenseIsApproximate` (lo fija `ApproximateMarkWiringTests`) y el trozo «Sin categoría» (`CategoryBreakdownUncategorizedTests`).
3. **Control «Nuevo registro»** en el Centro de Control (`ControlWidgets.swift` + un intent en `Yala/Shared/ControlCenterIntents.swift` que deje `new-transaction` como acción pendiente, el mismo camino que voz y foto; comprueba que la app la atiende al abrirse).
4. **Retirar el `WDS` viejo** (`YalaWidgets/Theme/WidgetDesignTokens.swift`) cuando ningún widget lo use, con `WidgetKPI`, `WidgetHeader`, `WidgetProgressBar` y `MiniTrendChart` si quedan sin usos, y las invitaciones (`WidgetNoDataInviteView`, `GroupsOnlyInviteView`) pasadas a `WidgetDS`. `WidgetKPI` lo exige un scan (`ApproximateMarkSecondarySurfacesWiringTests.passthroughComponentsForwardTheMark`): si se retira, ese scan pasa a mirar el componente que lleve la marca (`WidgetHeroAmount`), no se borra.
5. Capturas antes/después con el banco y comprobación real en el simulador; los tocados entran en la lista de `WidgetDesignSystemParityTests.losRedisenadosSoloUsanWidgetDS`.

## Qué NO hay que tocar
Lógica de datos de la app. Ni `marketing/` ni `Web/`. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Los cuatro widgets rediseñados, el control nuevo funcionando, `WDS` retirado, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en el digest. La card a «in qa» de Jürgen si hay algo que mirar en el iPhone.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen: card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra. Si sale algo que no cabe, cards 2.2 «ready to launch», `cierra-sola`, alta, de frank, listadas en el PR.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (S35f2, 2026-11-01)

Comprobado: #721 (S35f) y #722 (S35f1) están en `origin/2.2`; no hace falta rebasar sobre sus ramas. Ficheros (nota,
MODO AUTÓNOMO): los cuatro widgets, `WidgetCardComponents.swift`, `WidgetInsightsLogic.swift` (+ tests), las dos
invitaciones, `WidgetAmountText.swift`, `WidgetExtraLargePortrait.swift`, `ControlWidgets.swift`,
`YalaWidgetsBundle.swift`, `ControlCenterIntents.swift`, `AppBootstrapper.swift` (el caso del control), los 16
`Localizable.strings` del widget, los dos tests de scan, `widgets.md`, la auditoría y `coverage-index.json`. Se borran
`WidgetDesignTokens.swift`, `WidgetKPI`, `WidgetHeader`, `WidgetProgressBar`, `MiniTrendChart` y `WidgetSectorChart`.

| Decisión | Elegido | Por qué |
|---|---|---|
| Título de los Top que no cabe | `ViewThatFits`: el título largo con el período; si no cabe, el corto («Categorías» / «Subcategorías», que ya existe en los 16 idiomas) con el período | Sin copy nuevo ni recortes; el alemán y la versión de subcategorías no caben en largo |
| Fila del ranking | Insignia sólida con el icono (color de la categoría), nombre, importe en primario a tamaño fijo, % en gris, barra sólida del % del total | La fila de Presupuestos de la tanda 1; el % en color no pasaba AA |
| Tarta: cuántas en la leyenda | Hasta 5 filas; con más, las 4 primeras y «Otros» con el resto, y el aro se agrupa igual | Como la tarta del Panel (top N + Otros) y para que aro y leyenda digan lo mismo. «Sin categoría» es un trozo más: sale cuando está entre los primeros y, si no, cae en «Otros», como en la app |
| La cuenta de la agrupación | `WidgetInsightsLogic.pieLegend` con tests | Regla del área: lo que el widget deduce vive ahí |
| Total del centro | Primario (no rosa), con `isEstimate: entry.expenseIsApproximate`, lo único teñido | Colorear la excepción; una cosa teñida por widget |
| Tintado en los Top | Se tiñen las barras | Como Presupuestos |
| Refresco | `WidgetRefresh.nextDate` (medianoche o +4 h) | Política común G10 |
| Pie de frescura | En las dos tartas (grandes), como los grandes de la tanda 1 | G9 |
| Control «Nuevo registro» | Intent `OpenNewTransactionIntent` que deja `new-transaction` en `pendingControlAction`; la app gana ese caso en `checkForPendingControlAction` (hoy solo atiende voz, foto y panel) | El mismo camino que voz y foto; el enlace `new-transaction` ya existe para widget y atajo |
| Textos del control | Claves nuevas `widget.control.newRecord(.desc)` con valores que ya existen en cada idioma (`widget.ui.newRecord` y la primera frase de `widget.gallery.quickManual.desc`) | Sin traducciones inventadas |
| `WidgetAmountText` por defecto | `WidgetDS.Typography.labelSmall` / `captionSmall` | Nadie usa el valor por defecto salvo su preview; quita el último `WDS` |
| `WidgetSectionTitle` y `WidgetLabeledAmount` | Se borran: no tienen usos | Retiro del `WDS` |
| Scan de `WidgetKPI` | Se quita su comprobación; `WidgetHeroAmount` ya está en el mismo test, y se añade el total de las tartas | Lo pide el encargo: el scan mira al que lleva la marca |
