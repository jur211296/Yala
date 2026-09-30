---
description: Reglas inviolables de SwiftUI, presentaciones, Design System y fondos de vista. Se cargan al trabajar con vistas.
paths:
  - "Yala/App/Views/**"
  - "Yala/App/ContentView.swift"
  - "Yala/App/ViewModels/**"
  - "Yala/App/DesignSystem/**"
  - "Yala/App/Theme/**"
  - "YalaWidgets/**"
---
# SwiftUI · Presentaciones · Design System

## Estado
- `@Observable` SIEMPRE con `@MainActor`. `@State` SIEMPRE `private`.
- NUNCA `Binding(get:set:)` en body — usar `@Binding` + `.onChange()`.
- NUNCA `@AppStorage` dentro de `@Observable` (no triggerea updates).
- Preferir `@Observable` + `@State`/`@Bindable` sobre `ObservableObject`/`@Published`/`@StateObject`.
- **Preferencias persistentes → `AppPreferences` inyectado via `@Environment`.** NUNCA `@AppStorage` directo en views nuevas.

- **Mover un cálculo del body a una propiedad del VM CORTA el live-binding a los `@Model` que ese cálculo leía.** Un body que recorre objetos SwiftData queda observando sus propiedades una a una, así que una mutación **en sitio** (mismo objeto, otro importe) repinta sola sin que nadie recargue. Al precalcular en el ViewModel eso se acaba: la vista pasa a observar únicamente la propiedad del cache, y el refresco depende **entero** de que todo mutador llegue al recálculo. Medido el 2026-09-06 al mover las deudas de la tarjeta de grupo a `GroupsViewModel.debtsByGroup` (`recalculate()`): la lista de Grupos ya no repinta por una mutación in-place suelta, y `GroupsSyncClient.pullUntilExhausted` tiene salidas tempranas (`.transient`, sesión caducada, cap de iteraciones) que dejan páginas **aplicadas y guardadas sin bumpear `dataVersion`** — ahí la cifra se sostiene vieja hasta el próximo `onAppear`, pull-to-refresh o bump. ⇒ **Al precalcular en un VM, comprueba primero que TODO camino de mutación desemboca en el recálculo**, y prefiere la mutación que bumpea a confiar en la observación accidental. Contrapartida medida: en esa lista el cálculo en el body costaba **~25 ms por tecla del buscador** con 30 grupos, más que un frame entero.


## Gotchas de vistas

- **Cancelar una tarea que crea un `onChange` ANTES de cambiar su valor no la cancela (medido 2026-09-30).** El
  `onChange` corre en el render SIGUIENTE a la escritura, cuando el `cancel()` ya pasó, y la tarea nace después.
  Mordió en la gracia de 5 s del aviso de vaciado remoto de `ContentView`: los borrados deliberados la «cancelaban»
  antes de bajar `hasPersonalData`, y solo se salvaban porque bajaban también `hasCompletedOnboarding`, que cierra el
  guard. Los dos que lo reponen —«Vaciar datos» en solo-grupos y el restore remoto con `skipOnboarding`— encendían el
  aviso. ⇒ lo que tiene que impedir la reacción viaja al `onChange` como estado que él CONSUME (la absorción de
  `RemoteWipeGraceLogic`), armado ANTES de escribir el valor y en la misma vuelta del main actor que el cambio. Y
  **una señal `@State` que se recalcula en el `onChange` de otro contador no cae cuando cambia el store**, sino en el
  siguiente bump: `wipeAllUserData` no bumpea `dataVersion`, así que quien borra re-mide
  (`settleSignalsAfterDeliberateWipe`).

- **`containerRelativeFrame(.horizontal)` en `ScrollView(.vertical)` con `.contentMargins`** → deadlock de layout, splash nunca dismissa, sin crash log. Usar `onGeometryChange`. Detalles en UI-PATTERNS.md.

- **`YalaFormatter` no auto-refresca prefs** — lee `UserDefaults` directo. Vista que lo use con `decimalPlaces` o `currencyDisplayFormat` debe inyectar `@Environment(AppPreferences.self)` y leer `let _ = appPreferences.X` en body para registrar dependencia.

- **Anidar dos hijos de un `HStack` en otro `HStack` NO es neutro cuando la fila va justa (medido 2026-09-28).** `HStack { icono; texto; Spacer(); importe }` y `HStack { HStack { icono; texto }; Spacer(); importe }` pintan igual con holgura, pero con compresión reparten el ancho distinto: en un iPhone SE la tarjeta de grupo pasó a truncar el nombre («Viaje a Cu…») para no encoger el importe, que antes cedía con su `minimumScaleFactor`. Lo cazó un diff píxel a píxel antes/después a tamaño por defecto; a simple vista en el ProMax no se veía. ⇒ **para reorganizar una fila con el tamaño de texto, `AdaptiveRowStack(leading:trailing:)`**, que a tamaño normal pinta la fila plana de siempre y solo anida al apilar. `AnyLayout` obliga a una sola jerarquía para las dos formas, y por eso aquí no sirve.

- **Una pantalla que reparte su alto con `Spacer`s y no tiene scroll no cabe en un iPhone SE (medido 2026-09-28).** Nuevo registro y las pantallas de éxito tras guardar y tras aprobar un borrador se salían por arriba y por abajo **a tamaño normal**: con el teclado abierto en el formulario, y sin él en las de éxito. A AX5, «Guardar» quedaba fuera de alcance, también en el ProMax. ⇒ **envuélvela en `GeometryReader { proxy in ScrollView { VStack { … }.frame(minHeight: proxy.size.height) }.scrollBounceBehavior(.basedOnSize) }`**: cuando cabe, los `Spacer`s reparten igual y no hay scroll (medido píxel a píxel en el ProMax); cuando no, se desplaza. Si la pantalla tiene botones de salida, esos quedan fuera del scroll (molde de `GroupExpenseSuccessView`).

- **`.fixedSize()` en un control ensancha la columna ENTERA cuando el control no cabe (medido 2026-09-28).** La píldora del período (`PeriodSelectorLabel`) con ancho fijo mide más que un iPhone SE a AX5, y su `VStack` padre crece con ella: el Panel y Registros perdían los márgenes y todo el contenido se cortaba contra los dos bordes, no solo la píldora. ⇒ **a tamaños de accesibilidad, `.fixedSize(horizontal: false, vertical: true)`**, para que el texto pase a dos líneas. El síntoma engaña: parece un problema de cada fila, y es de una sola pieza de arriba.

- **`.dynamicTypeSize(...)` dentro del `body` NO topa una fuente `.system(size: X)` con `X` un `@ScaledMetric` (medido 2026-09-28).** El `@ScaledMetric` se resuelve con el entorno de FUERA del `body` y la fuente de tamaño fijo no mira el entorno: 33 de los 41 topes en AX1 que había en el repo no hacían nada. Si un tamaño escalado necesita techo, se topa el propio valor, no la vista.

- **El CI compila con Xcode 26.6 y su compilador tipa peor que el de 27 (medido 2026-09-29).** Cuatro `onChange` más en
  la cadena del `body` de `RecordsStandaloneView` compilaban en local (Xcode 27) y en el CI salieron con «the compiler
  is unable to type-check this expression in reasonable time». Moverlos a un `ViewModifier` propio **no bastó**: ahí,
  cinco `onChange` con cierres de varias líneas volvieron a fallar. Lo que pasa: como mucho **tres modificadores por
  `ViewModifier`** (el molde de los observadores de esa vista) y **cierres de una línea que llaman a una función**.
  Para medirlo en local, con margen: `OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend
  -warn-long-expression-type-checking=20'` y buscar tu fichero en los avisos; lo nuevo debe salir por debajo de lo
  viejo que ya pasa el CI.

- **Forms con `TextField`/`TextEditor`/`SecureField`** (sin `Form`): obligatorio `dismissKeyboardOnTap()` desde el primer commit. Detalles en SWIFT-STYLE.md.

- **Swift Charts `.annotation { }` NO propaga environment objects `@Observable`** → el contenido de una annotation de un mark (`BarMark`/`LineMark`/etc.) se hostea fuera del árbol de la vista; una sub-View que lea `@Environment(AppPreferences.self)` (ej. `AmountText`) NO lo resuelve y dispara `SIGTRAP` (`_assertionFailure` en `EnvironmentValues.subscript.getter`) al renderizar — sin crash log claro. Dentro de annotations usar `Text(...)` con el valor YA resuelto del callsite (`appPreferences.currency(...)` desde `self`) o un formatter estático (`YalaFormatter`), NUNCA una sub-View con `@Environment`. **`.chartOverlay { }` SÍ propaga** (ahí `AmountText` funciona, ej. `CashFlowWidget`). Causa del crash del chip Estadísticas en grupos (`8bb5ace8`).

- **Presentaciones (sheet/fullScreenCover) — 4 reglas del bug "toolbar muerta" (TestFlight 2.0.5):** (1) NUNCA un binding de presentación con setter no-op (`set: { _ in }`) ni sin `onDismiss:` de respaldo — si UIKit tumba la cadena presentada (p.ej. dismiss del sheet debajo de un cover), el estado queda pegado → cover fantasma irrecuperable; el reset del flag JAMÁS puede depender solo de un `Task { sleep; ... }` interno de la vista presentada. (2) **`opacity(0)` NO desactiva hit-testing**: un backdrop full-screen invisible con `.onTapGesture` se traga todos los taps de la app — siempre `allowsHitTesting(isVisible)`. (3) Toda presentación nueva que cuelgue del anchor de ContentView DEBE entrar a `ShellReadinessState`/`blocker()` (matriz de readiness), y los sheets de MainTabView/PanelShell están gateados por `RouterConsumerGateLogic` (peek-first: un intent que presenta se RETIENE en cola mientras un nodo superior tape — nunca se consume tapado). Corolario one-shots: flags tipo `markXShown` se queman en el `onAppear` del sheet real, nunca en el drain ni en el productor. **Corolario del MOMENTO (2026-07-28): «anchor libre» no basta — un cover montado mientras `AppBootstrapper.bootstrap` sigue corriendo se queda PEGADO** (el usuario lo descarta, UIKit no completa el desmontaje y la app ignora todos los taps; medido en iOS 27.0: ~1 de cada 3 arranques, 10 taps perdidos en ~40 s). Lo cubre el blocker `bootstrapPending` (`SessionState.isBootstrapSettled`, liberado por un `defer` de `bootstrap()`), hermano de `splash` y NO redundante con él: el splash se va por su propio reloj y no espera al bootstrap. **Gatear la MATRIZ, nunca un intent suelto**: retener la cola entera preserva el orden por prioridad (aviso de bandeja → paywall); adelantar uno solo invierte la pareja y monta el segundo encima del primero. Y al abrir un gate que estaba reteniendo, un solo drain por tick — `markReady` bumpea revision y el `.onChange(revision)` ya drena; un drain explícito además presentaría dos covers a la vez. (4) **NUNCA dos anchors presentando ante el mismo observable** (bug device sign-out 2026-07-14): UIKit no presenta dos veces y la reconciliación puede tumbar AMBAS cadenas dejando los flags en `true` sin que NINGÚN `onDismiss` corra (jamás se presentaron) → red muerta e irrecuperable; "SwiftUI materializa la presentación pendiente al despejarse el anchor" es FALSO. Un solo DUEÑO de la presentación (los demás anchors ceden — p.ej. cierran su sheet) + verificación de presentación EFECTIVA: solo el `onAppear` del contenido real prueba que UIKit presentó — si no llegó, re-intentar con toggle false→true tras un runloop turn (molde `SignOutRelaunchNetModifier` + `RelaunchNetLogic`); para blockers de la matriz, la CONDICIÓN VIVA del dominio es el input, el `@State` del cover es solo la red visual.

- **Un flag de presentación que además es BLOCKER de la matriz de readiness convierte «la presentación no montó» en un brick de toda la sesión (2026-09-10).** Los dos hechos son buenos por separado —un aviso destructivo tiene que bloquear al router, y el router tiene que retenerse— pero juntos crean un modo de fallo nuevo: si UIKit descarta esa presentación (el caso clásico: **dos `.alert` encadenados desde el mismo anchor**, donde el segundo se enciende mientras el primero se desmonta), el flag se queda en `true`, `blocker()` lo devuelve para siempre, y **el router no vuelve a drenar nada** — ni avisos de bandeja, ni paywall, ni invitaciones de grupo. Sin `onDismiss` no hay rescate, y `.alert` no tiene `onDismiss`. Solo se sale matando la app. ⇒ **una cadena de dos gestos (confirmar → «¿seguro?») no se hace con dos presentaciones del mismo anchor**: o dos CONTENEDORES distintos con el `onDismiss` del primero encadenando al segundo (molde de `UserDataResetView`: sheet → alert), o —mejor— **una sola presentación con FASES dentro**, que es lo que hacen `WelcomePrivateICloudGateView` y `LateICloudMirrorNoticeView`. Las fases dan además sitio para el progreso y el error, que un alert no tiene: sin ellas, entre «sí, borra» y el final pasaban decenas de segundos con la app mostrando nada, y si fallaba, tampoco.

- **Y cuando el aviso que brickea es un `.alert`, la salida medida (2026-09-14) es: condición viva como blocker + sonda a UIKit + desarme.** Un `.alert` no tiene `onDismiss` **ni contenido propio cuyo `onAppear` pruebe que apareció**, así que el molde de verificación efectiva de los covers (`SignOutRelaunchNetModifier`) no se le puede aplicar tal cual: la única señal disponible es la de UIKit —¿hay algo en la cadena `presentedViewController`?— y eso es lo que encapsula `ModalPresentationProbe`. Las tres piezas, y ninguna sobra: (1) el blocker de la matriz es la CONDICIÓN VIVA (`remoteWipeNoticePending`), nunca el `@State` del alert, porque la red toggla ese flag para re-presentar y una matriz colgada de él se abriría **en cada reintento** —50 ms bastan para que el router drene y monte otra cosa debajo—; (2) la red **no termina al confirmar la presentación**: sigue vigilando hasta que el aviso se conteste, porque el brick tiene dos formas y la de «montó y se cayó después» no la cubre un verificador de montaje; (3) **al agotar el cap, se SUELTA la condición viva** — aquí, a diferencia del cover terminal, quedarse retenido cuesta la sesión entera, así que se pierde el aviso y no la app, con canario (`remoteWipeNoticeNotPresented`) para enterarse. **El brick y su cura están medidos con mutantes en simulador**: con la presentación forzada a no montar y un paywall en cola, sin la red el log se queda en `blocked by: remoteWipeAlert` y el paywall no presenta **nunca** (25 s); con ella se suelta a los ~10 s y el paywall entra. **Y el aviso que deja la sonda:** forzada a `false` con el alert REALMENTE en pantalla, los toggles lo dejan **dibujado** aunque el estado se apague entero — UIKit no completa el desmontaje. No brickea (la matriz queda libre), pero por eso la sonda necesita una red viva en el simulador: `RemoteWipeNoticeRoutingUITests` se pone rojo el día que un runtime deje de reconocer la presentación de un `.alert`.

- **Y la otra mitad de la matriz: meter un flag en `ShellReadinessState` protege a los DEMÁS de presentar debajo, no protege a ESA presentación de montarse en mal momento.** Un `@State` encendido desde un `Task` async —una sonda de red que contesta cuando quiere— llega cuando el anchor puede estar presentando el cover de idioma o el sheet del trial, y encender un alert ahí **desmonta el cover** (traza medida en `ShellDataAlertsModifier`). La mitad que falta es entrar por `RouterEntryGate.shared.submit(...)`, que es quien retiene la cola hasta que el anchor esté libre. Regla práctica: **si el productor de una presentación es asíncrono, va por el router**; el `@State` directo solo vale cuando quien lo enciende es un tap.

- **El `actions` builder de un `.alert` NO admite un label dependiente del `@State`, y lo que rompe no es la alerta: es la app.** Medido el 2026-09-06. Al dar título y botón dinámicos a la alerta de invitación de `ContentView` —para que el mismo anchor sirviera a dos avisos distintos— **dejó de completarse el guardado de una transacción**: `TransactionSuccessView` no llegaba a montarse y `dismissTransactionSuccess()` agotaba sus 10 s. El síntoma cae a pantallas que no tienen ninguna relación con la alerta, así que **el diagnóstico por lectura no llega**: hay que bisecar. Aislado con control en las DOS direcciones — `Button(String(localized: "common.ok"))` pasa (×2) · `Button(activeInviteError?.cta ?? …)` falla (×4) — y con el contraste que delimita el alcance: **el TÍTULO dinámico pasa sin problema**, así que la frontera está en el ViewBuilder de `actions`, no en la alerta entera. ⇒ **el texto de los botones de un `.alert` va literal**; si dos avisos comparten anchor, lo que puede variar es el título y el mensaje. Y el corolario de método, que es el caro: un cambio de presentación aparentemente inerte —la alerta estaba OCULTA— puede romper un flujo cualquiera de la app, así que **no basta con correr los XCUITest del área tocada**. Este rojo salió en `QuickActionsFavoritesUITests`, un área que ningún cruce de `codeGlobs` habría señalado como afectada por un cambio en invitaciones de grupo.

## iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO.
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos.
- Si existe API iOS 26 que mejore integración con sistema, USARLA.

## Design System (en cambios UI)
- SIEMPRE `DS.Spacing`, `DS.Radius`, `DS.Typography`, `DS.Semantic.*`, `DS.Gradients.*` — NUNCA hardcoded.
- SIEMPRE filas clicables con `Button` + `contentShape(Rectangle())`. **Y el DÓNDE importa: si el label tiene `Spacer()` (u otro hueco no dibujado) y NO lleva fondo relleno, el `contentShape` va DENTRO del label, tras el padding — nunca colgado del `Button`.** Ahí fuera no extiende el área interactiva sobre el hueco: solo responden los glifos de los extremos y **el centro de la fila queda muerto**, para un dedo humano igual que para un tap sintético. Medido el 2026-08-07 en la fila de divisa de `GroupFormView` (mismo elemento, misma `y`, solo cambia la `x`: sobre el glifo abre el selector, al centro no corre ni la acción — el `.sheet` es inocente). Un label con fondo relleno es inmune y no necesita el matiz: `GroupCardView` (`.listRowCard()`) y `MoreView.heroPanelCard` (`.panelCard(small:)`) fueron MEDIDOS con el mismo instrumento y responden al tap central. Pin: `YalaUITests/Flows/GroupsSmokeUITests.swift#test_groupFormCurrencyRowOpensSelector` — el tap de XCUITest cae en el centro del frame, que es justo el punto muerto, así que devolver el `contentShape` al `Button` lo pone en rojo (verificado, exit 65).
- Componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, etc.
- **Un color de la paleta sobre tarjeta blanca NO vale para TEXTO.** Ninguno de los cinco llega al mínimo AA de 4,5 (`hotPink` 3,77 · `electricIndigo` 4,47 · `priorityNeed` 2,19 · `essentialNeed` 2,15 · `optionalNeed` 2,69), y `AmountText` pinta símbolo y decimales al 60 % de opacidad encima, lo que los baja a ~2,5. Para un monto coloreado usar un tono oscurecido del mismo matiz (`Color.incomeAmount`, #0F7A80, contraste 5,1). En superficies RELLENAS —chips, barras, anillos, iconos— la paleta sigue siendo la correcta: el requisito es del texto. Medido el 2026-09-02.
- **Y colorea la excepción, no la norma.** En una lista de movimientos casi todo son gastos: teñirlos pinta la pantalla entera y el color deja de avisar de nada. Solo el ingreso lleva color (`RecentRecordsWidget`, `ScheduledPaymentsWidget`). Decisión del 2026-09-02 en `docs/DECISIONS.md`.
- **Jerarquía del Panel: sección `title3` (20) › widget `subheadlineEmphasized` (15) › fila.** Hasta el 2026-09-02 la sección y el widget usaban el MISMO token y la fila (`headline`, 17) era el rótulo mayor de la pantalla. Y el aire va al revés que el tamaño: MÁS entre secciones (`xxl`) que del título a su contenido (`sm`), o por proximidad el título se lee como pie del bloque anterior.
- Tablas DS.Semantic / DS.Gradients en SWIFT-STYLE.md.

## Backgrounds de vista
- TODA View root, sheet, fullScreenCover NUEVA → `.yalaScreenBackground(_:ignoredEdges:)`.
- NUNCA aplicar `.background(theme.background)`, `.background(.thBackground)` ni default iOS sin background.
- Forms/Lists dentro de sheet → `.scrollContentBackground(.hidden)` MANUAL antes del modifier (el modifier no lo hace automático para preservar predictibilidad).
- **Regla SSOT (reestructura 2026-06-08)**: el fondo lo determina el **contenedor de presentación RAÍZ** del stack. Una vista navegada (push) HEREDA el fondo de su stack — dentro de un tab → `.panel`; dentro de un sheet → el del sheet. **Un `.sheet` NUNCA es `.panel`.**
- Variantes (`YalaBackgroundVariant`) — 4 (`.compact` eliminada):
  - `.panel` (default) — PanelBackgroundView gradient temático. SOLO vistas COMPLETAS: tab roots, vistas navegadas (push), fullScreenCover normal.
  - `.subtle` — `theme.background` plano. CUALQUIER sheet desde el bottom (sin detents o `[.large]`); TODO el stack del sheet de Profile (los ~20 Settings + sub-navegación); y success/celebración.
  - `.transparent` — sin fondo (DESNUDO, muestra el fondo de sistema del sheet — decisión owner, NO glassSheet). Sheets con detent PARCIAL fijo (`.medium`/`.height`/`.fraction`) que NO pasan por `.yalaSheetDetents`.
  - `.partialSheet` — sheets cuyo detent sale de `.yalaSheetDetents(_:)`: `.transparent` en ventana compacta, `.subtle` cuando la ventana lo fuerza a `.large`. Dual-detent `[.medium,.large]` con `selection: $selectedDetent` → `isLargeDetent ? .subtle : .transparent`.
- `.compact` ELIMINADA. `AnimatedMeshBackground` + `MeshConfigResolver` borrados (dead code).
- **El tamaño de una hoja lo decide la VENTANA, no el aparato (2026-09-28).** Una hoja con detent parcial que en ventana ancha deba ser grande usa `.yalaSheetDetents(_:)` (o `(_:selection:)`) en vez de `.presentationDetents`: en ventana de ancho regular (iPad a pantalla completa, iPhone Duo abierto) o en Mac fuerza `.large`; en compacta (iPhone, iPad en ventana estrecha o Split View) deja los detents. Hoy **19 hojas con detent parcial siguen con `.presentationDetents` a secas** y salen iguales en todas partes (Panel, Flujo de caja, puente de grupos…; ticket `partial-sheets-that-never-adapted-to-the-window`); una hoja nueva que las copie hereda eso. Una vista que necesite el booleano lee `@Environment(\.usesLargeSheets)`. **Nunca** `UIDevice.current.userInterfaceIdiom` para layout, y **nunca** el `horizontalSizeClass` leído dentro de la hoja: ahí lo fija la presentación y no tiene por qué ser el de la ventana que la presenta. Por eso `\.usesLargeSheets` se calcula UNA vez, en la raíz (`YalaApp.rootView` → `.sizesSheetsByWindow()`), y los valores propios del entorno sí llegan intactos a las hojas. Una escena nueva sin ese modificador deja todas sus hojas con los detents de iPhone. Test: `YalaTests/AdaptiveSheetSizingTests.swift`.
- Param `ignoredEdges: Edge.Set?`: si `nil`, default `.all`. Para vistas con `safeAreaInset` pasar edges específicos (`[.top]`, `[.bottom]`).
- OUT: WelcomeFlow/onboarding (`DS.Gradients.heroIndigoBlack` especializado), InboxAlertModal (custom modal Color.black backdrop), popovers (iOS nativo).
- `GlassSheetModifier.glassSheet()` se mantiene como helper de sheets que SÍ quieren material (`.presentationBackground(.ultraThinMaterial)` + drag indicator). `.transparent` NO usa material (es desnudo).

#### Patrones aceptados temporalmente (deuda incremental, migrar al tocar el archivo)

- **Pattern B**: `ZStack { PanelBackgroundView(); content }` manual. Migrado masivamente al modifier (2026-06-08). Residuales aceptados: `PanelView` (tab root complejo con overlays) + las 6 vistas de onboarding/welcome (fondo hero propio, OUT). Sanity: `grep -rn "PanelBackgroundView(" Yala/` solo muestra esas + `PanelBackgroundView.swift` (def) + `ViewModifiers.swift` (modifier).
- **Pattern Subtle**: `ZStack { theme.background.ignoresSafeArea(); ...overlays; content }` en success screens (TransactionSuccessView, SubscriptionSuccessView, InboxApproveSuccessView, InboxBulkApproveSuccessView). Reescribir el ZStack rompería overlays propios (ConfettiView, RadialGradient glow). Semánticamente ES `.subtle`.

## Audit markers
- `// A11Y-DT:` justifica font size hardcodeado (Dynamic Type).
- `// A11Y-DM:` justifica color hardcodeado (Dark Mode).

## Layout adaptativo: raíz y lista-detalle (2026-09-29)

- **La raíz MONTA las seis páginas desde el primer arranque y en la barra de pestañas OCULTA las que no tocan — nunca
  la seleccionada.** `MainTabView` es un `TabView(.sidebarAdaptable)`: en ventana compacta se ven las de siempre
  (configuración + temporal + seleccionada + Más + Buscar), en regular todas las páginas y Buscar, sin Más
  (`RootTabLayoutLogic.mountedTabs` / `shownTabs` / `hiddenTabs`, con test). Las dos mitades están medidas y tiran en
  sentidos opuestos:
  - **Una pestaña añadida al ENSANCHAR tumba la app al estrechar** (2026-09-29, lldb en el crash, iPad Pro 13): UIKit
    reconstruye la barra con las pestañas que tenía en la lateral y, con más de cinco, mete el ítem de las cuatro
    primeras; una pestaña que SwiftUI añadió con la lateral ya puesta no tiene controlador ni ítem hasta que se
    visita (`_tabs_rebuildTabBarItemsAnimated:`, `insertObject:atIndex:: object cannot be nil`). Cerraba la app con
    cinco de las seis páginas; con Registros no, porque entonces las cuatro primeras sí tenían ítem. Las que están en
    el primer montaje sí lo tienen. `.tabPlacement(.sidebarOnly)` no lo evita (UIKit las recorre igual) y el getter
    `UITab.viewController` fabrica un `UIViewController` vacío, no la pantalla.
  - **Una pestaña oculta y SELECCIONADA tumba la app** (`-[_UITabModel _setSelectedItem:…]`, fase 1). Por eso
    `shownTabs` incluye siempre la seleccionada, y **la shell de solo grupos sigue QUITANDO** en vez de ocultar: ahí
    la selección puede quedarse en Panel (lo cazó `GroupInviteOnboardingUITests`). Buscar (los 50 ms de una pestaña
    temporal) y Más (al ensanchar con Más elegida) también se quitan, no se ocultan.
  El orden es el mismo en los dos tamaños y en el iPhone la barra no cambia (medido al píxel). **Barra lateral plana,
  sin `TabSection`**: una sección que solo exista en regular cambia el árbol en cada redimensionado, y una permanente
  reordena la barra del iPhone, que el usuario ordena a mano (`TabBarConfigView`).
- **En vertical el iPad pinta pestañas arriba y en horizontal barra lateral**: es el `.automatic` de Apple y se deja
  así (medido en el iPad Pro 13). La barra lateral está a un toque en vertical.
- **Lista y detalle = `ListDetailSplit`** (`Views/Shared/ListDetailSplit.swift`): un único `NavigationSplitView` de dos
  columnas, `.balanced`, que en compacta se pliega solo a la pila de siempre. Lo usan `RecordsStandaloneView` y
  `PlanningView`; una pantalla nueva con lista y detalle lo reusa en vez de montar su split. Lo que se abre en el
  detalle lleva `.announcesShownInDetailColumn()`: si la lista estaba superpuesta, se retira para que se vea
  (`ListDetailOverlayLogic`, con test). Tres cosas medidas en el iPad (2026-09-29) que el contenedor ya resuelve:
  - **La columna de lista lleva `DS.Adaptive.listColumn*Width` (mínimo 375, el iPhone más estrecho).** Sin tope
    propio el split la deja en ~280-320 pt y las filas de presupuesto parten el importe en tres líneas.
  - **`.toolbar(removing: .sidebarToggle)` DETRÁS de `.navigationSplitViewColumnWidth` hace que el ancho se ignore**
    sin ningún aviso: la columna seguía en 320 con un ancho fijo de 420. Delante sí funciona. Aquí no se quita el
    botón, por lo siguiente.
  - **La visibilidad es un `@State`, nunca `.constant(.all)`, y el botón de plegar se queda.** Cuando lista y detalle
    no caben a la vez (iPad mini en vertical: 744 pt), el split SUPERPONE la lista sobre el detalle; con la
    visibilidad fija la superposición no se retira nunca y tapa el detalle, y sin el botón no hay forma de volver a
    la lista después de retirarla.
- **Un `navigationDestination` de la columna de lista presenta en la de detalle** (medido con presupuestos): sus filas
  no se tocaron. En compacta, empuja como siempre.
- **El `horizontalSizeClass` se lee FUERA del split**, en la vista que lo monta: dentro, la columna de lista es
  compacta aunque la ventana sea ancha.
- **Lo abierto vive fuera del split** (`RecordsViewModel.openRecordID`) y se resuelve contra lo cargado, nunca con
  `modelContext.model(for:)`, que fabrica un objeto aunque ya no exista. Si la ventana se estrecha con un registro
  abierto, `preferredCompactColumn = .detail` lo enseña empujado; Atrás lo cierra.
- **El detalle de registro es hoja en compacta y columna en regular** (`TransactionDetailSheet(presentation:)`): el
  iPhone no cambia de hoja a empuje. En columna, Editar abre el editor directo; el encadenado «cerrar hoja → editor»
  solo existe en la hoja.
- Ancho legible: `DS.Adaptive.readableWidth` (700) en el contenido de una columna de detalle.
- **La lista se aparta sola cuando lo abierto no cabe legible a su lado** (fase 2, 2026-09-29): con algo abierto en el
  detalle y el split por debajo de dos anchos de iPhone (750), `ListDetailSplit` pasa a `.detailOnly`
  (`ListDetailOverlayLogic.listYieldsToDetail`, con test); con «Elige un…» la lista se queda. Lo dispara abrir Yala IA
  al lado o estrechar la ventana. La lista sigue a un toque en el botón del sistema.
- **Un detalle que en compacta se empuja y en ancha va en columna** sabe cuál es (`GroupDetailView(presentation:)`,
  como `TransactionDetailSheet`): en columna no oculta la barra de pestañas ni pinta su chevron, y cerrar es vaciar la
  selección de quien lo monta (`onCloseColumn`), no `dismiss()`. Sin `if` de vistas entre los dos modos
  (`swipeBack(isEnabled:)`, `.toolbar(_:for:)` con valor): al redimensionar cambian de uno a otro y no deben cambiar
  de identidad.
- **Ajustes, dentro de su hoja: en compacta la `NavigationStack(path:)` de siempre; en ancha, `ListDetailSplit` con
  una `NavigationStack` propia en la columna de detalle** (`ProfileView.settingsContainer`, `settingsLink`). No es un
  split plegado en compacta, y está medido (2026-09-29): con los ajustes presentados por un `navigationDestination`
  de la columna de lista, lo que un ajuste empuja por su cuenta no se empuja — el «+» de Categorías
  (`navigationDestination(isPresented:)`) no hacía nada, en iPhone ni en iPad; lo cazó
  `CategoriesCrudUITests.test_createCategoryWithSubcategory`. En ancha el ajuste se empuja sobre «Elige un ajuste», así
  que su «Atrás» (el suyo o el del sistema) vuelve ahí. **Cualquier pantalla con lista y detalle cuyos detalles
  empujen algo por su cuenta necesita esa pila de verdad en el detalle.** La hoja lleva `.presentationSizing(.page)`:
  en el iPad Pro 13 unas veces ocupa la pantalla con lista y ajuste lado a lado y otras mide 810 pt y la lista flota
  sobre el ajuste; un `PresentationSizing` propio que pide `.infinity` no pasa de 810 (ticket
  `ipad-settings-sheet-size-depends-on-where-it-opens`).
- **Estrechar y ensanchar la ventana se prueba en XCUITest** (`XCUIApplication+Window`): con los marcos de SpringBoard
  (`card:<bundle>`, `window-controls:<bundle>`), que van en coordenadas de pantalla; `app.frame` es local a la ventana.
  Necesita «Apps en ventanas» en el iPad; sin eso el caso se salta diciéndolo.
- **Yala IA junto a los datos NO es un `.inspector`** (`yalaAIChat(isPresented:)`, `YalaAIChatLayoutLogic`): en ancha
  es una columna propia a la derecha dentro de un `HStack` que siempre envuelve al contenido; en compacta, la hoja de
  siempre. Medido el 2026-09-29 en Registros (iPad Pro 13 vertical): un `.inspector` colgado de un
  `NavigationSplitView` pasa a la columna de inspector de UIKit, que se SUPERPONE al registro abierto sin recolocarlo
  (ni apartando la lista ni envolviendo el split en otro contenedor), y colgado de la columna de detalle su barra se
  mete en la del registro aunque esté cerrado. En columna, `ChatSheetView(presentation: .column)` pinta su cabecera y
  no lleva `NavigationStack` (en Estadísticas vive dentro de otra pila).

## Layout adaptativo: rejillas en pares (2026-09-30)

- **Una lista de tarjetas que en ancha va en pares es un `PairedCardsStack`** (`Views/Shared/PairedColumnsLayout.swift`):
  en compacta monta el `VStackLayout(spacing:)` de siempre —el iPhone queda igual por construcción— y en ancha
  `PairedColumnsLayout`. Los mismos hijos en los dos, con `AnyLayout`: redimensionar no cambia su identidad. Lo usan
  Estadísticas › Resumen y Tendencias y las filas de Últimos registros. **No lo sustituyas por un `LazyVGrid` ni por
  filas troceadas a mano**: al pasar de una columna a dos cambian los padres y los hijos pierden su estado.
- **Pares, nunca tres columnas** (pliegue del Duo). Un impar se queda en la columna izquierda, no se estira. Lo que
  debe ocupar la fila entera (cabeceras de sección, el selector Detalle/Observaciones, un bloque que reparte su propio
  contenido) lleva `.spansAllColumns()` **en el hijo directo** del contenedor: el valor viaja por el subview del
  layout, y en un hijo de un hijo no llega.
- **Dos columnas solo si caben dos de 320** (`DS.Adaptive.pairedColumnMinWidth`); si no, una. Lo decide el layout con
  el ancho que le proponen, sin `GeometryReader`: con Yala IA abierto al lado la ventana sigue en regular pero
  estrecha.
- **La cabecera del Panel es un `HeaderBandLayout`**: los hijos marcados `.headerBandColumn(.leading/.trailing)`
  —saldo y acciones / «Tus finanzas»— forman una banda en el sitio del primero; los demás van a todo lo ancho, arriba o
  debajo según su orden. Por eso «Tus finanzas» vive en `PanelView`, entre los avisos y la barra de filtros, y no en
  `PanelFilterAndWidgetsSection`: el contenedor la sube a la banda sin mover a nadie de sitio en el árbol.
- **Lo que va dentro de media columna decide por su ancho, no por el size class.** El carrusel de cuentas enseñaba 4
  tarjetas en regular: en la columna derecha de la cabecera eran 4 de ~110 pt. Ahora pide ancho para 4 de 140.
- **Un widget solo en su fila ocupa la fila entera solo si sabe repartir su contenido** (`WidgetConfigManager
  .spansRowWhenAloneTypes`, hoy `latestRecords`); los demás siguen en media fila.
- **Estadísticas › Registros abre el registro en un panel, no en un split** (`DetailContainerView.recordsContent`):
  el chip vive dentro de la pila de Estadísticas. Lista y panel lado a lado con dos anchos de iPhone; si no caben, el
  panel tapa la lista (`ZStackLayout`, la lista sigue montada) y su X la devuelve; al pasar a compacta con uno
  abierto, la hoja de siempre. El panel es `TransactionDetailSheet(presentation: .pane)`: cabecera propia con X y
  Editar, porque un `.toolbar` o el título inline ahí dentro cambiarían la barra de Estadísticas.
