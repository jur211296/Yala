# Clasificación de lo que está en QA — barrido 2.3 antes de la build 7 (23-nov-2026)

Base: `origin/2.3` en `43d8d368b` + el PR de Salud financiera (hoja, nota y negrita), ya mergeado. El PR de Conecta tu IA
(Ajustes › Tu IA) seguía en cola al clasificar. Fuentes: 61 cards «in qa» del tablero (12:50 Lima) y 64 tickets de
`tickets/qa/` en `origin/2.3`. Cada ticket va emparejado con su card cuando tratan lo mismo. Los veredictos del barrido
final del 15-nov (`docs/qa/barrido-2-3-final/lista.md`) y del barrido tras el Flujo de caja del 19-nov
(`docs/qa/barrido-2-3-post-flujo/lista.md`) se reusan cuando el código no cambió desde entonces. Cada suite citada
existe hoy en `origin/2.3`, comprobado con `git grep`.

La columna «Nuevo» marca con ★ lo que entró desde la build 6.

## Recuento

| Destino | Items |
|---|---|
| done (con evidencia) | 60 (30 cards + 30 tickets sin card en QA) |
| simulador: lo pruebo yo | 8 |
| iPhone 14 por DeviceMCP: lo pruebo yo | 2 |
| visto bueno de Jürgen (§2.6) | 6 |
| iPhone de Jürgen (filtro doble §4) | 9 cards en 3 pruebas |
| en espera (infra, credencial, marketing o despliegue) | 10 |
| decisión pendiente | 1 |

Las cards de Jürgen (asignado `jurgen`) se clasifican con el mismo filtro. Moverlas a `done` lo decide la sesión al
cerrar, con la evidencia de aquí.

**Aviso para la build 7 (no es QA):** el esquema de iCloud Production ya tiene `CD_creditLimit`, pero el PR que lo
reexporta y vacía `PersonalCloudKitSchemaParityTests.pendingProductionDeploy` sigue abierto y **sin auto-merge**
(«CloudKit: reexportar esquemas de producción (límite de la tarjeta)»). Mientras no entre, `scripts/asc-preflight.sh`
para la subida. La card de reglas de captura (`cicc`) pide además `CD_captureRulesRaw` en Production antes de subir un
build: hay que comprobarlo en el preflight.

## Simulador: lo pruebo yo

| id | Qué | Caso | Nuevo | Paso concreto | Evidencia previa | Emparejado |
|---|---|---|---|---|---|---|
| m43b | Nuevo registro: hoja B1 con chips en una fila y la pantalla de éxito | 5 | ★ | SE e iPhone 17 Pro, semilla `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista`: Panel › + › guardar un gasto, ver la pantalla de éxito (descripción sobre el monto, Favorito y Recurrente). Cambiar a Ingreso y a Transferencia. «Agregar otro». Repetir con texto al máximo en el SE | `NuevoRegistroB1UITests`, `NuevoRegistroExitoSiempreUITests`, `NuevoRegistroTextoGrande23UITests` | — |
| lplc | «Vaciar mis datos» abre Exportar si lo tocas en el centro | 5 | | Ajustes › Vaciar datos › tocar el centro del botón rojo «Vaciar mis datos»: tiene que salir «¿Vaciar tus datos?», no «Exportar». Salir con Cancelar | `WipeButtonOwnTapWiringTests`, `UserDataResetScopeUITests` | `2026-11-16-bugs-barrido-final-2-3-app` |
| lhxq | Pantalla «Tu IA» en Ajustes: ver, conectar y desconectar | 5 | ★ | Tras mergear el PR de Conecta tu IA: Ajustes › Tu IA en claro y oscuro, en el SE y en el iPad. Lista vacía, y con un conector sembrado si hay seam: desconectar y ver que se va | (llega con el PR de Conecta tu IA) | — |
| vimy | Yala web en el móvil: la página se sale por la derecha | 5 (web) | | Yala web de producción (`app.yala-app.pe`) en un navegador a 390 px: Panel, + Apuntar, Más › Pagos, Estadísticas y Grupos sin desborde lateral. Sin sesión: al menos la pantalla de entrada | `WebGroupsParityGoldenTests` (el arreglo de Grupos del mismo PR) | — |
| — | Límite de la tarjeta y «uso de línea», también en dos monedas | 5 | ★ | Cuentas › tarjeta de crédito con límite › hoja de la cuenta: «uso de línea» con la cifra correcta. Repetir con una tarjeta en soles y dólares (estimado en soles). SE con texto al máximo y oscuro | `LimiteTarjetaUITests`, `LimiteTarjetaDosMonedasTests`, `HojaCuentaTarjetaLogicaTests` | `2026-11-22-cuenta-limite-tarjeta-campo-sincronizado` (la parte de la hoja) |
| — | Flujo proyectado: Panel, Flujo de caja, Tendencias y widget con la misma cifra | 5 | | Semilla `realista`, período «Este mes»: «Al 30 de noviembre» en el Panel (Tendencias › Saldo › Ver proyectado), en Más › Flujo de caja («Terminas con») y en la foto del widget de Saldo. Las tres iguales, sin plan y con plan | Barrido del 19-nov: cuadran en los cuatro aparatos (`docs/qa/barrido-2-3-post-flujo/lista.md`) | `flujo-de-caja-nutre-el-proyectado`, `flujo-proyectado-en-tendencias-y-panel` |
| — | Salud financiera: la hoja con el estilo del Panel, la nota y la negrita | 5 | ★ | Panel › Tu salud financiera › la hoja: tres secciones, «Lo que te queda» en la nota, negrita de Yala IA. Claro y oscuro, SE con texto al máximo, iPad | `SaludFinancieraHojaLoteUITests`, `SaludFinancieraDetalleLogicaTests` | — |
| — | Estadísticas «Lo que te falta pagar», Compromisos y la marca «≈» | 5 | ★ | Estadísticas › Resumen: «Lo que te falta pagar» igual que la cifra de la hoja de salud. Informes con una cuenta en dólares: «≈» delante de lo convertido | `FaltaPagarCompromisosTests`, `MarcaAproximadoInformesYGraficasTests` | — |

## iPhone 14 por DeviceMCP: lo pruebo yo

Pasan el filtro doble (borrado o pérdida de datos con iCloud real, que el simulador no monta), pero los datos del iPhone 14
son de Yala Dev y borrarlos lo decide la sesión. No hace falta la mano de Jürgen salvo que salga Face ID o el código.

| id | Qué | Caso | Qué lo retiene | Guion | Emparejado |
|---|---|---|---|---|---|
| s591 | iCloud privado: «Eliminar mi cuenta» vacía datos, cierra sesión y deja iCloud limpio | 7 | Borrado de datos; el simulador no tiene iCloud | `tickets/qa/2026-11-19-icloud-privado-eliminar-mi-cuenta.md`, «Guion de QA en el iPhone» | `2026-11-19-icloud-privado-eliminar-mi-cuenta` |
| b23b | Tras «Volver a tu iCloud» el iPhone se quedó sin datos | 7 | Pérdida de datos; el espejo real de iCloud no existe en el simulador | `tickets/qa/reverse-on-the-iphone-left-the-local-store-empty.md`, «Guion de device-QA» (Yala Dev contra staging). Pide entrar con una cuenta de Yala: si sale Google con contraseña o Face ID, pasa a Jürgen | `reverse-on-the-iphone-left-the-local-store-empty` |

## Visto bueno de Jürgen (§2.6, fuera de la tanda del iPhone)

| id | Qué se pregunta | Evidencia | Emparejado |
|---|---|---|---|
| ea78 | ¿Convence el texto y el sitio de la tarjeta «Gastos hormiga» en Estadísticas › Resumen? | Barrido del 14-nov; `AntExpensesCalculatorTests`, `ProductividadLote23UITests` | `insights-small-recurring-spending-card` |
| 9nn7 | ¿Se ven bien los logos de suscripción en la lista, la línea de tiempo y el calendario? | Barrido del 14-nov; `SubscriptionBrandCatalogTests` | `scheduled-payments-show-subscription-logos` |
| y6du | ¿Son las sugerencias de descripción que esperabas, y en ese orden? | Barrido del 14-nov; `DescriptionSuggestionLogicTests` | `new-record-suggests-previous-descriptions` |
| v466 | ¿Te gusta que Yala IA pregunte la cuenta antes de cada borrador cuando no hay medio de pago? | Barrido del 14-nov | — |
| fu74 | Repartir un recibo con IA en Grupos: funciona; Jürgen quiere refinar la experiencia | `docs/qa/barrido-2-3-final/evidencia/N01-grupos-ia-reparto-correcto.jpg`, `N02-grupos-ia-gasto-guardado.jpg` | `group-expense-from-a-receipt-with-ai` |
| — | El Welcome y la bienvenida siguen los estilos del resto de la app | Ya resuelto en su sesión; capturas del simulador que saque el barrido | `onboarding-sigue-los-estilos-del-resto-de-la-app` |

## iPhone de Jürgen (pasan el filtro doble de §4)

Agrupadas por montaje. Todas cumplen las dos condiciones: un fallo rompería un flujo principal (entrar, pagar, conectar)
y la parte que importa no se monta en el simulador ni la cubre un test.

| Prueba | Cards | Qué lo retiene (§4) | Dónde |
|---|---|---|---|
| 1. Entrar con Apple, en la app y en la web (y la web por QR) | 188b, 4yc7, ljz7, yzxs | No poder entrar. Apple pide Face ID y el simulador no inicia sesión con Apple. Con Google ya se vio el 15-nov | Yala Dev y `app.yala-app.pe` en Safari del iPhone 14 |
| 2. La prueba de Pro de un mes y la compra real | l1c5, ds65 | No poder pagar. StoreKit en Sandbox solo responde en TestFlight; en Yala Dev el seam dice que compró | TestFlight build 7 con el tester de Sandbox |
| 3. Conecta tu IA de verdad: Claude con Apple o Google, y un borrador que llega a la Bandeja con el nombre de la IA | r8hi, o9b0 | El conector es lo nuevo de 2.3 y entrar con Apple o Google en Claude es la única puerta de un usuario real. Pasa por la cuenta de Claude de Jürgen | claude.ai con el conector de producción, y la Bandeja del iPhone 14 al final |

## Done (con evidencia)

| id | Qué | Caso | Motivo | Evidencia | Emparejado |
|---|---|---|---|---|---|
| c8i9 | Tras «¡Tu cuenta está lista!» el Panel salía vacío | 4 | Arreglado, con el flujo fijado por test y probado en el iPhone 14 por la sesión del arreglo. Si en el recorrido del iPhone 14 se entra con Google sin la mano de Jürgen, mirarlo de paso | `PanelWaitsAfterEmpezarTests`, `WelcomeTrasCuentaListaUITests`, `AccountEntryLandingTests`; `~/Claude/entregas/2026-11-16-bugs-barrido-2-3-app/evidencia/` | `2026-11-16-bugs-barrido-final-2-3-app` |
| xhbn | Cancelar la entrada a una cuenta dejaba gastos de su grupo | 4 | Arreglado; la sesión se suelta al cancelar, con test; probado en el iPhone 14 por la sesión del arreglo | `CancelledEntryReleasesSessionTests`, `WelcomeAdoptExitTests` | `2026-11-16-bugs-barrido-final-2-3-app` |
| 120i | Detalles menores del barrido final (vuelta a iCloud, pasar a la nube, Yala IA en Grupos) | 3 | Ninguno pierde datos; el guardado sin descripción de Yala IA en Grupos ya tiene arreglo y test | `ReceiptSplitDescriptionTests` | — |
| 1jtn | Al cambiar de tema, la hoja de Ajustes quedaba con los colores viejos | 4 | El simulador lo reproduce y el test lo fija | `TemasRepintadoUITests`, `ThemeWindowStyleTests` | — |
| s8ou | Welcome: deslizar deja la tarjeta llena y la mitad derecha avanza | 4 | XCUITest del gesto | `WelcomeCarruselToqueUITests`, `WelcomeCarruselBarrasYToqueTests` | — |
| qx0l | Volver a Yala en un día nuevo no pedía las tasas de hoy | 2 | Cambio de día UTC con la app en segundo plano: difícil de provocar a mano; un «≈» de un día no pierde datos | `TasasDeCambioLogicTests`, `TasasDeCambioConverterTests` | `volver-de-segundo-plano-en-un-dia-nuevo-no-trae-las-tasas` |
| 1mwz | Calendario budista o japonés: tasas con otro año | 3 | Pocos usuarios con ese calendario; claves gregorianas con test | `TasasDeCambioLogicTests`, `TasasDeCambioLimpiezaTests` | `exchange-rate-date-keys-follow-the-phone-calendar` |
| 4afh | El Pro pagado podía no aparecer al entrar | 2 | Carrera del arranque; test que falla sin el arreglo | `AccountEntitlementSyncTests` | `entitlement-sync-forzado-es-noop-si-hay-otro-en-vuelo` |
| pboq | Con Apple solo se entra con el Apple ID del teléfono (card de Jürgen) | 3 | Entrar con otro Apple ID es de pocos usuarios; el bloqueo y su salida los fija el test | `StorageMigrationIdentityBlockUITests`, `StorageMigrationSignInLogicTests` | `cloud-sign-in-cannot-choose-another-apple-id` |
| d1ab | Bienvenida paso 2: voz, foto y Yala IA con prueba de cortesía | 3 | La franja, el candado y el recorrido se ven en el simulador; leer voz y foto es el mismo servicio de la app; un fallo no pierde datos ni bloquea la bienvenida | `Bienvenida23PasosUITests`, `Bienvenida23BaseUITests` | `onboarding-2-3-learn-to-record-courtesy-trial` |
| sj4c | Primeros pasos: intros como historias y la flecha que cae en «Más» | 1 | Posición de la flecha según el tamaño de pantalla; en el simulador ya caía | `PrimerosPasosPulidoCapturasUITests`, `PrimerosPasosPulidoTests` | — |
| phhl | Atajo del banco desde la notificación o el correo | 3 | B0 y B1 probados en el iPhone 14 con un aviso simulado; un aviso real que no se lee no pierde datos | `AtajoBancoB2B3Tests`; `docs/qa/barrido-2-3-final/lista.md` | — |
| qrnv | Captura por foto con el comercio, atajo del banco y suscripciones parte 2 | 4 | Tests del flujo | `CapturaAtajoParte2UITests`, `ComercioFotoCategoriaTests`, `PagosRecurrentesS2Tests` | — |
| k2hd | La cuenta se elige sola al leer una captura (parte 1) | 3 | Con Apple Pay y aviso real solo cambia qué cuenta se propone; si falla, cae en la cuenta por defecto | `CuentaSolaAlLeerUITests`, `CuentaSolaAlLeerEscaleraTests` | — |
| cicc | Cuenta sola al leer, parte 2: reglas de captura | 3 | Igual que la parte 1. Ojo: `CD_captureRulesRaw` en Production antes de subir (aviso arriba) | `CuentaSolaReglasUITests`, `CuentaSolaAlLeerReglasSyncTests` | — |
| h7tp | Límites de Flujo de caja con varios pagos y otra moneda | 4 | XCUITest del flujo; los cuatro campos ya están en iCloud (card en done) | `FlujoLimitesPagosYMonedaUITests`, `CashFlowLimitesPagosYMonedaSyncTests` | — |
| 6vex | Flujo de caja: la gráfica de 6 meses, mantener y tocar un mes (card de Jürgen) | 4 | XCUITest del gesto | `FlujoDetalleLineaUITests` (`test_unSoloCambiar_yTocarUnMesCambiaLosRegistros`) | — |
| 075s | Registros dentro de Estadísticas igual que la pestaña (card de Jürgen) | 4 | XCUITest con capturas | `RegistrosEstadisticasIgualesUITests`, `RegistrosEstadisticasCapturasUITests` | `2026-11-17-registros-estadisticas-identica` |
| rq3c | Tarjetas de cuentas personalizables (card de Jürgen) | 4 | XCUITest del editor; el diseño lo eligió Jürgen | `CardDesignUITests`, `CardLookContrastTests` | — |
| wop2 | Crear un grupo y repartir un gasto con Yala IA (card de Jürgen) | 4 | El simulador cubre hasta la revisión; crear el grupo usa el mismo servidor que «Nuevo grupo» | `IAGuiadosUITests`, `ChatGuidedGroupLogicTests` | — |
| g9yw | Guiados de Yala IA por voz (card de Jürgen) | 3 | La voz solo cambia la entrada del texto; los guiados los fija el test | `IAGuiadosUITests`, `ChatGuidedCreationTests` | `2026-11-15-ia-guiados` |
| wnu7 | Pagos planificados: logo propio con una foto | 4 | XCUITest y sync con test | `PagoLogoPropioUITests`, `PagoLogoPropioSyncTests` | `2026-11-19-pago-planificado-logo-propio-foto` |
| rjsz | Calendario de Registros: la semana a la vista y el iPad | 4 | Rojo sin el arreglo y verde con él, en el iPhone 17 Pro y el iPad | `RecordsCalendarWeek23UITests`, `RecordsCalendarFoldTests` | — |
| 4xrs | Categorías recientes y el buscador que entiende «café» | 4 | XCUITest | `CategoryQuickPick23UITests`, `CategoryQuickPick23Tests` | — |
| 1yeg | Estadísticas: comparación en Tendencias y VoiceOver de las gráficas | 1 | VoiceOver y XCUITest | `Estadisticas23ComparacionVoiceOverUITests`, `Estadisticas23ComparacionHastaHoyTests` | — |
| izvv | Nube: «Cambiar de cuenta» sin saltarse las consecuencias | 4 | XCUITest | `GroupsAssociationRowUITests`, `ChangeAccountG1Tests` | — |
| 1agd | Nube: cifrado y fotos a la vista al activar | 4 | XCUITest rojo antes y verde después | `PendingICloudWipeMigrationUITests` | — |
| anfw | Nube: volver a iCloud y «Activar sin borrar» en una hoja | 4 | Tests de la hoja y del borrado pendiente | `ReturnToICloudSheetLogicTests`, `PendingICloudWipeCloudTests` | — |
| 38yb | VoiceOver: cinco selectores sin nombre | 1 | Accesibilidad | `VoiceOverSelectoresConNombreUITests` | — |
| d8nx | Grupos: pagos que se duplican, dígitos que se pierden | 4 | Cada punto con test rojo sin el arreglo; el guardado fallido sin duplicar entró el 22-nov | `GroupsNecesarias23Lote01Tests`, `GruposGuardadoFallidoTests` | — |
| 8tks | Yala web: en Grupos la web y la app no reconocían a los mismos miembros | 4 | Goldens de paridad web↔app | `WebGroupsParityGoldenTests` | — |
| qf6g | Yala web, lote 3 (Grupos desde la web) | 4 | Lo que falló el 15-nov es 8tks, ya arreglado con goldens | `WebGroupsParityGoldenTests` | — |
| 7yhc | Yala web, lote 2 | 3 | Estadísticas y Pagos cuadraron el 15-nov; el QR con la cámara va en la prueba 1 de Jürgen (yzxs) | `docs/qa/barrido-2-3-final/evidencia/L05-web-estadisticas.jpg` | — |
| ln31 | CI: la imagen macos27 20261112 no encontraba simulador | 8 | El arreglo de la CI entró el 16-nov y la CI de 2.3 pasa desde entonces | PR «CI: el simulador del runner se valida contra los destinos que ve xcodebuild» | — |
| — | Con el texto al máximo, cifras cortadas o partidas | 1 | Tamaños | — | `amounts-cut-or-split-at-the-largest-text-size` |
| — | Con el texto al máximo, la barra de «Guardar» pisa el formulario | 1 | Tamaños | `KeyboardSaveBar23UITests` | `bottom-save-bar-overlaps-the-form-at-the-largest-text-size` |
| — | Enlace largo: «Unirme al grupo» tapa «Pegar» | 1 | Teclado y tamaño | `InviteRecoveryPasteVisibleUITests` | `invite-join-button-covers-paste-with-a-long-link` |
| — | VoiceOver lee «el iPhone» en el iPad | 1 | VoiceOver | `LocalizationParityTests` | `voice-live-transcript-label-says-iphone-on-ipad` |
| — | Yala se cierra por exceso de memoria (Sentry) | 3 | Medido: 16 de 17 eventos eran del iPhone de QA con 2.2; la card ya está en done | Ticket, sección de causas | `app-closed-by-ios-for-memory-yala-ios-b` |
| — | El conector sabe la zona horaria del usuario | 3 | Test | `PreferenceMergeLogicTests` | `app-uploads-its-timezone-to-the-cloud` |
| — | Token de App Attest rechazado sigue guardado | 2 | Solo se provoca rotando el secreto en producción | `AttestSessionTokenLogicTests` | `attest-session-token-rejected-by-the-gateway-stays-cached` |
| — | El alta en la nube escribe el consentimiento antes de tiempo | 2 | Orden interno, con test | `BornCloudSignUpServiceTests`, `CloudConsentRegistrationWiringTests` | `borncloud-consent-epoch-written-before-the-guard-decides` |
| — | Presupuesto de gasto ofrecía «Ingresos» | 4 | Test | `BudgetEditorExpenseCategoriesTests` | `budget-category-picker-offers-income-categories` |
| — | Mover en lote a otra divisa reetiquetaba el importe | 3 | Test | `RecordsViewModelBulkAccountCurrencyTests` | `bulk-move-to-another-currency-account-relabels-the-amount` |
| — | Activar la nube subía miles de elementos | 4 | Medido el 15-nov: 446 elementos | `ExchangeRateDuplicateLogicTests`; `docs/qa/barrido-2-3-final/evidencia/H04-en-tu-icloud-terminado.jpg` | `cloud-activation-uploads-thousands-of-items-for-a-few-records` |
| — | La verificación de «Activar la nube» no cuadraba y volvía a subir | 2 | Bucle de verificación, con tests | `IdentityRemapEmissionTests`, `MigrationJournalUnreadableWiringTests` | `cloud-activation-verify-loops-on-accounts` |
| — | «Activar la nube» y «Volver a iCloud» dicen cuánto falta | 4 | Visto el 15-nov: la vuelta subió «446» con su cifra | `docs/qa/barrido-2-3-final/evidencia/H04-en-tu-icloud-terminado.jpg` | `cloud-progress-shows-real-steps-and-counts` |
| — | «Cuánto puedo gastar hoy» | 4 | XCUITest | `DailyAllowanceUITests`, `DailyAllowanceLogicTests` | `daily-allowance-how-much-can-i-spend-today` |
| — | `ExternalEntryForeignSheetUITests` perdía el importe a veces | 4 | El test es la evidencia; la tanda de rojos del 23-nov cerró las inestables | `ExternalEntryForeignSheetUITests` | `external-entry-panel-link-loses-the-typed-amount-intermittently` |
| — | La hoja de bienvenida de Grupos volvía tras cerrarla | 4 | XCUITest | `GroupsOnboardingCloseUITests` | `groups-intro-sheet-comes-back-after-closing-it` |
| — | «Ya tienes datos» contaba 124 categorías | 3 | Test | `ICloudCorpusCategoryTallyTests` | `icloud-restore-preview-counts-categories-twice` |
| — | Gastos hormiga con IA para Pro | 4 | Su card ya está en done | Ticket | `insights-ant-expenses-ai-version-for-pro` |
| — | Títulos «Octubre De 2026» | 4 | Test | `PanelScheduledPaymentsPeriodLabelTests` | `month-year-titles-capitalize-every-word` |
| — | Tarjeta multidivisa, entrega 2 | 4 | XCUITest | `AccountLinesUITests`, `AccountLineCardViewTests` | `multi-currency-accounts-2-card-view` |
| — | Una cuenta con más de una divisa (paraguas) | 4 | Sus entregas tienen tests; el uso de línea en dos monedas se prueba en el simulador (arriba) | `AccountCardLogicTests`, `LimiteTarjetaDosMonedasTests` | `multi-currency-accounts` |
| — | Entrada por Grupos en la bienvenida | 4 | Pasó el 15-nov en el iPhone 14; la card está en done | `docs/qa/barrido-2-3-final/evidencia/C01-como-empiezas.jpg`, `C02-puerta-grupos-aterriza-en-grupos.jpg` | `onboarding-2-3-groups-entry` |
| — | Preferencias del dueño vuelven por iCloud KV tras cerrar sesión | 2 | Test | `SignOutPreferenceHoldTests` | `owner-preferences-return-via-ikv-after-private-sign-out` |
| — | El ojo del Panel oculta los montos | 4 | XCUITest | `PanelAmountsVisibilityUITests`, `AmountPrivacyTests` | `panel-eye-hides-amounts` |
| — | Con iCloud Drive apagado, un aparato nuevo reiniciaba el Panel de los otros | 3 | Test | `PanelPreferencesMigrationTests` | `panel-fresh-seed-reads-the-icloud-drive-token` |
| — | «Encontramos tus datos en iCloud» a quien solo tiene grupos | 3 | Copy; solo quien restaura con solo grupos | Ticket (resuelto por UX 2.2 L6-5) | `restore-found-copy-says-icloud-for-groups-that-never-were` |
| — | Pago ya pagado: «Ya lo pagué» y «Saltar» nombran el mes | 4 | XCUITest | `ScheduledPaymentsLote10UITests` | `scheduled-payment-actions-name-the-month-they-apply-to` |
| — | Cerrar sesión aceptando perder cambios dejaba una pantalla sin nada | 4 | Tests; cerrar sesión pasó el 15-nov | `SignOutDeferredRoutingTests`, `SignOutWelcomeDestinationTests`; `docs/qa/barrido-2-3-final/evidencia/B01-cerrar-sesion-vuelve-a-bienvenida.jpg` | `sign-out-in-place-leaves-a-screen-with-nothing-to-tap` |
| — | «Esto creará una cuenta nueva sin tus datos previos» | 3 | Test | `WelcomeLote6FixesTests` | `start-fresh-dialog-promises-what-the-gate-undoes` |
| — | Estadísticas y Registros recalculan por filtros con `onChange` | 4 | XCUITest | `StatisticsRecordsFilterObservationUITests` | `statistics-and-records-filter-onchange-may-fall-asleep-like-the-panel` |
| — | El selector de etiquetas desde el Panel no montaba filas | 4 | XCUITest | `TransactionsCrudUITests` (`test_recordSelectorsOpenAtMediumDetent`) | `tag-selector-from-the-panel-form-shows-no-rows-in-2-3` |
| — | Una transferencia en otro idioma crea otra subcategoría | 3 | Test | `TransferCategoryResolverLanguageTests` | `transfer-subcategory-is-looked-up-in-the-current-language` |
| — | Cancelar la entrada y cerrar la app montaba el espejo de iCloud | 4 | Pasó el 15-nov en el iPhone 14 | `WelcomeAdoptBackOutTests`, `FreshStartAfterAdoptExitTests`; `docs/qa/barrido-2-3-final/evidencia/D02-cancelada-vuelve-a-bienvenida.jpg` | `welcome-adopt-cancel-then-close-mounts-the-icloud-mirror` |

## En espera (no es una prueba del barrido)

| id | Qué | Qué espera | Emparejado |
|---|---|---|---|
| 3w7z | Registrar desde correos de alertas del banco | El buzón y el gateway lector, que activan Jürgen o Dan | — |
| i9d8 | Bienvenida 2.3: correo automático | La misma infraestructura de correo | `onboarding-2-3-bank-email-step` |
| vfg1 | «Activar la nube» con pocos datos tarda minutos | Una activación real con una cuenta nueva (TestFlight) | `cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover` |
| pv2l | Endurecer el conector MCP en producción | Despliegue de Dan | `2026-11-21-ia-ampliada-produccion-navegadores-publicada` |
| j93f | Goldens del gateway en serie | Credenciales de staging (`USER_*_PASS`, `GROUPS_ENC_KEY`) | — |
| 3z6j | Coste de tokens por función de IA | Gateway en producción y una semana de datos | — |
| dyhx | Telemetría propia en Cloudflare | Despliegue y su panel | `own-telemetry-panel-by-sections` |
| vfsf | Mezcla con voz de los reels IG semana 3 | Es de Lola (marketing): fuera del territorio de Frank | — |
| — | Campo del límite de la tarjeta sincronizado entre dos equipos | Dos aparatos con la misma cuenta de iCloud; antes, que entre el PR de reexportar el esquema | `2026-11-22-cuenta-limite-tarjeta-campo-sincronizado` |
| — | Navegadores conectados en la app publicada | Que la 2.3 esté en la tienda | `2026-11-21-ia-ampliada-produccion-navegadores-publicada` |

## Decisión pendiente

| Ticket | Qué falta decidir |
|---|---|
| `siri-free-users-on-device-model-awaits-decision` | Si «Anotar con Siri» se enciende para quien no tiene Pro con el modelo del propio iPhone. Está construido y probado (`SiriOnDeviceEntryUITests`); falta el sí o no de Jürgen |
