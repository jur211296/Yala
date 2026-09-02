---
description: Reglas inviolables de SwiftUI, presentaciones, Design System y fondos de vista. Se cargan al trabajar con vistas.
paths:
  - "Yala/App/Views/**"
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


## Gotchas de vistas

- **`containerRelativeFrame(.horizontal)` en `ScrollView(.vertical)` con `.contentMargins`** → deadlock de layout, splash nunca dismissa, sin crash log. Usar `onGeometryChange`. Detalles en UI-PATTERNS.md.

- **`YalaFormatter` no auto-refresca prefs** — lee `UserDefaults` directo. Vista que lo use con `decimalPlaces` o `currencyDisplayFormat` debe inyectar `@Environment(AppPreferences.self)` y leer `let _ = appPreferences.X` en body para registrar dependencia.

- **Forms con `TextField`/`TextEditor`/`SecureField`** (sin `Form`): obligatorio `dismissKeyboardOnTap()` desde el primer commit. Detalles en SWIFT-STYLE.md.

- **Swift Charts `.annotation { }` NO propaga environment objects `@Observable`** → el contenido de una annotation de un mark (`BarMark`/`LineMark`/etc.) se hostea fuera del árbol de la vista; una sub-View que lea `@Environment(AppPreferences.self)` (ej. `AmountText`) NO lo resuelve y dispara `SIGTRAP` (`_assertionFailure` en `EnvironmentValues.subscript.getter`) al renderizar — sin crash log claro. Dentro de annotations usar `Text(...)` con el valor YA resuelto del callsite (`appPreferences.currency(...)` desde `self`) o un formatter estático (`YalaFormatter`), NUNCA una sub-View con `@Environment`. **`.chartOverlay { }` SÍ propaga** (ahí `AmountText` funciona, ej. `CashFlowWidget`). Causa del crash del chip Estadísticas en grupos (`8bb5ace8`).

- **Presentaciones (sheet/fullScreenCover) — 4 reglas del bug "toolbar muerta" (TestFlight 2.0.5):** (1) NUNCA un binding de presentación con setter no-op (`set: { _ in }`) ni sin `onDismiss:` de respaldo — si UIKit tumba la cadena presentada (p.ej. dismiss del sheet debajo de un cover), el estado queda pegado → cover fantasma irrecuperable; el reset del flag JAMÁS puede depender solo de un `Task { sleep; ... }` interno de la vista presentada. (2) **`opacity(0)` NO desactiva hit-testing**: un backdrop full-screen invisible con `.onTapGesture` se traga todos los taps de la app — siempre `allowsHitTesting(isVisible)`. (3) Toda presentación nueva que cuelgue del anchor de ContentView DEBE entrar a `ShellReadinessState`/`blocker()` (matriz de readiness), y los sheets de MainTabView/PanelShell están gateados por `RouterConsumerGateLogic` (peek-first: un intent que presenta se RETIENE en cola mientras un nodo superior tape — nunca se consume tapado). Corolario one-shots: flags tipo `markXShown` se queman en el `onAppear` del sheet real, nunca en el drain ni en el productor. **Corolario del MOMENTO (2026-07-28): «anchor libre» no basta — un cover montado mientras `AppBootstrapper.bootstrap` sigue corriendo se queda PEGADO** (el usuario lo descarta, UIKit no completa el desmontaje y la app ignora todos los taps; medido en iOS 27.0: ~1 de cada 3 arranques, 10 taps perdidos en ~40 s). Lo cubre el blocker `bootstrapPending` (`SessionState.isBootstrapSettled`, liberado por un `defer` de `bootstrap()`), hermano de `splash` y NO redundante con él: el splash se va por su propio reloj y no espera al bootstrap. **Gatear la MATRIZ, nunca un intent suelto**: retener la cola entera preserva el orden por prioridad (aviso de bandeja → paywall); adelantar uno solo invierte la pareja y monta el segundo encima del primero. Y al abrir un gate que estaba reteniendo, un solo drain por tick — `markReady` bumpea revision y el `.onChange(revision)` ya drena; un drain explícito además presentaría dos covers a la vez. (4) **NUNCA dos anchors presentando ante el mismo observable** (bug device sign-out 2026-07-14): UIKit no presenta dos veces y la reconciliación puede tumbar AMBAS cadenas dejando los flags en `true` sin que NINGÚN `onDismiss` corra (jamás se presentaron) → red muerta e irrecuperable; "SwiftUI materializa la presentación pendiente al despejarse el anchor" es FALSO. Un solo DUEÑO de la presentación (los demás anchors ceden — p.ej. cierran su sheet) + verificación de presentación EFECTIVA: solo el `onAppear` del contenido real prueba que UIKit presentó — si no llegó, re-intentar con toggle false→true tras un runloop turn (molde `SignOutRelaunchNetModifier` + `RelaunchNetLogic`); para blockers de la matriz, la CONDICIÓN VIVA del dominio es el input, el `@State` del cover es solo la red visual.

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
- Variantes (`YalaBackgroundVariant`) — 3 tras eliminar `.compact`:
  - `.panel` (default) — PanelBackgroundView gradient temático. SOLO vistas COMPLETAS: tab roots, vistas navegadas (push), fullScreenCover normal.
  - `.subtle` — `theme.background` plano. CUALQUIER sheet desde el bottom (sin detents o `[.large]`); TODO el stack del sheet de Profile (los ~20 Settings + sub-navegación); y success/celebración.
  - `.transparent` — sin fondo (DESNUDO, muestra el fondo de sistema del sheet — decisión owner, NO glassSheet). Sheets con detent PARCIAL (`.medium`/`.height`/`.fraction`). **Idiom-aware**: si el detent viene de `DS.Adaptive.sheetDetents(...)`, usar `DS.Adaptive.usesLargeSheets ? .subtle : .transparent` (iPad fuerza `.large` → debe ser subtle). Dual-detent `[.medium,.large]` con `selection: $selectedDetent` → `isLargeDetent ? .subtle : .transparent`.
- `.compact` ELIMINADA. `AnimatedMeshBackground` + `MeshConfigResolver` borrados (dead code). `DS.Adaptive.usesLargeSheets` (= isPad||isiOSAppOnMac) expuesto para el fondo idiom-aware.
- Param `ignoredEdges: Edge.Set?`: si `nil`, default `.all`. Para vistas con `safeAreaInset` pasar edges específicos (`[.top]`, `[.bottom]`).
- OUT: WelcomeFlow/onboarding (`DS.Gradients.heroIndigoBlack` especializado), InboxAlertModal (custom modal Color.black backdrop), popovers (iOS nativo).
- `GlassSheetModifier.glassSheet()` se mantiene como helper de sheets que SÍ quieren material (`.presentationBackground(.ultraThinMaterial)` + drag indicator). `.transparent` NO usa material (es desnudo).

#### Patrones aceptados temporalmente (deuda incremental, migrar al tocar el archivo)

- **Pattern B**: `ZStack { PanelBackgroundView(); content }` manual. Migrado masivamente al modifier (2026-06-08). Residuales aceptados: `PanelView` (tab root complejo con overlays) + las 6 vistas de onboarding/welcome (fondo hero propio, OUT). Sanity: `grep -rn "PanelBackgroundView(" Yala/` solo muestra esas + `PanelBackgroundView.swift` (def) + `ViewModifiers.swift` (modifier).
- **Pattern Subtle**: `ZStack { theme.background.ignoresSafeArea(); ...overlays; content }` en success screens (TransactionSuccessView, SubscriptionSuccessView, InboxApproveSuccessView, InboxBulkApproveSuccessView). Reescribir el ZStack rompería overlays propios (ConfettiView, RadialGradient glow). Semánticamente ES `.subtle`.

## Audit markers
- `// A11Y-DT:` justifica font size hardcodeado (Dynamic Type).
- `// A11Y-DM:` justifica color hardcodeado (Dark Mode).
