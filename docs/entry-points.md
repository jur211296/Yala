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
   como cerrarlas tampoco avisa a nadie, el Panel vuelve a mirar cada 300 ms mientras solo eso lo retiene.
4. **Lo que tiene una fuente durable se vuelve a pedir desde ella.** Los intents transitorios se tiran al pasar a
   segundo plano (`AppRouter.resetTransients`); la foto compartida se re-emite desde `PendingImages/` en el arranque y
   en cada vuelta a primer plano, y la invitación desde `PendingJoinStore`. Las entradas que no tienen fuente durable
   —voz, imagen, nuevo registro y el consentimiento de IA que piden— se **aparcan** en `DeferredIntentBuffer` antes de
   tirarlas (`DeferredIntentBufferLogic.parksOnBackground`) y vuelven con su drenaje, salvo que la app pase fuera más de
   15 min (`parkedEntryTTL`): una hoja de dictar que aparece horas después al abrir Yala sorprende. La hoja de Yala Pro
   no se aparca: es un paywall, no lo que la persona pidió.

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
se conteste. Una foto compartida no cierra una hoja abierta para presentarse: espera a que la persona la cierre (la hoja
podría tener un formulario a medias), sea del Panel o de otra pestaña. Ir al Panel desde fuera cambia la pestaña por
debajo de una hoja de otra pestaña **sin cerrarla** (medido el 2026-10-11); lo que la cerraba era que el Panel presentara
encima, y eso ya no pasa (ticket `entry-to-panel-closes-sheets-of-other-tabs`).

## Entradas

| Origen | Cómo llega | Qué presenta (intent → consumidor · prioridad) | Antes del arranque | ¿Se conserva si se aplaza? |
|---|---|---|---|---|
| **Hoja de compartir** (`YalaShare`): aparece con 1 a 100 fotos, guarda las 10 primeras en `PendingImages/` como una tanda (`batch_<tanda>_<nn>_<compartidas>.jpg`, `SharedImageBatch`) y abre `yala://shared-image` | `onOpenURL` (`WindowURLEntry`) → `handleIncomingURL` → `enqueueSharedImage`. El intent lleva UNA foto; la hoja de lectura la expande a su tanda y lee todas | Puerta Pro (se lleva la tanda entera) → `.presentUpgradeSheet(.image)` · o `.navigate(.panel)` + `.presentSharedImage(url)` (panel · high) · o `.requestAIConsent(.image)` si falta el consentimiento | Espera (`EntryReadinessLogic`) y se trata en el paso 20b | Sí: los ficheros son durables, el intent aplazado guarda su ruta |
| Foto compartida que la app no llegó a abrir (la extensión no pudo abrir Yala, o la app murió) | Paso 21 del arranque y cada `.active` → `checkForPendingSharedImage` (`SharedImageRecoveryGate`) | Igual que la fila anterior | Solo corre tras el arranque | Sí, `PendingImages/` (se purga a las 24 h) |
| Recibo soltado en el iPad | `onDrop` → `ReceiptDropHandler` → `presentDroppedReceipt` → `enqueueSharedImage` | Igual que la hoja de compartir; el fallo abre la hoja en su error | Solo en caliente | El fichero, sí |
| Widget o Siri: `yala://voice-entry`, `image-entry`, `new-transaction` | `onOpenURL` → `executeAction` | `.presentVoiceEntry` / `.presentImageEntry` / `.presentNewTransaction` (panel · normal), o la hoja de Pro / el consentimiento. No lleva al Panel: con otra pestaña delante, espera a que la persona vuelva a él | Espera (`EntryReadinessLogic`) | Sí, si la app sale antes de presentarla: se aparca en `DeferredIntentBuffer` y vuelve al volver (≤ 15 min fuera). La hoja de Pro, no |
| Widget: `yala://panel`, `statistics[/records\|/categories]`, `planning`, `budgets`, `records`, `groups[/<id>]` | `onOpenURL` → `setOrDeferDeepLink` | `.navigate(destino)` (mainTab · normal) | Se aplaza (`DeferredIntentBuffer`) | Sí, serializable |
| Widget solo-grupos: `yala://activate-full` | `onOpenURL` | `.presentFullModeActivation` (contentView · normal) o `.navigate(.panel)` | Espera (`EntryReadinessLogic`) | No |
| Centro de Control: voz e imagen (`ControlCenterIntents`, escriben `pendingControlAction` en el App Group) | `.active` → `checkForPendingControlAction` | Como `voice-entry` / `image-entry` | No se consume; la lee el paso 21b | Sí, la clave del App Group; ya leída, se aparca como `voice-entry` |
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

- `invite-and-app-notices-present-over-other-tab-sheets`: las pantallas de unirse a un grupo (`.contentView`) y los
  avisos de `MainTabView` (prueba expirada, downgrade, hitos) presentan sin mirar si hay una hoja de otra pestaña
  abierta; el arreglo del Panel no los cubre.
- `notification-deeplink-accounts-not-parsed`: `ScheduledPaymentNotificationService` manda `deepLink: "accounts"`, que
  `NotificationService.parseDestination` no reconoce; el toque no lleva a ningún sitio.
- `widget-and-siri-entries-wait-for-the-panel-tab`: voz, imagen y nuevo registro desde un widget o Siri no llevan al
  Panel (la foto compartida sí): con otra pestaña delante, esperan sin aviso a que la persona vuelva a él. Falta decidir
  si deben llevar al Panel.
