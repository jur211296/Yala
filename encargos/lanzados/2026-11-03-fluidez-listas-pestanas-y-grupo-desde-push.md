# Fluidez de listas y pestañas, y abrir un grupo desde su notificación con los datos al día

Cierre: **cierra-sola** → al terminar, `/cerrar-total`. Esfuerzo: high.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-listas-pestanas-grupo-push` · Encargo 04 de la cola Yala (junta S35l1, S35l2 y S35l3) · al cerrar → encargo 05.

## Contexto
Tres cards chicas de 2.2 que deben entrar antes del barrido QA (regla de Jürgen del 2026-10-30: todo en 2.2 antes del barrido, nada a backlog).
- 1jvv: hallazgo del PR #734 (Fluidez C1/C3/C7). Ese PR hizo que borrar, deshacer o añadir filas en Registros, Grupos (gastos, saldos iniciales, liquidaciones) y Presupuestos se funda (`animatesRowEdits(ids:)` en `Yala/App/DesignSystem/ContentTransitions.swift`). Pero la animación vive en la rama con filas: al borrar la ÚLTIMA fila, la vista cambia a la rama de estado vacío en seco, y la primera alta después tampoco anima. Pista: subir `animatesRowEdits` (o una animación implícita sobre «hay filas») al contenedor que también monta el vacío, sin animar cambios de filtro. Regla del sistema común en `swiftui-ds.md` («Fluidez: el sistema común») y auditoría en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`.
- oxyr: sale de la card C2 (s1ve, PR #747 fluidez-animaciones-apagadas). C2 arregló los sitios de la lista C2 de la auditoría y sus hermanos en esos ficheros; quedan fuera los que la auditoría no listó. Inventario del 2026-11-02 (grep en `Yala/App/Views`): ~30 `withAnimation(` y ~40 `dsWithAnimation(` fuera de los ficheros de C2. Probables de pestaña: tartas del Panel (CategoriesPieWidget, SubcategoriesPieWidget, TagsPieWidget), SiriTipCard, PanelWidgetSection (showOnly), PanelView, CategoriesTabView:795, StatisticsFocusScroll, SankeyLabelModeToggle, GroupDetailView (4), GroupStatsView, Reportes y flujo de caja (CashFlowMonthStrip, CashFlowTableView, CashFlowSetupView, CashFlowMonthDetailView, GroupingChipsBar, ReportComparisonViews). En hojas (sí animan; solo revisar Reducir movimiento): Inbox, GroupExpenseFormView, ScheduledPaymentEditorView, RecordsFiltersView, MoreEditorSheet. Molde: `TabImplicitAnimationsWiringTests` (needles + deadWrappers).
- th4n: reportado por Jürgen en TestFlight 2.2 (5). Al tocar una push de Grupos, Yala abre el grupo correcto pero muestra datos viejos hasta hacer pull to refresh. #697 y #705 arreglaron destino y texto del aviso, no la recarga.

## Cards y criterio de hecho
- `tablero-fluidez-borrar-la-ultima-fila-de-una-lis-1jvv` — Fluidez: borrar la última fila de una lista salta al vacío en seco
  - Hecha cuando: Borrar la última fila y añadir la primera en Registros, detalle de grupo y Presupuestos pasan entre lista y vacío fundiéndose, con Reducir movimiento respetado y los XCUITest de borrado en verde; vídeo.
- `tablero-fluidez-los-withanimation-de-pestana-que-oxyr` — Fluidez: los withAnimation de pestaña que la auditoría no listó
  - Hecha cuando: Cada sitio clasificado (pestaña u hoja); los de pestaña animan con `.animation(_:value:)` implícita y DS.Animation en su contenedor (o se retira el envoltorio si no hay nada que animar), entran en TabImplicitAnimationsWiringTests y se ven en vídeo; los filtros que cambian la página entera siguen en seco.
- `tablero-entrar-a-un-grupo-desde-su-notificacion-th4n` — Entrar a un grupo desde su notificación no trae los cambios al instante; hay que hacer pull to refresh
  - Hecha cuando: Tocar una notificación de grupo, en frío, en segundo plano y con la app delante, abre el grupo ya con el cambio que avisó, sin pull to refresh; con test de UI que caiga si se quita el arreglo.

## Qué se pide
1. Lee cada card y su ticket, si tiene. Busca la causa raíz antes de tocar código.
2. Cumple el «hecha cuando» de cada card con tests (unitarios, source-scan o XCUITest según el caso): `ContentTransitionsWiringTests` para cada lista de 1jvv, `TabImplicitAnimationsWiringTests` para oxyr y un test de UI para th4n que caiga si se quita el arreglo.
3. Lo visual va con vídeo antes y después en `_capturas/` y en el digest, más un guion corto de device-QA para Jürgen (el de th4n en iPhone con dos cuentas: en frío, en segundo plano y con la app delante).

## Qué NO hay que tocar
- Filtros o cambios de período que reemplazan la lista o la página entera siguen en seco.
- No cambiar curvas ni el mapa de `DS.Haptic`; sin hápticos nuevos.
- Destino y texto de las notificaciones (ya los arreglaron #697 y #705).
- marketing/, Web/, nada fuera de estas cards.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- Tests verdes, incluido el XCUITest del área.
- Review adversarial del diff hecha.
- PR a 2.2 con auto-merge.

## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **1jvv · dónde vive la animación del vacío.** Un contenedor común (`ZStack(alignment: .top)`) con las dos ramas, cada
   una con `.transition(.stateSwap)` (la que se va no se lee ni se toca), y `.animatesEmptyStateSwap(ids:)` que solo anima
   cuando una edición PEQUEÑA vacía la lista o le pone la primera fila (`RowListEditLogic.crossesEmpty`). Las filas siguen
   con su `animatesRowEdits` de dentro, intacto. Alternativa descartada: subir `animatesRowEdits` al contenedor (animaría
   también el calendario y el hero de Registros en cada borrado). Listas: Registros (lista entera y día del calendario),
   detalle de grupo (gastos) y Presupuestos. Saldos del grupo no: su vacío depende de deudas y saldos, no de sus filas, y
   no se cruza con un gesto de esa pantalla. Pagos planificados ya montaba el vacío dentro del contenedor animado.
   Un filtro que deja 1-3 filas sigue fundiéndose (regla ya documentada); uno que vacía una lista larga, en seco.
2. **oxyr · alcance.** Inventario completo de `withAnimation`/`dsWithAnimation` fuera de C2, clasificado pestaña/hoja.
   Pestaña → implícita en su contenedor y entra en `TabImplicitAnimationsWiringTests`, o se retira el envoltorio si no
   anima nada. Hoja → solo Reducir movimiento. Filtros de página entera → en seco.
3. **th4n · causa y arreglo (sin datos del estado de la app en el reporte).** Pedir un ciclo con otro en vuelo devolvía
   `.coalesced` en el acto y el detalle recargaba lo viejo; el cambio dependía del `dataVersion` del final del ciclo, que
   el freno de 150 ms descarta con la app inactiva o en segundo plano; con el grupo ya abierto, el aviso ni recargaba.
   Arreglo: `syncNowFromUI/Push` esperan a la vuelta en vuelo (`awaitRunInFlight`); el aviso marca la apertura
   (`GroupNotificationOpening` → `SceneNavigation.groupOpenedFromNotification`) y el detalle, nuevo o ya abierto, recarga lo
   del teléfono, espera al ciclo y recarga directo; si se abre nuevo, mantiene el esqueleto hasta 4 s. Destino y texto de
   los avisos, sin tocar.
4. **Test de UI de th4n.** Seam `-uitest-group-push-change <new|edit|settlement>`: vuelta fingida del canal que aplica el
   cambio al acabar; cinco casos (frío, delante ×3 tipos, segundo plano con el grupo abierto). Se miden con el arreglo
   quitado.
