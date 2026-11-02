---
description: Reglas inviolables de SwiftUI, presentaciones, Design System y fondos de vista. Se cargan al trabajar con vistas.
paths:
  - "Yala/App/Views/**"
  - "Yala/App/ContentView.swift"
  - "Yala/App/YalaApp.swift"
  - "Yala/App/Scenes/**"
  - "Yala/App/Models/AppRouter.swift"
  - "Yala/App/Models/SceneNavigation.swift"
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
- **Un singleton que NO es `@Observable` (`CloudAuthService.shared`) leído desde el body no repinta nada al cambiar, y un
  `@State` que se cambia pero el body no lee, tampoco.** `StorageSettingsView` cambia `refreshTick` cada segundo y ningún
  body lo lee: lo que repinta es que `controller.refresh()` cambie propiedades del controller `@Observable`. Medido por
  la review del 2026-10-06 (`migrate-card-keeps-promising-an-account-the-check-refused`): un botón apagado por algo leído
  de `CloudAuthService` se quedaba apagado tras cerrar la sesión hasta salir y volver a entrar. ⇒ **si un control depende
  de estado no observable, copia ese estado a una propiedad `Equatable` del `@Observable` y renuévala donde ya corre el
  refresco** (`CloudMigrationController.liveSession`, en `refresh()`): solo repinta cuando cambia de verdad. **Para la
  sesión hay aviso desde el 2026-10-23** (card nve0): `CloudAuthService.sessionDidChangeNotification`, al entrar un inicio
  de sesión y dos veces en `signOut()` (antes y después de soltarla). La pestaña de Grupos se quedaba en «Crea tu cuenta»
  más de 10 s tras conectar la cuenta; la escucha con un contador que el body lee (`sessionRevision`). **Solo para
  repintar**: con las seis páginas montadas oye también los inicios de sesión que una puerta rechaza después (bloqueo [I]),
  así que lo que se escribe al aceptar una sesión va en cada puerta. No cubre la sesión que el SDK borra solo (ticket
  `cloud-session-removed-by-the-sdk-does-not-announce-itself`). **Desde la card n533 (2026-10-28) el resto de lectores no
  escucha el aviso: llama a `CloudSessionRevision.shared.track()` justo antes de leer `hasSession`** —el contador
  `@Observable` que sube el único emisor del aviso—, y así se repinta el `body` que lo evalúe aunque no tenga estado
  propio (una pantalla empujada, una función compartida por dos pantallas). Medido en Ajustes: sin él, «Tu cuenta de
  Yala» no salía con la sesión ya conectada hasta cerrar y volver a abrir. **Una lectura nueva de la sesión que pinte,
  con su `track()` y su fila en `CloudSessionRevisionWiringTests`**; la que solo decide al tocar o al aparecer no lo
  necesita (`WelcomeGroupsGateView.exitCell`).

- **Mover un cálculo del body a una propiedad del VM CORTA el live-binding a los `@Model` que ese cálculo leía.** Un body que recorre objetos SwiftData queda observando sus propiedades una a una, así que una mutación **en sitio** (mismo objeto, otro importe) repinta sola sin que nadie recargue. Al precalcular en el ViewModel eso se acaba: la vista pasa a observar únicamente la propiedad del cache, y el refresco depende **entero** de que todo mutador llegue al recálculo. Medido el 2026-09-06 al mover las deudas de la tarjeta de grupo a `GroupsViewModel.debtsByGroup` (`recalculate()`): la lista de Grupos ya no repinta por una mutación in-place suelta, y `GroupsSyncClient.pullUntilExhausted` tiene salidas tempranas (`.transient`, sesión caducada, cap de iteraciones) que dejan páginas **aplicadas y guardadas sin bumpear `dataVersion`** — ahí la cifra se sostiene vieja hasta el próximo `onAppear`, pull-to-refresh o bump. ⇒ **Al precalcular en un VM, comprueba primero que TODO camino de mutación desemboca en el recálculo**, y prefiere la mutación que bumpea a confiar en la observación accidental. Contrapartida medida: en esa lista el cálculo en el body costaba **~25 ms por tecla del buscador** con 30 grupos, más que un frame entero.

- **Corolario en Estadísticas (medido el 2026-10-09): la señal de «datos nuevos» es `DetailContainerViewModel.dataGeneration`, no `allTransactions.count` ni `dataVersion`.** `.count` no ve una edición en sitio (mismas filas) y `dataVersion` salta 150 ms antes de la recarga del contenedor, así que quien lo observe lee los arrays viejos. Y la señal no puede avanzar en cada recarga: el contenedor recarga **dos veces por alta** (al guardar, por `dataVersion`, y al cerrar la pantalla de éxito, por el `onDisappear` del sheet), y un contador por recarga duplicaba el recálculo de Distribución. Por eso solo avanza si la recarga trae algo (otro `dataVersion` o arrays distintos). Una pestaña que precalcule cuelga de ella (`CategoriesTabView` y, desde el 2026-10-25, `TrendsTabView`).


- **«Solo grupos» tiene dos orígenes desde el 2026-10-26 (card p0iu), y la shell los lee juntos.** Sin sesión privada
  (`!hasPrivateSession`, el eje) o con sesión privada y «Solo grupos» elegido en «Cómo usas Yala» (`GroupsOnlyViewMark`,
  espejo `SessionState.prefersGroupsOnlyView`). ⇒ **un gate de SHELL o de visibilidad lee
  `sessionState.isGroupsFocusedShell`**, nunca `!hasPrivateSession`: con la lectura vieja, quien eligió solo grupos vería
  filas, pestañas o temas de la app completa. **Un gate de DATOS sigue leyendo el eje** (bridge, borrados, cierre de
  sesión, la cuenta de los formularios de grupo): la vista no apaga la sesión, y por eso los gastos de grupo siguen
  llegando a los registros. La puerta destacada de Ajustes y Más distingue los dos orígenes con
  `UsageModeLogic.returnEntry`, y el intent `.presentFullModeActivation` es la VUELTA cuando hay sesión privada
  (`SessionState.isGroupsOnlyByChoice`). Un productor nuevo de avisos personales mira `PersonalRemindersPause` primero.
  **Y un intent nuevo de Apple Pay o Siri que deje un borrador o conteste con finanzas mira `GroupsOnlyIntentGate`
  primero** (encargo S11e, 2026-10-27): en esa shell la Bandeja no se ve, así que dice «Activa / Vuelve a Yala
  completo» y su enlace es `activate-full`. Al volver, los pagos programados que vencieron en la pausa no salen
  (`ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause`, antes de levantar la marca y tras `processDuePayments`).

## Gotchas de vistas

- **`.sheet(isPresented:)` con el contenido sacado de OTRO `@State` sale VACÍA si el `body` no lee ese estado fuera del
  cierre (medido el 2026-10-17, iOS 27.0, lote 8).** Buscar ponía `detailTransaction = record` y `showsDetail = true` en
  el mismo toque, y la hoja se presentaba con `if let transaction = detailTransaction` en nil: el cierre se quedó con el
  valor de antes. Con un `@Observable` (Registros, `RecordsViewModel`) el mismo molde funciona. ⇒ **para presentar UN
  objeto, `.sheet(item:)`**; si hace falta encadenar otra presentación al cerrar, guarda el objeto en un estado aparte
  (`recordAwaitingEditor`) antes de vaciar el `item`. Pin: `UXAudit22Lote8CWiringTests`.
- **Un `.task` (o un `onAppear`) colgado de un `Group` cuyo contenido es un `if` falso no corre nunca (medido el
  2026-10-21, iOS 27.0, lote decidido 14).** Los modificadores de un `Group` se reparten entre sus hijos; sin hijos no
  hay vista que aparezca. La tarjeta de avisos de grupo medía su estado en ese `.task` y no salía jamás. ⇒ **lo que mide
  antes de decidir si se pinta cuelga de un marcador propio que solo existe hasta tener respuesta**
  (`Color.clear.frame(width: 1, height: 1).task { … }`, molde de `GroupNotificationsOptInCard`).
- **El `onAppear` de un `ViewModifier` puede correr ANTES que el de la vista que lo lleva (medido el 2026-10-17, iOS 27.0,
  lote 9).** `BudgetAlertOpening` (abrir el presupuesto de una alerta) buscaba en `viewModel.allBudgets` desde su
  `onAppear`, y el `onAppear` de `BudgetsListView` —el que hace `setContext`— aún no había corrido: lista vacía, el
  aviso consumido y nada abierto. Lo cazó un XCUITest en rojo. ⇒ **lo que un modificador lea al aparecer lo prepara él**
  (aquí, `viewModel.setContext(modelContext)` idempotente antes de leer), no cuenta con el orden de los `onAppear`.
- **Una hoja pedida por una vista recién montada tras una reconstrucción (`.id(...)` de `ContentView`) puede llegar con las
  hojas del árbol VIEJO aún cerrándose, y UIKit la rechaza (medido el 2026-10-24, iOS 27.0, card 6d71).** Al cambiar el
  idioma, el Panel nuevo pedía Ajustes en su `onAppear` (+ una vuelta del main actor) con Ajustes y el selector de antes
  todavía presentados: `Attempt to present … which is already presenting`, la ventana quedaba vacía medio segundo después
  y el flag `isPresentingSettings` en `true` sin hoja — el botón de Ajustes, muerto hasta cerrar la app. Iba por la
  carrera: a mano, con toques lentos, salía bien; el XCUITest caía 2 de 3. ⇒ **espera a que la ventana no tenga nada
  presentado (`ModalPresentationProbe`) y verifica que la hoja llegó; si no, baja el flag** (`SettingsReturnOpening`).
  Una vuelta del main actor no basta: el cierre de UIKit dura ~0,3-0,5 s.
- **Un empuje con `navigationDestination(item:)` pedido en el PRIMER `onAppear` de una vista que se está montando por un
  cambio de chip se pierde sin aviso (medido el 2026-10-17, iOS 27.0, lote 10).** El recordatorio de un pago cambia
  Planificación al chip de Pagos y, en el mismo instante, `ScheduledPaymentAlertOpening` ponía el `item`: encontraba el
  pago y no empujaba nada. Puesto una vuelta del main actor después (`Task { @MainActor in item = … }`), empuja. Con la
  vista ya montada (el caso de presupuestos, L9-5) no hace falta. Lo cazó
  `ScheduledPaymentsLote10UITests#test_reminderTap_opensThatPaymentsDetail` en rojo.
- **Pasar de un `fullScreenCover` a otro del mismo anchor deja ~0,6 s de negro, y la cura —un solo cover que cambia
  de contenido— se lleva por delante el `onDismiss` del que desaparece (medido el 2026-10-25, card 4gfj).** UIKit baja
  uno entero y sube el otro; entre medias se ve lo de debajo. Con un cover y `.transition(.opacity)` sobre el fondo
  común (pintado DEBAJO de las dos pantallas, o el centro del fundido deja ver el del cover) el salto se funde, pero
  volver de una pantalla a la otra ya no cierra nada: lo que limpiaba su `onDismiss` tiene que correr también al cambiar
  el contenido, y el respaldo del `onDismiss` solo si lo último pintado era esa pantalla. Mientras baja, el cover sigue
  pintando lo último, no lo que dicen los flags apagados. Molde: `WelcomeFlowModifier` + `WelcomeCoverContentLogic`.
  **Y las dos pantallas llevan `.zIndex(1)` (medido el 2026-10-28, iOS 27.0, card feer)**: sin él, la que SALE se pinta
  por debajo del degradado opaco del `ZStack` y desaparece en un fotograma; solo se veía fundirse la que entraba. Vale
  para cualquier `ZStack` con un fondo opaco y un `switch` con `.transition` encima.
- **Un `.overlay` colgado DESPUÉS de `.glassEffect` no se ve: el cristal lo tapa (medido el 2026-10-17, iOS 27.0).** El
  contorno rojo de la cápsula de un filtro oculto estaba en el código y no salía en pantalla. Antes del `.glassEffect`,
  como contenido, sí (`FilterChipView`).

- **Un `.confirmationDialog` colgado de un BOTÓN no pinta el `Button(role: .cancel)` en iOS 26 (medido el 2026-10-04,
  iPhone 17 Pro, iOS 27.0).** Sale anclado al botón y la salida de cancelar no aparece: `app.sheets.buttons[id]`
  no la encuentra y la persona solo puede tocar fuera. ⇒ si la opción de «no hacer nada» tiene que verse —porque es
  una decisión sobre datos—, dale un `Button` normal sin rol. Molde: `StorageSettingsView`, diálogo del borrado de
  iCloud pendiente (`PendingICloudWipeMigrationUITests`). **Colgarlo de la raíz de la pantalla tampoco lo arregla
  (medido el 2026-10-17, lote 20):** esta regla decía que los de `StorageConfirmations` no tenían el problema, y
  «¿Activar la nube?» salía con solo «Continuar»; los siete de esa pantalla pasaron a botón sin rol
  (`PendingICloudWipeMigrationUITests#test_activateCloudConfirmation_showsCancel_andCancelStops`).
  **Colgarlo de la raíz no siempre basta (medido el 2026-10-16, lote 18):** en el flujo de caja, el de borrar una
  línea (en el detalle del mes, dentro del scroll) y el de «Reiniciar plan» (en el contenido de Reportes) salían como
  globo anclado a media pantalla, sin «Cancelar». Se pasaron a `.alert`, que siempre pinta las dos salidas
  (`CashFlowPlanUITests#test_resetPlan_asksWithAVisibleCancel`). En XCUITest los botones de esa alerta salen
  duplicados en el árbol: `.firstMatch`.

- **Una `.alert` colgada de la RAÍZ de una `NavigationStack` no sale si hay una pantalla empujada encima, aunque una
  `.sheet` colgada del mismo sitio sí (medido el 2026-10-17, iPhone 17 Pro, iOS 27.0, lote 20).** En Ajustes, las
  presentaciones del cierre de sesión y del borrado de cuenta colgaban de `listColumn`; desde «Tu cuenta de Yala»
  (empujada) la hoja de alcance salía y la alerta que la sigue («Esto es definitivo») no, sin ningún aviso en el log:
  la cuenta no se podía eliminar. ⇒ **una presentación cuya entrada vive en una pantalla empujada cuelga del
  CONTENEDOR de la pila** (fuera del `NavigationStack`), no de su raíz. Molde: `ProfileView.signOutPresentations` /
  `deleteAccountPresentations`, aplicados en `body`. Test: `DeleteAccountDialogUITests#test_deleteAccount_continue_showsTheFinalConfirmation`
  (con la alerta devuelta a la raíz, cae en la espera del título).

- **Un `DragGesture` en el contenido de un `ScrollView` vertical le quita el arrastre al scroll, también con
  `.simultaneousGesture` (medido el 2026-10-16, iOS 27.0, lote 18).** La lista del mes del flujo de caja solo se movía
  arrastrando desde la tira de meses; sin el gesto, se movía. ⇒ **para deslizar a los lados dentro de un scroll,
  `HorizontalSwipeGesture`** (`Views/Shared/`, UIKit con `UIGestureRecognizerRepresentable`): solo arranca si la
  velocidad horizontal manda y reconoce a la vez **solo** con el pan del `UIScrollView` — con `true` a todo, el
  `Button` de la fila también disparaba y abría su hoja. `PeriodNavigationHeader` y `RecordsCalendarView` siguen con el
  patrón viejo (sin medir). Test: `CashFlowPlanUITests#test_monthDetail_scrollsWithAFingerOnTheList_andASideSwipeChangesMonth`.

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

- **Un `guard` que CALLA el arranque en una fase transitoria necesita quien lo retome cuando la fase pasa (card 7e60,
  2026-10-28).** `presentNextOnboardingScreen` se calla con el cierre de sesión en `.awaitingRelaunch` (para no consumir
  el destino del relanzamiento). Tras un cierre que cambia el almacén EN CALIENTE, el `ContentView` nuevo se monta y
  decide su pantalla en esa fase —`checkInitialSyncState` no espera a nada—, y la fase vuelve a `.idle` después: sin
  quien lo retomara, ni Welcome ni app ni pantalla de reabrir, y la persona lo vivió como un crash sin informe en
  Sentry. ⇒ un `guard` así apunta lo que calló y el `onChange` de la fase lo retoma
  (`onboardingRoutingDeferredForRelaunch` + `SignOutDeferredRoutingLogic`). El simulador no lo reproduce: monta con
  espejo y el cambio en caliente se salta.

- **Una decisión del arranque que lea el eje de sesión NO puede tomarse en el splash (medido el 2026-10-19).**
  `checkInitialSyncState` corre en paralelo a `AppBootstrapper.bootstrap`, y el eje (`PrivateSessionMark`) lo escribe
  el backfill del bootstrap: decidido en el splash, el aviso en frío de «iCloud no está disponible» no salía en ningún
  XCUITest con `-uitest-reset` (y en un iPhone, en el primer arranque tras actualizar). ⇒ espera con
  `waitForBootstrap()` y RE-MIDE lo que leyó el splash, al final del `.task` del arranque para no retrasar el splash
  (`requestColdStartICloudNoticeAfterBootstrap`). Y su estado va en un tipo del PROCESO, no en `@State`: con varias
  ventanas la líder se remonta (ver «Varias ventanas»).

- **Una fila que recibe un `@Model` no lo lee si ya está borrado (card f8rj, crash de TestFlight 2.2 (2), iOS 27.2).**
  La fila observa su modelo y puede volver a pintarse con él borrado: bajo una hoja que lo borró («Eliminar para
  siempre» del editor de la Bandeja), con la lista esperando a recargar por `dataVersion`, o porque una recarga devolvió
  una fila que esperaba su borrado diferido. En el iPhone 27.x leer cualquier propiedad aborta (`_assertionFailure`
  desde el getter); **en el simulador 27.0 no**, así que ningún XCUITest lo caza. ⇒ el `body` de la fila mira primero
  `isDeleted || modelContext == nil` y no pinta nada (`InboxDraftRowView`, `RecordRowView`); quien borra con la fila
  montada la poda antes (`DraftService.deleteInboxDraftPruningRow`); y una retirada optimista con borrado diferido
  esconde lo que espera en cada recarga (`InboxViewModel.beginRemoval`, `RecordPendingDeletion`). Pin:
  `DeletedModelRowGuardWiringTests`, `InboxPendingRemovalTests`. Un `.ips` de TestFlight sin dSYM no se simboliza
  recompilando el commit: sale otro UUID y las direcciones caen en código sin relación (medido).
  **Un formulario que borra SU modelo y llama a `dismiss()` tiene el mismo problema** (card 1w89, 2026-10-31): sigue
  presentado durante el cierre y su `body` se vuelve a evaluar al cerrarse la confirmación. El título de una alerta o
  de un `confirmationDialog` que nombra lo borrado se copia al abrirla; lo demás que el `body` lea pasa por un accesor
  que mire `isDeleted || modelContext == nil` (`NewTransactionView.readableTransactionToEdit`); y **su ViewModel cuenta**:
  `NewTransactionViewModel.amountCurrencyCode` leía el registro para pintar el importe, así que tras guardar el borrado
  lo suelta (`releaseDeletedRecord`). Mira también al PADRE que presenta la hoja: puede repintar con el modelo borrado
  antes de recargar. Pin: `DeletedModelFormGuardWiringTests`. **Los otros diez casos (card gxa9, 2026-10-31)** dejaron
  dos cosas medidas: (1) **`modelContext == nil` también es verdad en un modelo que nunca se insertó**, y los tests de
  ViewModel construyen así sus modelos: con la guarda dentro del `init` o de un cálculo del ViewModel cayeron 22 tests
  (`AccountFormViewModelTests`, `CategoryDetailViewModelTests`…). ⇒ la guarda «mira antes de leer» va en la VISTA, que
  siempre recibe modelos de un contexto (`AccountFormView.init`, `TagFormView.init`, `CategoryDetailView.init` con
  `readsCategory:`), y el ViewModel suelta con una marca o vaciando lo cargado (`releaseDeletedAccount`,
  `releaseDeletedCategory`, `releaseDeletedTag`); (2) **la lista que presenta el formulario filtra lo borrado en el
  array que pinta**, como `AccountsSettingsListViewModel.accounts` (presupuestos, categorías, etiquetas). Ajustes del
  grupo, cuyo `body` lee el grupo en decenas de filas, no pinta filas con él borrado (molde de
  `BudgetDetailView.isBudgetValid`). Pin: `DeletedModelMoreFormsGuardWiringTests` + `DeletedModelMoreFormsReleaseTests`.
  **El detalle del grupo tras salir de él (2026-11-01, ticket `group-detail-reads-the-group-after-leaving-it`)** dejó una
  tercera: (3) **una lógica pura que recibe propiedades del modelo YA LEÍDAS las lee antes de decidir**:
  `GroupDetailDismissDecision.shouldDismiss` recibía `isHiddenForAll` e `isArchived`, y el `onChange` que cerraba el detalle
  los leía del grupo borrado. ⇒ lo que solo vale con el modelo vivo va `@autoclosure` y detrás de `isDeleted`. El detalle
  guarda su `body` con `isGroupReadable` (título de `viewModel.groupName`) y el ViewModel suelta con `releaseDeletedGroup`.

- **En una página de pestaña, el buscador va en `.navigationBarDrawer(displayMode: .always)`, nunca `.automatic` (medido
  el 2026-10-30, iOS 27.0, PR #703).** Las páginas siguen montadas al cambiar de pestaña. Con `.automatic`, al volver a
  Grupos la barra reservaba el alto del cajón vacío ~0,4 s y luego lo plegaba, y el contenido saltaba ~45 pt de golpe
  (vídeo de Jürgen). Lo fija `GroupsSearchDrawerWiringTests`, que prohíbe el `.automatic` en `Yala/App/Views`. Desde el
  2026-10-30 Grupos no tiene buscador (la búsqueda es la pestaña Buscar), y el mismo test fija que no vuelva.

- **`containerRelativeFrame(.horizontal)` en `ScrollView(.vertical)` con `.contentMargins`** → deadlock de layout, splash nunca dismissa, sin crash log. Usar `onGeometryChange`. Detalles en UI-PATTERNS.md.

- **`YalaFormatter` no auto-refresca prefs** — lee `UserDefaults` directo. Vista que lo use con `decimalPlaces` o `currencyDisplayFormat` debe inyectar `@Environment(AppPreferences.self)` y leer `let _ = appPreferences.X` en body para registrar dependencia.

- **Anidar dos hijos de un `HStack` en otro `HStack` NO es neutro cuando la fila va justa (medido 2026-09-28).** `HStack { icono; texto; Spacer(); importe }` y `HStack { HStack { icono; texto }; Spacer(); importe }` pintan igual con holgura, pero con compresión reparten el ancho distinto: en un iPhone SE la tarjeta de grupo pasó a truncar el nombre («Viaje a Cu…») para no encoger el importe, que antes cedía con su `minimumScaleFactor`. Lo cazó un diff píxel a píxel antes/después a tamaño por defecto; a simple vista en el ProMax no se veía. ⇒ **para reorganizar una fila con el tamaño de texto, `AdaptiveRowStack(leading:trailing:)`**, que a tamaño normal pinta la fila plana de siempre y solo anida al apilar. `AnyLayout` obliga a una sola jerarquía para las dos formas, y por eso aquí no sirve.

- **Una pantalla que reparte su alto con `Spacer`s y no tiene scroll no cabe en un iPhone SE (medido 2026-09-28).** Nuevo registro y las pantallas de éxito tras guardar y tras aprobar un borrador se salían por arriba y por abajo **a tamaño normal**: con el teclado abierto en el formulario, y sin él en las de éxito. A AX5, «Guardar» quedaba fuera de alcance, también en el ProMax. ⇒ **envuélvela en `GeometryReader { proxy in ScrollView { VStack { … }.frame(minHeight: proxy.size.height) }.scrollBounceBehavior(.basedOnSize) }`**: cuando cabe, los `Spacer`s reparten igual y no hay scroll (medido píxel a píxel en el ProMax); cuando no, se desplaza. Si la pantalla tiene botones de salida, esos quedan fuera del scroll (molde de `GroupExpenseSuccessView`).
  **Con un `.safeAreaInset(edge: .bottom)` por fuera y el teclado puesto, el `minHeight` del molde tapa lo de abajo
  (medido el 2026-11-01, Nuevo gasto de Grupos, iOS 27.0):** el alto que mide el `GeometryReader` deja de descontar la
  barra del inset, el contenido «cabe» y lo último queda debajo de «Guardar». ⇒ mientras haya un campo con foco, sin
  alto mínimo (`.frame(minHeight: focusedField == nil ? proxy.size.height : nil)`), o el molde de Nuevo registro
  (`SaveAreaPlacement`, que mete «Guardar» en el contenido con el teclado).
- **Cambiar el `foregroundStyle` de un `TextField` mientras tiene el foco no se ve hasta que lo pierde (medido el
  2026-11-01, iOS 27.0).** Un monto que pasaba de gris a rosa al escribir el primer dígito se quedó gris con «240»
  escrito. ⇒ el gris de «sin monto» va en el `prompt` (`Text(verbatim: "0.00").foregroundStyle(.tertiary)`) y el texto
  lleva su color fijo, como Nuevo registro.

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

- **Cambiar por código la `selection` de `.presentationDetents(_:selection:)` NO movió la hoja (medido 2026-10-04,
  simulador iOS 27.0, `VoiceRecordingView`).** El binding sí cambió —el fondo que se deriva de él pasó a `.subtle`— pero
  la hoja siguió a media altura, en la misma pasada que el cambio de fase y también aplazado una vuelta del main actor
  con `withAnimation`. Causa sin aislar. ⇒ **no diseñes un flujo que dependa de agrandar la hoja por código**: que el
  contenido quepa o se desplace dentro, y el usuario la estira. Si un fondo se deriva del detent elegido, fíjalo a la
  altura real, no a la pedida.

- **`.presentationBackground(<material>)` como ESTILO impide presentar la hoja cuando la pide otra hoja que ya está
  sobre una hoja (medido el 2026-10-27, iOS 27.0).** En «Detalles» de un registro de Yala IA (hoja sobre la hoja del
  chat), Categoría, Cuenta y Etiquetas —los tres selectores con `SelectorSheetSizing.mediumFirst`— no abrían: SwiftUI
  construía el selector y UIKit no lo mostraba. Fecha, sin ese modificador, sí. Sin error ni aviso en el log. Desde
  Nuevo registro (un nivel menos) abrían bien, y por eso #602 lo metió sin que nadie lo viera. Como VISTA
  (`.presentationBackground { Rectangle().fill(.thickMaterial) }`) sí presentaba. **Desde el 2026-10-31 los selectores
  no pintan fondo de presentación** (regla «Ninguna hoja con fondo gris», en «Backgrounds de vista»), y presentan en los
  tres niveles igual que Fecha. Lo fijan los cuatro casos `test_draftDetails_*` de `ChatMessagingLayoutUITests`.

- **Forms con `TextField`/`TextEditor`/`SecureField`** (sin `Form`): obligatorio `dismissKeyboardOnTap()` desde el primer commit. Detalles en SWIFT-STYLE.md.

- **Swift Charts `.annotation { }` NO propaga environment objects `@Observable`** → el contenido de una annotation de un mark (`BarMark`/`LineMark`/etc.) se hostea fuera del árbol de la vista; una sub-View que lea `@Environment(AppPreferences.self)` (ej. `AmountText`) NO lo resuelve y dispara `SIGTRAP` (`_assertionFailure` en `EnvironmentValues.subscript.getter`) al renderizar — sin crash log claro. Dentro de annotations usar `Text(...)` con el valor YA resuelto del callsite (`appPreferences.currency(...)` desde `self`) o un formatter estático (`YalaFormatter`), NUNCA una sub-View con `@Environment`. **`.chartOverlay { }` SÍ propaga** (ahí `AmountText` funciona, ej. `CashFlowWidget`). Causa del crash del chip Estadísticas en grupos (`8bb5ace8`).

- **Presentaciones (sheet/fullScreenCover) — 4 reglas del bug "toolbar muerta" (TestFlight 2.0.5):** (1) NUNCA un binding de presentación con setter no-op (`set: { _ in }`) ni sin `onDismiss:` de respaldo — si UIKit tumba la cadena presentada (p.ej. dismiss del sheet debajo de un cover), el estado queda pegado → cover fantasma irrecuperable; el reset del flag JAMÁS puede depender solo de un `Task { sleep; ... }` interno de la vista presentada. (2) **`opacity(0)` NO desactiva hit-testing**: un backdrop full-screen invisible con `.onTapGesture` se traga todos los taps de la app — siempre `allowsHitTesting(isVisible)`. (3) Toda presentación nueva que cuelgue del anchor de ContentView DEBE entrar a `ShellReadinessState`/`blocker()` (matriz de readiness), y los sheets de MainTabView/PanelShell están gateados por `RouterConsumerGateLogic` (peek-first: un intent que presenta se RETIENE en cola mientras un nodo superior tape — nunca se consume tapado). Corolario one-shots: flags tipo `markXShown` se queman en el `onAppear` del sheet real, nunca en el drain ni en el productor. **Corolario del MOMENTO (2026-07-28): «anchor libre» no basta — un cover montado mientras `AppBootstrapper.bootstrap` sigue corriendo se queda PEGADO** (el usuario lo descarta, UIKit no completa el desmontaje y la app ignora todos los taps; medido en iOS 27.0: ~1 de cada 3 arranques, 10 taps perdidos en ~40 s). Lo cubre el blocker `bootstrapPending` (`SessionState.isBootstrapSettled`, liberado por un `defer` de `bootstrap()`), hermano de `splash` y NO redundante con él: el splash se va por su propio reloj y no espera al bootstrap. **Gatear la MATRIZ, nunca un intent suelto**: retener la cola entera preserva el orden por prioridad (aviso de bandeja → paywall); adelantar uno solo invierte la pareja y monta el segundo encima del primero. Y al abrir un gate que estaba reteniendo, un solo drain por tick — `markReady` bumpea revision y el `.onChange(revision)` ya drena; un drain explícito además presentaría dos covers a la vez. (4) **NUNCA dos anchors presentando ante el mismo observable** (bug device sign-out 2026-07-14): UIKit no presenta dos veces y la reconciliación puede tumbar AMBAS cadenas dejando los flags en `true` sin que NINGÚN `onDismiss` corra (jamás se presentaron) → red muerta e irrecuperable; "SwiftUI materializa la presentación pendiente al despejarse el anchor" es FALSO. Un solo DUEÑO de la presentación (los demás anchors ceden — p.ej. cierran su sheet) + verificación de presentación EFECTIVA: solo el `onAppear` del contenido real prueba que UIKit presentó — si no llegó, re-intentar con toggle false→true tras un runloop turn (molde `SignOutRelaunchNetModifier` + `RelaunchNetLogic`); para blockers de la matriz, la CONDICIÓN VIVA del dominio es el input, el `@State` del cover es solo la red visual.

- **Un flag de presentación que además es BLOCKER de la matriz de readiness convierte «la presentación no montó» en un brick de toda la sesión (2026-09-10).** Los dos hechos son buenos por separado —un aviso destructivo tiene que bloquear al router, y el router tiene que retenerse— pero juntos crean un modo de fallo nuevo: si UIKit descarta esa presentación (el caso clásico: **dos `.alert` encadenados desde el mismo anchor**, donde el segundo se enciende mientras el primero se desmonta), el flag se queda en `true`, `blocker()` lo devuelve para siempre, y **el router no vuelve a drenar nada** — ni avisos de bandeja, ni paywall, ni invitaciones de grupo. Sin `onDismiss` no hay rescate, y `.alert` no tiene `onDismiss`. Solo se sale matando la app. ⇒ **una cadena de dos gestos (confirmar → «¿seguro?») no se hace con dos presentaciones del mismo anchor**: o dos CONTENEDORES distintos con el `onDismiss` del primero encadenando al segundo (molde de `UserDataResetView`: sheet → alert), o —mejor— **una sola presentación con FASES dentro**, que es lo que hacen `WelcomePrivateICloudGateView` y `LateICloudMirrorNoticeView`. Las fases dan además sitio para el progreso y el error, que un alert no tiene: sin ellas, entre «sí, borra» y el final pasaban decenas de segundos con la app mostrando nada, y si fallaba, tampoco.

- **Y cuando el aviso que brickea es un `.alert`, la salida medida (2026-09-14) es: condición viva como blocker + sonda a UIKit + desarme.** Un `.alert` no tiene `onDismiss` **ni contenido propio cuyo `onAppear` pruebe que apareció**, así que el molde de verificación efectiva de los covers (`SignOutRelaunchNetModifier`) no se le puede aplicar tal cual: la única señal disponible es la de UIKit —¿hay algo en la cadena `presentedViewController`?— y eso es lo que encapsula `ModalPresentationProbe`. Las tres piezas, y ninguna sobra: (1) el blocker de la matriz es la CONDICIÓN VIVA (`remoteWipeNoticePending`), nunca el `@State` del alert, porque la red toggla ese flag para re-presentar y una matriz colgada de él se abriría **en cada reintento** —50 ms bastan para que el router drene y monte otra cosa debajo—; (2) la red **no termina al confirmar la presentación**: sigue vigilando hasta que el aviso se conteste, porque el brick tiene dos formas y la de «montó y se cayó después» no la cubre un verificador de montaje; (3) **al agotar el cap, se SUELTA la condición viva** — aquí, a diferencia del cover terminal, quedarse retenido cuesta la sesión entera, así que se pierde el aviso y no la app, con canario (`remoteWipeNoticeNotPresented`) para enterarse. **El brick y su cura están medidos con mutantes en simulador**: con la presentación forzada a no montar y un paywall en cola, sin la red el log se queda en `blocked by: remoteWipeAlert` y el paywall no presenta **nunca** (25 s); con ella se suelta a los ~10 s y el paywall entra. **Y el aviso que deja la sonda:** forzada a `false` con el alert REALMENTE en pantalla, los toggles lo dejan **dibujado** aunque el estado se apague entero — UIKit no completa el desmontaje. No brickea (la matriz queda libre), pero por eso la sonda necesita una red viva en el simulador: `RemoteWipeNoticeRoutingUITests` se pone rojo el día que un runtime deje de reconocer la presentación de un `.alert`.

- **Y la otra mitad de la matriz: meter un flag en `ShellReadinessState` protege a los DEMÁS de presentar debajo, no protege a ESA presentación de montarse en mal momento.** Un `@State` encendido desde un `Task` async —una sonda de red que contesta cuando quiere— llega cuando el anchor puede estar presentando el cover de idioma o el sheet del trial, y encender un alert ahí **desmonta el cover** (traza medida en `ShellDataAlertsModifier`). La mitad que falta es entrar por `RouterEntryGate.shared.submit(...)`, que es quien retiene la cola hasta que el anchor esté libre. Regla práctica: **si el productor de una presentación es asíncrono, va por el router**; el `@State` directo solo vale cuando quien lo enciende es un tap.

- **Liberar la matriz dentro de un `onChange` puede perder el drenaje: el `markReady` va una vuelta del main actor después (medido el 2026-10-08).** `markReady` sube la `revision` del router, y hecho dentro de la acción de un `onChange` —la actualización de la vista— el `.onChange(of: AppRouter.shared.revision)` del MISMO cuerpo a veces no ve el bump: instrumentado, la matriz queda libre, el router bumpea y no llega ni el `onChange` ni el drenaje. Lo retenido (oferta, aviso de bandeja, invitación) se quedaba hasta relanzar la app: 1 de 7-16 arranques al soltar la hoja del cambio de Apple ID o el aviso de vaciado. ⇒ **`ContentView.updateContentViewReadiness` bloquea en el acto y libera con `Task { @MainActor in applyContentViewReadiness() }`**, que re-mide la matriz antes de liberar. **Aplazar solo la liberación, nunca el bloqueo**: un `markUnready` tarde deja una vuelta en la que el `onChange(revision)` drena con el shell ya tapado. Un consumidor nuevo que libere desde un `onChange` y dependa del `onChange(of: revision)` para drenar hereda el bug; los que drenan explícitamente tras `markReady` (`PanelShell`, `routerConsumer`) no. Pin: `ContentViewReadinessReleaseWiringTests`.

- **Y al revés: lo que el manejador de un drenaje ENCIENDE tiene que bloquear en esa misma vuelta, no en la del observador (medido el 2026-10-13, CI en iOS 26.5).** `drainNext` sube la `revision`; si el bloqueo que el manejador acaba de encender solo llega a la matriz por un `onChange` de `ReadinessGateObservers`, en 26.5 el `onChange(of: revision)` corre ANTES y drena el siguiente con el consumidor aún listo: la oferta salía encima del aviso de vaciado o del de bandeja en 8 de ~60 arranques, y una de las dos presentaciones se perdía. ⇒ **`drainContentViewIntents` termina con `defer { updateContentViewReadiness() }`**; un consumidor nuevo cuyo manejador encienda un bloqueo publicado por otro hace lo mismo. En iOS 27.0 el orden era el otro y no se reproducía ni con la máquina cargada: un rojo de cola que solo sale en el CI se mide ALLÍ, con `NSLog` y la consola de la app que trae el `.xcresult` (`xcresulttool export diagnostics`). Ticket: `drained-notice-lets-the-next-intent-drain-before-the-matrix-blocks`.

- **El orden ENTRE consumidores lo da la cola, no quién drena antes (2026-10-30, ticket
  `notices-come-out-one-after-another-by-priority`).** La matriz y el candado evitan que dos avisos salgan a la vez, pero no
  eligen cuál sale primero: con uno de `.contentView` y otro de `.mainTab` en cola, ganaba el consumidor cuyo `onChange`
  corriera antes, y Novedades (`low`) podía salir antes que «Tu prueba terminó» (`high`). ⇒ **los dos drenajes del shell
  preguntan `AppRouter.shellNoticeAhead(of:in:)`** antes de presentar, y la regla de quién cede es `NoticeOrderLogic`
  (una hoja de MainTab cede ante lo de `.contentView` que vaya delante; un diferible de `.contentView`, ante una hoja de
  MainTab; los críticos no ceden). Solo se cede ante un consumidor LISTO en esa ventana: ceder ante uno sin montar
  colgaría el aviso. **Un consumidor nuevo que presente avisos propios entra en esa regla** (y en sus tests,
  `NoticeOrderTests`), o vuelve a decidir el orden quien mire antes. Y **el `id` de un aviso que el productor recalcula
  sobre lo que aún no se vio es FIJO**: la clave por cifras del de la Bandeja dejaba «2 nuevos» y «3 nuevos» en cola, y
  salían los dos seguidos.

- **El botón destacado de un `.alert` (`.keyboardShortcut(.defaultAction)`) toma el RELLENO del `AccentColor` del catálogo y el TEXTO del tinte de SwiftUI de quien presenta la alerta; si los dos coinciden, el texto sale NEGRO (medido en píxeles el 2026-10-17, iOS 27.0, claro y oscuro).** No elige por contraste: sobre `#3D36B3` también salía negro. Ignora `.tint` y `foregroundStyle` en el propio botón (y `role: .confirm` no cambia nada), y el mismo tinte colorea el texto de los demás botones de la alerta. ⇒ para cambiar ese texto, presenta la alerta desde un ancla con su propio tinte (`content.background { Color.clear.alert(…).tint(…) }`, sin teñir la pantalla de debajo) y recuerda que ese tinte pinta también «Cancelar». Molde: `AIConsentAlertModifier` + `Color.alertActionTint` (blanco en oscuro; en claro, el relleno, así que sale negro: blanco dejaría los otros botones ilegibles sobre el cristal claro). El catálogo y el token están atados por `AlertActionIndigoParityTests`. Ticket: pulido del 2026-10-17 («Activar» con texto oscuro).

- **El molde del ancla propia (`content.background { Color.clear.alert(…).tint(…) }`) NO vale para los avisos de
  `ShellDataAlertsModifier` (medido el 2026-10-22, iOS 27.0, lote decidido 2.2 · 15).** Para que «Seguir esperando» de
  «Datos no disponibles» saliera relleno y legible se colgó el aviso de un ancla propia con `alertActionTint`, en
  `.background`, en `.overlay` y como hermano 1×1 en un `ZStack`: con las tres el aviso **dejó de presentarse** y
  `RemoteWipeNoticeRoutingUITests` cayó 4 de 5 (también el de «sin iCloud», que no se había tocado); con el ancla de
  siempre, 5 de 5 verde. Solo con `.keyboardShortcut(.defaultAction)` el relleno sale, pero con el texto del mismo índigo
  que el fondo. ⇒ en esos avisos el relleno legible no cabe en un `.alert`; si hace falta, es otra presentación.
  **Y esa otra presentación tampoco cabe DENTRO de `ShellDataAlertsModifier` (medido el 2026-10-23, L20-15).** Con
  «Datos no disponibles» pasado a `.sheet` en ese mismo modificador, ni la hoja ni el aviso de «iCloud no disponible»
  (que no se había tocado) llegaron a presentarse: `RemoteWipeNoticeRoutingUITests` 1 de 5, y 5 de 5 con el código de
  antes como control. Con la hoja en su PROPIO modificador colgado de la cadena de `ContentView`
  (`RemoteWipeNoticeSheetModifier`, junto a `AppleIDCloseNoticeModifier`), 5 de 5. Causa sin aislar. ⇒ una
  presentación nueva del ancla de `ContentView` va en su propio modificador, y se mide con su XCUITest antes de darla
  por buena: el síntoma es «no sale», sin nada en el log.

- **Un `.alert` con tres botones no admite cualquier orden (medido el 2026-10-19, iOS 27.0, lote decidido 2.2 · 04).** El
  botón con `role: .cancel` va SIEMPRE al final, lo declares donde lo declares; y si ninguno lleva `.cancel`, SwiftUI añade
  un «Cancelar» propio al final, que cierra la alerta sin ejecutar nada. Con «Exportar · Esperar · Cerrar sesión
  igualmente» (L20-7) solo caben dos formas: «Esperar» como `.cancel` (y queda último) o los tres sin rol y un «Cancelar»
  de más. Antes de prometer un orden en una alerta, mídelo; si el orden es la decisión, puede que no sea una alerta.

- **En un `.alert`, el botón con `role: .cancel` va SIEMPRE al final, y sin ninguno SwiftUI añade un «Cancelar» propio
  (medido el 2026-10-19, iPhone 17 Pro, iOS 27.0, aviso «Datos no disponibles»).** Para poner «Seguir esperando» primero
  se le quitó el rol: salió arriba, pero el aviso pasó a tener tres botones —«Seguir esperando», «Empezar de cero» y un
  «Cancelar» que repite al primero—, y los `accessibilityIdentifier` de esos botones no llegaron al árbol (`""`).
  `.keyboardShortcut(.defaultAction)` en el de cancelar lo rellena pero no lo sube, y con el tinte de la app su texto
  sale ilegible (la regla del botón destacado, arriba). ⇒ **el orden de una alerta no se elige**: si la salida segura
  tiene que ir primero, hace falta otra presentación (una hoja con fases, molde `AppleIDCloseNoticeView`).

- **El `actions` builder de un `.alert` NO admite un label dependiente del `@State`, y lo que rompe no es la alerta: es la app.** Medido el 2026-09-06. Al dar título y botón dinámicos a la alerta de invitación de `ContentView` —para que el mismo anchor sirviera a dos avisos distintos— **dejó de completarse el guardado de una transacción**: `TransactionSuccessView` no llegaba a montarse y `dismissTransactionSuccess()` agotaba sus 10 s. El síntoma cae a pantallas que no tienen ninguna relación con la alerta, así que **el diagnóstico por lectura no llega**: hay que bisecar. Aislado con control en las DOS direcciones — `Button(String(localized: "common.ok"))` pasa (×2) · `Button(activeInviteError?.cta ?? …)` falla (×4) — y con el contraste que delimita el alcance: **el TÍTULO dinámico pasa sin problema**, así que la frontera está en el ViewBuilder de `actions`, no en la alerta entera. ⇒ **el texto de los botones de un `.alert` va literal**; si dos avisos comparten anchor, lo que puede variar es el título y el mensaje. Y el corolario de método, que es el caro: un cambio de presentación aparentemente inerte —la alerta estaba OCULTA— puede romper un flujo cualquiera de la app, así que **no basta con correr los XCUITest del área tocada**. Este rojo salió en `QuickActionsFavoritesUITests`, un área que ningún cruce de `codeGlobs` habría señalado como afectada por un cambio en invitaciones de grupo.

## Animar dentro de una pestaña (medido el 2026-10-27, iOS 27.0, card `estadisticas-chips-animacion-6l5n`)

- **`ContentView` anula la animación de toda transacción que cruza el `TabView`** (`.transaction { $0.animation = nil }`,
  desde el 2026-01-15). Dentro de una pestaña, un `withAnimation` o un `withTransaction` animado **no animan nada**: la
  píldora del período de Estadísticas saltaba de ancho en un fotograma con los dos, y animó en cuanto se quitó ese
  apagado (prueba hecha y revertida: no se toca, es de toda la app). Lo que sí funciona es una animación **implícita**
  dentro de la vista, `.animation(_:value:)`, que actúa por debajo del apagado. Las transiciones con su propia
  `.animation` (`AnyTransition.opacity.animation(…)`) también pasan. La barra de chips de Estadísticas, que va en un
  `safeAreaInset`, sí animó con `withTransaction`: la diferencia con el contenido del scroll no está aislada. ⇒ **en una
  pestaña, anima con `.animation(_:value:)` y compruébalo en vídeo**, no con «compila».
- **El apagado se queda y se anima caso por caso (decisión 1yhi, opción B, 2026-10-30).** La animación va en el
  CONTENEDOR común de lo que aparece y de lo que se mueve por ello, no en la vista que se va: con el `.animation` en el
  aviso, el aviso se funde pero lo de debajo sube de golpe. Los sitios animados así (avisos del Panel y de Grupos,
  flotantes de Panel, Grupos, Presupuestos y Pagos, plegado y cápsulas del flujo de caja) los fija
  `TabImplicitAnimationsWiringTests`, junto con el apagado de `ContentView`; uno nuevo se añade a su lista.
  **El apagado no llega a las hojas**: dentro de una hoja presentada desde una pestaña, `withAnimation` sí anima
  (medido en vídeo el 2026-10-30: «Más opciones» de Exportar se abre en ~10 fotogramas). Los «Más opciones» de los
  formularios, que van en hoja, no necesitan nada.
- **`disablesAnimations` no lo deshace una transacción anidada.** El botón de `NavigationChipButton` llama a su acción con
  `disablesAnimations = true` (contra un parpadeo del título grande), y un `withTransaction(Transaction(animation:))`
  dentro no animaba. Por eso existe `animatesSwitch`.
- **El label de un `Menu` no se anima**: su tamaño llega en una pasada aparte, sin animación, y arrastra a lo de al lado.
  Si lo que enseña tiene que animarse, se pinta fuera y el `Menu` va encima, transparente (`TrendsPeriodMenu` con
  `titleMotion`).
- **`GlassEffectContainer` alrededor de chips que cambian de ancho rompe la animación**: la cápsula nueva no crecía hasta
  el final y la pulsación fundía chips vecinos. Fuera del contenedor, anima.
- **Un cambio que recalcula la pantalla se come la animación que va a la vez**: las animaciones avanzan en el hilo
  principal, y montar una pestaña de Estadísticas lo bloquea 0,12–0,27 s en el iPhone (vídeo de Jürgen, 60 fps). Lo caro
  se hace con la pantalla quieta y lo pequeño se anima después (`StatisticsPeriodControl.choose`).
  **Toda fila de chips cuyo chip elegido cambia de ancho (solo el elegido enseña el nombre) monta sus páginas con
  `StagedTabPages`** (Estadísticas y el detalle de grupo, card pjum, 2026-10-31). La página nueva se monta invisible
  debajo de la que se ve y, cuando ya apareció, la página cambia y la fila se anima en el mismo fotograma. Sustituye a
  `switchTab` (card yc6k), que animaba el chip primero y montaba la página al terminar: Jürgen lo vio en el iPhone como
  «primero cambia el chip y un segundo después la página cambia de golpe». Lo que la pestaña cambie desde fuera de la fila
  (el saldo, «Ver los saldos») pasa por el mismo `StagedTabSelection.select`. Planificación y Reportes enseñan el nombre
  en todos y no lo necesitan. **La página no se funde**: el título grande vive dentro del scroll de la página (iOS 26), y
  un fundido de la página funde también el título; con la vieja aún montada, la nueva no lo recibe y «Viaje a Cusco»
  desaparecía ~0,3 s (medido en vídeo). Por eso `StagedTabPages` desmonta la vieja en el mismo instante en que enseña la
  nueva. Pin: `StagedTabSelectionTests`, `FluidezWiringTests`.
- **Un `Text` que cambia de valor con animación se funde con el anterior**: los dos quedan uno encima del otro («Este mes»
  sobre «Mes pasado»). Un valor, una vista (`.id(valor)`) con salida `.identity`. Una salida con sentido no sirve: SwiftUI
  la saca con la transición de su último fotograma, que es la del cambio anterior.
- **Cómo se mide**: `simctl io recordVideo` escribe un fotograma solo cuando la pantalla cambia, así que los tiempos de
  fotograma (`ffprobe -show_entries frame=pts_time`) dicen dónde hay bloqueo (hueco sin fotogramas) y una hoja de
  contactos con `select='between(t,…)'` + `-fps_mode passthrough` enseña si hay interpolación o salto.

## Fluidez: el sistema común (card pjum, 2026-10-31)

La tabla vista por vista y lo que queda en cards: `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`.

- **Curvas con nombre en `DS.Animation`**, una por intención: `.selection` (chip, segmento, píldora, pestaña interna),
  `.appear` (aviso, sección plegable, flotante, lo que entra o sale) y `.number` (una cifra que cambia). Una animación
  nueva usa una de las tres; si ninguna sirve, se añade aquí, no se escribe un `.spring(...)` suelto.
- **Siempre por `dsAnimation(_:value:reduceMotion:)` o `reduceMotion ? nil : …`.** Con Reducir movimiento no hay
  animación. Dentro de una pestaña, implícita; en una hoja vale `dsWithAnimation(reduceMotion, …)`. Nunca
  `dsWithAnimation(false)` fijo (ignora el ajuste: lo tenía el editor de pagos).
- **Hápticos, `DS.Haptic`, uno por gesto**: selección → `selection()`; éxito (guardar, aprobar, confirmar) →
  `success()`; aviso (validación que no deja seguir, error al guardar) → `error()`; borrado (al confirmarlo) →
  `warning()`. Si el ViewModel ya vibra al confirmar, la vista no repite: confirmar una liquidación y marcar una fila de
  Registros vibraban dos veces. El éxito va donde el guardado ya ha salido bien, no en el botón: el botón vibra
  aunque falle. `.sensoryFeedback(_:trigger:)` vale para lo declarativo (la marca de una fila), sin sumarle un
  `DS.Haptic` en el mismo toque. Un `UIImpactFeedbackGenerator` suelto es deuda (la Bandeja, card C4).
- **Una cifra que cambia a la vista: `AmountText(…, animatesValue: true)`**: `numericText` con su animación implícita.
  Un `.contentTransition(.numericText())` sin `.animation(_:value:)` detrás no hace nada dentro de una pestaña, y así
  estaban los heros de Categorías, Tendencias y Pagos. **Solo rueda lo que cambia con la cifra ya en pantalla** (600 ms
  tras aparecer): el primer cálculo de una página recién montada sale quieto, porque si no Distribución rodaba de 0
  hasta su saldo cada vez que se abría (`CategoriesTabView.balanceKPI`).
- **Un selector de cápsula desliza la cápsula** (`matchedGeometryEffect`, molde `GenericSegmentedPill` y
  `TransactionTypeSelectorView`), y su animación va en el propio selector, no en lo que cambia debajo.
- **Un fundido de pantalla entera puede duplicar el árbol de accesibilidad mientras dura**: dos copias de cada botón, y
  un XCUITest que toque en ese instante cae con «varios elementos». **Lo que se va al terminar una carga** (esqueleto,
  `ProgressView`, «Analizando…») sale con `.transition(.loadingPlaceholder)` (`ContentTransitions.swift`, card C1,
  2026-11-01): se funde y, desde el primer fotograma de su salida, ni se lee ni se toca. `yalaSkeleton` funde así el
  esqueleto ENCIMA de los datos (`zIndex(1)`), que entran debajo ya opacos (`.identity`). Medido ese día: con el
  esqueleto redactado ningún mutante llegó a duplicar el árbol (inferido: la copia `.redacted(.placeholder)` no se
  expone), así que la salida oculta es el cinturón y `SkeletonFadeAccessibilityUITests` fija el criterio, no la pieza.
  **Si lo que llega lleva el título grande en su scroll** (la lista de Grupos), entra con `.identity`: fundirla funde
  el título con ella.
- **Filas que entran o se van: `.animatesRowEdits(ids:)`** en el contenedor de las filas, con los ids en el orden en
  que se pintan. Solo anima una edición de 1-3 filas con el resto en su orden (`RowListEditLogic`); un filtro o un
  período que cambian la lista entera siguen en seco. La animación cubre el contenedor: lo de dentro que cambie en la
  misma transacción y no deba fundirse (la frase con la cifra del grupo) lleva `.transaction { $0.animation = nil }`.
- **El háptico de «Deshacer» va en quien deshace, no en el botón del aviso**: el aviso también lleva «Ver» y «Editar»,
  que no deshacen nada, y un deshacer puede no tener nada que deshacer (`returnToPending` que lanza, `unskipOccurrence`
  que no guarda). `success()` tras deshacer de verdad.

## iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO.
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos.
- Si existe API iOS 26 que mejore integración con sistema, USARLA.

## Design System (en cambios UI)
- SIEMPRE `DS.Spacing`, `DS.Radius`, `DS.Typography`, `DS.Semantic.*`, `DS.Gradients.*` — NUNCA hardcoded.
- SIEMPRE filas clicables con `Button` + `contentShape(Rectangle())`. **Y el DÓNDE importa: si el label tiene `Spacer()` (u otro hueco no dibujado) y NO lleva fondo relleno, el `contentShape` va DENTRO del label, tras el padding — nunca colgado del `Button`.** Ahí fuera no extiende el área interactiva sobre el hueco: solo responden los glifos de los extremos y **el centro de la fila queda muerto**, para un dedo humano igual que para un tap sintético. Medido el 2026-08-07 en la fila de divisa de `GroupFormView` (mismo elemento, misma `y`, solo cambia la `x`: sobre el glifo abre el selector, al centro no corre ni la acción — el `.sheet` es inocente). Un label con fondo relleno es inmune y no necesita el matiz: `GroupCardView` (`.listRowCard()`) y `MoreView.heroPanelCard` (`.panelCard(small:)`) fueron MEDIDOS con el mismo instrumento y responden al tap central. Pin: `YalaUITests/Flows/GroupsSmokeUITests.swift#test_groupFormCurrencyRowOpensSelector` — el tap de XCUITest cae en el centro del frame, que es justo el punto muerto, así que devolver el `contentShape` al `Button` lo pone en rojo (verificado, exit 65).
- Componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, etc.
- **Un color de la paleta sobre tarjeta blanca NO vale para TEXTO.** Cuatro de los cinco no llegan al mínimo AA de 4,5, y el quinto lo pasa justo (`hotPink` 3,77 · `electricIndigo` 4,61 desde el 2026-10-17, 4,46 sobre el fondo `#FAFBFF` · `priorityNeed` 2,19 · `essentialNeed` 2,15 · `optionalNeed` 2,69), y `AmountText` pinta símbolo y decimales al 60 % de opacidad encima, lo que los baja a ~2,5. Para un monto coloreado usar un tono oscurecido del mismo matiz (`Color.incomeAmount`, #0F7A80, contraste 5,1). En superficies RELLENAS —chips, barras, anillos, iconos— la paleta sigue siendo la correcta: el requisito es del texto. Medido el 2026-09-02.
- **El color del tema tiene TRES tokens, y cada uno para una cosa (lote 12.3, 2026-10-25).** `theme.accent` /
  `.thAccent` es el RELLENO (botones, chips elegidos, barras). `theme.accentText` / `.thAccentText` es el acento como
  TEXTO o icono sobre el fondo y las tarjetas: en los temas oscuros es más claro (#818CF8 índigo, #FF4DA6 rosa), porque
  `electricIndigo` da 3,2–4,5 sobre las superficies oscuras y no puede aclararse sin romper el blanco de los botones.
  `theme.onAccent` / `.thOnAccent` es lo que va ENCIMA del relleno: blanco en los índigo, **negro** en Teal, Rosa y
  Minimalista. ⇒ **nunca `.white` a mano sobre el acento**, ni `Color.contrastingText(for: theme.accent)` (su fórmula no
  es la de WCAG y daba blanco sobre el turquesa, 2,19:1): sobre un relleno cualquiera, `theme.onFill(color)`. Y el
  acento como texto nunca con `.foregroundStyle(.tint)`: el tinte global sigue siendo el relleno. Lo fija
  `ThemeTokenContrastTests` en los diez temas.
- **`Color.incomeAmount` es adaptativo desde el 2026-10-25**: #0F7A80 en claro y el turquesa de marca (#00C2CB) en
  oscuro, donde el fijo daba 3,3:1. Como RELLENO con texto blanco encima, `Color.incomeFill` (fijo, 5,1:1): el
  adaptativo se aclara en oscuro y el blanco encima dejaría de leerse.
- **En la LISTA de Grupos, lo que debes va en `Color.groupOweAmount` (rosa rojizo) y lo que te deben en `Color.groupOwedAmount` (verde), sin naranja (Jürgen, 2026-10-30, sustituye al «en Grupos los montos no llevan color»).** Vale para el resumen de arriba y las filas por persona de cada tarjeta; los dos tokens pasan AA en los diez temas (`ThemeTokenContrastTests`). Dentro de un grupo (su cifra, gasto, miembro y saldo) los montos siguen en `Color.primary`: la decisión fue de la lista. El degradado del tema se queda (`.panel`). La regla de abajo sigue para Registros y el Panel.
- **Y colorea la excepción, no la norma.** En una lista de movimientos casi todo son gastos: teñirlos pinta la pantalla entera y el color deja de avisar de nada. Solo el ingreso lleva color (`RecentRecordsWidget`, `ScheduledPaymentsWidget`). Decisión del 2026-09-02 en `docs/DECISIONS.md`.
- **Jerarquía del Panel: sección `title3` (20) › widget `subheadlineEmphasized` (15) › fila.** Hasta el 2026-09-02 la sección y el widget usaban el MISMO token y la fila (`headline`, 17) era el rótulo mayor de la pantalla. Y el aire va al revés que el tamaño: MÁS entre secciones (`xxl`) que del título a su contenido (`sm`), o por proximidad el título se lee como pie del bloque anterior.
- Tablas DS.Semantic / DS.Gradients en SWIFT-STYLE.md.
- **Una pantalla de ajustes es un `YalaSettingsList`** (`DesignSystem/SettingsList.swift`, 2026-10-02): `List`
  agrupada del sistema, bloque `theme.card` por sección sobre el fondo de siempre, cabecera gris, ayuda en el pie
  del bloque y solo si dice algo que la fila no dice. No vuelvas a la tarjeta por fila con su caption debajo. Tres
  cosas medidas al migrar: (1) **`.secondary`/`.tertiary` dentro de un `Menu` o de un botón de `List` derivan del
  tinte** — el valor de «Idioma de voz» salía en el color de acento; `YalaSettingsRowLabel` usa
  `secondaryLabel`/`tertiaryLabel` fijos. (2) **Con `Toggle(isOn:) { título }` la fila entera es el switch, y tocar
  su título no lo cambia** (como en Ajustes de iOS): un XCUITest que hacía `tap()` sobre el elemento quedó rojo; se
  toca `toggle.switches.firstMatch`. (3) **Un `NavigationLink` en `List` pinta su chevron**: quita el propio o salen
  dos. La lista monta solo las celdas visibles, así que un XCUITest que busca filas baja hasta ellas.

- **Un flujo por pasos que se hace FUERA de Yala es un `YalaStepGuide`** (`DesignSystem/StepGuide.swift`,
  2026-10-02, referencia del 15-sep en `docs/design/referencias/`): progreso doble en la barra, cabecera con datos,
  pasos con hilo y un solo botón (el del paso activo), «Lo que vas a ver», garantía y dos salidas al pie. Hoy lo usan
  Apple Pay (Tutoriales) y Face ID (Seguridad). iOS no le cuenta a Yala si un paso de fuera se hizo: avanza «Hecho», o
  la acción del paso si hacerla ES el paso (abrir Atajos, y solo si `openURL` contesta que abrió). Los ids de XCUITest
  van en el título de la cabecera (`rootIdentifier`) y en el título de cada paso (`step_guide_step_<n>`, con su estado
  en `value`): uno en la raíz pisaría los de dentro.

- **Una pantalla de ENTRADA del Welcome es un `WelcomeFormScreen`** (`Views/Onboarding/WelcomeForm.swift`,
  2026-10-02, referencia del 15-sep): titular grande sans (`DS.Typography.welcomeHeadline`, el `largeTitle` de la app:
  Jürgen retiró el serif el 2026-10-26) sin logo, lo que se elige en
  UNA tarjeta (`welcomeFormCard()` o filas con `WelcomeOptionDivider`), y fuera solo la pregunta de pie. Fondo, el
  degradado fijo de siempre. Pesos de botón con `WelcomeFormButton`, cápsula con la letra de `YalaPrimaryButton`:
  `.filled` (blanco) para lo que se propone, `.outline` para la salida sin cuenta de Yala. Los pasos del onboarding que
  eligen entre opciones van también en UNA tarjeta con separadores (`OnboardingView.optionCard`), no una por opción. Donde Jürgen decidió que nada se recomienda («Es mi primera vez»),
  mismo peso para todas. El Hero y las fases de progreso/error siguen con logo. **El «Volver» del Welcome no crece
  más allá de `xxxLarge`** (Large Content Viewer, como una barra de navegación): a AX5 medía ~80 pt y tapaba el
  titular y el logo de las puertas.

## Backgrounds de vista
- TODA View root, sheet, fullScreenCover NUEVA → `.yalaScreenBackground(_:ignoredEdges:)`.
- NUNCA aplicar `.background(theme.background)`, `.background(.thBackground)` ni default iOS sin background.
- Forms/Lists dentro de sheet → `.scrollContentBackground(.hidden)` MANUAL antes del modifier (el modifier no lo hace automático para preservar predictibilidad).
- **Regla SSOT (reestructura 2026-06-08)**: el fondo lo determina el **contenedor de presentación RAÍZ** del stack. Una vista navegada (push) HEREDA el fondo de su stack — dentro de un tab → `.panel`; dentro de un sheet → el del sheet. **Un `.sheet` NUNCA es `.panel`.** Excepción única: la hoja «Gráficas» del flujo de caja (`CashFlowChartsSheet`, 2026-10-30) va en `.panel`, porque sus tarjetas de gráficas son las de Tendencias (`panelCard`, translúcidas en oscuro) y sobre el fondo plano salían grises.
- Variantes (`YalaBackgroundVariant`) — 4 (`.compact` eliminada):
  - `.panel` (default) — PanelBackgroundView gradient temático. SOLO vistas COMPLETAS: tab roots, vistas navegadas (push), fullScreenCover normal.
  - `.subtle` — `theme.background` plano. CUALQUIER sheet desde el bottom (sin detents o `[.large]`); TODO el stack del sheet de Profile (los ~20 Settings + sub-navegación); y success/celebración.
  - `.transparent` — sin fondo (DESNUDO, muestra el fondo de sistema del sheet — decisión owner, NO glassSheet). Sheets con detent PARCIAL fijo (`.medium`/`.height`/`.fraction`) que NO pasan por `.yalaSheetDetents`.
  - `.partialSheet` — sheets cuyo detent sale de `.yalaSheetDetents(_:)`: `.transparent` en ventana compacta, `.subtle` cuando la ventana lo fuerza a `.large`. Dual-detent `[.medium,.large]` con `selection: $selectedDetent` → `isLargeDetent ? .subtle : .transparent`.
- `.compact` ELIMINADA. `AnimatedMeshBackground` + `MeshConfigResolver` borrados (dead code).
- **El tamaño de una hoja lo decide la VENTANA, no el aparato (2026-09-28).** Una hoja con detent parcial que en ventana ancha deba ser grande usa `.yalaSheetDetents(_:)` (o `(_:selection:)`) en vez de `.presentationDetents`: en ventana de ancho regular (iPad a pantalla completa, iPhone Duo abierto) o en Mac fuerza `.large`; en compacta (iPhone, iPad en ventana estrecha o Split View) deja los detents. Hoy **19 hojas con detent parcial siguen con `.presentationDetents` a secas** y salen iguales en todas partes (Panel, Flujo de caja, puente de grupos…; ticket `partial-sheets-that-never-adapted-to-the-window`); una hoja nueva que las copie hereda eso. Una vista que necesite el booleano lee `@Environment(\.usesLargeSheets)`. **Nunca** `UIDevice.current.userInterfaceIdiom` para layout, y **nunca** el `horizontalSizeClass` leído dentro de la hoja: ahí lo fija la presentación y no tiene por qué ser el de la ventana que la presenta. Por eso `\.usesLargeSheets` se calcula UNA vez, en la raíz (`YalaApp.rootView` → `.sizesSheetsByWindow()`), y los valores propios del entorno sí llegan intactos a las hojas. Una escena nueva sin ese modificador deja todas sus hojas con los detents de iPhone. Test: `YalaTests/AdaptiveSheetSizingTests.swift`.
- Param `ignoredEdges: Edge.Set?`: si `nil`, default `.all`. Para vistas con `safeAreaInset` pasar edges específicos (`[.top]`, `[.bottom]`).
- OUT: WelcomeFlow/onboarding (`DS.Gradients.heroIndigoBlack` especializado), InboxAlertModal (custom modal Color.black backdrop), popovers (iOS nativo).
- **Ninguna hoja con fondo gris: el patrón es el de «Configurar panel» (Jürgen, 2026-10-30, card g1uw).** A media
  altura la hoja enseña el Liquid Glass del sistema; al estirarla a grande, `.subtle`. Se consigue **no pintando**:
  ningún `.presentationBackground` (ni material ni color: el `.thickMaterial` de L2-22 salía gris sólido en los
  selectores de Cuenta y Categoría) y la raíz con `isLargeDetent ? .subtle : .transparent` (con `selection`) o
  `.partialSheet` (sin ella). Nada opaco a pantalla completa en la raíz (`.background(.thCard)` sobre la `List` tapaba
  el glass en los selectores de período); las tarjetas de dentro sí llevan su `theme.card`. **`.partialSheet` sin
  `selection` NO pasa a `.subtle` al estirarla** (solo lo resuelve la ventana): para que el detent elegido cambie el
  fondo, la hoja lleva su `@State selectedDetent` y los detents con `selection:`. Una vista que se presenta grande en un
  sitio y a media altura en otro pone ella misma los detents parciales cuando se le pide
  (`GroupPickerSheet(opensAtMediumHeight:)`). Molde: `PanelSectionsConfigView`; lo fija
  `SheetGlassBackgroundWiringTests`, que prohíbe `.presentationBackground` en `Yala/App` (salvo el `.clear` del aviso
  de Bandeja y la definición de `glassSheet()`) y cualquier llamada a `.glassSheet()`.
- `GlassSheetModifier.glassSheet()` (`.presentationBackground(.ultraThinMaterial)`) no tiene usos y **no se usa en
  hojas**: tapa el glass del sistema, lo contrario de la regla de arriba. `.transparent` NO usa material (es desnudo).

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
  - **Cambiar la configuración guardada con la barra viva también la tumba** (card fozu, 2026-10-27, iOS 27.0):
    guardar otra barra reordena las seis montadas y cambia cuáles van ocultas, y cambiar solo Estadísticas por
    Registros cerraba la app al guardar (`-[UITab viewController]` desde `setTabs:animated:`, 2 de 2); Jürgen vio
    Grupos y Registros en negro hasta matar la app. ⇒ **la `TabView` lleva `.id(tabConfig.activeTabs)`**: con otra
    configuración nace de nuevo, como en un arranque. Y mientras el editor de Más está abierto
    (`SceneNavigation.isEditingTabBarLayout`) la barra se queda con la que tenía (`TabBarLayoutFreeze`): remontarla al
    guardar cerraba el editor de golpe. Un escritor nuevo de la configuración con la app abierta pasa por ahí, no la
    cambia en sitio. Test: `CustomTabBarUITests`.
  El orden es el mismo en los dos tamaños y en el iPhone la barra no cambia (medido al píxel). **Barra lateral plana,
  sin `TabSection`**: una sección que solo exista en regular cambia el árbol en cada redimensionado, y una permanente
  reordena la barra del iPhone, que el usuario ordena a mano (`TabBarConfigView`).
- **En vertical el iPad pinta pestañas arriba y en horizontal barra lateral**: es el `.automatic` de Apple y se deja
  así (medido en el iPad Pro 13). La barra lateral está a un toque en vertical.
- **El iPhone también gira (2026-10-01)**: vertical y horizontal a izquierda y derecha (`UISupportedInterfaceOrientations`
  en los cuatro build settings de `Yala` y `Yala Dev`). Dos consecuencias para una pantalla nueva: (1) **un iPhone
  grande girado es ancho REGULAR** —pestañas con las seis páginas, lista y detalle a la vez—, así que girar es
  redimensionar y lo abierto tiene que vivir fuera de la forma; (2) **el alto puede ser de 375 pt** (SE girado), así
  que nada que no quepa puede quedar fuera de un scroll. Nunca `if` por orientación: alto o ancho del contenedor.
  Test: `YalaUITests/IPhoneLandscapeUITests` (girar con un registro abierto y con el formulario a medias).
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
    no caben a la vez (iPad mini en vertical: 744 pt, antes de plegar la página; hoy, Yala IA abierto al lado), el
    split SUPERPONE la lista sobre el detalle; con la visibilidad fija la superposición no se retira nunca y tapa el
    detalle, y sin el botón no hay forma de volver a la lista después de retirarla.
- **Un `navigationDestination` de la columna de lista presenta en la de detalle** (medido con presupuestos): sus filas
  no se tocaron. En compacta, empuja como siempre.
- **Y lo que eso presenta no puede empujar nada por su cuenta si la columna de detalle no lleva su `NavigationStack`**
  (medido el 2026-10-14, iPhone e iPad, lote 9): el botón de gráficas del detalle de un presupuesto
  (`navigationDestination(isPresented:)`) no hacía nada, ni con `NavigationLink(value:)` y el destino registrado en
  la lista (desde la columna de detalle no se ve). Lo que funciona: `NavigationStack { vacío }` en `detail:` y el
  destino registrado en la propia vista abierta (`PlanningView`, `BudgetDetailView`). Es la misma familia que el «+»
  de Categorías en Ajustes. **Dos cosas que siguen igual y no se arreglan así**: cambiar de chip con algo abierto deja
  la columna con el triángulo amarillo (el destino vivía en la lista que se desmonta; `.id` de la pila no lo cambia,
  ticket `ipad-planning-chip-switch-leaves-a-detail-without-destination`), y en ancho
  `app.navigationBars.buttons.element(boundBy: 0)` es el botón de la barra lateral, no el «Atrás»: en XCUITest,
  `buttons["BackButton"]`.
- **Lo que se abre en la columna de detalle lleva `.id(<identidad de lo abierto>)`** (medido el 2026-10-12 en el iPad
  Pro 13). Al abrir otro elemento, SwiftUI REUTILIZA la vista del detalle —con `navigationDestination(item:)` y también
  con `NavigationLink(value:)`—, así que su `@State` iniciado en el `init`, en `onAppear` o en una `.task` se queda con
  el anterior: el grupo nuevo enseñaba los gastos, el saldo y los miembros del primero, y el presupuesto nuevo el
  gastado del anterior, con el título ya cambiado. En iPhone no se ve porque cada empuje crea la vista. Molde:
  `RecordsStandaloneView.detailColumn`, `GroupsContainerView`, `BudgetsListView`. Test:
  `AdaptiveNavigationUITests#test_switchingGroups_*` y `#test_switchingBudgets_*`.
- **El `horizontalSizeClass` se lee FUERA del split**, en la vista que lo monta: dentro, la columna de lista es
  compacta aunque la ventana sea ancha.
- **Lo abierto vive fuera del split** (`RecordsViewModel.openRecordID`) y se resuelve contra lo cargado, nunca con
  `modelContext.model(for:)`, que fabrica un objeto aunque ya no exista. Si la ventana se estrecha con un registro
  abierto, `preferredCompactColumn = .detail` lo enseña empujado; Atrás lo cierra.
- **El detalle de registro es hoja en compacta y columna en regular** (`TransactionDetailSheet(presentation:)`): el
  iPhone no cambia de hoja a empuje. En columna, Editar abre el editor directo; el encadenado «cerrar hoja → editor»
  solo existe en la hoja.
- Ancho legible: `DS.Adaptive.readableWidth` (700) en el contenido de una columna de detalle.
- **Una `List` con `contentMargins` propios, en la columna de detalle, arranca pegada a la columna de lista**
  (medido 2026-10-03, iPad mini y Pro 13, Pro Max girado). Junto a la columna la lista tiene área segura (400 pt en el
  mini girado) y el sistema se queda con el MAYOR entre ese área y el margen, no con la suma: el margen desaparece justo
  donde hay columna al lado. Un `ScrollView` con `contentMargins` sí los suma (el detalle de Grupos deja su aire). La
  salida, en `YalaSettingsList`: medir el área segura de cada lado y pasarle a `contentMargins` área + margen
  (`DS.Adaptive.readableListInsets`). Dos que NO valen: `safeAreaPadding` (cambia 2 pt el margen interior de las filas
  también en el iPhone en vertical, y en el Pro Max girado seguía pegada) y rehacer la lista con `.id` cuando cambia el
  área segura (no arregla nada). Y un efecto de la celda más estrecha: una fila sin márgenes propios
  (`.listRowInsets(EdgeInsets())`) con un texto que casi cabe en una línea sale con los bordes de los glifos cortados
  (la cabecera de Personalización a 384 pt, y ya en 2.1 la de Tutoriales en el SE en vertical): esas cabeceras llevan
  `DS.Spacing.sm` de aire lateral.
- **La lista se aparta sola cuando lo abierto no cabe legible a su lado** (fase 2, 2026-09-29): con algo abierto en el
  detalle y el split por debajo de dos anchos de iPhone (750), `ListDetailSplit` pasa a `.detailOnly`
  (`ListDetailOverlayLogic.listYieldsToDetail`, con test); con «Elige un…» la lista se queda. Lo dispara abrir Yala IA
  al lado o estrechar la ventana. La lista sigue a un toque en el botón del sistema.
- **Con texto de accesibilidad la columna se ensancha y, donde no caben dos, la página se pliega (2026-10-01; con
  cualquier texto desde el 2026-10-24).**
  `DS.Adaptive.listColumnWidths(isAccessibilityText:)` da 440/460/520 con AX1–AX5 (los 408 pt de contenido del Pro
  Max vertical, donde AX5 cabe, más márgenes); con texto de siempre, los 375/400/480 de antes. Dos cosas medidas en el
  Pro Max girado que no son obvias: **el split SUMA la isla encima del ancho pedido** (pedida a 520, la columna midió
  582), y **no pone AL LADO del detalle una columna que lea AX5** — a 522 y a 582 la superpuso sobre «Elige un…», que
  quedaba medio tapado; la de 446 de siempre sí va al lado, pero ahí AX5 parte «Este mes». Por eso cada página con
  `ListDetailSplit` lleva `.foldsListDetailWhenColumnsDontFit()` puesto por QUIEN LA MONTA (`ContentView.viewForTab`):
  sin ancho para dos columnas del tamaño de texto (`ListDetailOverlayLogic.foldsToSingleColumn`), la página entera ve
  ancho compacto y es la pila de vertical. Con AX: el Pro Max girado (832) y el iPad mini (744 / 853); el iPad Pro 13
  sigue en split. **Con texto de siempre también desde el 2026-10-24** (umbral 2 × 375): el iPhone Duo abierto en
  vertical (669 pt) superponía la lista, que tapaba el grupo abierto y cortaba «Elige un…» por la mitad; ahí y en el
  iPad mini en vertical (744) la página es la pila. El Pro Max girado (832) y el Duo abierto en horizontal siguen en
  split. **El ancho es el que mide la vista, sin restarle nada**: ya viene sin la isla ni la barra lateral, aunque el
  proxy siga reportando esos márgenes (iPad Pro 13 girado: 1096 de ancho y 280 de margen). Restarlos los contaba dos
  veces y apartaba la lista en el Pro 13 con AX. Va fuera porque Registros y Grupos leen el size class por su cuenta para
  decidir hoja o columna. Una página nueva con `ListDetailSplit` lo lleva también (Ajustes no: va en su hoja, y ahí
  el ancho lo decide la presentación; no está medido con AX). Test:
  `IPhoneLandscapeUITests#test_accessibilityText_turnedLargeIPhone_planningHeaderStaysReadable` (por UDID en el Pro Max)
  + `YalaTests/ListDetailOverlayLogicTests`.
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
  tarjetas en regular: en la columna derecha de la cabecera eran 4 de ~110 pt. Desde el 2026-10-03
  (`panel-accounts-redesign`) cada tarjeta mide el 80 % del ancho del carrusel con techo de 320 pt
  (`PanelAccountCardLogic.cardWidth`): siempre asoma la siguiente, en el iPhone y en la columna del iPad.
- **Una gráfica de alto fijo que deba aprovechar un iPhone grande va dentro de `AdaptiveChartHeight(base:)`**
  (2026-10-01): mide su propio ancho y le da `base × clamp(ancho / 320, 1, 1,2)` (`DS.Adaptive.chartHeight`), solo
  en compacto. Medido: en el SE la gráfica de tendencia mide ~311 pt, así que no cambia; en el Pro Max ~376 → 200 pt.
  Hoy la usan la tendencia del Panel y las dos de Estadísticas › Tendencias. **Qué NO ganó, y por qué** (hasta el
  2026-10-03): tres tarjetas de cuenta en un Pro Max (saldrían a ~128 pt). Ese día el carrusel pasó a una tarjeta
  grande y la siguiente asomando, que da el sitio al nombre y al saldo sin depender del modelo de iPhone.
- **Un widget solo en su fila ocupa la fila entera solo si sabe repartir su contenido** (`WidgetConfigManager
  .spansRowWhenAloneTypes`, hoy `latestRecords`); los demás siguen en media fila.
- **Un hero (la cabecera con la cifra grande de una página) es un `HeroHeader`** (`Views/Shared/HeroHeader.swift`,
  2026-10-04): rótulo de la cifra arriba a la izquierda (`HeroHeaderLabel`), píldora de período a su derecha, cifra
  `panelHeroAmount` y detalle debajo. No trae margen lateral: lo pone quien lo monta, en el eje izquierdo del resto de
  la pantalla (en Estadísticas ya lo da `scrollViewGlassEdges`; sumarle otro lo dejaba a 32 pt, medido). Lo usan el Panel, las
  cuatro pestañas de Estadísticas, Registros y Pagos planificados. No montes otra pila centrada: había cinco heros
  distintos y ninguno compartido (`distribution-subviews-miss-the-new-panel-hero`). El rótulo lleva
  `stats_hero_caption` en Estadísticas y solo sale si sale la cifra.
- **Con poco ALTO, la cabecera de resumen se compacta: `SummaryHeaderStack(period:caption:figure:detail:)`**
  (`Views/Shared/SummaryHeaderStack.swift`, 2026-10-01). La usan Registros (y con ella Estadísticas › Registros) y
  Estadísticas › Resumen. Con alto suficiente pinta el `HeroHeader` (desde el 2026-10-04; antes, una pila centrada);
  con poco alto, el rótulo baja bajo la cifra y prueba, de la primera que quepa a lo ancho: banda (cifra | período y detalle), período al lado de la cifra,
  detalle en una fila, la pila; las cuatro con 4 pt de margen vertical. Dos cosas medidas que no son obvias:
  - **«Poco alto» es el alto del contenedor CONTANDO las barras que se le superponen** (`measuresShortContainer`:
    tamaño + márgenes de seguridad, umbral `DS.Adaptive.shortContainerMaxHeight` = 500). El alto visible a secas no
    vale: en un SE vertical, bajo el título grande y los chips de Estadísticas, ya baja de 420 y compactaba el
    vertical. Girados quedan ≤ ~440; en vertical, ≥ ~615.
  - **En la banda el período va a la derecha, no encima de la cifra**: encima, la columna izquierda volvía a tener tres
    filas y la primera fila de Registros seguía bajo la barra en el SE girado (empezaba 47 pt por debajo).
  Test: `IPhoneLandscapeUITests#test_shortHeight_*` (por UDID en SE y Pro Max) + `YalaTests/ShortContainerHeightTests`.
- **Estadísticas › Registros abre el registro en un panel, no en un split** (`DetailContainerView.recordsContent`):
  el chip vive dentro de la pila de Estadísticas. Lista y panel lado a lado con dos anchos de iPhone; si no caben, el
  panel tapa la lista (`ZStackLayout`, la lista sigue montada) y su X la devuelve; al pasar a compacta con uno
  abierto, la hoja de siempre. El panel es `TransactionDetailSheet(presentation: .pane)`: cabecera propia con X y
  Editar, porque un `.toolbar` o el título inline ahí dentro cambiarían la barra de Estadísticas.

## iPhone Duo (SDK 27.1, medido el 2026-10-24 en el simulador)

- **Un ancho medido con `onGeometryChange` no puede fijar el ancho de un HERMANO dentro de lo que se mide.** En
  `ZStack(alignment: .leading) { carril; relleno.frame(width: medido × ratio) }` el relleno al 100 % hace que el
  `ZStack` no baje de la medida anterior: la barra crece y no encoge nunca. Al plegar o girar el Duo, «Entradas y
  salidas» quedaba más ancha que la pantalla y descentraba a sus vecinas (el iPhone girado y el iPad lo tenían
  igual). ⇒ **el relleno va en `.overlay(alignment: .leading)` del carril**, y lo que se mide es el carril. Igual con un
  `HStack` de segmentos a porcentaje: se mide un `Color.clear` flexible y los segmentos van en su overlay (las barras
  segmentadas de las tortas). `GeometryReader` no tiene el problema: toma el tamaño propuesto.
- **Barras verticales.** Pasan solos a la barra vertical los botones con icono (`YalaToolbarButton`, `YalaSaveButton`
  y un `Button` con `Image`). No pasan: los de solo texto y los de vista propia, que se quedan en una barra horizontal
  arriba. Uno de vista propia sin título arriba (la bandeja del Panel) se pintó **flotando abajo, encima del
  contenido**, en el primer arranque: va con `.joinsVerticalBar()` (`ToolbarVerticalBar.swift`).
- **Opción 2 de Jürgen (2026-10-24), en el Duo cerrado: los botones de la página van en la barra vertical y, si no
  caben, ceden las pestañas.** El avatar (`ProfileToolbarItem`) lleva `.joinsVerticalBar` desde el propio componente,
  así ninguna página se queda con el avatar arriba. Y cada página de pestaña lleva `.prefersToolbarItemsInVerticalBar()`
  **dentro de su pila, junto a su `.toolbar`**: puesto en la `TabView` o en el contenido de cada `Tab` no hace nada
  (medido). **Desde el 2026-10-30 (card a5kf) también en el Duo abierto en horizontal y a medio plegar**, sin condición
  de ancho: las dos cosas solo actúan donde hay barra vertical. Abierto, con siete pestañas, el avatar se quedaba
  arriba en una franja propia que le quitaba alto a la página; ahora las pestañas del Panel se pliegan a un botón y
  bandeja, Filtros, Configurar y avatar caben. En las páginas con lista y detalle (Grupos, Registros, Planificación) el
  avatar va en la barra de la columna de lista, que el sistema deja horizontal: ahí no cambia. **No lo ates al ancho**:
  la condición de ancho compacto era lo que dejaba la franja. El iPad no tiene barra vertical (27.0 ni con el SDK 27.1:
  es del Duo), y su barra lateral es la de pestañas. Una página de pestaña nueva lleva el modificador; un botón de
  barra de vista propia nuevo, `.joinsVerticalBar`.
- **Un botón de barra de solo texto que ya está en el menú de la página se retira con `.hiddenInVerticalBar()`**
  («Seleccionar» de Registros). Darle icono cambiaría el iPhone (su barra horizontal prefiere el icono: «Cancelar»
  sería una ✕), y `.axisBehavior(.horizontalOnly)` no basta: la barra del título grande es horizontal y lo deja ahí.
  `\.toolbarVerticalEdge` (iOS 27.1) es el borde de la barra: medido, `.trailing` en el Duo cerrado y `nil` en el
  iPhone, en el Duo abierto en vertical y en la columna de la lista del Duo abierto en horizontal, que van en
  horizontal. Los «Cancelar / Hecho» de las hojas se quedan arriba, decidido.
- **Ancho (regla A, 2026-10-24): nada de lo que se desplaza pasa por detrás de la barra vertical; bajo ella, solo el
  fondo.** Es la regla de Apple (`app-resizability`). Un `ScrollView` horizontal pinta hasta el borde físico aunque su
  página acabe antes: las cuentas y los chips del Panel y las tarjetas del Welcome llegaban por detrás de la barra y los
  widgets no. `scrollViewGlassEdges` lleva `.staysOutOfVerticalBar()`, que recorta el scroll de la página en su propio
  borde por el lado de la barra. **No leas el
  inset de un `GeometryProxy` para esto**: es el del espacio ofrecido y el recorte quedaba 84 pt más adentro (el marco
  del scroll ya acaba en el borde seguro). La alternativa B (la página por debajo del cristal) está en capturas en
  `qa/evidencia-duo-cerrado-20261024/`: tapa «Todo el tiempo», importes y botones.
- **Un carrusel horizontal no se corta en seco contra la barra: se funde (Jürgen, 2026-10-25).** El tajo recto hacía
  que la barra pareciera una pieza aparte. Todo `ScrollView(.horizontal)` lleva `.fadesTowardVerticalBar()`: se
  desvanece en sus últimos 32 pt y acaba justo en el borde de la barra, y solo mientras queda contenido por ver hacia
  ella. Va **en el carrusel, no en la página**, porque un fundido de página borraría también el borde de lo que no se
  mueve (la tarjeta de Saldo). Un carrusel de páginas a todo el ancho (`containerRelativeFrame`) lleva
  `fadeWidth: DS.Spacing.lg`: se funde solo en el margen y la página visible conserva su borde. Lee el borde de la
  página que publica `staysOutOfVerticalBar`; fuera de una de esas páginas, y sin barra, no hace nada. Un carrusel
  nuevo lo lleva.
- **Dos excepciones a la regla A, decididas por Jürgen el 2026-10-25 sobre capturas: `.extendsUnderVerticalBar()`.**
  La vista ocupa también la columna de la barra y se centra en la pantalla entera. (1) Las pantallas con logo del
  Welcome (`WelcomeFlowScreen`: Hero y puertas). (2) La lista de Ajustes (`ProfileView`): al desplazar, las filas
  pasan bajo la hora y la X, y lo eligió viéndolo. Los selectores del Welcome (`WelcomeFormScreen`) **no**: vio las
  dos y prefirió el ancho seguro, con el «‹» en la barra. Fuera de estas, la regla A sin excepciones: una pantalla
  nueva que la quiera saltar se pregunta.
- **El «‹» del Welcome es un botón de barra del sistema** (`welcomeBackButton`): en el iPhone es el círculo de cristal
  de toda la app y en el Duo cerrado pasa a la barra vertical. Las pantallas de formulario reservan el alto con la barra
  de navegación, no con un hueco fijo (`WelcomeFormLayout.topInset`). **Dentro del cover del Welcome la pila es UNA,
  montada por encima de los pasos (`welcomeNavigationHost()`), y un paso nunca abre la suya** (card feer, 2026-10-28):
  con una pila por pantalla, cambiar de paso quitaba una pila de UIKit y ponía otra, y la que salía desaparecía en un
  fotograma —sin fundirse— mientras la nueva, en el iPhone, crecía desde la esquina con negro alrededor. Fuera del host
  (`FullModeActivationView`, que intercala pantallas con pila propia) `welcomeBackButton` sigue montando la suya. Lo fija
  `WelcomeCoverContentLogicTests` (`noStepOfTheCoverOwnsAStack`).
- **`.navigationBarBackButtonHidden(_:)` por fuera manda sobre el `swipeBack()` de la pantalla de dentro.** Ajustes
  lo ponía en `false` para todas sus pantallas y las trece que pintan su propio «‹» enseñaban dos (en la barra vertical
  del Duo se veían uno encima del otro). `ProfileView.paintsOwnBackButton(_:)` dice cuáles; una pantalla de Ajustes
  nueva se añade ahí (el `switch` no tiene `default`).
- **En la barra vertical cabe poco, y lo que no cabe va al menú «···» solo si tiene título**: un botón de solo icono
  que desborda **desaparece**. Medido en el Panel abierto en horizontal (siete pestañas: cabe un botón y «···»):
  Filtros, que era un `Image`, se esfumó. ⇒ un botón que pueda desbordar lleva `Label(título, systemImage:)` (en una
  barra se ve solo el icono, como antes) y su prioridad: `.overflowsLast()` para lo que lleva contador o no puede ir al
  menú (una vista propia no tiene cómo pintarse ahí), `.overflowsFirst()` para el ajuste que menos se toca.
- **El pliegue es una región reservada `division` (iOS 27.1), y el sistema la da por INACTIVA en una vista que no la
  cruza de arriba abajo**: el contenido de un scroll la recibía inactiva casi siempre. ⇒ se mide en la raíz de la
  escena (`publishesVerticalFold()`, en `YalaApp.rootView`) y cada contenedor la traduce a su espacio con
  `.readsVerticalFold($fold)`. **Solo está activa a medio plegar**; abierto en plano, inactiva, y las columnas vuelven
  a mitades. Con el pliegue activo, `PairedColumnsLayout`, `HeaderBandLayout` y los pares del Panel
  (`foldAwarePairLayout`) ponen una columna a cada lado si las dos siguen midiendo 320, y `ListDetailSplit` separa
  lista y detalle sobre él (`DS.Adaptive.listColumnIdealWidth`). Un pliegue horizontal (abierto en vertical) no separa
  columnas: lo cruza el scroll.
- **El Duo abierto en vertical mide 669 pt: ancho regular, pero no caben dos columnas de iPhone.** Por eso la página con
  lista y detalle se pliega a la pila (`foldsListDetailWhenColumnsDontFit()`, arriba).
- **En el Duo cerrado (678 pt de alto, como un SE) una pantalla que reparte el alto con `Spacer` sin scroll se corta**:
  el titular del Welcome salía «Tus finanzas person…». `WelcomeFlowScreen` lleva el molde del scroll con alto mínimo.
- **Conducir el simulador del Duo**: `axe` lee el árbol pero sus toques no llegan (ni cerrado ni girado); XcodeBuildMCP
  igual. Lo que funciona es hacer clic en la pantalla del Duo dentro de Device Hub. Las posturas (cerrado, medio
  plegado, abierto, girar) son botones de Device Hub, sin `simctl`.

## Teclado, puntero, menús contextuales y soltar (2026-09-30)

- **Un atajo de teclado nuevo va en `YalaCommands` y su acción la publica la VENTANA** con `focusedSceneValue`
  (`RootCommandActions` desde `MainTabView`, `RecordCommandActions` desde `RecordsStandaloneView`). No lo cuelgues de
  un singleton: cada ventana del iPad manda sobre sí misma, los números de ⌘1…⌘6 siguen su barra lateral
  (`KeyboardCommandLogic.sectionTabs`) y fuera de la app montada los atajos salen desactivados solos.
- **Un atajo que ABRE algo pregunta primero `RootCommandPerformer.keyboardMayAct`** (sin `shellModalBlocker` y sin
  nada presentado EN ESA VENTANA según `ModalPresentationProbe.isAnythingPresented(in:)`). Un `.commands` dispara
  con una hoja encima, y encender otra presentación con el anchor ocupado es la trampa de las «Presentaciones» de
  arriba.
- **Reusa el camino del dedo**: ⌘N va por el router como el Centro de Control, ⌘⇧N por el FAB de grupos, ⌘K y ⌘,
  por el Panel (`SceneNavigation.pendingKeyboardPanelRequest`), soltar un recibo por `enqueueSharedImage` como la
  extensión de compartir. Así heredan las puertas Pro y de consentimiento sin copiarlas.
- **Un menú contextual nunca ofrece lo que el editor prohíbe** (`RecordContextActionLogic`). Y es más estricto que
  el editor cuando no puede medir lo mismo: el editor habilita Borrar en un registro de grupo huérfano tras un fetch
  al store de grupos; la fila no hace ese fetch, así que el menú no ofrece Borrar ni Duplicar en NINGÚN registro con
  puntero de grupo. En modo selección no hay menú.
- **Lo que un menú o un atajo presenta cuelga del host, no de la lista** (`RecordRowActionsPresenter` en
  `RecordsStandaloneView` y `DetailContainerView`): en el iPad la lista puede estar apartada (`.detailOnly`) y una
  confirmación anclada ahí no tendría dónde salir. Un solo anchor por observable.
- **Un atajo con la tecla de uno del SISTEMA (⌘Z, ⌘C, ⌘V…) no se suma a su grupo: lo sustituye, y solo mientras haga
  falta (medido el 2026-10-20, iOS 27.0, lote decidido 2.2 · 08).** `CommandGroup(after: .undoRedo) { Button(…)
  .keyboardShortcut("z") }` deja dos ⌘Z en el menú principal y, al reconstruirlo, UIKit **cierra la app** con
  `NSInvalidArgumentException: Replacement elements contain duplicates` — también en el iPhone, donde no hay menú a la
  vista: reventaba en cuanto salía el aviso de «Deshacer». Lo cazó un XCUITest, no el build. La salida:
  `if condición { CommandGroup(replacing: .undoRedo) { … } }` (el `if` vale en `Commands`), y fuera de la condición el
  grupo del sistema queda intacto con el deshacer de los campos de texto. Molde: `YalaCommands`, ⌘Z del borrado.
- **Resaltado del puntero = `.pointerHighlight(cornerRadius:)`** con el radio de la pieza (`nil` = cápsula): da la
  forma al resaltado y a la vista previa del menú contextual. En iPhone no hace nada.

## Varias ventanas (2026-10-02)

Desde la fase 4 del carril adaptativo el iPad (y el iPhone Duo abierto) abre varias ventanas de Yala, cada una con su
propia navegación. Lo que cualquier cambio nuevo tiene que respetar:

- **La navegación es de la ventana, no del proceso: `SceneNavigation`** (`Yala/App/Models/SceneNavigation.swift`), una
  por ventana, en el entorno (`@Environment(SceneNavigation.self)`). Pestaña, sub-pestañas, destinos pendientes
  (`pendingGroupID`, `pendingRecordID`…), peticiones de teclado y lo que tapa la ventana (`shellModalBlocker`,
  `isMainTabModalVisible`, `isInboxSheetVisible`). **Un estado de navegación nuevo va ahí, nunca a `SessionState`**:
  en `SessionState` cambiaría la pestaña de todas las ventanas a la vez, que es el bug que esto cerró. Filtros y
  período siguen globales a propósito. El código que no es una vista llega a la ventana que toca con
  `SceneRegistry.shared.routingNavigation` (la que está delante) o recorre `allNavigations` si el cambio es del
  teléfono (un borrado, la shell de solo grupos).
- **Un solo `ContentView` por proceso: el de la ventana LÍDER** (`SceneRegistry.leaderID`, la viva más antigua;
  `WindowRoleView`). Es el shell de proceso —arranque, Welcome, borrados remotos, cierre de sesión, alertas de
  sistema, consumidor `.contentView`— y dos copias duplicarían esos flujos. Las demás ventanas montan
  `FollowerWindowRoot`: sus pestañas y nada del shell. **Un flujo de proceso nuevo va en `ContentView`**, no en una
  vista que pueda montarse dos veces. Si la líder se cierra, asciende la siguiente y monta `ContentView` (splash
  incluido): el mismo camino que el remonte del swap.
- **Un bloqueo nuevo de la matriz del shell se clasifica también en `FollowerWindowGateLogic`**: si es una pregunta
  que hay que contestar en la líder antes de usar Yala, va a `attentionBlockers` (la seguidora enseña «Yala te espera
  en otra ventana» y un botón que trae la líder); si es arranque, a `startingBlockers`; si es una hoja de la líder,
  no se toca (la seguidora sigue operando). La seguidora **desmonta** su contenido en esos estados —tapar no basta:
  una hoja presentada queda por encima de cualquier capa—. Test: `YalaTests/MultiWindowRoutingTests`.
- **El router sella cada intent con su ventana al encolar** (`AppRouter.enqueue`): la que recibió el enlace
  (`WindowURLEntry`), la notificación (`targetScene`), la tecla o el recibo soltado, y si no, la que el usuario tocó
  la última (`WindowTouchObserver` en la sonda de `SceneRoot`, que no reconoce nada y no retrasa ningún toque; la
  notificación de ventana `key` sola no basta entre escenas). Un intent que un manejador encadena va a la ventana que
  lo drenó (`noteFocused` al principio de `handleMainTabIntent`/`handlePanelIntent`). **Un consumidor nuevo pasa SU ventana**: `markReady/markUnready/peekNext/drainNext(…, in:
  navigation.id)` —`.routerConsumer(_:)` ya lo hace—. `in: nil` drena todo y solo lo usan los unit tests del router.
  Un productor nuevo que no venga de un toque marca antes la ventana con `SceneRegistry.shared.noteFocused(_:)`.
  `.contentView` no se sella: va siempre a la líder, y si lo pidió el usuario desde otra ventana
  (`RouterIntent.bringsLeaderForward`), la trae al frente; un aviso de fondo no le quita la ventana a nadie.
- **El cierre de sesión para todas las ventanas menos la que lo lanzó** (`SceneRegistry.signOutDriverID`, del
  PROCESO: la que estaba al frente al entrar en `.working`, o la que lo pidió con `noteSignOutRequested()` si hay red
  por medio, como el borrado de cuenta), porque subir los pendientes exige que nadie escriba más. Si la que lo lanzó se
  cierra, las demás siguen paradas. La seguidora se desmonta; la líder no —cortaría su shell—: la tapa una `UIWindow`
  de nivel alto en su escena (`LeaderSignOutBusyOverlay`), que queda por encima también de sus hojas y se queda el
  teclado. Con una sola ventana que lo lanzó, nada cambia. Los covers terminales (cierre de sesión, forzado de
  actualización, swap de contenedor) salen en todas.
- **Lo que es una vez por proceso no cuelga de `ContentView`**: una ventana que asciende a líder monta otro. El
  arranque tiene guarda de reentrada (`AppBootstrapper.isBootstrapping`), los chequeos de usuario que vuelve corren una
  vez por contenedor (`SceneRegistry.claimBootChecks`) y los de volver a primer plano cuelgan del agregado del proceso
  (`SceneRegistry.appActivations`, contado en `YalaApp.handleScenePhase`, que cuelga de los DOS `WindowGroup` y
  descarta el aviso repetido), no del `scenePhase` de una vista, que es el de SU ventana.
- **Un flag de «tengo una hoja abierta» se baja también al desmontarse** (`MainTabView.onDisappear`,
  `InboxView.onDisappear`): con ventanas que pasan a esperar o ascienden, `onDismiss` no está garantizado, y un flag
  colgado retiene el router el resto de la sesión.
- **«Abrir en una ventana nueva» = `OpenInNewWindowButton(route:)`** (`WindowRoute.group` / `.record`), que solo
  aparece con `supportsMultipleWindows`. La ventana nueva es una Yala completa que ATERRIZA en el destino por el
  mismo camino que un enlace (sus puertas incluidas), no un detalle suelto. Una escena nueva (`WindowGroup` más)
  envuelve su contenido en `SceneRoot` y pasa por `YalaApp.rootView`, o se queda sin navegación, sin registro y con
  las hojas al tamaño del iPhone.
- **La multiventana vive en `Yala/Resources/Info.plist`** (`UIApplicationSupportsMultipleScenes = true` en el
  manifiesto escrito; el generado está apagado en las cuatro configuraciones). Se comprueba con
  `plutil -p <.app>/Info.plist | grep -A1 SupportsMultipleScenes`.
- **XCUITest con dos ventanas: «Apps en pantalla completa»** (`MultiWindowUITests`, iPad Pro 13 por UDID). Las dos se
  distinguen por `app.windows` (incluye la de detrás). Medido el 2026-10-02 en iOS 27.0: con «Apps en ventanas», abrir
  la segunda o arrastrar su barra tumba `backboardd` del simulador (SIGABRT en `MTLSimDevice newTextureWithDescriptor`;
  la app sale con SIGKILL sin culpa suya) en 3 de 4 corridas. Y el iPad RESTAURA las ventanas entre arranques:
  `-uitest-reset` descarta las restauradas (`SceneRegistry`, solo DEBUG).
