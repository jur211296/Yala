---
esfuerzo: medium
release: no
---
# Estadísticas y el flotante dicen qué falta; globo de comparación al día y chips enteros en Planificación y Reportes

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `estadisticas-avisos-y-retoques` · Sesión cola **S33** · al cerrar → **S34** (`banner-deshacer-abajo`).

## Contexto
Tres retoques de la misma zona:
- La fila bajo el hero de Estadísticas (`StatsQuickActionsSlot`) no recibe `hasAccounts` ni `needsCategories` y se queda gris sin explicación; el botón flotante (`FABStackView`) también sale gris sin decir por qué. El Panel ya lo resuelve («Crea tu primera cuenta» / «Crear categorías»).
- El globo de ayuda de la comparación (`ComparisonTip`) habla de «P-1»/«A-1», etiquetas retiradas (PR #675).
- En Planificación (`PlanningView.navigationChipsBar`) y Reportes (`FinancialReportView`) el chip pulsado se corta arriba y abajo; Estadísticas lo arregló con `.scrollClipDisabled()`.

Cards:
- `tablero ver tablero-estadisticas-y-el-boton-flotante-siguen-7jfp`
- `tablero ver tablero-estadisticas-el-globo-de-ayuda-de-la-com-g6nw`
- `tablero ver tablero-planificacion-y-reportes-el-chip-pulsado-nawy`

## Qué se pide
1. Estadísticas y el flotante dicen qué falta y ofrecen la salida, como el Panel; XCUITest del caso.
2. Reescribe el globo para los chips «Con el mes anterior» / «Con <mes> de <año pasado>» en los 16 idiomas; sin claves huérfanas en los .strings.
3. `.scrollClipDisabled()` en las dos filas de chips; en Reportes comprueba que el cristal cabe con el padding del VStack.
4. Capturas antes/después en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El resto de Estadísticas y la lógica de comparación. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Qué enseña el botón flotante cuando falta algo.** El mismo botón rosa relleno de la fila del Panel, flotando:
   «Crea tu primera cuenta» o «Crear categorías», y al tocarlo abre esa salida. Sustituye al «+» gris mudo en las tres
   pantallas que lo montan (Panel, Estadísticas, Registros): el flotante es un componente compartido y dejar un solo
   sitio callado sería la misma incoherencia. Reversible: es la rama «no se puede registrar» de `FABStackView`.
2. **Qué abre la salida fuera del Panel.** Lo mismo que el Panel: alta de cuenta; para categorías, crea las de siempre
   si no hay ninguna propia, o abre Ajustes › Categorías si las hay. Una sola hoja por pantalla (`sheet(item:)`).
3. **Regla de «hay categorías».** Estadísticas y Registros pasan a la regla del Panel
   (`PanelQuickActionsGateLogic`): las subcategorías de sistema de Grupos no cuentan. Antes las contaban y el «+» salía
   activo sin nada que elegir (el caso S12h del Panel).
4. **Ids de XCUITest.** «Crea tu primera cuenta» de la fila toma el prefijo (`stats_create_first_account`); en el Panel
   sigue `panel_create_first_account`. Flotante: `fab_create_first_account` / `fab_create_categories`.
5. **Globo de la comparación.** Se reescribe (no se retira) en los 16 idiomas, sin nombrar las etiquetas: «Elige con qué
   comparar tus cifras: con el periodo anterior o con el mismo periodo del año pasado». Se borran `comparison.monthShort`
   / `comparison.yearShort` y `ComparisonMode.shortName`, que solo servían al globo.
6. **Chips.** `.scrollClipDisabled()` en Planificación y Reportes; Reportes ya reserva `DS.Spacing.sm` arriba y abajo,
   el mismo aire que `navigationChipsInset` de Estadísticas.
7. **Cards al cerrar.** Las tres a «in qa» de Jürgen solo si queda algo que solo el iPhone vea; el globo de TipKit no se
   fuerza en el simulador sin seam, así que su card queda en qa para un vistazo.
