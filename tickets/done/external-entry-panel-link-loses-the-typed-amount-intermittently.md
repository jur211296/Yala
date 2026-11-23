---
id: external-entry-panel-link-loses-the-typed-amount-intermittently
status: qa
priority: high
area: "transactions, statistics, testing"
created: 2026-10-15
updated: 2026-11-06
source: gate del lote 15 de la auditoría UX 2.2 (encargo 2026-10-15-auditoria-ux-2-2-lote-15-desde-fuera)
---

# `ExternalEntryForeignSheetUITests` pierde a veces el importe escrito tras el enlace al Panel

## Medido (2026-10-15, iPhone 17 Pro, iOS 27.0, `Yala Dev`, rama del lote 15 sobre `origin/2.2`)

- En la corrida del gate (11 suites, 40 casos, centinela «estuviste solo»), un rojo:
  `test_halfFilledFormInAnotherTab_panelLink_keepsTheForm` → «El importe escrito se perdió (valor: «0.00»)»
  (`ExternalEntryForeignSheetUITests.swift:184`).
- El mismo caso aislado, dos veces seguidas en el mismo simulador: verde las dos (34 s y 32 s).
- El camino que prueba (`yala://panel` → `setOrDeferDeepLink(.panel)`) no lo tocó el lote 15.

## Hipótesis (sin medir)

Familia de la regla de `.claude/rules/testing.md` sobre `typeText` en iOS 27.0: el teclado sigue entrando y lo escrito
no llega entero al campo antes de salir a segundo plano. Si es eso, es el test y no el producto.

## Hecho cuando

- Se mide si el valor se pierde en la app (el campo vacío tras volver) o en la escritura del test, con N corridas.
- Arreglado el que toque, o en la Lista Negra con dueño y fecha.

## 2026-10-18 · otra vez, en el caso de voz

Gate de los lotes 11 y 16 (batería completa, centinela «estuviste solo»): rojo en
`test_halfFilledFormInAnotherTab_voiceEntry_keepsTheFormAndOpensOnThePanelWhenClosed` (`:111`, «0.00»); aislado justo
después, verde (34,6 s). Mismo patrón que el del 15-oct en el caso del enlace.

## Medido el 2026-10-22 (sesión «Auditoría UX 2.2 · siguiente lote»)

Sale también en `test_halfFilledFormInAnotherTab_sharedPhoto_keepsTheFormAndReadsWhenClosed` («El importe escrito se
perdió (valor: «0.00»)»), no solo en el del enlace al Panel. Reproducido en la base `d72ff0263` (2.2 sin los cambios de
esa sesión): 1 de 3 iteraciones de la suite (`-test-iterations 3`). En la rama de la sesión, el del enlace al Panel cayó
una vez y el de la foto otra, en corridas distintas.

## 2026-11-05 · medido: lo pierde la APP (lote T3)

Ya no es una hipótesis del test. Medido en el iPhone SE (3.ª gen, iOS 27.2), `Yala Dev`, corrida vigilada (centinela 0),
`ExternalEntryForeignSheetUITests` con `-test-iterations 3`: `test_halfFilledFormInAnotherTab_panelLink_keepsTheForm` cayó
**1 de 3** en `:209` («El importe escrito se perdió (valor: «0.00»)»). En la misma tanda, los otros seis casos 3 de 3; en el
iPhone 17 Pro (27.2), los siete 3 de 3.

- **El tecleo llegó**: el caso espera a que el campo diga `1234` antes de pulsar Inicio (`launchWithHalfFilledFormInStatistics`).
- **No hubo relanzamiento**: `pid=51047` al arrancar y al volver.
- **La hoja se desmontó y se volvió a montar sin cerrarse**. Traza de la vuelta (`UITestHooks.lifecycleSummary`):
  `freshForm d=1, fase inactive d=1, fase background d=1, fase inactive d=1, pestaña panel d=1,
  formulario fuera abierto=true d=1, freshForm d=1, formulario fuera abierto=true d=1, freshForm d=1, fase active d=1`
  — `formularios=3`. Dos `onDisappear` de `NewTransactionView` con `showNewTransaction` aún en `true`, y cada vuelta con
  `formBaseline == nil`, o sea un `@State` nuevo.

### Dónde (citado del árbol de `origin/2.3` en `6b6b71dfb`)

- La hoja: `Yala/App/Views/Statistics/DetailContainerView.swift:839-846`, `.sheet(isPresented: $recordsViewModel.showNewTransaction) { NewTransactionView() … .onDisappear { traceLifecycle("formulario fuera abierto=…") } }`, dentro de `DetailContainerSheets` (`:810`).
- Se cuelga del CONTENIDO de la página: `DetailContainerView.body` (`:222-235`, `mainContent … .modifier(DetailContainerSheets(…))`), que es la raíz de la pila de Estadísticas.
- El marcador del montaje nuevo: `Yala/App/Views/Transactions/NewTransactionView.swift:728-730` (`if formBaseline == nil { formBaseline = …; noteLifecycle(.freshForm) }`).
- Lo que lo dispara: el enlace `yaladev://panel` cambia la pestaña a Panel por debajo con la hoja abierta (`pestaña panel` en la traza).

### Causa (inferida, sin aislar)

Es la familia de la regla de `swiftui-ds.md` «una hoja colgada del contenido RAÍZ de una `NavigationStack` se reconstruye
desde cero … sin cerrarse» (medida el 2026-11-05 con Exportar al cambiar el tamaño del texto): aquí lo que reconstruye
el contenido es el cambio de pestaña con la app volviendo a primer plano. El molde de esa regla es colgar la hoja con
estado del CONTENEDOR de la pila. Falta medir si basta con eso o si el `NewTransactionView` necesita además guardar su
borrador fuera de la vista. Afecta igual a los casos de foto y voz del mismo fichero (los rojos del 18 y 22-oct).

### Para quien lo arregle

- Red: `ExternalEntryForeignSheetUITests` (los siete casos), con `-test-iterations 3` o más; en el SE sale antes.
- El caso de `:209` lleva un comentario que lo marca como este bug; al arreglarlo, quitar esa nota del mensaje.
- Card del tablero: «Nuevo registro desde Estadísticas pierde el importe al salir y volver por enlace» (`xhp6`).
- No se tocó código de app en el lote T3 (decisión de Jürgen del 5-nov: card aparte).

## 2026-11-06 · Arreglado: la hoja cuelga del contenedor de la pila

- Reproducido en la base (`origin/2.3` en `b182e5774`), iPhone SE (3.ª gen) iOS 27.2, `-test-iterations 3`: **1 de 21**
  (caso de la foto compartida), «0.00» con la traza `freshForm` ×3 y `formulario fuera abierto=true` ×2.
- Arreglo: la hoja de «Nuevo registro» la presenta `StatisticsView`, por fuera de la `NavigationStack`, y
  `DetailContainerView` (contenido raíz de la pila) ya no la presenta; solo recarga al cerrarse. El `RecordsViewModel`
  sube a `StatisticsView` para que los botones sigan escribiendo la misma bandera, y la hoja recibe el
  `savedRecordEditorOpener` que antes heredaba. Molde de la regla de `swiftui-ds.md`.
- Con el arreglo, mismo SE, `-test-iterations 5`: **35 de 35** verdes. Bastó con el ancla; no hizo falta guardar el
  borrador fuera de la vista. Como el rojo es intermitente (1 de 21), 0 de 35 es una señal fuerte pero no una prueba:
  la red sigue siendo `ExternalEntryForeignSheetUITests`. Pin de sitio: `StatisticsNewTransactionSheetAnchorWiringTests`.
- Registros no tiene el patrón: su hoja cuelga del `ListDetailSplit`, que es el contenedor.
- QA en el iPhone: Estadísticas › Nuevo registro › escribe un importe › Inicio › abre `yala://panel` (o comparte una
  foto) › al volver, el importe sigue.
