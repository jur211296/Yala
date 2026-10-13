# Mapa de flujos de Yala para la auditoría de UX de 2.2

Inventario de lo que una persona puede hacer en Yala, flujo a flujo, repartido en **20 lotes**. Cada lote es una
sesión de la fase 2. Es la fase 1 de la card `tablero-auditoria-de-ux-por-flujos-para-2-2-mapa-ogl6`.

**De dónde sale y cuánto fiarse.** Se sacó leyendo el código de la rama `2.2` en `e7e9feda8` (2026-10-13), desde
los puntos de entrada (`docs/entry-points.md`, la barra de pestañas, las hojas que abre cada pantalla). Nadie lo
recorrió en el simulador. Por eso:

- **Lo medido** es que cada vista, fichero y XCUITest citado existe. Los XCUITest se buscaron con `grep` en
  `YalaUITests/Flows/` y pueden cubrir solo una parte del flujo («parcial» lo dice cuando se vio).
- **Lo inferido** son las columnas «Pantallas» y las notas «Visto en el código». Una nota cita un texto o una línea
  que se leyó, pero no se comprobó en pantalla. **La sesión del lote la confirma o la descarta antes de actuar.**
- Las líneas no se citan: se mueven. Las vistas y funciones van por nombre.

Cuatro hallazgos se verificaron a mano y ya tienen ticket propio:
`deleting-an-account-asks-nothing` (lote 7), `cashflow-line-context-menu-deletes-without-asking` (lote 18),
`siri-settings-screen-lists-phrases-siri-does-not-know` (lote 15) y `settings-footer-shows-a-fixed-version-1-0-0`
(lote 16).

## Cómo se lee

- **Abreviaturas de ruta:** `V/` = `Yala/App/Views/` · `VM/` = `Yala/App/ViewModels/` · `L/` = `Yala/App/Logic/` ·
  `S/` = `Yala/App/Services/` · `YS/` = `Yala/Services/` · `SG/` = `Yala/Services/Groups/` · `CV` = `Yala/App/ContentView.swift` ·
  `PV` = `V/Profile/ProfileView.swift`.
- **XCUITest:** el fichero de `YalaUITests/Flows/` sin el sufijo `UITests`. «no» = ninguno lo toca.
- **Ajustes** es la hoja `ProfileView`. Se abre desde el avatar de la barra de cualquier pestaña, la tarjeta
  «Perfil» de Más, ⌘, en iPad y el banner de sincronización.
- **Barra de pestañas por defecto:** Panel, Estadísticas, Planificación, Más y la lupa de Buscar
  (`TabBarConfiguration.default`). Registros y Reportes viven en Más salvo que la persona los suba a la barra.
- **Un hueco que afecta a todos los lotes:** la tarjeta «Primeros pasos», los banners de guía y los tips sombreados se
  ocultan en todos los XCUITest (`UITestHooks.isActive`). Ningún test ve lo que ve una persona nueva.

## Orden recomendado

Primero lo que vive todo el mundo y lo de la primera vez; al final, lo que se toca poco o solo en casos raros.

| Lote | Qué cubre | Flujos | Por qué en este puesto | Card |
|---|---|---|---|---|
| 1 | Primera vez: bienvenida y onboarding personal | 13 | Lo vive el 100 % de las personas y decide si se quedan | `tablero-auditoria-ux-2-2-lote-1-primera-vez-bien-j3b2` |
| 2 | Apuntar un movimiento a mano | 12 | La acción más repetida de la app | `tablero-auditoria-ux-2-2-lote-2-apuntar-un-movim-likq` |
| 3 | El Panel: cómo voy | 12 | La pantalla que se abre cada día | `tablero-auditoria-ux-2-2-lote-3-el-panel-como-vo-znm3` |
| 4 | Apuntar con voz, con foto o compartiendo; la Bandeja | 9 | El atajo que más ahorra, y donde cae todo lo que llega de fuera | `tablero-auditoria-ux-2-2-lote-4-voz-foto-compart-frwk` |
| 5 | Primeros días: primeros pasos, guías y tips | 12 | Lo que acompaña la primera semana | `tablero-auditoria-ux-2-2-lote-5-primeros-dias-gu-k4gd` |
| 6 | Primera vez con datos previos o en la nube | 9 | Quien reinstala, cambia de iPhone o entra con su cuenta | `tablero-auditoria-ux-2-2-lote-6-primera-vez-con-z12j` |
| 7 | Cuentas, categorías, etiquetas, favoritos e importar | 16 | La estructura que todo lo demás usa | `tablero-auditoria-ux-2-2-lote-7-cuentas-categori-q0da` |
| 8 | Registros: ver, editar, buscar y filtrar | 15 | Corregir y encontrar lo apuntado | `tablero-auditoria-ux-2-2-lote-8-registros-ver-ed-o9xi` |
| 9 | Presupuestos | 12 | La herramienta de control más conocida | `tablero-auditoria-ux-2-2-lote-9-presupuestos-wccd` |
| 10 | Pagos planificados | 11 | Suscripciones y pagos fijos | `tablero-auditoria-ux-2-2-lote-10-pagos-planifica-77ys` |
| 11 | Estadísticas | 11 | Entender en qué se va el dinero | `tablero-auditoria-ux-2-2-lote-11-estadisticas-5g4x` |
| 12 | Grupos I: entrar, crear, invitar y unirse | 15 | La puerta de entrada de muchos usuarios nuevos | `tablero-auditoria-ux-2-2-lote-12-grupos-i-entrar-r7ji` |
| 13 | Grupos II: gastos y saldar cuentas | 10 | El uso diario de un grupo | `tablero-auditoria-ux-2-2-lote-13-grupos-ii-gasto-xgs3` |
| 14 | Yala IA | 11 | Función Pro con mucho texto y consentimientos | `tablero-auditoria-ux-2-2-lote-14-yala-ia-l0ze` |
| 15 | Desde fuera de la app | 13 | Widgets, Siri, Centro de Control, notificaciones, iPad | `tablero-auditoria-ux-2-2-lote-15-desde-fuera-de-u8ko` |
| 16 | Ajustes: perfil y preferencias | 22 | Muchas pantallas pequeñas y poco visitadas | `tablero-auditoria-ux-2-2-lote-16-ajustes-perfil-qwh7` |
| 17 | Yala Pro | 7 | Se ve en momentos clave, pero no es un flujo diario | `tablero-auditoria-ux-2-2-lote-17-yala-pro-713o` |
| 18 | Reportes: Comparativa y Flujo de caja | 11 | Escondidos en Más; el vocabulario más técnico de la app | `tablero-auditoria-ux-2-2-lote-18-reportes-compar-dgfm` |
| 19 | Grupos III: administrar, salir y modos | 15 | Lo que hace el dueño de un grupo, de vez en cuando | `tablero-auditoria-ux-2-2-lote-19-grupos-iii-admi-3kay` |
| 20 | Tus datos: exportar, vaciar, cerrar sesión, nube y avisos del sistema | 17 | Raro y delicado: se toca poco y cada paso puede borrar algo | `tablero-auditoria-ux-2-2-lote-20-tus-datos-expor-0hqg` |

Son **253 flujos**. Los lotes de más de 15 (7, 16 y 20) tienen muchas pantallas de un solo paso; si uno no cabe en
una sesión, se parte por la mitad de su tabla y la segunda mitad abre card nueva.

---

## Lote 1 · Primera vez: bienvenida y onboarding personal

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 1.1 | Abrir la app (pantalla de carga) | Cada arranque en frío | `SplashScreenView` (mín. 2,5 s) → bienvenida u `MainTabView` | `V/SplashScreenView.swift`, `CV` | no (`LaunchSlice` mira el arranque con datos) |
| 1.2 | Elegir idioma cuando el del iPhone no está soportado | Automática, antes de la bienvenida | `LanguageSelectionView` → bienvenida | `V/Onboarding/LanguageSelectionView.swift`, `CV` | no |
| 1.3 | Ver la presentación y tocar «Empezar» | Primera instalación | `WelcomeHeroView` (tarjetas que rotan) → `WelcomeChooserView` | `V/Onboarding/WelcomeFlowContainer.swift`, `WelcomeHeroView.swift`, `WelcomeChooserView.swift` | `WelcomeChooser` |
| 1.4 | Volver del selector a la presentación | «Volver» en el selector | `WelcomeBackButton` → `WelcomeHeroView` | `V/Onboarding/WelcomeBackButton.swift` | no |
| 1.5 | «Es mi primera vez», con los datos en mi iCloud privado | Selector › «Es mi primera vez en Yala» | `WelcomeNewChooserView` → `WelcomePrivateICloudGateView` («Revisando qué hay en tu iCloud…») → `OnboardingView` | `V/Onboarding/WelcomeNewChooserView.swift`, `WelcomePrivateICloudGateView.swift` | `PrivateGateDeviceUnreadable`, `WelcomeLateNoticeKeptGroups` |
| 1.6 | Reabrir Yala a mitad de la bienvenida | El destino elegido necesita la copia de iCloud y este arranque no la cargó | `WelcomeMirrorRelaunchView` («Un último paso: reabre Yala») | `V/Onboarding/WelcomeMirrorRelaunchView.swift` | no |
| 1.7 | Ya tenía datos en iCloud: traerlos o empezar de cero | Puerta de iCloud con datos | `WelcomePrivateICloudGateView` → «Traer mis datos» (lote 6) / «Empezar de cero» con segunda confirmación | `V/Onboarding/WelcomePrivateICloudGateView.swift` | `PrivateGateDeviceUnreadable` |
| 1.8 | Empezar de cero con datos en el teléfono | Camino privado con datos locales | Alerta «Detectamos datos previos…» → «Borrar todo y continuar» | `CV` (`startFreshPrivateOnboarding`) | `WelcomeFreshStartAlert` |
| 1.9 | Hacer el onboarding completo | Tras 1.5, 1.8 o el alta en la nube | `OnboardingView`, 8 pasos: nombre · propósito · organización · tipo de cuenta · nombre y divisa · saldo (con `BalanceCalculatorSheet`) · categorías · «Así queda tu Yala» | `V/Onboarding/OnboardingView.swift`, `OnboardingFlowScreen.swift`, `L/OnboardingStepPlan.swift` | `OnboardingFlow` (solo el paso 1), `OnboardingPurposeStep` |
| 1.10 | Hacer el onboarding «solo gastos» | Paso 2 › «Solo anotar mis gastos» | Se saltan organización, tipo de cuenta y saldo | `L/OnboardingStepPlan.swift` (`skippedSteps`) | `OnboardingPurposeStep` |
| 1.11 | Volver un paso atrás o cerrar el onboarding | Chevron «Atrás» (pasos 2-8) · X del paso 1 | La X del paso 1 lleva a la presentación, no al selector | `V/Onboarding/OnboardingView.swift` (`goBack`) | no |
| 1.12 | Recibir la oferta de prueba Pro al terminar | 0,8 s tras cerrar el onboarding, solo en un alta y sin Pro | `ProTrialOfferSheet` | `V/Subscription/ProTrialOfferSheet.swift`, `L/EntryOnboardingEffects.swift` | parcial (`PaywallInboxAlertRouting`, solo el enrutado) |
| 1.13 | Que me obliguen a actualizar la app | `min-version` remoto (hoy apagado) | `ForceUpdateView` («Actualiza para continuar») | `V/Shared/ForceUpdateView.swift`, `S/ForceUpdateGate.swift` | no |

**Visto en el código (por confirmar en pantalla):**
- 2,5 s fijos de logo en cada arranque en frío, también para quien ya usa la app.
- `LanguageSelectionView` reparte el alto con `Spacer()` sin `ScrollView`: el patrón que la regla de UI marca como «no
  cabe en un iPhone SE».
- A una persona nueva se le pide elegir dónde viven sus datos antes de ver la app, con un texto largo
  (`welcome.new.privateBody`: «Tus datos viven en los dispositivos Apple de tu Apple ID…»).
- 1.6 pide salir a mano: «Ve a la pantalla de inicio y vuelve a entrar».
- 1.7 y 1.8 ponen un borrado irreversible en el primer minuto de uso.
- Onboarding: jerga y párrafos largos en cuentas («Una cuenta representa donde guardas tu dinero. Cada cuenta tiene
  una sola divisa.»), saldo («Tu saldo inicial le dice a Yala con cuánto dinero arrancas…») y la calculadora
  («Línea de crédito», «Disponible»).
- 1.12 es un paywall nada más acabar 8 pasos y antes de ver la app.

**Tickets abiertos del lote:** `qa/onboarding-login-should-match-the-sep15-reference`,
`welcome-cancel-during-the-identity-step-does-not-return-to-the-chooser`, `welcome-cloud-back-leaves-chooser-marked-seen`,
`private-icloud-gate-back-lands-on-the-wrong-branch`, `welcome-destructive-buttons-are-plain-text-taps`,
`start-fresh-dialog-promises-what-the-gate-undoes`, `welcome-discard-gate-says-carry-on-right-after-asking-to-wipe`,
`groups-only-sign-up-drops-a-language-chosen-just-before-it`.

---

## Lote 2 · Apuntar un movimiento a mano

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 2.1 | Apuntar un gasto | Píldora «Nuevo registro» del Panel · FAB «+» › Manual (Panel, Registros, Estadísticas) · ⌘N · widget o Siri `yala://new-transaction` | `NewTransactionView` → `TransactionSuccessView` («Aceptar» / «Registrar otro» / «Editar») | `V/Transactions/NewTransactionView.swift`, `VM/NewTransactionViewModel.swift`, `V/Transactions/TransactionSuccessView.swift`, `V/Shared/FABStackView.swift` | `TransactionsCrud` |
| 2.2 | Apuntar un ingreso | Selector de tipo del formulario | `TransactionTypeSelectorView` | `V/Transactions/Components/TransactionTypeSelectorView.swift` | parcial (`IncomeExpenseClassification`) |
| 2.3 | Pasar dinero entre mis cuentas | Tipo «Transferencia» | Chips Origen/Destino → `AccountSelectorSheet` → `TransferAmountInputView` (pide tipo de cambio si las divisas difieren) | `V/Transactions/Components/TransferAmountInputView.swift`, `AccountSelectorSheet.swift` | no |
| 2.4 | Cambiar la fecha | Chip de fecha | `DatePickerSheet`; alerta si la fecha es futura | `V/Transactions/Components/DatePickerSheet.swift` | no |
| 2.5 | Escribir la nota con atajos (@ cuenta, ! categoría, # etiqueta) | Campo de descripción | Popover de autocompletado | `NewTransactionView.swift`, `DescriptionAutocomplete.swift` | no |
| 2.6 | Elegir categoría y necesidad | Chips de subcategoría y de necesidad | `SubcategorySelectorSheet`, `NeedSelectorSheet` | `SubcategorySelectorSheet.swift`, `V/Transactions/Components/NeedSelectorSheet.swift` | `TransactionsCrud` |
| 2.7 | Poner etiquetas (y crear una nueva) | Chip de etiquetas | `TagSelectorSheet` → `TagFormView` | `TagSelectorSheet.swift`, `V/Tags/TagFormView.swift` | `TransactionsCrud` |
| 2.8 | Apuntar en otra divisa | Elegir una cuenta en esa divisa | `AccountSelectorSheet` → chip «≈ S/ x (TC: y)» | `NewTransactionView.swift` | no |
| 2.9 | Calcular mi parte de un gasto | Botón «Calcular» (solo gastos) | `SplitCalculatorSheet` → «Usar monto» | `V/Shared/SplitCalculatorSheet.swift`, `L/Calculators/SplitCalculator.swift` | `SplitCalculator` |
| 2.10 | Guardar un movimiento como favorito | Botón «Favorito» del formulario | `SaveAsFavoriteSheet` | `SaveAsFavoriteSheet.swift`, `VM/SaveAsFavoriteViewModel.swift` | `QuickActionsFavorites` |
| 2.11 | Usar un favorito | ★ en la barra del formulario | `FavoritesListView(.select)` → formulario relleno | `V/Favorites/FavoritesListView.swift` | no |
| 2.12 | Convertir el movimiento en recurrente | Botón «Recurrente» (exige el formulario completo) | Editor de pago planificado | `NewTransactionView.swift` (`recurringSheetContent`) | no |

**Visto en el código:**
- El «+» del Panel abre el formulario; el «+» flotante abre un menú Grupo/Voz/Imagen/Manual. Dos «+» con conducta distinta.
- No hay cuenta por defecto: solo se rellena sola si el Panel está filtrado por una cuenta.
- Cambiar de tipo borra la subcategoría elegida sin avisar.
- No hay selector de divisa en el formulario: la decide la cuenta. «TC:» no se explica.
- En transferencias no funcionan los atajos @ ! # ni «Calcular».
- «Usa @ cuenta, ! categoría, # etiqueta» es jerga para quien nunca apuntó gastos.
- No se puede crear una categoría desde el formulario.
- ☆ guarda un favorito y ★ usa uno: el mismo icono para acciones opuestas.
- La alerta de fecha futura manda a «Pagos Planificados» con mayúsculas.

**Tickets abiertos del lote:** `small-screen-leftovers-after-the-iphone-se-audit`,
`merchant-memory-suggests-across-natures-in-three-more-places`, `save-as-favorite-from-a-mismatched-row-relabels-it`,
`scheduled-payment-once-labeled-monthly`, `tag-chips-change-order-on-every-launch`.
**Cards de 2.2 que lo cambian:** «Tarjeta con varias divisas, entrega 3» (la divisa del importe decide la línea) y
«Pagos en cuotas».

---

## Lote 3 · El Panel: cómo voy

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 3.1 | Ver cómo voy este mes | Pestaña Panel | `PanelShell` → `PanelView` (hero, acciones rápidas, avisos, «Tus finanzas», widgets) | `V/Panel/PanelView.swift`, `V/Panel/Sections/PanelHeroSection.swift`, `HeroMonthView.swift`, `VM/PanelViewModel.swift` | `PanelDashboard` |
| 3.2 | Ver solo ingresos o solo gastos | Píldoras ↑/↓ del hero | Cambia el filtro de naturaleza global | `V/Panel/HeroMonthView.swift` | no |
| 3.3 | Cambiar el período, también uno a medida | Píldora de período | `TrendsPeriodMenu` → `CustomPeriodPickerSheet` | `PanelSheetsModifier.swift`, `V/Filters/PeriodSelectorLabel.swift` | no |
| 3.4 | Filtrar el Panel | Icono de filtro de la barra | `RecordsFiltersView` | `V/Records/RecordsFiltersView.swift` | `PanelAccounts` |
| 3.5 | Ordenar u ocultar secciones | Icono de cuadrícula; preferencias de sección | `PanelSectionsConfigView`, `PanelSectionPreferencesSheet` | `V/Panel/PanelSectionsConfigView.swift` | `PanelDashboard` |
| 3.6 | Entender un widget del Panel («?») | Botón ⓘ de la cabecera de un widget (con «Textos de ayuda» activo) | `WidgetInfoSheet` | `V/Panel/InfoSheets/WidgetInfoButton.swift`, `WidgetInfoSheet.swift` | parcial (`SharedImageEntry`) |
| 3.7 | Leer los avisos del Panel | Pila sobre «Tus finanzas» | Prueba, Pro, actualización (con «Actualizar» / «Ahora no»), nudge de grupos, tip de Siri, attest, guía | `V/Panel/PanelView.swift` | `UpdateAvailableBanner`, `CloudAttestPanelBanner`, `ProConversionUpsells` |
| 3.8 | Ver una cuenta desde el Panel | Tocar una tarjeta del carrusel | `AccountDetailSheet` → «Editar» / «Filtrar por esta cuenta» | `V/Panel/AccountsCarouselView.swift`, `V/Panel/Sheets/AccountDetailSheet.swift` | `PanelAccounts` |
| 3.9 | Filtrar o editar una cuenta con pulsación larga | Menú contextual de la tarjeta | Filtrar / `AccountFormView` | `V/Panel/AccountsCarouselView.swift` | no |
| 3.10 | Crear una cuenta desde el Panel | Tarjeta «+» del carrusel · estado vacío «Aún no tienes cuentas» | `AccountFormView` o `UpgradePromptSheet(.accounts)` al límite | `V/Panel/PanelAccountsSection.swift` | no |
| 3.11 | Ver los últimos registros | Widget «Últimos registros» | `RecentRecordsWidget`; el pie lleva a Registros | `V/Panel/RecentRecordsWidget.swift`, `V/Panel/Sections/PanelThematicSection.swift` | no |
| 3.12 | Abrir las hojas de detalle del Panel (saldo de hoy, ganancia cambiaria, salud financiera) | Píldora «Hoy ⓘ» y tarjetas | `BalanceLiveAnchorEducationSheet`, `FXPnLDetailSheet`, `FinancialScoreDetailSheet` | `V/Panel/` | no (sin confirmar el disparador) |

**Visto en el código:**
- Tocar cualquier punto del hero lleva a Estadísticas › Resumen sin ninguna pista visual.
- El filtro ↑/↓ es global: sigue puesto en Estadísticas y Registros.
- Pueden apilarse hasta seis avisos antes de llegar a las cuentas.
- Sin cuenta, la fila de acciones sale atenuada sin decir por qué.
- Las filas de «Últimos registros» no se pueden tocar, y el callback de «ver más» se pasa pero no se usa.
- El icono de la Bandeja no lleva texto.

**Tickets abiertos del lote:** `panel-balance-chart-contradicts-its-own-figure`,
`hoja-del-saldo-vivo-ignora-los-filtros-de-sesion`, `records-standalone-amount-discrepancy`,
`panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo`, `partial-sheets-that-never-adapted-to-the-window`,
`accounts-need-more-visibility-in-the-ui`.
**Cards de 2.2 que lo cambian:** «El hero de cada vista: que el usuario elija qué muestra», «Las cuentas se ven
poco», «Tarjeta con varias divisas, entrega 2», «Seguimiento de ahorros con metas», «Seguimiento de deudas personales».
Revisa este lote **antes** de que salgan, para que sus propuestas partan de un Panel ya limpio.

---

## Lote 4 · Apuntar con voz, con foto o compartiendo; la Bandeja

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 4.1 | Apuntar un gasto dictándolo | Píldora de onda del Panel · FAB › Voz · `yala://voice-entry` · Centro de Control · primeros pasos | Puerta Pro → consentimiento de IA → `VoiceRecordingView` (escuchando → procesando → «Esto entendí» con `VoiceDraftReviewCard`) → `InboxDraftEditSheet` → Guardar / «Volver a grabar» / «Probar con imagen» | `V/Voice/VoiceRecordingView.swift`, `VoiceDraftReviewCard.swift`, `YS/VoiceTranscriptionService.swift` | `VoiceEntryReview`, `VoiceInputCurrencyExamples`, `VoiceImageSettingsFab` |
| 4.2 | Apuntar con una foto, un recibo o un PDF | Píldora de foto · FAB › Imagen · `yala://image-entry` · Centro de Control | `ImageSelectionView`: Cámara / Fotos (hasta 10) / Archivo (con contraseña si el PDF la tiene) → leyendo → revisión → `InboxDraftEditSheet` | `V/Image/ImageSelectionView.swift`, `S/ImageOCR/`, `S/ImageVision/` | `ImageEntryReview` |
| 4.3 | Mandar capturas a Yala desde otra app | Hoja de compartir › Yala | `YalaShare` guarda hasta 10 → `yala://shared-image` → Panel → Pro y consentimiento → `ImageSelectionView` leyendo la tanda | `YalaShare/ShareViewController.swift`, `docs/entry-points.md` | `SharedImageEntry` |
| 4.4 | Soltar un recibo en el iPad | Arrastrar sobre la ventana | Panel → `ImageSelectionView`, o `UpgradePromptSheet(.image)` | `Yala/App/Commands/RootCommandsModifier.swift` (`ReceiptDropHandler`) | `ReceiptDrop` |
| 4.5 | Revisar lo pendiente en la Bandeja | Icono de bandeja del Panel · aviso al abrir (`InboxAlertModal`) · notificación | `InboxView` (pendientes y archivados) → `InboxDraftEditSheet` → Aprobar → `InboxApproveSuccessView` | `V/Inbox/InboxView.swift`, `InboxDraftEditSheet.swift`, `VM/InboxViewModel.swift` | `InboxCrud`, `InboxNewItemsModal` |
| 4.6 | Aprobar, rechazar o eliminar deslizando | Deslizar a la derecha (aprobar) o a la izquierda (eliminar / rechazar) | Filas de `InboxView` | `V/Inbox/InboxView.swift` | parcial (`InboxCrud`, aprobar) |
| 4.7 | Aprobar varios a la vez | «Aprobar todo» · Seleccionar | `InboxBulkActionsSheet` → `InboxBulkApproveSuccessView` | `V/Inbox/InboxBulkActionsSheet.swift` | no |
| 4.8 | Aprobar un pago planificado que venció | Automático al arrancar: borrador en la Bandeja | `InboxView` | `Yala/App/AppBootstrapper.swift` (`processDueScheduledPayments`) | no |
| 4.9 | Recuperar un borrador rechazado o archivado | Sección de archivados de la Bandeja | `InboxView` | `V/Inbox/InboxView.swift` | no (sin confirmar) |

**Visto en el código:**
- La píldora de voz es solo un icono.
- «Si cierras sin guardar, lo encontrarás en tu Bandeja de Entrada.»: bien, pero «Bandeja de Entrada» no se presentó antes.
- `YalaShare` solo acepta imágenes (`UTType.image`), no PDF. Si falla, se cancela sin mensaje.
- El estado vacío de la Bandeja dice «…borradores de voz e imagen aparecerán aquí» y olvida Apple Pay, Siri y compartir.
- Deslizar del todo a la izquierda elimina para siempre sin confirmar (dentro de la hoja sí pregunta). «Rechazar» y
  «Eliminar» se distinguen mal.

**Tickets abiertos del lote:** `qa/voice-entry-end-to-end`, `qa/image-entry-end-to-end-redesign`,
`qa/sharing-several-photos-hides-yala`, `qa/share-image-reading-does-not-always-start`,
`qa/inbox-dismiss-x-does-not-delete-the-draft-for-good`, `inbox-header-leaves-no-room-for-drafts-at-large-text`,
`declining-ai-consent-keeps-a-dropped-or-shared-photo-pending`, `qa/pdf-statement-reads-only-the-first-page`.
**Cards de 2.2 que lo cambian:** «Registrar movimientos desde correos de alertas del banco», «Registrar movimientos
desde la notificación del banco» (las dos caen en la Bandeja), «Partir la IA según modo nube o privado».

---

## Lote 5 · Primeros días: primeros pasos, guías y tips

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 5.1 | Seguir los «Primeros pasos» del Panel | Tarjeta del Panel, solo en altas | `SetupChecklistCard`, 7 pasos en orden: Ajustes · primer gasto · primer presupuesto · pago que se repite · voz · foto (imágenes de ejemplo) · «Descubre qué más puede hacer Yala» (paywall); «Minimizar» / «Ahora no» | `V/Panel/SetupChecklistCard.swift`, `Yala/App/Models/SetupStep.swift`, `SetupChecklistManager.swift`, `PanelView.swift` (`handleSetupStep`) | no (oculta en UITest) |
| 5.2 | Decidir si el primer gasto era de prueba | Primer registro guardado desde un paso de práctica | Éxito → alerta «¡Listo! Creaste tu primer gasto» → «Conservar» / «Era de prueba» | `V/Panel/SetupStepRow.swift`, `NewTransactionView.swift` | `FirstExpensePracticeAlert` |
| 5.3 | Leer el banner de guía de una pantalla nueva | Primera visita a ~18 pantallas | `ContextualGuideBanner` («Este es tu resumen»), se cierra y se recuerda | `V/Shared/ContextualGuideBanner.swift` | no (oculto en UITest) |
| 5.4 | Recorrer la guía sombreada de Ajustes | Primera vez que se abre Ajustes | `CoachMarkOverlay`, 9 pasos (Cuentas … Tutoriales) con «Omitir guía», «n/9», «Siguiente» / «Listo» | `Yala/App/Tips/CoachMarkOverlay.swift`, `YalaTips.swift`, `PV` | no (suprimida en UITest) |
| 5.5 | Saltarse un tip sombreado | «Omitir guía» | Cierra y da la guía por vista | `Yala/App/Tips/CoachMarkOverlay.swift`, `ProTourManager.swift` | no |
| 5.6 | Recorrer el tour Pro tras suscribirse | Al cerrar el éxito de la suscripción | `CoachMarkOverlay` en tres fases: Perfil · Panel · Estadísticas › Resumen | `Yala/App/Tips/ProTourManager.swift` | no |
| 5.7 | Ver los globos de TipKit | Selector de comparación de Estadísticas · chip de IA de las gráficas del flujo de caja | `ComparisonTip`, `AIChartsProTip`, `AIChartsFreeUpsellTip` | `Yala/App/Tips/YalaTips.swift` | no |
| 5.8 | Recorrer las guías del flujo de caja | Primera vez en el plan y en la tabla | `CoachMarkOverlay` (`CashFlowSetupTourSteps`, `CashFlowTableTourSteps`) | `Yala/App/Tips/YalaTips.swift` | no (disparador sin confirmar) |
| 5.9 | Aceptar las notificaciones tras el tercer registro | Éxito del tercer registro, con el permiso sin decidir | `NotificationPrimerSheet` → diálogo del sistema / «Ahora no» | `V/Notifications/NotificationPrimerSheet.swift` | no |
| 5.10 | Celebrar un hito de registros (10, 50, 100) | Free, al guardar ese registro | `MilestoneUpgradeSheet` | `V/Shared/MilestoneUpgradeSheet.swift`, `S/ProUpsellService.swift` | no |
| 5.11 | Que me pidan una reseña | ≥15 registros, ≥7 días, cada 120 días | `requestReview` del sistema | `S/ReviewPromptService.swift` | no |
| 5.12 | Ver las Novedades de una versión | Primer arranque tras actualizar | `WhatsNewSheet` → «Continuar» | `V/WhatsNew/WhatsNewSheet.swift`, `WhatsNewConfig.swift` | no |

**Visto en el código:**
- El último paso de «Primeros pasos» es un paywall y se marca hecho aunque se cierre sin comprar.
- Tocar la zona oscura de un tip **avanza** al siguiente paso en vez de cerrar. Son 9 pasos seguidos.
- El onboarding crea recordatorios por defecto sin pedir permiso al sistema; el permiso llega en el tercer registro, y
  cerrar esa hoja cierra también el formulario.
- `WhatsNewConfig` solo tiene 1.1, 1.2 y 2.0: con la app en 2.1 las Novedades no salen nunca. Tampoco se pueden
  reabrir desde Ajustes.
- No se pide ningún permiso del sistema durante el onboarding.

**Tickets abiertos del lote:** `small-screen-leftovers-after-the-iphone-se-audit`, `qa/step-flows-should-match-the-sep15-reference`.

---

## Lote 6 · Primera vez con datos previos o en la nube

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 6.1 | Recuperar mis datos de iCloud al instalar | Selector › «Ya tengo una cuenta» › «Restaurar desde iCloud» · «Traer mis datos» (1.7) | `WelcomeExistingChooserView` («¡Hola de nuevo!») → `WelcomeRestoreView` (buscando → encontrados / no / incompleto / pausado / desactivado / error) → `RestoreProgressView` → app u onboarding precargado | `V/Onboarding/WelcomeRestoreView.swift`, `RestoreProgressView.swift`, `WelcomeExistingChooserView.swift` | no |
| 6.2 | Entrar con mi cuenta de Yala (Apple o Google) | «Ya tengo una cuenta» › «Entrar con Apple/Google» | `WelcomeCloudSignInView` → `CloudConsentView` → «Conectando con tu cuenta…» → app; salidas de error (no hay cuenta, datos de otra cuenta, cuenta preparándose) | `V/Onboarding/WelcomeCloudSignInView.swift` | `WelcomeChooser` |
| 6.3 | Crear una cuenta nueva en la nube | «Es mi primera vez» › «Tu cuenta en la nube» | `WelcomeNewChooserView` → `WelcomeCloudSignInView` (alta) → `CloudConsentView` → `OnboardingView` | `V/Onboarding/WelcomeCloudSignInView.swift`, `V/Settings/CloudConsentView.swift` | `WelcomeChooser` |
| 6.4 | Que Yala me recuerde que este Apple ID ya tenía cuenta | «Es mi primera vez» con la marca de cuenta previa | `WelcomeCloudSignInView` («Con este Apple ID ya se creó una cuenta…») → «Crear otra cuenta» | `V/Onboarding/WelcomeFlowContainer.swift` (`handleNewBranch`) | `WelcomeChooser` |
| 6.5 | Ver que terminé el onboarding en otro aparato | Señal de iCloud con el onboarding abierto | Se cierra el onboarding y sale un toast | `CV` (`handleRemoteOnboardingCompleted`) | no |
| 6.6 | Aviso tardío «Encontramos datos tuyos en iCloud» | ~5 s tras arrancar | `LateICloudMirrorNoticeView` («Se van a mezclar…») → «Déjalo así» / empezar de cero → confirmación → borrando → error | `V/Shared/LateICloudMirrorNoticeView.swift` | parcial (`WelcomeLateNoticeKeptGroups`) |
| 6.7 | Pasar de solo grupos a «Yala completo» | Más · Perfil · nudges · detalle de grupo · widget `yala://activate-full` · se retoma al arrancar | `FullModeActivationView` (dónde guardar → puerta de iCloud o consentimiento → onboarding temático o restaurar) → `FullModeActivationFinaleView` («¿Traemos tus gastos de grupo?») | `V/Groups/FullModeActivationView.swift`, `FullModeActivationFinaleView.swift`, `CV` | `FullModeActivationChooser` |
| 6.8 | Aceptar el consentimiento de la nube | Alta, entrada o activación en la nube | `CloudConsentView` | `V/Settings/CloudConsentView.swift` | parcial (`WelcomeChooser`) |
| 6.9 | Reabrir Yala tras restaurar o entrar | Fin de los flujos 6.1-6.3 cuando hace falta | `WelcomeMirrorRelaunchView` / pantalla de relanzar | `V/Onboarding/WelcomeMirrorRelaunchView.swift` | no |

**Visto en el código:**
- 6.1 no tiene ningún XCUITest.
- «Esto creará una cuenta nueva sin tus datos previos. ¿Continuar?»: según su ticket, ni crea una cuenta ni es cierto
  en dos estados.
- «Nuestro equipo puede verlos para darte soporte…»: honesto, pero es una decisión de privacidad antes de usar la app.
- «Esto puede tardar unos minutos. Mantén Yala abierta.»

**Tickets abiertos del lote:** `restore-found-copy-says-icloud-for-groups-that-never-were`,
`restore-error-state-is-never-reached`, `restore-prefill-skips-currency-for-an-empty-summary`,
`welcome-adopt-exit-offers-retry-on-a-blocked-account`, `welcome-shows-a-takeover-exit-as-a-connection-error`,
`born-cloud-signup-into-existing-account-relaunch-says-nothing`, `qa/full-mode-activation-must-ask-where-personal-data-lives`,
`activation-discard-loses-the-group-history-question`, `late-icloud-sheet-buttons-may-leave-the-screen-at-large-dynamic-type`.

---

## Lote 7 · Cuentas, categorías, etiquetas, favoritos e importar

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 7.1 | Crear una cuenta desde Ajustes | Ajustes › Cuentas › + | `AccountFormView` (tipo, divisa, saldo inicial, color, tarjeta de crédito) → alerta «Divisa secundaria» si es otra divisa | `V/Accounts/AccountFormView.swift`, `VM/Accounts/AccountFormViewModel.swift`, `V/Settings/AccountsSettingsListView.swift` | `AccountsCrud`, `SecondaryCurrencyPrompt` |
| 7.2 | Editar una cuenta | Ajustes › Cuentas › fila · Panel › tarjeta › Editar | `AccountFormView` en edición | `V/Accounts/AccountFormView.swift` | `AccountsCrud` |
| 7.3 | Archivar una cuenta o sacarla del total | Interruptores del formulario | Aviso en línea | `V/Accounts/AccountFormView.swift` | `AccountsCrud` |
| 7.4 | **Eliminar una cuenta** | «Eliminar cuenta», al fondo del formulario en edición | Ninguna confirmación: borra y cierra | `V/Accounts/AccountFormView.swift` (`handleDeleteTapped`), `Yala/Services/EntityDeletionService.swift` | no |
| 7.5 | Cambiar la divisa de una cuenta | Fila Divisa del formulario | Selector → alerta «¿Cambiar la divisa a X?» con N registros, o bloqueo → progreso | `YS/CurrencyChangeService.swift`, `L/AccountCurrencyChangeLogic.swift` | no |
| 7.6 | Ajustar el saldo de una cuenta | Formulario › ajuste / calculadora | `AdjustmentModeSelectorView`, calculadora de saldo | `V/Accounts/` | no (sin confirmar el recorrido) |
| 7.7 | Reordenar mis cuentas | Ajustes › Cuentas (arrastrar) | Se refleja en el carrusel | `V/Settings/AccountsSettingsListView.swift` | no |
| 7.8 | Crear una categoría con subcategorías | Ajustes › Categorías › + | `CategoryDetailView` → `SubcategoryDetailView` | `V/Categories/CategoryDetailView.swift`, `SubcategoryDetailView.swift`, `V/Settings/CategoriesSettingsListView.swift` | `CategoriesCrud` |
| 7.9 | Borrar una categoría | `CategoryDetailView` › Eliminar | Diálogo «Se eliminarán la categoría y todas sus subcategorías…» | `V/Categories/CategoryDetailView.swift` | no |
| 7.10 | Borrar una subcategoría con registros | `SubcategoryDetailView` › Eliminar | `SubcategoryTransferSheet` (mover a otra o borrar registros) | `V/Categories/SubcategoryTransferSheet.swift`, `VM/SubcategoryTransferViewModel.swift` | no |
| 7.11 | Ocultar una categoría | `CategoryDetailView` | Alerta «Categoría oculta» | `V/Categories/CategoryDetailView.swift` | no (disparador sin confirmar) |
| 7.12 | Crear, editar o borrar una etiqueta | Ajustes › Etiquetas · `TagSelectorSheet` | `TagsSettingsListView` → `TagFormView` → «¿Eliminar etiqueta?»; reordenar | `V/Settings/TagsSettingsListView.swift`, `V/Tags/TagFormView.swift` | parcial (`TagsCrud`, solo crear) |
| 7.13 | Gestionar favoritos | Ajustes › Favoritos | `FavoritesListView(.manage)` → `FavoriteEditorView`; borrar y reordenar | `V/Favorites/`, `VM/FavoritesListViewModel.swift` | `FavoritesCrud` |
| 7.14 | Añadir una segunda divisa | Ajustes › Divisa · alerta al crear una cuenta en otra divisa | `CurrencySettingsView` → `SecondaryCurrencyPickerSheet` | `V/Settings/CurrencySettingsView.swift`, `SecondaryCurrencyPickerSheet.swift` | `CurrencySettings`, `CurrencyPicker` |
| 7.15 | Importar un CSV o Excel | Ajustes › Datos › «Importar archivo» | `ImportIntroSheet` (plantilla) → selector de archivo → `ImportAccountPickerSheet` / `ImportCurrencyMappingSheet` → alerta de resultado | `V/Import/`, `VM/ImportIntroViewModel.swift` | no |
| 7.16 | Elegir la cuenta por defecto | **No existe** | — | `NewTransactionView.swift` | — |

**Visto en el código:**
- 7.4 está **verificado**: borra al primer toque y sus registros quedan sin cuenta. Ticket
  `deleting-an-account-asks-nothing`.
- 7.9 no dice que los registros de la categoría se quedan sin categoría (el propio código lo anota: «This will orphan
  any transactions»).
- Borrar un favorito no pide confirmación.
- El aviso de archivar es largo y técnico.
- La alerta de segunda divisa remite a «Perfil > Divisa».
- Una importación no se puede deshacer.
- 7.16: hay que elegir la cuenta en cada registro.

**Tickets abiertos del lote:** `deleting-an-account-asks-nothing`, `account-form-redesign`,
`accounts-settings-list-redesign`, `archiving-exclusion-open-decisions`, `qa/changing-an-account-currency-orphans-its-whole-history`,
`initial-balance-date-move-leaves-converted-amount-stale`, `es-419-category-names-use-peruvian-words`,
`csv-import-leaves-no-origin-mark-and-reuses-opposite-categories`, `preferred-currency-has-three-different-defaults`.
**Cards de 2.2 que lo cambian:** «Tarjeta con varias divisas» (entregas 1-4), «Las cuentas se ven poco», «Seguimiento
de deudas personales».

---

## Lote 8 · Registros: ver, editar, buscar y filtrar

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 8.1 | Ver todos mis registros | Más › Registros (o su pestaña) · pie del Panel · Estadísticas › Registros | `RecordsStandaloneView` (`ListDetailSplit`) → `RecordsTabView` (hero, `FilterControlBar`, lista) | `V/Records/RecordsStandaloneView.swift`, `V/Statistics/RecordsTabView.swift`, `V/Records/Components/RecordRowView.swift` | `StatisticsNavigation`, `AdaptiveNavigation` |
| 8.2 | Ver el detalle de un registro | Tocar una fila | `TransactionDetailSheet` (hoja en iPhone, columna en iPad) | `V/Records/TransactionDetailSheet.swift` | `RecordsDetailSheet` |
| 8.3 | Editar un registro | Detalle › Editar · menú contextual · ⌘E · resultado de búsqueda | `NewTransactionView` en edición | `V/Transactions/NewTransactionView.swift`, `VM/RecordsViewModel.swift` | `RecordsDetailSheet`, `KeyboardShortcuts` |
| 8.4 | Borrar un registro | Editor › Eliminar · pulsación larga › Eliminar · ⌫ en iPad | Alerta «Confirmar» / diálogo del menú | `NewTransactionView.swift`, `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.5 | Duplicar un registro | Pulsación larga › Duplicar · editor › Duplicar | `NewTransactionView` como duplicado → toast | `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.6 | Cambiar la categoría rápido | Pulsación larga › «Cambiar categoría» | `SubcategorySelectorSheet`, se aplica al cerrar | `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.7 | Ver los registros en calendario | Selector Lista/Calendario | `RecordsCalendarView` → día | `V/Records/Components/RecordsCalendarView.swift` | no |
| 8.8 | Encontrar duplicados | ··· › «Identificar duplicados» | `DuplicateModeBanner` | `V/Records/Components/RecordsOverflowMenu.swift` | no |
| 8.9 | Seleccionar varios y borrarlos | ··· › Seleccionar › papelera | Diálogo de confirmación | `V/Records/RecordsStandaloneView.swift` | parcial (`BulkEdit`, solo abrir) |
| 8.10 | Editar varios a la vez | Seleccionar >1 › lápiz | `BulkEditSheet` (cuenta, subcategoría, etiquetas, nota, monto) | `V/Records/BulkEditSheet.swift`, `VM/BulkEditViewModel.swift` | `BulkEdit` |
| 8.11 | Buscar un movimiento | Pestaña lupa · ⌘F | `GlobalSearchView` (chips Todo/Nota/Categoría…) → editor; «Ver todo» → Estadísticas › Registros | `V/Search/GlobalSearchView.swift` | parcial (`KeyboardShortcuts`, ⌘F) |
| 8.12 | Filtrar registros | ··· › Filtros · chips de `FilterControlBar` | `RecordsFiltersView` (cuentas, categorías, etiquetas, tipo, necesidad, divisa, «nota contiene») → «Aplicar» | `V/Records/RecordsFiltersView.swift`, `VM/RecordsFiltersViewModel.swift`, `V/Filters/FilterControlBar.swift` | `Filters`, `DeferredFilters`, `CurrencyFilterStats` |
| 8.13 | Filtrar excluyendo | Segmento Incluir/Excluir | `RecordsFiltersView` → `ExcludeModeBadge` | `V/Filters/ExcludeModeBadge.swift` | `AdvancedFilters` |
| 8.14 | Abrir un registro en otra ventana (iPad) | Menú contextual | Ventana nueva | `Yala/App/Scenes/OpenInNewWindowButton.swift` | `MultiWindow` |
| 8.15 | Ver un gasto de grupo desde mis registros | Tocar un registro que viene de un grupo | Formulario en solo lectura con aviso | `NewTransactionView.swift` | no |

**Visto en el código:**
- Hay dos listas de Registros distintas (Más › Registros y Estadísticas › Registros).
- El detalle solo ofrece «Editar»: no hay borrar ni duplicar ahí. No se puede deslizar para borrar.
- La alerta de borrar se titula «Confirmar» y no dice qué se borra.
- La búsqueda abre el editor, no el detalle como en Registros. «Ver todo» pone el período global en «Todo» sin avisar.
- La selección múltiple está escondida en el menú ···.
- Cerrar los filtros con la X descarta lo elegido sin avisar; cambiar Incluir/Excluir borra la selección.
- En gastos de grupo, «Duplicar» sale atenuado sin explicar por qué.

**Tickets abiertos del lote:** `filtro-de-cuentas-se-colapsa-al-navegar-a-registros`,
`stats-filter-segment-tap-should-ask-include-or-exclude`, `faq-says-long-press-starts-bulk-edit`,
`bulk-move-to-another-currency-account-relabels-the-amount`, `save-error-alert-lies-when-the-context-autosaves`,
`ipad-list-highlights-the-open-row`, `ipad-records-empty-detail-half-hidden-with-chat-open`.
**Cards de 2.2 que lo cambian:** «Al tocar un segmento de una gráfica con exclusiones activas, que la app pregunte…»,
«El detalle de un registro pinta "≈ 0,00"…».

---

## Lote 9 · Presupuestos

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 9.1 | Ver mis presupuestos y cómo voy | Planificación › Presupuestos · Más · widget y sección del Panel · `yala://budgets` | `PlanningView` → `BudgetsListView` (Semanal/Mensual/Anual/Único, flechas, Excedidos/Activos/Inactivos) | `V/Planning/PlanningView.swift`, `BudgetsListView.swift`, `BudgetRowView.swift`, `VM/BudgetsViewModel.swift` | `BudgetsCrud` |
| 9.2 | Poner un límite de gasto (crear presupuesto) | Botón + · paso de «Primeros pasos» · Ajustes › Presupuestos › + | `BudgetEditorView` (datos, período, rango si es Único, activo, alertas, filtros de categoría, «Incluir gastos compartidos») | `V/Planning/BudgetEditorView.swift` | `BudgetsCrud` |
| 9.3 | Llegar al límite gratis de presupuestos | + con 3 activos | `LimitReachedBanner` → `UpgradePromptSheet(.budgets)` | `V/Planning/BudgetsListView.swift`, `S/FeatureGateService.swift` | no |
| 9.4 | Ver el detalle de un presupuesto | Tocar la fila | `BudgetDetailView` | `V/Planning/BudgetDetailView.swift` | `AdaptiveNavigation` |
| 9.5 | Ver las gráficas de un presupuesto | Detalle › icono de gráfica | `BudgetChartsView` → `BudgetChartsPeriodSelector` | `V/Planning/BudgetChartsView.swift` | no |
| 9.6 | Cambiar el período que veo | Flechas o etiqueta del período | `PeriodNavigationHeader` → `BudgetPeriodSelectorSheet` | `V/Planning/Components/BudgetPeriodSelectorSheet.swift` | no |
| 9.7 | Editar un presupuesto | Detalle › lápiz · pulsación larga · Ajustes | `BudgetEditorView` | `V/Planning/BudgetEditorView.swift` | no |
| 9.8 | Borrar un presupuesto | Editor › «Eliminar presupuesto» | Alerta «¿Eliminar presupuesto?…» | `V/Planning/BudgetEditorView.swift` | no |
| 9.9 | Pedir aviso al acercarme al límite | Editor › Alertas | Interruptor y umbrales 50/75/90/100 | `V/Planning/BudgetEditorView.swift`, `YS/BudgetAlertService.swift` | `BudgetAlertsConfig` |
| 9.10 | Tocar una alerta de presupuesto | Notificación «Ya llevas el 75 % de "X"…» | Abre la lista de presupuestos | `YS/BudgetAlertService.swift`, `YS/NotificationService.swift` | no |
| 9.11 | Encender o apagar todas las alertas | Ajustes › Notificaciones | `NotificationsSettingsView` | `V/Settings/NotificationsSettingsView.swift` | parcial (`BudgetAlertsConfig`) |
| 9.12 | Elegir qué presupuestos salen en el widget | Ajustes › Presupuestos | `BudgetsFavoritesSettingsView` | `V/Settings/BudgetsFavoritesSettingsView.swift` | no |

**Visto en el código:**
- «Único» no explica qué significa.
- Sin filtros, el presupuesto cuenta todos los gastos, y no se ve.
- «Incluir gastos compartidos» es vocabulario de Grupos.
- Con las alertas generales apagadas solo dice «Activa las alertas de presupuesto en Perfil > Notificaciones», sin enlace.
- La notificación lleva a la lista, no al presupuesto avisado.
- Hay dos sitios para gestionar presupuestos (Planificación y Ajustes), y el widget solo se elige desde Ajustes.
- «Tu cumplimiento en los últimos 6 períodos»: «cumplimiento» es abstracto.

**Tickets abiertos del lote:** `budget-tied-to-income-or-expense`, `ai-recommended-budgets`, `ipad-list-highlights-the-open-row`.

---

## Lote 10 · Pagos planificados

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 10.1 | Ver mis pagos del mes | Planificación › Pagos planificados · Más · widget · notificación | `ScheduledPaymentsView` (Todos/Recurrentes/Suscripciones) → `ScheduledPaymentsListView` (total, Pagado/Pendiente, lista o calendario) | `V/Planning/ScheduledPaymentsView.swift`, `ScheduledPaymentsListView.swift`, `ScheduledPaymentRowView.swift` | parcial (`ScheduledPaymentSkip`) |
| 10.2 | Apuntar un pago que se repite | Botón + · «Primeros pasos» · Ajustes › Pagos planificados › + · «Recurrente» del formulario | `ScheduledPaymentEditorView` | `V/Planning/ScheduledPaymentEditorView.swift`, `V/Settings/ScheduledPaymentsSettingsView.swift` | parcial (`ScheduledPaymentsCrud`, solo desde Ajustes) |
| 10.3 | Elegir cada cuánto se repite | Editor › Recurrencia | «Una sola vez» o cada N días/semanas/meses/años, días, fecha de fin | `V/Planning/ScheduledPaymentEditorView.swift` | `ScheduledPaymentRecurrenceA11y` |
| 10.4 | Compartir un pago recurrente con un grupo | Editor › «¿Es un gasto compartido?» | Hojas de grupo, moneda y división; al vencer, borrador en la Bandeja → formulario de grupo | `V/Planning/ScheduledPaymentEditorView.swift`, `V/Inbox/InboxView.swift` | no |
| 10.5 | Ver el detalle y el historial de un pago | Tocar la fila | `ScheduledPaymentDetailView` | `V/Planning/ScheduledPaymentDetailView.swift` | `ScheduledPaymentSkip` |
| 10.6 | Saltarme un pago | Detalle › fecha › «Saltar» / «Revertir» | Diálogo en el detalle | `V/Planning/ScheduledPaymentDetailView.swift` | `ScheduledPaymentSkip` |
| 10.7 | Marcar un pago como hecho (vincular un gasto ya apuntado) | Detalle › fecha › «Vincular gasto» | `TransactionAssociationSheet` → «Ver registro» | `V/Planning/Components/TransactionAssociationSheet.swift` | no |
| 10.8 | Pagar por adelantado | Detalle › primera fecha › «Adelantar gasto» | `InboxDraftEditSheet` | `V/Planning/ScheduledPaymentDetailView.swift` | no |
| 10.9 | Tocar un recordatorio de pago | Notificación «Hoy toca pagar X…» | Planificación › Pagos planificados | `YS/ScheduledPaymentNotificationService.swift` | no |
| 10.10 | Tocar el aviso de pago de la tarjeta de crédito | Notificación de cuenta | No lleva a ningún sitio (`deepLink: "accounts"`) | `YS/ScheduledPaymentNotificationService.swift` | no |
| 10.11 | Editar, pausar o borrar un pago | Detalle › lápiz · Ajustes › Pagos planificados (deslizar) | `ScheduledPaymentEditorView`, alerta | `V/Planning/ScheduledPaymentEditorView.swift` | no |

**Visto en el código:**
- El mismo concepto se llama «Pagos planificados», «Pago programado» y «Pagos programados».
- No hay botón «Marcar como pagado»: hay que «Vincular gasto». En un ingreso también dice «gasto».
- Las cadenas de «¿Saltar esta ocurrencia?» y de «¡Tienes pagos pendientes!» existen sin que nadie las use.
- Gestión duplicada en Planificación y Ajustes; crear desde Planificación no tiene test.

**Tickets abiertos del lote:** `scheduled-payment-once-labeled-monthly`, `qa/scheduled-payments-notif-dedup`,
`notification-deeplink-accounts-not-parsed`, `qa/account-currency-change-leaves-scheduled-and-favorites-stale`.
**Cards de 2.2 que lo cambian:** «Pagos en cuotas».

---

## Lote 11 · Estadísticas

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 11.1 | Abrir Estadísticas y cambiar de pestaña | Pestaña Estadísticas · Más · hero del Panel · `yala://statistics[/…]` · notificación de informe | `StatisticsView` → `DetailContainerView` (Resumen, Tendencias, Distribución, Registros) | `V/Statistics/StatisticsView.swift`, `DetailContainerView.swift` | `StatisticsNavigation`, `DeeplinkRouting` |
| 11.2 | Cambiar el período | Píldora del hero | `TrendsPeriodMenu` → `CustomPeriodPickerSheet` | `V/Filters/PeriodSelectorComponents.swift` | `StatisticsHeroLikePanel` |
| 11.3 | Elegir con qué comparar | Selector junto a los filtros | `ComparisonModeSelector` («P-1», «A-1») | `V/Statistics/Components/ComparisonModeSelector.swift` | no |
| 11.4 | Filtrar por cuenta, categoría, etiqueta, necesidad o divisa | Botón de filtros | `RecordsFiltersView` | `V/Statistics/DetailContainerView.swift` | `CurrencyFilterStats` |
| 11.5 | Ver el resumen del período | Chip Resumen | `InsightsTabView` (hero, «Tu salud financiera», Compromisos, Por necesidad, Observaciones) | `V/Statistics/InsightsTabView.swift` | `StatisticsNavigation` |
| 11.6 | Pedir un resumen inteligente con IA | Resumen › «Resumen inteligente» (Pro) · teaser difuminado (gratis) | Consentimiento de insights → tarjeta de IA · `UpgradePromptSheet(.smartInsightsAI)` | `V/Statistics/InsightsTabView.swift`, `Yala/App/Theme/ViewModifiers.swift` | no |
| 11.7 | Ver cómo evoluciona mi dinero | Chip Tendencias | `TrendsTabView` (Total/Por cuenta/Por divisa, `PeriodComparisonChartView`, «Flujo de Efectivo», `WeekdayBarChart`) | `V/Statistics/TrendsTabView.swift`, `PeriodComparisonChartView.swift` | `StatisticsHeroLikePanel` |
| 11.8 | Leer o generar las observaciones de Tendencias | Final de Tendencias | Viñetas; Pro: «Generar con IA» | `V/Statistics/TrendsTabView.swift` | `TrendsInsightCard` |
| 11.9 | Ver en qué se me va el dinero | Chip Distribución | `CategoriesTabView` (Gráficas/Detalle, tortas, necesidades, `SankeyChartView`) | `V/Statistics/CategoriesTabView.swift`, `V/Statistics/Sankey/SankeyChartView.swift` | `StatisticsHeroLikePanel` |
| 11.10 | Recibir un informe diario, semanal o mensual | Ajustes › Notificaciones › Reporte… o «+» | `NotificationsSettingsView` → `NotificationEditorSheet` | `V/Settings/NotificationEditorSheet.swift`, `YS/ReportNotificationService.swift` | parcial (`NotificationsSettings`) |
| 11.11 | Tocar el informe | Notificación «En la semana gastaste S/ X» | Estadísticas en la pestaña que estuviera | `YS/ReportNotificationService.swift` | no |

**Visto en el código:**
- «P-1», «A-1», «Compromisos», «Prioritaria/Esencial/Opcional»: jerga.
- «Flujo de Efectivo» (Tendencias) y «Flujo de caja» (Reportes) son cosas distintas con casi el mismo nombre.
- El período aquí es un menú sin flechas; en Planificación, flechas.
- Tocar un trozo de la torta o un nodo del Sankey filtra sin avisar.
- El teaser de IA mezcla idiomas: «Insights con IA».
- El informe por notificación no lleva al Resumen.

**Tickets abiertos del lote:** `distribution-default-should-be-detail-not-charts`,
`distribution-pie-totals-styled-differently-per-page`, `trends-cards-ignore-an-in-place-amount-edit`,
`weekday-bar-daily-average-unmarked`, `insights-and-trends-payload-labels-mislead-the-model`,
`trends-insight-title-capitalizes-the-period-mid-sentence`, `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas`.
**Cards de 2.2 que lo cambian:** «El hero de cada vista…», «Al tocar un segmento de una gráfica…».

---

## Lote 12 · Grupos I: entrar, crear, invitar y unirse

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 12.1 | Entrar a Grupos y ver mis grupos | Pestaña Grupos · FAB del Panel › Grupo · `yala://groups/<id>` · notificación · ventana nueva (iPad) | `GroupsContainerView` (resumen, nudge, tarjetas, «Ver archivados») → `GroupDetailView` (Registros, Saldos, Estadísticas) | `V/Groups/GroupsContainerView.swift`, `GroupCardView.swift`, `GroupDetailView.swift` | `GroupsSmoke`, `GroupDetailDeeplinkColdLaunch`, `AdaptiveNavigation` |
| 12.2 | Ver el estado vacío que me toca | Pestaña sin grupos | `YalaEmptyState` en 5 variantes (sin grupos, cómo funcionan, están en tu cuenta, crea tu cuenta, un último paso) | `V/Groups/GroupsContainerView.swift`, `GroupsEmptyStateLogic` | parcial (`GroupsEmptyState`, 3 de 5) |
| 12.3 | Ver cómo funcionan los grupos | Primera visita · «Ver cómo funciona» · bienvenida | `GroupsOnboardingView`, 3 pasos → «Ir a Grupos» / «Iniciar sesión» / «Crear mi cuenta» | `V/Groups/Onboarding/GroupsOnboardingView.swift` | `GroupsEducational` |
| 12.4 | Iniciar sesión o crear cuenta para Grupos | Estados vacíos · educativo · crear grupo sin sesión · invitación | `GroupsSignInView` (Apple/Google) → `GroupsAccountIsCompleteBlockView` si toca → `GroupsConsentView` | `V/Groups/GroupsSignInView.swift`, `GroupsAccountIsCompleteBlockView.swift` | no |
| 12.5 | Aceptar el consentimiento de Grupos | Tras iniciar sesión · «Un último paso» | `GroupsConsentView` → «Aceptar y continuar» | `V/Groups/GroupsConsentView.swift` | parcial (`GroupsEmptyState`, `WelcomeChooser`) |
| 12.6 | Activar las notificaciones de grupo | Alerta al tener el primer grupo | Alerta → permiso de iOS o «Abrir Ajustes» | `V/Groups/GroupsContainerView.swift` | no |
| 12.7 | Crear un grupo | Estado vacío · FAB «+» › Nuevo grupo | Comprobaciones (disponibilidad, consentimiento, sesión) → `GroupFormView` (nombre, icono, color, simplificar deudas, divisa, división por defecto) | `V/Groups/GroupFormView.swift`, `GroupCreateRoutingLogic` | parcial (`GroupsSmoke`) |
| 12.8 | Crear mi primer grupo desde la bienvenida | Bienvenida › «Vengo por un grupo» › «Crear mi primer grupo» | `WelcomeGroupsChooserView` → `WelcomeGroupsGateView` → educativo → sesión → consentimiento → `GroupsOrganizerNameView` → `GroupFormView` | `V/Onboarding/WelcomeGroupsChooserView.swift`, `WelcomeGroupsGateView.swift`, `V/Groups/GroupsOrganizerNameView.swift` | `WelcomeChooser` |
| 12.9 | Invitar a alguien por enlace | Detalle › Miembros › «Invitar por enlace» · registros vacíos | `GroupMembersView` → hoja de compartir | `V/Groups/GroupMembersView.swift`, `VM/GroupDetailViewModel.swift` | no |
| 12.10 | Abrir una invitación sin tener la app | Enlace en el navegador | Web `invite.astro` → App Store → bienvenida › «Tengo una invitación» → `InviteRecoveryView` (pegar el enlace) | `Web/src/pages/invite.astro`, `V/Onboarding/InviteRecoveryView.swift` | `WelcomeChooser` |
| 12.11 | Unirme a un grupo con la app instalada | Tocar el enlace · pegarlo · lo retoma el reconciliador | Puerta neutral si toca → sesión → consentimiento → `GroupInviteOnboardingView` (nombre → conectando → tardando / error / pendiente / listo) | `S/GroupBackendInviteEntryHandler.swift`, `V/Groups/GroupInviteOnboardingView.swift`, `SG/PendingJoinStore.swift` | `GroupInviteOnboarding` |
| 12.12 | Unirme desde un teléfono con datos de otro | Invitación en un aparato con datos y sin onboarding personal | `WelcomeGroupsGateView` («Antes de unirte, este teléfono queda en blanco») → «Continuar y borrar» → relanzar → 12.11 | `L/GroupInviteNeutralGateLogic.swift`, `V/Onboarding/WelcomeGroupsGateView.swift` | parcial (`WelcomeChooser`) |
| 12.13 | Tocar un enlace que no vale o de un grupo archivado | Enlace caducado · grupo archivado · canal caído | Alertas «Enlace no válido», grupo archivado, «Hubo un problema con el grupo» | `Yala/App/AppBootstrapper.swift`, `CV` (`GroupInviteModifier`) | no |
| 12.14 | Esperar a que el admin me apruebe | Tarjeta pendiente · banner · enlace | Alerta «Esperando aprobación»; si rechazan, `PendingApprovalBanner` | `V/Groups/GroupCardView.swift`, `GroupDetailView.swift` | `GroupPendingMemberDoor` |
| 12.15 | Ver el estado de una unión en curso o caducada | Pestaña Grupos con una unión pendiente | Chip «Conectando con tu grupo…» / error con «Reintentar» / caducada | `V/Groups/GroupsContainerView.swift` (`joinIntentBanner`) | parcial (`GroupInviteOnboarding`) |

**Visto en el código:**
- «Un último paso» con «Continuar» no dice qué paso es.
- `GroupsSignInView` dice «…sigue con tu invitación» también a quien está creando su primer grupo.
- Tras sesión y consentimiento entrando por «crear grupo», no vuelve al formulario.
- 12.8 son unas 7 pantallas, y «Crear mi grupo» abre otro formulario.
- Al guardar un grupo no se propone invitar a nadie. Solo el dueño puede invitar.
- La web de invitación no dice que, tras instalar, hay que volver a tocar el enlace o pegarlo.
- Se pide cuenta y consentimiento antes de enseñar a qué grupo se une.
- «Vuelve a entrar en un rato para comprobarlo»: se le pide mirar, no se le avisa.
- Errores mostrados en crudo (`error.localizedDescription`).

**Tickets abiertos del lote:** `qa/groups-consent-door-spec`, `invite-aasa-requires-s-param`,
`invite-link-creation-blames-the-connection-for-any-rpc-failure`, `groups-organizer-intent-is-lost-on-relaunch`,
`invite-neutral-gate-reopens-the-welcome-without-recomputing-readiness`,
`groups-join-intent-expires-silently-after-transient-failures`, `groups-create-approve-remove-show-a-raw-rpc-error`,
`groups-double-load-on-entry-needs-redeciding`.

---

## Lote 13 · Grupos II: gastos y saldar cuentas

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 13.1 | Añadir un gasto de grupo | FAB del detalle · FAB de la lista › Nuevo gasto · menú de la tarjeta · FAB del Panel › Grupo | `GroupExpenseComposerView` → `GroupExpenseFormView` (importe, descripción, divisa, fecha, «Pagado por X y dividido…» con igual / % / importes / partes, cuenta, subcategoría) → «¿Registrar también en tu Yala personal?» → `GroupExpenseSuccessView` | `V/Groups/GroupExpenseFormView.swift`, `GroupExpenseComposerView.swift`, `GroupSplitEditorCard.swift`, `GroupExpenseSuccessView.swift` | `GroupsSmoke`, `GroupExpenseSuccess` |
| 13.2 | Ver, editar y borrar un gasto de grupo | Fila en Registros del grupo · menú contextual | `GroupExpenseDetailSheet` → Editar → `GroupExpenseFormView`; borrar con diálogo «Eliminar» | `V/Groups/GroupExpenseDetailSheet.swift`, `GroupRecordsView.swift` | `GroupsSmoke` |
| 13.3 | Apuntar deudas de antes (saldos iniciales) | Miembros › «Saldos iniciales» (dueño) · diálogo tras aprobar a alguien | `GroupOpeningBalanceFormView`, `GroupOpeningBalanceDetailSheet` | `V/Groups/GroupOpeningBalanceFormView.swift` | no |
| 13.4 | Convertir un borrador de la Bandeja en gasto de grupo | Bandeja › borrador › «Convertir a gasto compartido» | `InboxDraftEditSheet` → `GroupPickerSheet` → `GroupExpenseFormView` | `V/Inbox/InboxDraftEditSheet.swift`, `V/Groups/GroupPickerSheet.swift` | `InboxConvertToGroup` |
| 13.5 | Completar en la Bandeja un gasto o pago de grupo | Fila de la Bandeja creada por el puente | `GroupExpenseDraftFinalizationSheet` / `GroupSettlementDraftFinalizationSheet` | `V/Inbox/GroupExpenseDraftFinalizationSheet.swift`, `GroupDraftFinalizationScaffold.swift` | no |
| 13.6 | Ver quién debe a quién y las estadísticas del grupo | Pestañas Saldos y Estadísticas · barra de saldo | `GroupBalancesView` («¡Están al día!», «Deudas pendientes»), `GroupStatsView` | `V/Groups/GroupBalancesView.swift`, `GroupStatsView.swift`, `SG/GroupBalanceService.swift` | parcial (`AdaptiveNavigation`) |
| 13.7 | Saldar una deuda | Saldos › deuda › «Liquidar» | `SettlementFormView` («Registrar pago», cuenta o «Ninguna — finalizar después») → pendiente → el otro confirma ✓ o rechaza ✗ | `V/Groups/SettlementFormView.swift`, `GroupBalancesView.swift` | no |
| 13.8 | Responder a un cambio de importe de un pago | Bandeja › fila de aviso | `GroupSettlementAmountChangeSheet` («Cambió el monto» → «Ajustar a X» / «Dejar en Y») | `V/Inbox/GroupSettlementAmountChangeSheet.swift` | `SettlementAmountChangeNotice` |
| 13.9 | Compartir el resumen del grupo como imagen | Ajustes del grupo › resumen | `GroupShareableSummarySheet` → hoja de compartir | `V/Groups/GroupShareableSummarySheet.swift` | `GroupsSmoke` |
| 13.10 | Reflejar los gastos de grupo en mis cuentas (puente) | Grupos › engranaje · Ajustes del grupo › «Integración personal» | `GroupsGlobalSettingsView` → `BridgeActivationSheet` («Empezar desde ahora» / «Importar todo el historial») / `BridgeDeactivationSheet` | `V/Groups/GroupsGlobalSettingsView.swift`, `BridgeActivationSheet.swift`, `SG/GroupTransactionBridge.swift` | parcial (`GroupsSmoke`, solo abre) |

**Visto en el código:**
- Desde el Panel sin grupos, el formulario de gasto se abre solo tras crear el primer grupo, sin explicarlo.
- Borrar un gasto solo dice «Eliminar»: no avisa de que desaparece para todos ni de que se borra el registro personal.
- Confirmar y rechazar un pago son solo iconos ✓/✗, y rechazar no pide confirmación.
- Vocabulario mezclado: «Liquidar», «Registrar pago», «Salda pagos».
- El educativo avisa de pasada de que el gasto «también lo registramos en tu cuenta personal automáticamente».
- 13.10: la hoja dice «tu cuenta de grupos» y el interruptor «mis cuentas personales».
- No hay forma manual de enlazar un gasto de grupo con un registro personal ya existente.

**Tickets abiertos del lote:** `bridge-virtual-only-currency-mismatch-is-silent`,
`settlement-direction-edited-after-approval-leaves-the-bank-stale`, `group-balance-service-shares-not-deduped`,
`debt-simplification-nondeterministic-ties`, `settlement-amount-change-notice-archived-row-reads-as-a-rejected-payment`,
`groups-in-group-search`.
**Cards de 2.2 que lo cambian:** «Yala IA entiende Grupos como un contenedor aparte de lo personal», «Seguimiento de
deudas personales» (cuidar que no choque con las deudas de grupo).

---

## Lote 14 · Yala IA

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 14.1 | Abrir Yala IA por primera vez | Píldora «IA» del Panel · botón de destellos en Estadísticas y Registros · ⌘K | Puerta Pro → consentimiento «Asistente financiero» → `YalaAIOnboardingView` (5 pasos) → `ChatSheetView` (columna en iPad) | `L/YalaAIOnboardingLogic.swift`, `V/Chat/Onboarding/YalaAIOnboardingView.swift`, `V/Chat/YalaAIChatPresentation.swift` | parcial (`AdaptiveNavigation`, la columna) |
| 14.2 | Tocar Yala IA sin ser Pro | El mismo botón | `UpgradePromptSheet(.chatAssistant)` | `V/Panel/PanelView.swift` (`startChat`) | no |
| 14.3 | Hacerle una pregunta | Caja «Escribe tu pregunta...» | `ChatSheetView` (burbujas, cargando, error, «Reiniciar contexto de conversación») | `V/Chat/ChatSheetView.swift`, `VM/ChatAssistantViewModel.swift` | `ChatMessagingLayout` |
| 14.4 | Usar las sugerencias o los temas | Saludo con 3 sugerencias · botón «Temas» | `ChatGreetingBubble`, `ChatTopicsSheet` | `V/Chat/ChatGreetingBubble.swift`, `ChatTopicsSheet.swift` | `ChatMessagingLayout` |
| 14.5 | Dictar la pregunta | Micrófono de la caja | `VoiceListeningPanel` | `V/Chat/VoiceListeningPanel.swift` | parcial (`ChatMessagingLayout`) |
| 14.6 | Apuntar un gasto hablándole | Respuesta con tarjeta de registro | `ChatTransactionDraftCard` (Guardar / Descartar / Detalles) → `ChatDraftDetailSheet` → «Ver registros creados» | `V/Chat/ChatTransactionDraftCard.swift`, `ChatDraftDetailSheet.swift` | `ChatMessagingLayout` |
| 14.7 | Llegar al límite diario de preguntas | ≥65 de 75 preguntas | «Te quedan %d preguntas hoy» → «Has usado tus preguntas de hoy» | `YS/ChatAssistantService.swift` | no |
| 14.8 | Buscar una conversación anterior | — | No hay historial: «Esta conversación se borra al cambiar de día.» | `V/Chat/ChatSheetView.swift` | parcial (`ChatMessagingLayout`) |
| 14.9 | Personalizar el tono de la IA | Icono de ajustes del chat · Ajustes › «Personalizar resumen IA» | `AIPersonalizationSheet`, `SmartInsightsSettingsView` | `V/Chat/AIPersonalizationSheet.swift`, `V/Settings/SmartInsightsSettingsView.swift` | no |
| 14.10 | Retirar los consentimientos de IA | Ajustes › Privacidad IA | `AIPrivacySettingsView` (3 interruptores, «¿Desactivar esta función?») | `V/Settings/AIPrivacySettingsView.swift` | no |
| 14.11 | Ocultar el botón de Yala IA | Ajustes › Personalización | Interruptor | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationGroupedList` |

**Visto en el código:**
- El consentimiento sale **antes** de la presentación, con un párrafo denso sobre OpenAI y 13 meses de datos, y se
  titula «Asistente financiero», no «Yala IA».
- La píldora dice solo «IA»; «Pregúntale a Yala» solo lo lee VoiceOver.
- «Reiniciar contexto» es jerga. «Insights, Asistente y Hero del Panel» mezcla nombres internos.
- Hay tres consentimientos de IA separados (voz/imagen, chat, insights).

**Tickets abiertos del lote:** `ai-onboarding-demo-speaks-english-and-dollars`,
`qa/ai-chat-reads-heavier-than-a-messaging-app`, `qa/chat-draft-card-redesign`, `qa/chat-dictation-looks-poor`,
`chat-ignores-expenses-only-mode`, `chat-creates-only-one-transaction-per-message`,
`chat-suggestions-reject-the-users-own-recurring-payments`.
**Cards de 2.2 que lo cambian:** «Partir la IA según modo nube o privado», «Yala IA entiende Grupos…», «Yala en
ChatGPT, Claude y Grok» (el conector MCP). Este lote va **después** de esas decisiones si salen antes.

---

## Lote 15 · Desde fuera de la app

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 15.1 | Ir a una pestaña desde un widget de datos | Saldo, Gasto, Flujo de caja → Panel; categorías → Distribución; Últimos registros → Registros; Presupuestos; Pagos programados; Resumen del mes (iPad XL); widgets de pantalla bloqueada | Navega a la pestaña | `YalaWidgets/Widgets/`, `YalaWidgets/YalaWidgetsBundle.swift` | `DeeplinkRouting` |
| 15.2 | Apuntar desde un widget de entrada rápida | Manual / Voz / Imagen | Panel → formulario, voz o imagen (o paywall / consentimiento) | `YalaWidgets/Widgets/QuickEntryWidgets.swift` | `WidgetEntryToPanel`, `WidgetEntryBackground` |
| 15.3 | Tocar un widget estando en solo grupos | Cualquier widget de datos | «Aún no tienes finanzas personales» → `yala://activate-full` | `YalaWidgets/Views/GroupsOnlyInviteView.swift` | no |
| 15.4 | Apuntar desde el Centro de Control | Controles «Registro por voz» y «Foto o archivo» | Clave en el App Group → al volver, Panel → hoja | `YalaWidgets/ControlWidgets.swift`, `Yala/Shared/ControlCenterIntents.swift` | no |
| 15.5 | Apuntar con un atajo de Siri que abre la app | «Registra en Yala», «Registra con voz…», «Escanear gasto…» | Deep link → Panel | `Yala/App/Intents/AppShortcutsProvider.swift`, `QuickExpenseIntent.swift` | parcial (`WidgetEntryToPanel`, las URLs) |
| 15.6 | Apuntar hablándole a Siri sin abrir la app | «Anota un gasto en Yala» → «¿Qué quieres registrar?» | Borrador en la Bandeja → notificación → `InboxAlertModal` | `QuickExpenseIntent.swift` (`SiriNaturalEntryIntent`), `SiriPendingStore.swift`, `S/InboundCaptureDrain.swift` | no |
| 15.7 | Capturar un pago de Apple Pay | Automatización de Wallet en Atajos | Borrador en la Bandeja → notificación → `InboxAlertModal` | `QuickExpenseIntent.swift` (`ApplePayTransactionIntent`), `ApplePayPendingStore.swift` | parcial (`InboxNewItemsModal`) |
| 15.8 | Configurar Apple Pay con la guía | Ajustes › Tutoriales › Apple Pay | `ApplePayAutomationGuideView` → `YalaStepGuide` → abre Atajos | `V/Settings/ApplePayAutomationGuideView.swift` | `StepGuide` |
| 15.9 | Leer qué le puedo decir a Siri | Ajustes › «Siri y Atajos» | `SiriShortcutsView` | `V/Settings/SiriShortcutsView.swift` | no |
| 15.10 | Tocar una notificación de Yala | Recordatorio, presupuesto, pago, informe, grupo, Siri/Apple Pay | Navega a la pestaña; `inbox` abre la Bandeja | `YS/NotificationService.swift` (`parseDestination`) | no |
| 15.11 | Usar Yala en varias ventanas (iPad) | Menú contextual de un registro o grupo | Ventana nueva; la otra muestra «Yala te espera en otra ventana» | `Yala/App/Scenes/` | `MultiWindow` |
| 15.12 | Usar los atajos de teclado | ⌘N, ⌘⇧N, ⌘,, ⌘F, ⌘K, ⌘1…6, ⌘E, Supr, ↑/↓ | Según la acción | `Yala/App/Commands/YalaCommands.swift` | `KeyboardShortcuts` |
| 15.13 | Girar el iPhone o redimensionar la ventana | Horizontal · Split View | `ListDetailSplit` | `V/Shared/ListDetailSplit.swift` | `IPhoneLandscape`, `AdaptiveNavigation` |

**Visto en el código:**
- 15.9 está **verificado**: la pantalla enseña tres frases que Siri no conoce. Ticket
  `siri-settings-screen-lists-phrases-siri-does-not-know`.
- Sin Pro, Siri contesta «Activa Yala Pro para usar registro con Siri.» y no abre nada.
- El aviso de saldo de cuenta (`deepLink: "accounts"`) no lleva a ningún sitio.
- Con algo abierto en el iPad, soltar un archivo se rechaza sin decir por qué.
- Supr sin modificador borra el registro abierto.
- No existen Spotlight, Handoff ni accesos rápidos del icono (lo dice `docs/entry-points.md`).

**Tickets abiertos del lote:** `siri-settings-screen-lists-phrases-siri-does-not-know`,
`siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`,
`qa/after-session-redesign-review-widgets-siri-applepay-and-web-copy`, `notification-deeplink-accounts-not-parsed`,
`apple-pay-capture-in-a-groups-only-session-has-no-personal-inbox`, `iphone-duo-native-app`.
**Cards de 2.2 que lo cambian:** «Integrar Yala con el nuevo Siri con IA de iOS 27», «Registrar movimientos desde la
notificación del banco». Este lote revisa lo que hay **hoy**; lo que cambie Siri con IA se audita con su card.

---

## Lote 16 · Ajustes: perfil y preferencias

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 16.1 | Editar mi nombre, foto o icono de perfil | Ajustes › avatar o «Editar» | `PersonalDetailsView` | `V/Profile/PersonalDetailsView.swift`, `PV` | no |
| 16.2 | Cambiar la divisa principal | Ajustes › «Divisa y tipo de cambio» | `CurrencySettingsView` → `CurrencyPickerSheet` → «recalculando conversiones» | `V/Settings/CurrencySettingsView.swift`, `CurrencyPickerSheet.swift`, `CurrencyChangeService` | `CurrencySettings`, `CurrencyPicker` |
| 16.3 | Ver los tipos de cambio | Divisa › «Ver todo» | `ExchangeRatesSheet` | `V/Settings/ExchangeRatesSheet.swift` | no |
| 16.4 | Cambiar el idioma de la app | Ajustes › Personalización › «Idioma de la app» | `LanguagePickerSheet` | `V/Settings/PersonalizationSettingsView.swift` | no |
| 16.5 | Pasar a modo solo gastos | Personalización › interruptor | Diálogo «Se ocultarán los ingresos, transferencias y saldos…» | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationGroupedList` |
| 16.6 | Ajustar la personalización (iconos coloridos, textos de ayuda, botón de chat, período, primer día, decimales, formato, campo con foco) | Personalización › filas | Hojas de selección | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationColorfulIcons`, `PersonalizationGroupedList`, `VoiceImageSettingsFab` |
| 16.7 | Cambiar el tema | Ajustes › Temas | `ThemeSettingsView` → paywall o variante | `V/Settings/ThemeSettingsView.swift` | no |
| 16.8 | Cambiar el icono de la app | Ajustes › Icono de la app | `AppIconSettingsView` → alerta del sistema o paywall | `V/Settings/AppIconSettingsView.swift` | no |
| 16.9 | Configurar la barra de pestañas | Más › editar | `MoreEditorSheet` → `TabBarConfigView` | `V/More/MoreEditorSheet.swift`, `V/Settings/TabBarConfigView.swift` | `ProfileSettings` |
| 16.10 | Proteger Yala con Face ID (guía) | Ajustes › Seguridad › «Proteger con Face ID» | `FaceIDProtectionGuideView` → `YalaStepGuide` | `V/Settings/FaceIDProtectionGuideView.swift` | `SecurityFaceIDGuide`, `StepGuide` |
| 16.11 | Revisar los permisos del sistema | Seguridad › Permisos | Ajustes de iOS | `PV` | no |
| 16.12 | Configurar notificaciones y recordatorios | Ajustes › Notificaciones | `NotificationsSettingsView` → `NotificationEditorSheet` | `V/Settings/NotificationsSettingsView.swift`, `NotificationEditorSheet.swift` | `NotificationsSettings` |
| 16.13 | Valorar la app | Seguridad › Valorar | `requestReview` | `PV` | no |
| 16.14 | Hacer un tutorial | Ajustes › Ayuda › Tutoriales | `TutorialsListView` → `TutorialDetailView` → `TutorialCompletionView` | `V/Settings/TutorialsListView.swift`, `TutorialDetailView.swift` | parcial (`StepGuide`) |
| 16.15 | Leer las preguntas frecuentes | Ayuda › FAQ | `FAQView` | `V/Settings/FAQView.swift` | no |
| 16.16 | Escribir a soporte | Ayuda › Contacto | `SupportFormSheet` → `mailto:` | `V/Profile/SupportFormSheet.swift` | no |
| 16.17 | Leer privacidad y términos | Ajustes › Legal | Navegador | `PV` | no |
| 16.18 | Ver qué versión tengo | Pie de Ajustes | Texto fijo | `PV`, `Yala/Utils/L10n.swift` | no |
| 16.19 | Personalizar el resumen IA | Personalización › «Personalizar resumen IA» | `SmartInsightsSettingsView` | `V/Settings/SmartInsightsSettingsView.swift` | no |
| 16.20 | Ver Más y sus tarjetas | Pestaña Más | `MoreView` (Perfil, Registros, Reportes, Presupuestos, Activar Yala completo…) | `V/More/MoreView.swift` | `ProfileSettings` |
| 16.21 | Recorrer Ajustes en iPad | Hoja de Ajustes en `ListDetailSplit` | Ajustes en dos columnas | `PV` (`settingsContainer`) | `AdaptiveNavigation` |
| 16.22 | Guardar el resumen del widget del Panel a otro tamaño | «?» de un widget › tamaño | `WidgetInfoSheet` | `V/Panel/InfoSheets/WidgetInfoSheet.swift` | no |

**Visto en el código:**
- 16.18 está **verificado**: dice «Versión 1.0.0 (Build 1)» siempre. Ticket `settings-footer-shows-a-fixed-version-1-0-0`.
- Cambiar la divisa principal no pide confirmación, migra todos los registros y, si falla, solo lo imprime en DEBUG.
- La fila de idioma solo aparece si se eligió idioma en el onboarding; el pie dice «Reinicia la app para aplicar el
  cambio.» sin botón.
- Elegir un tema cierra toda la hoja de Ajustes a los 300 ms, sin aviso.
- Abrir la pantalla de iconos sin Pro devuelve el icono original sin preguntar.
- Permisos sale de la app sin avisar.
- Soporte se cierra tras abrir `mailto:` aunque no haya app de correo, y lo escrito se pierde.
- El tope de divisas secundarias solo lo anuncia el hint de accesibilidad.

**Tickets abiertos del lote:** `settings-footer-shows-a-fixed-version-1-0-0`, `qa/settings-redesign-as-grouped-lists-like-ios`,
`currency-change-asks-rates-for-the-old-currency`, `language-override-bypasses-the-cloud-prefs-channel`,
`qa/step-flows-should-match-the-sep15-reference`, `ipad-settings-sheet-size-depends-on-where-it-opens`.

---

## Lote 17 · Yala Pro

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 17.1 | Suscribirme o gestionar la suscripción | Ajustes › Seguridad › Suscripciones | `SubscriptionView` → `SubscriptionSuccessView`; siendo Pro, «Gestionar en App Store» | `V/Settings/SubscriptionView.swift`, `V/Subscription/SubscriptionSuccessView.swift` | `ProConversionUpsells` |
| 17.2 | Toparme con una función de pago | Voz, imagen, chat, insights, cuentas o presupuestos al límite, temas, iconos, flujo de caja, soltar recibo | `UpgradePromptSheet` → `SubscriptionView` | `V/Shared/UpgradePromptSheet.swift`, `S/FeatureGateService.swift` | `ProConversionUpsells`, `PaywallInboxAlertRouting` |
| 17.3 | Empezar la prueba gratis | Tras el onboarding · checklist | `ProTrialOfferSheet` | `V/Subscription/ProTrialOfferSheet.swift` | `ExternalEntryForeignSheet`, `PaywallInboxAlertRouting` |
| 17.4 | Que se acabe la prueba | Automático | `UpgradePromptSheet(.trialExpired)` | `CV` | `ExternalEntryForeignSheet` |
| 17.5 | Elegir qué conservo al dejar de ser Pro | Automático mientras haya exceso | `DowngradeResolutionSheet` («Confirmar selección» / «Reactivar Pro») | `V/Subscription/DowngradeResolutionSheet.swift` | no |
| 17.6 | Restaurar compras | `SubscriptionView` · `ProTrialOfferSheet` | Alerta si hay error | `V/Settings/SubscriptionView.swift` | no |
| 17.7 | Ver el banner de Pro o de prueba en el Panel | Panel | `TrialBanner`, `ProUpgradeBanner` | `V/Panel/PanelView.swift` | `ProConversionUpsells` |

**Visto en el código:**
- Productos: mensual a 4,99 y anual a 29,99, los dos con un mes gratis (`Configuration.storekit`).
- La fila de suscripciones no existe en solo grupos.
- `UpgradePromptSheet` es a menudo una hoja sobre otra hoja.
- En el flujo de caja, tocar un método con candado no hace nada ni ofrece Pro.

**Tickets abiertos del lote:** `paywall-inbox-routing-uitest-misses-the-held-paywall-in-a-batch`,
`blocked-sign-in-still-binds-the-subscription-to-that-account`, `orphan-alerts-behind-fullscreen-covers`,
`journal-unreadable-card-says-reopen-when-a-downgrade-needs-an-update`.

---

## Lote 18 · Reportes: Comparativa y Flujo de caja

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 18.1 | Abrir Reportes | Más › «Comparativa» o «Flujo de caja» · su pestaña si se configuró | `FinancialReportView` (chips Comparativa y Flujo de caja, guía) | `V/Reports/FinancialReportView.swift`, `V/More/MoreView.swift` | `CashFlowPlan` |
| 18.2 | Comparar este mes con el anterior | Chip Comparativa | Filtros (período, «P-1/A-1»), agrupaciones (Tipo … «Naturaleza») → `GroupingReorderSheet` → tabla → `NetFlowSummaryView` | `V/Reports/FinancialReportView.swift`, `GroupingChipsBar.swift`, `PivotRowView.swift`, `NetFlowSummaryView.swift` | no |
| 18.3 | Crear mi plan de flujo de caja | Chip Flujo de caja sin plan | `CashFlowSetupView` («¿Qué es el flujo de caja?», líneas sugeridas, «¿Con cuánto empiezas?», «Crear mi plan») → `CashFlowTableView` con tour | `V/Reports/CashFlow/CashFlowSetupView.swift`, `CashFlowTableView.swift`, `VM/CashFlowPlanViewModel.swift` | parcial (`CashFlowPlan`, solo monta) |
| 18.4 | Revisar el plan mes a mes | Tira de meses | `CashFlowMonthStrip` → `CashFlowMonthDetailView` → `CashFlowOthersSheet` | `V/Reports/CashFlow/CashFlowMonthDetailView.swift` | no |
| 18.5 | Ajustar el monto de un mes | Tocar una celda | `CashFlowCellDetailSheet` («Solo este mes / Este mes y futuros») | `V/Reports/CashFlow/CashFlowCellDetailSheet.swift` | no |
| 18.6 | Cambiar cómo se calcula una línea | Tocar una línea | `CashFlowLineConfigSheet` (promedios, fijo, tendencia, personalizado; candado Pro) | `V/Reports/CashFlow/CashFlowLineConfigSheet.swift` | no |
| 18.7 | Añadir una línea al plan | «Agregar línea» · «+ Agregar al plan» | `CashFlowAddLineSheet`, `CashFlowOthersSheet` | `V/Reports/CashFlow/CashFlowAddLineSheet.swift` | no |
| 18.8 | Borrar una línea | Pulsación larga en la fila del mes · configuración de la línea | Menú contextual / diálogo | `V/Reports/CashFlow/CashFlowDetailLineRow.swift`, `CashFlowMonthDetailView.swift` | no |
| 18.9 | Cambiar el saldo inicial | Resumen del mes | `EditStartingBalanceSheet` | `V/Reports/CashFlow/CashFlowTableView.swift` | no |
| 18.10 | Configurar el horizonte o reiniciar el plan | Menú ··· | `CashFlowHorizonSheet`, diálogo «Reiniciar plan» | `V/Reports/CashFlow/CashFlowHorizonSheet.swift` | no |
| 18.11 | Ver las gráficas del flujo de caja | Icono de gráfica | `CashFlowChartsSheet` (5 gráficas, chip IA) | `V/Reports/CashFlow/CashFlowChartsSheet.swift` | no |

**Visto en el código:**
- 18.8 está **verificado**: desde el menú, el botón se llama como la pregunta de confirmación y borra sin preguntar.
  Ticket `cashflow-line-context-menu-deletes-without-asking`.
- Reportes está escondido en Más por defecto.
- Jerga: «Naturaleza», «Profundizar», «P-1», «A-1», «Flujo neto», «Acum», «% ejecutado», «Proyección»,
  «Configurar horizonte».
- La guía de la Comparativa explica con color: «Rojo = gastaste más, verde = gastaste menos».
- Sin Pro, el chip de IA de las gráficas ofrece «Insights con IA», no el flujo de caja.

**Tickets abiertos del lote:** `cashflow-line-context-menu-deletes-without-asking`, `financial-report-amounts-unmarked`,
`qa/cashflow-scheduled-line-ignores-payment-currency`, `cashflow-spend-prediction`,
`ipad-reports-and-search-get-a-readable-width`, `multi-currency-accounts-4-reports-and-export`.

---

## Lote 19 · Grupos III: administrar, salir y modos

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 19.1 | Aprobar o rechazar solicitudes | Detalle › Miembros | `GroupMembersView` → ✓/✗ → diálogo → «¿Añadir saldo inicial?» | `V/Groups/GroupMembersView.swift`, `GroupMemberRow.swift` | `GroupMembersAdmin` |
| 19.2 | Cambiar el rol o quitar a un miembro | Menú «…» de la fila | «Cambiar rol» (sin confirmación) · «Quitar» (con aviso si debe) | `V/Groups/GroupMemberRow.swift` | parcial (`GroupMembersAdmin`) |
| 19.3 | Editar el grupo, sus opciones y su presupuesto | Detalle › engranaje | `GroupSettingsView` | `V/Groups/GroupSettingsView.swift` | no |
| 19.4 | Archivar o desarchivar un grupo | Ajustes del grupo · «Ver archivados» | Diálogo → sección de archivados | `V/Groups/GroupSettingsView.swift`, `GroupsContainerView.swift` | no |
| 19.5 | Eliminar el grupo | Ajustes del grupo › «Eliminar grupo» (desactivado con deudas) | «¿Eliminar este grupo?…» | `V/Groups/GroupSettingsView.swift`, `GroupOwnerExitLogic` | no |
| 19.6 | Salir de un grupo, o transferirlo y salir | Ajustes del grupo · tarjeta de solicitud rechazada | Diálogo con aviso de deuda | `V/Groups/GroupSettingsView.swift`, `GroupLeaveErrorLogic` | no |
| 19.7 | Salir de varios grupos a la vez | Ajustes › Vaciar datos › «También salir de mis grupos» | `GroupBatchLeaveView` | `V/Settings/GroupBatchLeaveView.swift`, `SG/GroupBatchLeaveOrchestrator.swift` | `GroupBatchLeave`, `UserDataResetScope` |
| 19.8 | Volver a un grupo migrado o congelado | Banner del detalle | `MigratedGroupBanner` | `V/Groups/GroupDetailView.swift` | no |
| 19.9 | Asociar o desasociar la cuenta de grupos | Ajustes › «¿Dónde viven tus datos?» › Grupos | `GroupsAssociationSection` → `GroupsSignInView` / diálogo «Conservar los gastos que pagué» / «Quitarlo todo del Panel» | `V/Settings/GroupsAssociationSection.swift`, `SG/GroupsAssociationDetach.swift` | `GroupsAssociationRow` |
| 19.10 | Usar Yala solo para grupos | Llegar por invitación o «Vengo por un grupo» sin onboarding personal | Barra reducida a Grupos, Ajustes reducido, nudges | `V/Groups/GroupsContainerView.swift`, `PV`, `SG/BridgeModeResolver.swift` | `ProfileGroupInvite`, `DeeplinkRouting`, `SessionExitsPerCell` |
| 19.11 | Exportar en modo solo grupos | Ajustes › Exportar datos | `GroupsExportView` (CSV directo) | `V/ExportWizard/GroupsExportView.swift` | no |
| 19.12 | Ver un error de sincronización de grupo | Lo lanza la app | Alerta «Hubo un problema con el grupo» | `CV` (`GroupInviteModifier`), `SG/GroupExpenseService.swift` | no |
| 19.13 | Ver que este teléfono no puede sincronizar grupos | Fijo en la pestaña | Banner sin acción | `V/Groups/GroupsContainerView.swift` (`groupsAttestTerminalBanner`) | `GroupsAttestTerminalBanner` |
| 19.14 | Volver tras cerrar la sesión de grupos | Estado vacío «Tus grupos están en tu cuenta» | `GroupsSignInView` | `V/Groups/GroupsContainerView.swift` | no |
| 19.15 | Recibir avisos de grupo (gasto nuevo, recordatorio de pago) | Notificación | `groups/<id>` | `SG/GroupNotificationService.swift`, `GroupSettlementReminderService` | no (sin recorrer) |

**Visto en el código:**
- Hacer admin a alguien es un toque sin confirmación.
- El presupuesto del grupo se teclea dentro de un `.alert`.
- Archivar se pinta en rojo aunque se puede deshacer.
- Se puede salir con deuda: «La otra parte seguirá viendo esa deuda como pendiente».
- Salir de varios grupos solo se alcanza desde «Vaciar datos».
- El texto de desasociar es técnico: «Los apuntes de lo que te deben o debes desaparecen en los dos casos».
- 19.13 no ofrece ninguna acción. 19.14: según su ticket, el banner ya no tiene quién lo encienda.

**Tickets abiertos del lote:** `group-presence-predicates-disagree-on-archived-and-hidden`,
`groups-create-approve-remove-show-a-raw-rpc-error`, `qa/session-exits-one-verb-per-session`,
`groups-signout-reentry-banner-has-no-producer`, `detach-purge-failed-copy-says-groups-remain-after-a-cursor-only-failure`,
`groups-only-session-storage-screen-says-data-lives-in-icloud`, `groups-settlement-reminder-stale-clock`.

---

## Lote 20 · Tus datos: exportar, vaciar, cerrar sesión, nube y avisos del sistema

| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 20.1 | Exportar mis movimientos a CSV o Excel | Ajustes › «Exportar datos» | `ExportFiltersStepView` → `ExportColumnsStepView` → `ExportSummaryStepView` (CSV / Excel) → compartir → «Exportación completada» | `V/ExportWizard/ExportFiltersStepView.swift`, `ExportColumnsStepView.swift`, `ExportSummaryStepView.swift` | `ExportFreePeriods` |
| 20.2 | Exportar antes de vaciar | Vaciar datos › exportar | `UserDataResetView` → `ExportFiltersStepView` | `V/Settings/UserDataResetView.swift` | no |
| 20.3 | Vaciar mis datos | Ajustes › Datos › «Vaciar datos» | `UserDataResetView` → `DestructiveScopeSheet` → «¿Seguro? Esto es definitivo.» | `V/Settings/UserDataResetView.swift` | `UserDataResetScope` |
| 20.4 | Cerrar sesión | Ajustes › Seguridad › «Cerrar sesión» · Tu cuenta de Yala | `DestructiveScopeSheet` → segunda confirmación si no hay copia → progreso → `SignOutRelaunchView` | `PV`, `Yala/Services/CloudSync/CloudSessionSignOut.swift`, `V/Settings/SignOutRelaunchView.swift` | `SessionExitsPerCell` |
| 20.5 | Ver «Tu cuenta de Yala» | Ajustes › Seguridad (solo con cuenta en la nube) | `YalaAccountView` | `V/Profile/YalaAccountView.swift` | `YalaAccount` |
| 20.6 | Eliminar mi cuenta de Yala | Tu cuenta de Yala › «Eliminar mi cuenta» | `DestructiveScopeSheet` → «Esto es definitivo» → «Reintentar» si falla → relanzar | `PV`, `Yala/Services/CloudSync/AccountDeletionService.swift` | `DeleteAccountDialog` |
| 20.7 | Pasar mis datos de iCloud a una cuenta de Yala | Ajustes › «Dónde viven tus datos» › «Activar la nube» (oculto en producción) | `StorageSettingsView` → `CloudConsentView` → `StorageSignInChooserView` → «¿Activar la nube?» → «¿Seguro?» → progreso → «reinicia Yala»; bloqueo `StorageMigrationBlockedView` | `V/Settings/StorageSettingsView.swift`, `StorageSignInChooserView.swift`, `StorageMigrationBlockedView.swift` | `StorageMigrationAttest`, `StorageMigrationIdentityBlock`, `PendingICloudWipeMigration`, `StorageJournalUnreadable` |
| 20.8 | Activar la nube en este dispositivo | Misma pantalla, tarjeta de este dispositivo | Consentimiento → Apple/Google → progreso | `V/Settings/StorageSettingsView.swift` | parcial |
| 20.9 | Volver a iCloud | Storage › «Volver a iCloud» · Tu cuenta de Yala | Dos diálogos → progreso cancelable → relanzar | `V/Settings/StorageSettingsView.swift`, `V/Profile/YalaAccountView.swift` | no |
| 20.10 | Volver a entrar cuando caduca la sesión | Tarjeta de sincronización de Storage | Entrar con Apple/Google | `V/Settings/StorageSettingsView.swift` | no (sin recorrer) |
| 20.11 | Ver el estado de iCloud y forzar la sincronización | Ajustes › iCloud · banner de sincronización | `iCloudSyncSettingsView` («Reintentar», «Diagnosticar», sin cuenta) | `V/Settings/iCloudSyncSettingsView.swift`, `V/Shared/SyncStatusBanner.swift` | no |
| 20.12 | Aviso: iCloud listo tarde | Automático (crítico) | Alerta «Cierra y vuelve a abrir la app…» | `V/Shared/ShellDataAlertsModifier.swift` | no |
| 20.13 | Aviso: datos borrados de iCloud desde otro aparato | Automático (crítico) | Alerta «Datos no disponibles»: «Empezar de cero» / «Seguir esperando» | `V/Shared/ShellDataAlertsModifier.swift`, `CV` | `RemoteWipeNoticeRouting` |
| 20.14 | Aviso: cambiaste de Apple ID | Automático (crítico) | `AppleIDCloseNoticeView` | `V/Shared/AppleIDCloseNoticeView.swift` | `AppleIDCloseNotice` |
| 20.15 | Reabrir Yala tras cerrar sesión o migrar | Fin de 20.4, 20.6, 20.7, 20.9 | `SignOutRelaunchView` («Ve a la pantalla de inicio y vuelve a abrir Yala») | `V/Settings/SignOutRelaunchView.swift` | parcial (`SessionExitsPerCell`) |
| 20.16 | Exportar al cerrar sesión con cambios sin subir | Cerrar sesión con cambios pendientes | Rescate «Exportar» en `PV` | `PV` | no (sin recorrer) |
| 20.17 | Usar el panel de pruebas de la nube (solo builds Dev) | `DEV_BUILD` | `CloudSyncDebugView` | `V/Settings/` | no |

**Visto en el código:**
- No existe exportar a PDF. El subtítulo de exportar solo menciona CSV, aunque también hay Excel.
- Tras exportar antes de vaciar, el final dice «Volver a ajustes» aunque vengas del borrado.
- Varias salidas piden cerrar la app a mano: «Ve a la pantalla de inicio y vuelve a abrir Yala», «Cierra Yala del
  todo (deslízala fuera del selector de apps)».
- En 20.13 el botón destructivo «Empezar de cero» va primero, en un aviso que la persona no provocó.
- 20.7 está oculta en producción por un flag remoto.

**Tickets abiertos del lote:** `export-errors-are-hardcoded-in-spanish`, `exportable-insights`,
`settings-sign-out-scope-says-groups-stay-in-an-account-that-may-not-exist`, `sign-out-wipe-abort-in-icloud-says-nothing`,
`groups-only-account-deletion-skips-export-wait`, `storage-sync-sign-in-count-has-no-plural`,
`forcesync-returns-ok-without-touching-the-network`, `remote-wipe-receiver-has-no-behaviour-test`,
`reverse-tap-on-a-stale-card-aborts-instead-of-starting`.
**Cards de 2.2 que lo cambian:** «Partir la IA según modo nube o privado», «Endurecer el conector MCP en producción».

---

## Fase 2: qué hace cada sesión de lote

*Copiado del encargo de la fase 1 (`encargos/lanzados/2026-10-13-auditoria-ux-flujos-2-2.md`). Cada sesión de lote lo lee aquí.*

Revisar cada flujo del lote con **cinco lentes de usuario**:
1. Conoce apps financieras.
2. Nunca bajó una app financiera, pero sabe registrar sus gastos.
3. Nunca registró sus gastos y probablemente no entiende ciertos términos.
4. Viene de Excel.
5. Quiere lo más fácil posible: no va a leer toda la pantalla ni seguir cincuenta pasos.

Para cada flujo, decidir si ya es amigable para cualquier usuario o si necesita: mejores textos, un proceso más corto,
botones o textos de ayuda, o una UI actualizada (puede haber quedado desfasada con los cambios recientes). Implementar
lo acotado, con **capturas antes/después** (`capturas/antes-*.png`, `capturas/despues-*.png`) siguiendo
`~/Claude/referencias-ui/README.md`, y crear card para lo que necesite decisión de Jürgen.

### Cómo se trabaja un lote (añadido en la fase 1)

1. **Recorre antes de opinar.** Cada flujo se recorre en el simulador antes de decidir nada. Las notas «Visto en el
   código» de este mapa son pistas, no hechos: confírmalas en pantalla y descarta las que no se reproduzcan.
2. **Una tabla de veredictos por lote,** en el PR: flujo · lente que tropieza · qué le pasa · veredicto (*ya está bien*
   / *textos* / *más corto* / *ayuda* / *UI*) · qué se hizo o qué card se abrió.
3. **Lo acotado se implementa** en el mismo PR: textos, un paso que sobra, un botón de ayuda, un orden. Copy nuevo
   según `BRAND-VOICE.md`, en los 16 idiomas.
4. **Lo que cambia el producto va a card de Jürgen,** con la propuesta visual: quitar o fusionar pantallas, cambiar
   qué se pide en el onboarding, cambiar un precio o un límite.
5. **Antes de tocar un flujo, mira sus tickets abiertos** (lista al final de cada lote) y las cards de 2.2 que lo van
   a cambiar. No rehagas lo que una card ya va a rediseñar: déjalo anotado en la tabla.
6. **Capturas:** se sacan en `capturas/` del worktree y, antes del gate, se copian a
   `~/Claude/worktrees/_capturas/<fecha>-<slug>/`, porque el worktree se retira al cerrar.
7. **Simulador:** uno solo, `nice -n 10 xcodebuild -jobs 2`, load < 8, nada de simulador de 9:00 a 11:00 (Lima), y
   `xcrun simctl shutdown all` al terminar.
8. **Si el lote no cabe en una sesión,** se parte por la mitad de su tabla y la segunda mitad abre card nueva.
9. **Al cerrar,** cada flujo del lote tiene veredicto. La card del lote pasa a `qa` si hay device-QA de iPhone, o a
   `done` si no.
