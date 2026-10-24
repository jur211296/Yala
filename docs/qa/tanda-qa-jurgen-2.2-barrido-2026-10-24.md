# Tanda de QA de Jürgen — 2.2, barrido del 2026-10-24

Barrido con `/barrido-qa` (card `barrido-de-qa-2-2-dejar-en-qa-solo-lo-qu-fzmv`) sobre `origin/2.2` en `03fa38a03`
(#615). Para lo que sigue en «in qa», sustituye a la tanda del 18-oct (`tanda-qa-jurgen-2.2.md`): las pruebas de esa
tanda que siguen vivas están aquí, y las que se cerraron hoy ya no. Los guiones detallados de Grupos siguen en las
tandas de cada lote (`tanda-qa-jurgen-2.2-lote13-grupos-crear.md`, `…-lote14-grupos-invitar.md`); aquí se dice cuál
correr y en qué orden.

## Resumen

- **Revisadas:** las 72 cards de Yala en «in qa».
- **Pasan a done: 28**, cada una con su evidencia en la nota de la card. La evidencia es de hoy, sobre
  este árbol: 162 tests unitarios en 18 suites (162/162) y 49 XCUITest en 13 suites (49/49, el simulador para mí solo toda la corrida).
- **Salen de QA sin cerrarse: 2.** `n5zw` (iCloud Drive apagado) vuelve a la cola: su arreglo ya falló en tu iPhone el
  19-oct y no ha tenido segunda vuelta. `qb1r` (idioma de la app) queda bloqueada: **falla en el simulador** (abajo).
- **Bug nuevo: 1.** Tras elegir otro idioma en Ajustes › Personalización › «Idioma de la app», la app no vuelve a
  Personalización y el botón de Ajustes deja de responder hasta cerrar Yala. Reproducido 2 de 2. Card
  `tras-cambiar-el-idioma-desde-personaliza-6d71`, lista para lanzar; capturas en
  `~/Claude/worktrees/_capturas/2026-10-24-barrido-qa-2-2/qb1r-*.png`.
- **No son mías: 2** (`b4es` y `eukp`, de Lola, marketing). No las toqué.
- **Se quedan para ti: 40.** La mayoría piden tu iPhone o tu iPad (§4); 5 piden tu visto bueno a capturas, a
  un texto o al widget (§5).
- **Tiempo estimado: unos 2 h 30 min** de teléfono, repartidos en montajes, y 5 min de capturas.

Los ids van sin el prefijo `tablero-`. §4 es «solo en un aparato real»; §5 es «tu visto bueno».

## Qué bloquea 2.2

| Card | Por qué bloquea | Montaje |
|---|---|---|
| `ux-2-2-l12-17-se-pide-cuenta-y-consentim-046l` | La card lo marca: quien abre una invitación tiene que ver el grupo antes de crear cuenta | A1 |

Lo demás no bloquea por sí solo. Las de compras (montaje D) conviene correrlas antes de mandar la versión a revisión.

## Antes de empezar

1. **Yala Dev** compilado desde `2.2` (Xcode 27.1), contra staging, para los montajes A, B, D y E.
2. **TestFlight de 2.2** para el montaje C. Si no hay ninguno subido, ese montaje espera.
3. **Cuenta de sandbox** de Apple para el montaje D (Ajustes › App Store › Cuenta de sandbox).
4. **Antes del montaje B4**, despliega los tres campos de iCloud de 2.2: `docs/despliegue-cloudkit-2-2.md` (las cards
   «Desplegar…» a tu nombre). Sin eso, el favorito con destino y el ajuste «Desde <mes>» no llegan al otro iPhone.

## Las pruebas, por montaje

### A · Un iPhone con Yala Dev contra staging y una cuenta de prueba (unos 55 min)

**A1 · Unirse por invitación: el grupo antes de la cuenta** (`046l`) · §4 inicio de sesión real. BLOQUEA.
Montaje A §2 de `tanda-qa-jurgen-2.2-lote14-grupos-invitar.md` (~6 min).

**A2 · Invitar y el permiso de avisos** (`x468`, `d4ad`) · §4 cuenta real y el permiso real de iOS.
Montaje A §1 y §2.6 de la tanda del lote 14 (~6 min).

**A3 · Crear el primer grupo** (`mhtg`, `c42m`, `5tex`, `i104`) · §4 sesión real y servidor.
Pruebas 1, 2 y 3 de `tanda-qa-jurgen-2.2-lote13-grupos-crear.md` (~12 min). En la prueba 1, en la hoja «… está
listo», toca «Invitar por WhatsApp u otra app»: sale la hoja de compartir con el enlace (`i104`).

**A4 · Avisos de grupo por el otro camino** (`fptw`) · §4 sesión real y el permiso de iOS. Pasos 1-3 de la nota de la
card (~5 min): borra y reinstala Yala Dev › sin grupos, + del Panel › «Grupo» › «Crear grupo» › en el gasto sale
«Avisos del grupo» › «Activar avisos». El paso 4 (la tarjeta una vez arriba de la lista) va en el montaje B.

**A5 · Volver por «Vengo por un grupo»** (`ewvm`) · §4 Google real contra staging. Guion de la card (~5 min): cerrar
sesión y volver a entrar con la misma cuenta no pide «Grupos en la nube» ni tu nombre.

**A6 · Google en un iPhone que usó Apple** (`qqo7`) · §4 dos inicios de sesión reales. Guion de la card (~3 min).

**A7 · Reabrir solo para lo privado** (`ypit`) · §4 cuenta real de la nube. Pruebas A y B de la card (~6 min).

**A8 · Pantalla negra al elegir «Vengo por un grupo»** (`apsn`) · §4 App Attest. Guion de la card (~4 min): la
presentación de Grupos en 1-2 s; si tarda, logo sobre morado, nunca negro.

**A9 · Activar la nube y volver a iCloud** (`ppxk`, `igt9`, `27z3`, `gulp`) · §4 iCloud real y sesión real (~12 min).
Primero aprueba las capturas (abajo). Luego, en Yala Dev con datos:
1. Perfil › «Dónde viven tus datos» › «Activar la nube»: los pasos avanzan, «Subir tus datos» lleva su cifra («650 de
   1537») y cambia cada pocos segundos; si sale «Esperar a iCloud», «Cancelar» se puede tocar. Apunta la hora de
   inicio y la de «Nube activa» (`ppxk`, `igt9`).
2. Ya en la nube, «Volver a iCloud»: sale **una** pregunta con «Sí, volver a iCloud» y «Cancelar» (`gulp`). Sigue:
   la pantalla dice en cada momento qué hace y la cifra baja (`27z3`).

**A10 · Lote 5 con Apple y Google** (`k4gd`) · §4 inicio de sesión real. Bloque B1 de `tanda-qa-jurgen-2.2.md`.

**A11 · «Importación completada»** (`trc6`) · §4 el fallo era de tiempo en un iPhone real. Perfil › «Importar
archivo» › `movimientos-qa-1500.csv` › una cuenta › «Importar»: sale «Importación completada» con la cifra. Repítelo dos
veces: sale las tres (~3 min).

**A12 · El widget con «Sin categoría»** (`1a5m`) · §5 el widget dibujado. Con un gasto sin categoría este mes, añade el
widget «Categorías que más gastan»: sale un trozo gris «Sin categoría» y el total cuadra con el Panel (~1 min).

### B · Dos dispositivos (unos 25 min)

**B1 · Unirse y esperar aprobación** (`7xnd`, `ywm1`) · §4 dos dispositivos y push real. Montaje A §3 y §4 de la
tanda del lote 14 (~10 min).

**B2 · Hacer y quitar administrador** (`pbcq`) · §4 dos teléfonos con dos cuentas. Guion en
`tickets/backlog/groups-set-member-role-deploy.md` (~5 min). Ya desplegado en staging y producción.

**B3 · Lote 5: terminar el onboarding en el otro** (`k4gd`) · §4 dos dispositivos. Bloque C1 de
`tanda-qa-jurgen-2.2.md`. Y de paso el paso 4 de `fptw`: en el segundo iPhone, la tarjeta «Avisos del grupo» sale una
vez arriba de Grupos; sales y vuelves, y ya no está.

**B4 · Campos nuevos de iCloud** (`qp67`, `ax7s`) · §4 dos iPhone con el mismo iCloud, **tras desplegar** los campos.
1. iPhone A: Reportes › Flujo de caja › mes siguiente › Salario › «Ajustar monto» › 9000 › «Ese mes y los
   siguientes». En B, al rato: ese mes y los siguientes dicen «Desde <mes>» y 9,000; los anteriores no cambian.
2. iPhone A: Nuevo registro › Transferencia › origen y destino › «Favorito» › Guardar. En B, Ajustes › Favoritos lo
   enseña «origen → destino».

### C · TestFlight de 2.2 contra producción (unos 40 min)

**C1 · Entrar con tu cuenta** (`hov2`) · §4 cuenta de producción. Borra Yala, instala el TestFlight, «Ya tengo una
cuenta» con tu cuenta del grupo y cronometra hasta «¡Tu cuenta está lista!». Pásame la hora.

**C2 · La primera foto** (`vv0k`) · §4 TestFlight, compra sandbox y App Attest. Tras instalar y suscribirte, Registrar
con foto de un recibo: se lee a la primera, o el aviso dice el motivo. Pásame la hora si falla.

**C3 · Activar la nube en producción** (`ppxk`) · el paso 1 de A9, ahora en TestFlight.

**C4 · Apple Pay en dólares** (`i9rh`; comprueba de paso L15-8) · §4 automatización de Wallet. Paga en $ con la
tarjeta: la notificación dice «Pago de US$ … en <comercio> por revisar» · «Tócalo para aprobarlo.»; al tocarla, la
Bandeja trae el borrador en la línea USD de la tarjeta.

**C5 · Siri** (`egjm`, `wewa`, `laik`) · §4 Siri por voz, iOS 27 y Apple Intelligence. Guiones de cada card:
`egjm` (5 min, desbloqueado y bloqueado), `wewa` (5 min, en alemán) y `laik` (10 min, iPhone 15 Pro o posterior,
español e inglés, con y sin Apple Intelligence).

**C6 · Accesos del icono al actualizar** (`vq9a`) · §4 actualizar encima. Con el TestFlight de 2.2 encima de 2.1 y
sin cerrar Yala antes: mantén pulsado el icono › «Nuevo registro» abre Nuevo registro. Luego ciérrala del todo, mantén
pulsado el icono: salen «Nuevo registro», «Registrar por voz» y «Foto o archivo»; «Foto o archivo» abre Registrar con
foto o archivo.

**C7 · App Attest con Xcode** (`g8rc`) · §4 App Attest. **El último del día**, porque sustituye la Yala de TestFlight:
Xcode › scheme «Yala» en Debug › tu iPhone › una pregunta a Yala IA: contesta, sin 401.

### D · Compras en sandbox (unos 25 min)

Una sola cuenta de sandbox, en este orden, porque cada paso deja el teléfono listo para el siguiente:

1. **Comprar desde la voz** (`fleb`): siendo gratis, Panel › Voz › «Probar Pro gratis 1 mes» › compra › «Comenzar»:
   se abre la voz escuchando, sin hojas de Pro debajo.
2. **Tour Pro** (`k4gd`): bloque C2 de `tanda-qa-jurgen-2.2.md`.
3. **Fin de la prueba** (`u5pi`): Ajustes › Icono de la app › Neón. Cancela en «Gestionar» y espera a que caduque.
   Reabre Yala: **una** hoja «Tu prueba de Pro terminó» con «Tu icono de Yala vuelve al original»; confirma: el icono
   vuelve (con la alerta de iOS) y no sale una segunda hoja.
4. **Renovar** (`7c97`): con más de 4 cuentas o 3 presupuestos, «Tu suscripción terminó» › «Renovar» › compra ›
   «Comenzar»: vuelves a Yala sin la hoja. Si la hoja vuelve a salir, avísame.

### E · Tu iCloud real (unos 10 min)

**E1 · Volver con datos no enseña las guías** (`ds09`) · §4 restaurar de verdad. Guion de la card: borra, reinstala,
«Ya tengo una cuenta» › restaurar desde iCloud; ninguna «GUÍA» ni el tour de Ajustes. Control: instalación nueva ›
«Es mi primera vez» sí las enseña.

### F · iPad (unos 10 min; no bloquea)

**F1** `qo1l` (dos ventanas, cerrar sesión en una) y **F2** `neah` (soltar un PDF con Ajustes abierto, y tres fotos):
guiones de cada card.

### G · Web publicada

**G1** `aw34`: montaje B de la tanda del lote 14, cuando la web de invitación de 2.2 esté publicada.

## Para aprobar con capturas (sin iPhone, 5 min)

| Card | Qué miras | Capturas |
|---|---|---|
| `igt9`, `27z3` | Los pasos con su cifra de «Activar la nube» y «Volver a iCloud» | `~/Claude/worktrees/_capturas/2026-10-23-activar-la-nube-progreso-2-2/antes-*.png` y `despues-*.png` |
| `17ec` | La tarjeta con una fila por línea y «Total ≈» en el Panel, y su ficha | `~/Claude/entregas/Yala--tarjeta-varias-divisas-entrega-2/capturas/despues-1-panel.png`, `despues-2-ficha.png`, `despues-2b-ficha-linea-usd.png` |
| `gulp` | El texto de la confirmación de «Volver a iCloud» | «Tus datos vuelven a vivir en este iPhone y en tu iCloud. No pierdes nada.» |

## Lo que pasó a done hoy

| Card | Evidencia (corrida de hoy sobre `03fa38a03`) |
|---|---|
| `ptdt` | BalanceFutureDatedCutoffTests en verde hoy sobre 2.2 @ 03fa38a03 (un movimiento de mañana no cuenta en el saldo, la cifra, la curva por cuenta ni el widget; cuenta cuando llega su día, y la foto del widget se rehace al cambiar de día). Una liquidación de grupo con fecha futura es un movimiento más para ese corte. Más la medida en el simulador del PR #556. |
| `2yze` | la acción ejecutada desde Atajos en el simulador abre la hoja de Pro (captura del PR #581) y SiriOnDeviceEntryUITests + SiriEntryRouteTests en verde hoy (sin Pro y sin modelo → hoja de Pro). Lo que solo hace Siri por voz va en el paso 6 del guion de laik, que se queda. |
| `h65m` | ApplePayNotificationCopyTests y ApplePayCurrencyHintTests en verde hoy (el texto «Pago de … por revisar · Tócalo para aprobarlo.» y la moneda de la última cuenta usada cuando llega sin símbolo). La notificación real la verás en la prueba de Apple Pay de i9rh, que se queda: lleva esa comprobación. |
| `pfur` | YalaProLote06UITests en verde hoy (test_themeWall_showsThePreviewOfTheTappedTheme, test_iconWall_showsThePreviewOfTheTappedIcon) y SettingsLote15UITests (test_proEnded_withProTheme_saysTheThemeGoesBack), más las capturas antes-10/despues-10 del PR #561. El cambio real de icono con la alerta de iOS va en el paso 5 de u5pi. |
| `ou7o` | YalaProLote06UITests en verde hoy (test_trialBanner_lastFiveDays_showsDaysPriceAndManage, test_trialBanner_hiddenBeforeTheLastFiveDays) y las capturas antes-07/despues-07 del PR #561. |
| `e0bd` | YalaProLote06UITests en verde hoy (test_proActive_showsPlanCardManageAndWhatHappensIfYouCancel, test_proActive_renewalOff_saysEnds) y las capturas antes-08/despues-08 del PR #561. «Gestionar o cancelar» abre la hoja de Apple, que es del sistema. |
| `k8qc` | YalaProLote06UITests en verde hoy (test_settingsRow_showsStatus_andPaywallExplainsTheTrial y test_voiceGate_titleSaysWhatHappens_plansInside_tryProFree, con la oferta de un mes de la configuración de StoreKit). El texto sale del periodo de la oferta, no de un literal, así que el sandbox enseña lo mismo. |
| `5l7h` | SettingsLote15UITests/test_permissions_openInsideYala_withEachState en verde hoy (cada permiso con su estado y su botón a Configuración). |
| `xj9h` | SettingsLote15UITests/test_rateAndRecommend_bothRows en verde hoy (las dos filas; Recomendar abre compartir con el enlace). Valorar abre el enlace de reseña de la App Store, que el simulador no tiene: es una URL fija del código. |
| `xael` | SettingsLote15UITests/test_privacy_opensInsideYala en verde hoy (privacidad y términos dentro de Yala, «Listo» vuelve). |
| `wd7k` | YalaAILoteDecidido07UITests/test_personalization_proCanHideTheButton_andFindsTheToneAndTheSummary en verde hoy (con Pro, el interruptor «Yala IA» existe y oculta el botón). |
| `unct` | YalaAILoteDecidido07UITests/test_topics_areGroupedByArea_andALogExampleLandsInTheBox en verde hoy (temas por áreas con tus datos; el ejemplo de Apuntar queda en la caja sin enviarse). La respuesta de la IA a una pregunta no es de este cambio. |
| `y9vp` | YalaAILoteDecidido07UITests/test_draftCard_saysExpenseWithItsSign_andSaveAllNeedsTwoCompleteOnes en verde hoy («Gasto» con el importe en negativo y «Guardar los N» con dos completos). |
| `o7ae` | TransactionFormDecided02UITests en verde hoy: test_firstRecords_fullScreen_editWithoutChangesClosesWithoutAsking, test_afterThreeRecords_noticeWithUndo_restoresTheBalance, test_afterThreeRecords_openingAnotherFormRetiresTheNotice y test_afterThreeRecords_editFromTheNotice_opensTheRecord: las dos ramas, Deshacer contra el saldo y Editar. |
| `4ues` | el hechaCuando pedía vídeo antes/después con y sin «Reducir movimiento» en un PR mergeado, y está en el PR #602 (mergeado el 23-oct). La parte de «Reducir movimiento» es accesibilidad: la das por buena. La vibración ligera es UIImpactFeedbackGenerator(.light) del sistema (DesignTokens), que el simulador no reproduce. |
| `dxow` | UXAudit22Lote04UITests en verde hoy: test_privateCellWithoutAccount_rowSaysRemoveMyData_aloneAtTheEnd_andItsSheetToo (fila y hoja dicen «Quitar mis datos») y test_privateSignOut_waitShowsTheUploadCard_andTheNoticeOffersExportFirst (el aviso de los 45 s dice «Quitar mis datos igualmente», al final, y nunca «Cerrar sesión igualmente»). |
| `wtme` | UXAudit22Lote04UITests/test_privateSignOut_waitShowsTheUploadCard_andTheNoticeOffersExportFirst en verde hoy: tarjeta de subida durante la espera y, a los 45 s, Exportar · Esperar · Quitar mis datos igualmente en ese orden. Desde el PR #595 el último botón dice «Quitar mis datos igualmente» (card dxow), no «Cerrar sesión igualmente». |
| `vlc4` | UXAudit22Lote04UITests/test_yalaAccount_showsTheEmail_andDataLocationIsARow en verde hoy (el correo de la sesión arriba y «Dónde viven tus datos» como fila). La lectura de VoiceOver es accesibilidad. |
| `2ogb` | ExportBeforeLosingItUITests en verde hoy (cerrar sesión sin copia ofrece «Exportar antes» y exportar no cierra la sesión) y DestructiveScopeLogicTests/exportBefore_onlyWhereSomethingIsLostForGood (eliminar la cuenta de la nube ofrece el mismo «Exportar antes», con la misma hoja). |
| `l8hc` | UXAudit22Lote11DecididasUITests/test_reportEditor_saysWhatWillArrive_andTestExplainsAMissingPermission en verde hoy (la línea con lo que llegará y «Probar» sin permiso) y ReportUpcomingTests (el lunes cuenta la semana cerrada y dice «La semana pasada»; el mensual del día 1 nombra el mes cerrado). |
| `7t42` | UXAudit22Lote11DecididasUITests en verde hoy (test_proObservations_doNotAskForATap: con Pro sale solo, sin tocar; test_proObservations_withoutConsent_offerTheButtonInPlace) e InsightsAIResultStoreTests (se reutiliza el último resultado mientras no cambian los datos ni el período, y se pide otro cuando cambian). |
| `v5p0` | ScheduledPaymentNotificationServiceTests/dueToday_carriesThePaymentID_andTheAppAmountFormat (el aviso lleva el id del pago y el monto con el formato de la app), NotificationColdLaunchTapTests (el toque llega con su destino) y ScheduledPaymentsLote10UITests/test_reminderTap_opensThatPaymentsDetail (abre el detalle de ese pago), en verde hoy. |
| `nezl` | ScheduledPaymentNotificationServiceTests (el aviso de la tarjeta lleva su id), NotificationColdLaunchTapTests y ScheduledPaymentsLote10UITests/test_cardReminderTap_opensTheAccountSheet (abre la ficha de esa tarjeta), en verde hoy. |
| `q680` | PendingICloudWipeMigrationUITests/test_activationSheet_isOneStep_andCancelStops en verde hoy (una sola hoja con Apple y Google, «Exportar una copia antes», «Ver los detalles» con el texto legal y «Cancelar» que no arranca nada). |
| `q33i` | la misma hoja de L20-11, PendingICloudWipeMigrationUITests/test_activationSheet_isOneStep_andCancelStops en verde hoy (tres líneas, «Ver los detalles» y «Exportar una copia antes»). |
| `0xrh` | UXAudit22Decidido14UITests/test_wholeMessage_leavesTheCleanLink_andThePasteButtonIsThere en verde hoy (pegar el mensaje entero de WhatsApp deja el enlace limpio, y el botón «Pegar» está). El toque al «Pegar» lo maneja iOS. |
| `ivwq` | es la misma prueba que la card de despliegue pbcq, que se queda para ti. Lo de esta card (opción B implementada y mergeada, PR #588) está hecho y desplegado; la prueba con dos teléfonos vive en pbcq. |
| `dbxp` | AccountCardReportsUITests en verde hoy (informe, flujo de caja y exportación por tarjeta) y AccountCardAIContextTests (lo que recibe Yala IA describe la tarjeta una vez, con sus líneas en su moneda y el total marcado como aproximado, sin sumar soles con dólares). Lo que contesta el modelo con ese contexto no es de este cambio. |

## Lo que se queda y qué lo retiene

| Card | Lo retiene | Montaje |
|---|---|---|
| `046l` | §4 inicio de sesión real y servidor | A1 |
| `x468` | §4 mandar el enlace de verdad desde una cuenta real | A2 |
| `d4ad` | §4 permiso real de iOS tras crear o unirse con sesión real | A2 |
| `mhtg`, `c42m`, `5tex` | §4 sesión real y servidor | A3 |
| `i104` | §4 el enlace se acuña con una cuenta real | A3 |
| `fptw` | §4 crear el grupo con sesión real; permiso de iOS | A4, B3 |
| `ewvm` | §4 Google real contra staging | A5 |
| `qqo7` | §4 Apple y luego Google, reales | A6 |
| `ypit` | §4 cuenta real de la nube | A7 |
| `apsn` | §4 App Attest (el tiempo de arranque) | A8 |
| `ppxk` | §4 iCloud real y App Attest (el tiempo) | A9, C3 |
| `igt9`, `27z3` | §5 capturas + §4 subida real | Capturas, A9 |
| `gulp` | §5 el texto + §4 Yala Dev en la nube | Capturas, A9 |
| `k4gd` | §4 Apple/Google, dos dispositivos y compra sandbox | A10, B3, D |
| `trc6` | §4 el fallo de tiempo solo salía en un iPhone real | A11 |
| `1a5m` | §5 el widget dibujado (la galería del simulador no respondió) | A12 |
| `7xnd`, `ywm1` | §4 dos dispositivos y push | B1 |
| `pbcq` | §4 dos teléfonos con dos cuentas | B2 |
| `qp67`, `ax7s` | §4 campo nuevo de iCloud entre dos iPhone, tras desplegarlo | B4 |
| `hov2` | §4 cuenta de producción en TestFlight | C1 |
| `vv0k` | §4 TestFlight, compra sandbox y App Attest | C2 |
| `i9rh` | §4 automatización de Apple Pay | C4 |
| `egjm`, `wewa`, `laik` | §4 Siri por voz, iOS 27, Apple Intelligence | C5 |
| `vq9a` | §4 actualizar encima de 2.1 | C6 |
| `g8rc` | §4 App Attest | C7 |
| `fleb`, `u5pi`, `7c97` | §4 compras reales en sandbox | D |
| `ds09` | §4 restaurar de tu iCloud real | E1 |
| `qo1l`, `neah` | §4 iPad real | F |
| `aw34` | la web de 2.2 publicada | G1 |
| `17ec` | §5 el diseño de la tarjeta | Capturas |
