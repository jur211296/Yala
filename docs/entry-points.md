# Puntos de entrada a Yala

Inventario de todas las formas de entrar a la app, cómo llega cada una al router de presentaciones y en qué orden se
presenta lo que traen. Auditado el 2026-10-10 contra el código (ticket `share-image-reading-does-not-always-start`).
Las funciones se citan por nombre y no por línea: las líneas se mueven. **Si cambias una entrada, cambia su fila.**

## Cómo se coordina una entrada

Todo lo que una entrada quiere presentar pasa por `RouterEntryGate.shared.submit(_:)` → `AppRouter`. El coordinador
tiene cuatro reglas, y ninguna entrada se las salta:

1. **Lo que decide con estado aún sin cargar espera al arranque.** Antes de `AppBootstrapper.isInitialized`, la puerta
   Pro (`StoreKitManager.isProUser` arranca en `false` y se carga en el paso 3), el consentimiento de IA y el eje de la
   sesión no valen. `EntryReadinessLogic` aparta esos enlaces (`shared-image`, `image-entry`, `voice-entry`,
   `new-transaction`, `activate-full`) y el paso 20b del arranque los trata en su orden de llegada. La acción del
   Centro de Control tampoco se consume antes: su clave se queda en el App Group y la lee el paso 21b.
2. **Lo que llega con la app sin poder presentar se aplaza y se conserva.** `RouterEntryGate` difiere `.navigate` y
   `.presentSharedImage` mientras falte el arranque o el onboarding, y `DeferredIntentBuffer` los guarda en disco
   (24 h). `.presentSharedImage` guarda la ruta de la foto y solo vuelve si el fichero sigue ahí. El buffer se drena
   en el paso 20 del arranque, en cada vuelta a primer plano y al completarse el onboarding
   (`resumeEntriesAfterOnboarding`).
3. **Nada se presenta tapado.** Cada consumidor retiene su cola mientras algo esté encima (`RouterConsumerGateLogic`,
   `ContentViewReadinessLogic`). Al cerrarse lo que tapaba, sale lo pendiente. El Panel pregunta además a UIKit si su
   ventana tiene algo presentado (`ModalPresentationProbe`), porque las hojas de OTRA pestaña no publican ningún flag;
   como cerrarlas tampoco avisa a nadie, el Panel vuelve a mirar cada 300 ms mientras solo eso lo retiene. `ContentView`
   y `MainTabView` hacen la misma pregunta para sus avisos **diferibles**; los **críticos** no esperan (tabla de abajo,
   «Avisos con una hoja abierta en otra pestaña»).
4. **Lo que tiene una fuente durable se vuelve a pedir desde ella.** Los intents transitorios se tiran al pasar a
   segundo plano (`AppRouter.resetTransients`); la foto compartida se re-emite desde `PendingImages/` en el arranque y
   en cada vuelta a primer plano, y la invitación desde `PendingJoinStore`. Las entradas que no tienen fuente durable
   —voz, imagen, nuevo registro y el consentimiento de IA que piden— se **aparcan** en `DeferredIntentBuffer` antes de
   tirarlas (`DeferredIntentBufferLogic.parksOnBackground`) y vuelven con su drenaje, salvo que la app pase fuera más de
   15 min (`parkedEntryTTL`): una hoja de dictar que aparece horas después al abrir Yala sorprende. La hoja de Yala Pro
   no se aparca: es un paywall, no lo que la persona pidió. Con la misma caducidad se aparcan los avisos diferibles que
   esperaban a una hoja y no tienen fuente que los vuelva a pedir: la respuesta a un enlace de invitación
   (`showInviteError`, `showGroupArchivedNotice`) y el hito de registros (`presentMilestoneUpgrade`).

## Orden: qué sale primero

La cola ordena por prioridad y, dentro de la misma, por llegada (`RouterIntent.priority`). Cada consumidor presenta en
su anchor, y el de `ContentView` tapa a los demás.

| Prioridad | Qué | Por qué ahí |
|---|---|---|
| `critical` | Avisos de sistema que no pueden esperar (`remoteWipe`, `iCloudMismatch`, `appleIDChangedClosePrivate`) y la respuesta a un enlace de invitación que la persona acaba de tocar (`showInviteError`, `showGroupArchivedNotice`) | O protegen datos, o contestan a un toque que está esperando respuesta |
| `high` | **La foto compartida** (`presentSharedImage`), el consentimiento de IA, el aviso de la Bandeja, el espejo tardío de iCloud, prueba expirada, downgrade | Lo que la persona acaba de pedir desde fuera y los avisos que no deberían esperar al arranque siguiente |
| `normal` | Navegar a una pestaña, abrir un formulario, la oferta de prueba, las pantallas de unirse a un grupo | Pueden esperar a que se cierre lo anterior |
| `low` | Novedades y pedir reseña | Pueden esperar al arranque siguiente |

**Por defecto, propuesto el 2026-10-10 y pendiente de que Jürgen lo confirme:** entre una invitación y una foto
compartida, gana la invitación (va en el anchor de `ContentView`, que tapa al Panel) y la foto espera en cola hasta que
se conteste. Una foto compartida no cierra una hoja con datos sin guardar: espera a que la persona la cierre (un
formulario a medias, Ajustes, el chat, una hoja de otra pestaña). **Desde el 2026-10-12 sí cierra las del Panel que no
tienen nada por guardar** y empieza la lectura (opción B de Jürgen, ticket
`shared-photo-waits-silently-behind-an-open-panel-sheet`): la Bandeja, el registro por imagen en «elige una foto» y el
«?» de un widget sin un tamaño cambiado, siempre que estén solas en la ventana (`SharedPhotoPanelSheetLogic`). Con algo
encima —un borrador en edición, el selector de fotos, un aviso— espera. Ir al Panel desde fuera cambia la pestaña por
debajo de una hoja de otra pestaña **sin cerrarla** (medido el 2026-10-11); lo que la cerraba era que el Panel presentara
encima, y eso ya no pasa (ticket `entry-to-panel-closes-sheets-of-other-tabs`).

## Avisos con una hoja abierta en otra pestaña

Una hoja de otra pestaña (un «Nuevo registro» a medias en Estadísticas, el detalle de un registro) no publica ningún flag.
Lo que `ContentView` o `MainTabView` presentaran encima la cerraba y lo escrito se perdía. Desde el 2026-10-11
(ticket `invite-and-app-notices-present-over-other-tab-sheets`) preguntan a UIKit por la ventana
(`ModalPresentationProbe.isAnythingPresented(in:)`), como el Panel, y cada aviso hace lo que dice esta tabla
(`RouterConsumerGateLogic.waitsForForeignPresentation`, un `switch` sin `default`: un aviso nuevo no compila sin decidir).

| Aviso | Consumidor | Con la hoja abierta | Por qué |
|---|---|---|---|
| Vaciado remoto (`remoteWipe`) | contentView | **Sale al momento** | Integridad de datos: borra lo local |
| Cuenta de iCloud cambiada (`iCloudMismatch`) | contentView | **Sale al momento** | Integridad de cuenta |
| Apple ID cambiado (`appleIDChangedClosePrivate`) | contentView | **Sale al momento** | Seguridad: enseña datos del dueño anterior hasta contestar |
| Datos eliminados de iCloud (`presentRemoteWipeNotice`) | contentView | **Sale al momento** | Integridad de datos |
| Espejo tardío de iCloud (`presentLateICloudMirrorNotice`) | contentView | **Sale al momento** | Integridad: mezcla dos corpus personales mientras no se conteste |
| Onboarding completado en otro aparato (`remoteOnboardingCompleted`) | contentView | **Sale al momento** | Estado de la cuenta; solo actúa con el onboarding abierto |
| Error de grupo (`showGroupSyncError`) | contentView | **Sale al momento** (dudoso) | Un gasto de grupo no llegó a su sitio: se trata como error que impide seguir |
| Activar Yala completo (`presentFullModeActivation`) | contentView | **Sale al momento** (dudoso) | Respuesta a un toque, no un aviso: se toca desde DENTRO de la hoja de Ajustes |
| Paso del organizador de Grupos (`presentGroupsOrganizerStep`) | contentView | **Sale al momento** (dudoso) | Lo encadena el flujo que la persona está conduciendo |
| Aviso de la Bandeja (`showInboxAlert`) | contentView | Espera | Informativo; vuelve desde los borradores si la app sale |
| Oferta de prueba (`presentTrialOffer`) | contentView | Espera | Oferta; vuelve en el arranque siguiente |
| Novedades (`presentWhatsNew`) | contentView | Espera | Informativo; vuelve en el arranque siguiente |
| Enlace de invitación que no vale / grupo archivado (`showInviteError`, `showGroupArchivedNotice`) | contentView | Espera | Invitación; se aparca al salir (15 min) |
| Unirse, entrar o consentir para Grupos; puerta del invitado (`presentGroupsConsent`, `presentGroupsSignIn`, `presentGroupBackendInviteOnboarding`, `presentGroupsInviteNeutralGate`) | contentView | Espera | Invitación; vuelve desde `PendingJoinStore` |
| Prueba expirada (`presentTrialExpired`) | mainTab | Espera | Oferta; su productor la vuelve a pedir |
| Downgrade (`presentDowngradeResolution`) | mainTab | Espera | Aviso; vuelve en el arranque siguiente mientras siga el exceso |
| Hito de registros (`presentMilestoneUpgrade`) | mainTab | Espera | Celebración; se aparca al salir (15 min) |
| Cambiar de pestaña, pedir reseña (`navigate`, `requestAppStoreReview`) | mainTab | Como siempre | No presentan una hoja de Yala; `navigate` no espera detrás de un aviso retenido |

Dos detalles del candado: `.contentView` solo mira la ventana con su matriz libre (si no, retendría la invitación que
derriba la cadena del Welcome, B4-04, detrás del cover que se está yendo), y un diferible retenido no tapa a un crítico
que llegue detrás (`AppRouter.drainNext(for:in:skipping:)`). Como cerrar la hoja no avisa a nadie, los dos vuelven a
mirar cada 300 ms mientras haya algo retenido solo por eso.

## Entradas

| Origen | Cómo llega | Qué presenta (intent → consumidor · prioridad) | Antes del arranque | ¿Se conserva si se aplaza? |
|---|---|---|---|---|
| **Hoja de compartir** (`YalaShare`): aparece con 1 a 100 fotos, guarda las 10 primeras en `PendingImages/` como una tanda (`batch_<tanda>_<nn>_<compartidas>.jpg`, `SharedImageBatch`) y abre `yala://shared-image` | `onOpenURL` (`WindowURLEntry`) → `handleIncomingURL` → `enqueueSharedImage`. El intent lleva UNA foto; la hoja de lectura la expande a su tanda y lee todas | Puerta Pro (se lleva la tanda entera) → `.presentUpgradeSheet(.image)` · o `.navigate(.panel)` + `.presentSharedImage(url)` (panel · high) · o `.requestAIConsent(.image)` si falta el consentimiento | Espera (`EntryReadinessLogic`) y se trata en el paso 20b | Sí: los ficheros son durables, el intent aplazado guarda su ruta |
| Foto compartida que la app no llegó a abrir (la extensión no pudo abrir Yala, o la app murió) | Paso 21 del arranque y cada `.active` → `checkForPendingSharedImage` (`SharedImageRecoveryGate`) | Igual que la fila anterior | Solo corre tras el arranque | Sí, `PendingImages/` (se purga a las 24 h) |
| Recibo soltado en el iPad | `onDrop` → `ReceiptDropHandler` → `presentDroppedReceipt` → `enqueueSharedImage` | Igual que la hoja de compartir; el fallo abre la hoja en su error | Solo en caliente | El fichero, sí |
| Widget o Siri: `yala://voice-entry`, `image-entry`, `new-transaction` | `onOpenURL` → `executeAction` | En una sesión solo grupos, `.presentFullModeActivation` (no hay Panel; desde el lote 15 de la auditoría UX 2.2, antes no pasaba nada). Si no, `.navigate(.panel)` + `.presentVoiceEntry` / `.presentImageEntry` / `.presentNewTransaction` (panel · normal), o la hoja de Pro / el consentimiento, también en el Panel. Lleva al Panel desde el 2026-10-12, como la foto compartida; con una hoja abierta en otra pestaña, la pestaña cambia por debajo y la hoja sale al cerrarse | Espera (`EntryReadinessLogic`) | Sí, si la app sale antes de presentarla: se aparca en `DeferredIntentBuffer` y vuelve al volver (≤ 15 min fuera). La hoja de Pro, no |
| Widget: `yala://panel`, `statistics[/records\|/categories]`, `planning[/scheduled-payments]`, `budgets`, `records`, `groups[/<id>]` | `onOpenURL` → `setOrDeferDeepLink` | `.navigate(destino)` (mainTab · normal) | Se aplaza (`DeferredIntentBuffer`) | Sí, serializable |
| Widget solo-grupos: `yala://activate-full` | `onOpenURL` | `.presentFullModeActivation` (contentView · normal) o `.navigate(.panel)` | Espera (`EntryReadinessLogic`) | No |
| Centro de Control: voz e imagen (`ControlCenterIntents`, escriben `pendingControlAction` en el App Group) | `.active` → `checkForPendingControlAction` | Como `voice-entry` / `image-entry`: lleva al Panel | No se consume; la lee el paso 21b | Sí, la clave del App Group; ya leída, se aparca como `voice-entry` |
| Enlace de invitación `https://yala-app.pe/invite` | `onOpenURL` → `handleInviteLink` (y `YalaAppDelegate.application(_:continue:)`) | `.showInviteError` (critical), pantallas de unirse (contentView · normal), `.showGroupSyncError` (high) | El camino backend persiste en `PendingJoinStore` y lo retoma el reconciliador | Sí, `PendingJoinStore` |
| Vuelta de Google Sign-In | `onOpenURL` → `GIDSignIn.handle` | Nada | — | — |
| Toque en una notificación local (sin categorías ni acciones) | `NotificationService.userNotificationCenter(didReceive:)` → `routeTap` con el `deepLink` del `userInfo`. El delegado lo asigna `YalaAppDelegate.didFinishLaunching` (`installAsCenterDelegate`), antes de que termine el lanzamiento: así llega también el toque que abre la app cerrada | `.navigate(destino)`; `inbox` acaba en la hoja de la Bandeja | Se aplaza | Sí, serializable |
| Apple Pay y Siri en lenguaje natural (no abren la app) | Cola del App Group → `InboundCaptureDrain` en el arranque y en cada `.active` | Borradores en la Bandeja → `.showInboxAlert` (contentView · high) | Se encola sin aplazar | Sí, los borradores |
| Atajos de teclado | `.commands` → `RootCommandPerformer` | ⌘N → `.navigate(.panel)` + `.presentNewTransaction`; el resto, flags de la ventana | Solo en caliente | ⌘N, sí (se aparca como `new-transaction`); el resto, no |
| Ventana nueva o restaurada (iPad) | `SceneRoot.land()` | Flags de la ventana (`pendingGroupID`, `pendingRecordID`) | — | — |
| Push remoto | `YalaAppDelegate` | Nada: sync silencioso | — | — |
| Spotlight, Handoff, accesos rápidos del icono | **No existen** en el código ni en el `Info.plist` | — | — | — |

## Avisos que la app saca sola al entrar

| Aviso | Quién lo pide | Consumidor · prioridad |
|---|---|---|
| Welcome, onboarding, idioma, restaurar | `ContentView` con flags propios, dentro de la matriz de readiness | — (bloquean el router) |
| Forzar actualización, relanzar tras cerrar sesión | `ContentView`, flags dentro de la matriz | — (bloquean el router) |
| Aviso de la Bandeja | Arranque y cada `.active` (`checkForPendingInboxDrafts`) | contentView · high |
| Espejo tardío de iCloud, aviso de datos borrados | `ContentView` (`runLateICloudMirrorCheck`, gracia de 5 s) | contentView · high |
| Prueba expirada, downgrade | `refreshSubscriptionStatus`, `checkForDowngrade` | mainTab · high |
| Oferta de prueba, reanudar «Yala completo» | `ContentView` tras el arranque | contentView · normal |
| Novedades | `ContentView` | contentView · low |
| Alertas de sistema (`iCloudMismatch`, `remoteWipe`, Apple ID cambiado) | Arranque, observadores, `PreferenceSyncService` | contentView · critical |

## Huecos conocidos que siguen abiertos

Con ticket en `tickets/backlog/`:

- `notification-deeplink-accounts-not-parsed`: `ScheduledPaymentNotificationService` manda `deepLink: "accounts"`, que
  `NotificationService.parseDestination` no reconoce; el toque no lleva a ningún sitio.
