//
//  AppGroupInboundPurge.swift
//  Yala
//
//  Purga de las superficies de ENTRADA que viven en el App Group: las colas cross-launch que la
//  app materializa como `InboxDraft` al abrir (Apple Pay, Siri, imágenes compartidas) y el
//  snapshot de contexto que lee el intent de Siri.
//
//  Existe porque el App Group es COMPARTIDO entre cuentas y sobrevive al borrado de los stores.
//  En toda frontera donde el store personal muere o cambia de dueño, una cola superviviente se
//  drena contra el store SIGUIENTE (`ApplePayDraftService`/`SiriDraftService`/recuperación de
//  imágenes no distinguen owner) y crea borradores con montos y comercios de la cuenta anterior.
//
//  Un llamador: `SwiftDataConfiguration.performSignOutWipeIfArmed` — boot-cleanup del sign-out en
//  `.cloud` (y del cierre local tras borrar la cuenta). Corre PRE-MOUNT, antes de que nadie drene nada.
//
//  COSTE ACEPTADO: purgar es DESTRUCTIVO para el propio usuario en un caso soportado — el sign-out
//  `.cloud` conserva el claim-store, así que la MISMA cuenta puede re-entrar por adopt, y un pago de
//  Apple Pay encolado y aún sin materializar se pierde en silencio. Se acepta porque el usuario acaba de
//  pedir un cierre que borra TODOS sus datos locales (el wipe devuelve el device a "recién instalado"),
//  una cola pendiente ES un dato local no materializado, y el boot-hook NO puede saber qué cuenta
//  iniciará sesión después: conservarla filtraría montos y comercios a una cuenta ajena, que es el daño
//  mayor e irreversible de los dos.
//
//  LOS CIERRES PRIVADOS NO PAGAN ESE COSTE (2026-09-26, ticket `private-exit-loses-unmaterialized-inbound-captures`).
//  Desde el paso 9 también arman este borrado la privada, el «equipo» y solo-grupos, y ahí iCloud se queda: quien
//  vuelve suele ser la misma persona. Cuando esos cierres esperan al export, cada recuento convierte antes en
//  borrador lo que espera en las colas (`InboundCaptureDrain.forSignOut`), así que viaja a iCloud como cualquier
//  cambio; lo que no se pudo convertir cuenta como pendiente y el aviso lo incluye. Esta purga sigue igual: es la
//  frontera de privacidad. En un cierre privado solo le llega lo capturado DESPUÉS del arm (la sesión ya estaba
//  cerrada) o lo que la persona aceptó perder. La nube y M1 siguen purgando sin materializar. Y con el borrado
//  armado nadie drena al store condenado (`InboundCaptureDrain.drain`).
//
//  NO es una enumeración exhaustiva del App Group. Fuera quedan, a propósito, las superficies de ámbito
//  DEVICE (`isProUser` sigue a la suscripción del Apple ID, `pendingControlAction` es transient, el
//  override de idioma es preferencia de device) y las del dominio GRUPOS — ver el doc-comment de
//  `DataWipeService.removeUserPreferenceKeys`. Que este helper no las incluya NO significa
//  que sobrevivan al sign-out `.cloud`: `PendingJoinStore`/`GroupJoinIntentTracker` mueren ahí dentro de
//  `DataWipeService.resetForSignOutWipe` (vía `AppRouter.resetAll`) y el consent lo limpia el propio
//  `performSignOutWipeIfArmed` tras escribir `.icloud`. (Corrección 2026-07-21: este comentario decía
//  que el `.cloud` NO tocaba las de grupos «porque con el flag OFF el store de grupos sobrevive» —
//  razonamiento stale por partida doble: con el flag ON ese mismo hook BORRA los archivos de
//  `YalaGroups` vía `signOutWipeIncludesGroups`, y el `PendingJoinStore` que decía proteger ya moría
//  allí de todos modos.) Y hay al menos una de ámbito CUENTA que esta purga NO cubre:
//  `lastUsedAccountID` (el `shortcutID` que `ApplePayDraftService` usa para elegir cuenta) — en el
//  sign-out `.cloud` lo barre `DataWipeService.resetAllUserPreferences`, pero en las fronteras M1 no lo
//  barre nadie (residual conocido y benigno: el UUID no resuelve en el store de la invitada).
//
//  Idempotente: los callers la re-ejecutan completa tras un kill a mitad. Residual inherente al diseño
//  cross-proceso (preexistente, heredado de M1): una entry que el intent encole ENTRE el `peekAll` y el
//  `remove` sobrevive — ventana de microsegundos, sin compare-and-swap disponible en CFPreferences.
//

import Foundation

enum AppGroupInboundPurge {

    /// Vacía las colas de entrada y el snapshot de contexto de Siri.
    static func purgeInboundSurfaces() {
        ApplePayPendingStore.remove(keys: ApplePayPendingStore.peekAll().map(\.key))
        SiriPendingStore.remove(keys: SiriPendingStore.peekAll().map(\.key))

        // Snapshot que el intent de Siri lee sin abrir SwiftData: nombres de subcategoría (pueden ser
        // propios del usuario) + divisa. La app lo reconstruye en su próximo `refresh` (bootstrap /
        // foreground), así que dejarlo ausente es seguro — `read()` devolviendo `nil` es un estado
        // esperado (primer uso post-instalación).
        SiriIntentContextCache.clear()

        for url in SharedContainerService.pendingImageURLs() {
            SharedContainerService.removePendingImage(at: url)
        }
    }
}
