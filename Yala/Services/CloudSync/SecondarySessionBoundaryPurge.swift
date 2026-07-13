//
//  SecondarySessionBoundaryPurge.swift
//  Yala
//
//  Purga E2E-M1 de las superficies DURABLES del App Group en las FRONTERAS de la sesión
//  secundaria (entrada Y salida). El App Group es compartido entre cuentas — sin esta purga:
//  el widget de lock-screen muestra saldos de la otra cuenta; las colas de Apple Pay/Siri y
//  `PendingImages/` del dueño se materializarían como `InboxDraft` en el store de la invitada
//  (los `processPending` no distinguen owner); y los deltas del espejo del outbox (con montos)
//  cruzarían identidades. Requisito VINCULANTE del diseño (E2E-M1, serio — owner 2026-07-06,
//  ver MODO-NUBE-GAPS-E2E-3FASES + GUARDARRAÍL M1 en ARQUITECTURA §d.5).
//
//  Todas las operaciones son idempotentes — el caller (hooks de boot en SwiftDataConfiguration)
//  re-ejecuta completo tras un kill a mitad (marker AL FINAL).
//

import Foundation

enum SecondarySessionBoundaryPurge {

    /// Purga las 6 superficies. Segunda red además de esta purga: `rehydrateOutboxFromMirror`
    /// aplica owner-scoping DURO por `userID` (ya implementado — defensa en profundidad).
    static func purge() {
        WidgetDataCache.clearCache()

        ApplePayPendingStore.remove(keys: ApplePayPendingStore.peekAll().map(\.key))
        SiriPendingStore.remove(keys: SiriPendingStore.peekAll().map(\.key))

        for url in SharedContainerService.pendingImageURLs() {
            SharedContainerService.removePendingImage(at: url)
        }

        SyncOutboxMirror()?.purgeAll()
        PrefsOutbox()?.purgeAll()
    }
}
