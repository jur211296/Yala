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

    /// Purga las superficies durables del App Group. Segunda red además de esta purga:
    /// `rehydrateOutboxFromMirror` (personal y grupos) aplica owner-scoping DURO por `userID` (ya
    /// implementado — defensa en profundidad).
    static func purge() {
        WidgetDataCache.clearCache()

        // Colas de entrada + snapshot de contexto de Siri. SSOT compartido con el boot-cleanup del
        // sign-out en `.cloud` (`SwiftDataConfiguration.performSignOutWipeIfArmed`), que sufría el
        // MISMO daño por la misma razón: allí el store personal muere por borrado de archivos y una
        // cola superviviente se materializa en la cuenta siguiente.
        AppGroupInboundPurge.purgeInboundSurfaces()

        SyncOutboxMirror()?.purgeAll()
        PrefsOutbox()?.purgeAll()
        // M1/D8 (G5-C): el espejo App Group del outbox de GRUPOS lleva `fieldsJSON` con MONTOS del dueño
        // → no debe sobrevivir la frontera de la sesión secundaria. El owner-scoping por `userID` del
        // rehydrate es la primera línea; esta purga es la segunda (belt ratificado por el brief).
        GroupsOutboxMirror()?.purgeAll()

        // HALLAZGO 1 del review G5-C (HIGH): las superficies de JOIN-INTENT viven en
        // `UserDefaults.standard` SIN scoping por sesión (`PendingJoinStore` key compartida,
        // `GroupJoinIntentTracker`, consent de grupos). Con grupos habilitados en secundaria (flag ON),
        // la invitada puede crear intents de invite; un intent que sobreviva la frontera se ejecutaría
        // bajo el DUEÑO al volver (reconcile(.boot) → presentGroupsSignIn del grupo de la invitada →
        // redimir SU token con la cuenta equivocada). La purga corre en AMBAS fronteras (entrada y
        // salida), idempotente; el dueño en `.icloud` no tiene consent backend legítimo que pisar.
        PendingJoinStore.clearAll()
        GroupJoinIntentTracker.shared.clear()
        GroupsConsentState.clear()
        // Y la señal EN MEMORIA del tap, que es el caso peligroso de verdad en esta frontera: un arm
        // puesto por la persona A y consumido con la sesión de la persona B mandaría la solicitud de
        // entrada al grupo de A con la cuenta de B.
        GroupBackendInviteEntryHandler.clearInviteTapArms()
    }
}
