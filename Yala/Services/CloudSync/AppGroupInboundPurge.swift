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
//  Dos llamadores, misma razón, un solo SSOT:
//  - `SecondarySessionBoundaryPurge.purge()` — fronteras de la sesión secundaria M1 (entrada y salida).
//  - `SwiftDataConfiguration.performSignOutWipeIfArmed` — boot-cleanup del sign-out en `.cloud`
//    (y del cierre local tras borrar la cuenta). Corre PRE-MOUNT, antes de que nadie drene nada.
//
//  COSTE ACEPTADO: purgar es DESTRUCTIVO para el propio usuario en un caso soportado — el sign-out
//  `.cloud` conserva el claim-store, así que la MISMA cuenta puede re-entrar por adopt, y un pago de
//  Apple Pay encolado y aún sin materializar se pierde en silencio. Se acepta porque el usuario acaba de
//  pedir un cierre que borra TODOS sus datos locales (el wipe devuelve el device a "recién instalado"),
//  una cola pendiente ES un dato local no materializado, y el boot-hook NO puede saber qué cuenta
//  iniciará sesión después: conservarla filtraría montos y comercios a una cuenta ajena, que es el daño
//  mayor e irreversible de los dos.
//
//  NO es una enumeración exhaustiva del App Group. Fuera quedan, a propósito, las superficies de ámbito
//  DEVICE (`isProUser` sigue a la suscripción del Apple ID, `pendingControlAction` es transient, el
//  override de idioma es preferencia de device) y las del dominio GRUPOS — ver el doc-comment de
//  `DataWipeService.removeUserPreferenceKeys` y el de `SecondarySessionBoundaryPurge.purge()`, que sí
//  barre las de grupos porque en M1 la frontera cruza identidades y en el sign-out `.cloud` NO (con el
//  flag OFF el store de grupos sobrevive: barrer un `PendingJoinStore` vivo ahí mataría un intent de
//  join legítimo del mismo Apple ID). Y hay al menos una de ámbito CUENTA que esta purga NO cubre:
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
