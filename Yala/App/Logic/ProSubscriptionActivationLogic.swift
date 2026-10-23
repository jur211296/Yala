//
//  ProSubscriptionActivationLogic.swift
//  Yala
//
//  Lógica PURA del borde «Apple dijo .success / restaurar» → «¿es Pro de verdad?»
//  (bug TF 2.1 b11: el sheet de éxito salía con la app en Free).
//
//  Lo que el manager hacía mal, medido en el código y no en la hipótesis:
//   1. Tras `.success` ponía `didJustSubscribe = true` SIEMPRE, sin mirar `isProUser`.
//   2. La Transaction verificada de la compra se `finish()`-eaba y se tiraba: el Pro
//      salía solo de `Transaction.currentEntitlements`, que en sandbox puede llegar
//      vacío un instante (y a veces seguir vacío al reabrir).
//   3. Restaurar no decía nada si no había derecho.
//
//  Este tipo no toca StoreKit. El manager le pasa HECHOS de transacciones ya
//  verificadas; aquí se decide si hay derecho local, si se celebra y qué feedback
//  lleva el restore.
//

import Foundation

nonisolated enum ProSubscriptionActivationLogic {

    static let knownProductIDs: Set<String> = [
        "com.yala.pro.monthly",
        "com.yala.pro.yearly",
    ]

    /// Hechos de una Transaction ya verificada. Sin StoreKit para poder testear el borde.
    nonisolated struct TransactionFacts: Equatable, Sendable {
        var productID: String
        var productTypeIsAutoRenewable: Bool
        var revocationDate: Date?
        var expirationDate: Date?
        /// El `originalID` de la suscripción: lo comparten sus renovaciones y la vuelta a suscribirse en el mismo
        /// grupo, y no lo comparte la de otro Apple ID. `nil` = no se sabe.
        var originalID: UInt64? = nil
    }

    /// Última compra/entitlement local que aplicamos. Sobrevive a un
    /// `currentEntitlements` vacío (el reopen Free del ticket) hasta su expiry.
    nonisolated struct LastVerifiedLocal: Equatable, Sendable {
        var productID: String
        var expirationDate: Date?
        /// El `originalID` de la transacción verificada. `nil` en lo que guardó un build anterior al 2026-10-22.
        var originalID: UInt64? = nil
    }

    /// ¿Esta transacción es un derecho Pro LOCAL vigente?
    /// Producto conocido, auto-renovable, no revocada, no caducada (`>` en el borde,
    /// igual que el expiry de cuenta en `ProEntitlementLogic`).
    static func isActiveLocalEntitlement(
        _ facts: TransactionFacts,
        now: Date = .now
    ) -> Bool {
        guard knownProductIDs.contains(facts.productID) else { return false }
        guard facts.productTypeIsAutoRenewable else { return false }
        guard facts.revocationDate == nil else { return false }
        if let expiration = facts.expirationDate, expiration <= now { return false }
        return true
    }

    static func isLastVerifiedStillActive(
        _ last: LastVerifiedLocal?,
        now: Date = .now
    ) -> Bool {
        guard let last, knownProductIDs.contains(last.productID) else { return false }
        if let expiration = last.expirationDate, expiration <= now { return false }
        return true
    }

    /// ¿Esta transacción caducada es la suscripción VIEJA, ya sustituida por el derecho verificado? Tras renovar una
    /// suscripción terminada, StoreKit sigue listando un rato la transacción caducada y aún no la nueva; leída como
    /// veredicto, dejaba Free a quien acababa de pagar y borraba su compra verificada, y la hoja «Tu suscripción
    /// terminó» volvía a salir (card `tablero-al-renovar-desde-tu-suscripcion-termino-7c97`, 2026-10-22).
    ///
    /// Una transacción caducada de la MISMA suscripción nunca desmiente un derecho verificado que aún no ha vencido: si
    /// caducó, caducó antes que él, así que es un periodo anterior. Lo único que quita ese derecho antes de tiempo es una
    /// revocación (reembolso, familia), y una revocada no entra aquí. «La misma» es el mismo `originalID`: la caducada
    /// de OTRO Apple ID en este teléfono sí es un veredicto, o el derecho guardado del anterior sobreviviría a ella. Sin
    /// `originalID` o sin fecha en cualquiera de los dos lados no se pueden situar, y manda Apple, como antes.
    static func isSupersededExpiredListing(
        _ facts: TransactionFacts,
        lastVerified: LastVerifiedLocal?,
        now: Date = .now
    ) -> Bool {
        guard knownProductIDs.contains(facts.productID), facts.revocationDate == nil,
              let expired = facts.expirationDate, expired <= now,
              let subscription = facts.originalID, subscription == lastVerified?.originalID else { return false }
        return lastVerified?.expirationDate != nil && isLastVerifiedStillActive(lastVerified, now: now)
    }

    /// ¿Apple lista uno de NUESTROS productos sin derecho vigente y que no sea la suscripción vieja ya sustituida? Es
    /// su veredicto: el derecho guardado no puede contradecirlo.
    private static func listsAVerdictAgainst(
        _ lastVerified: LastVerifiedLocal?,
        in entitlements: [TransactionFacts],
        now: Date
    ) -> Bool {
        entitlements.contains {
            knownProductIDs.contains($0.productID)
                && !isSupersededExpiredListing($0, lastVerified: lastVerified, now: now)
        }
    }

    /// Unión: entitlements actuales O la última verificación vigente.
    /// Vacío en `currentEntitlements` NO apaga Pro si `lastVerified` sigue vivo —
    /// eso es lo que convertía un `.success` (y un reopen) en Free.
    /// Si Apple lista uno de NUESTROS productos y no está vigente (revocado /
    /// caducado), el cache no puede resucitarlo — salvo que sea la suscripción vieja
    /// que el derecho guardado ya sustituyó (`isSupersededExpiredListing`): tras renovar,
    /// esa lectura dejaba Free a quien acababa de pagar.
    static func localActive(
        entitlements: [TransactionFacts],
        lastVerified: LastVerifiedLocal?,
        now: Date = .now
    ) -> Bool {
        if entitlements.contains(where: { isActiveLocalEntitlement($0, now: now) }) {
            return true
        }
        if listsAVerdictAgainst(lastVerified, in: entitlements, now: now) {
            return false
        }
        return isLastVerifiedStillActive(lastVerified, now: now)
    }

    /// Qué persistir después de ver entitlements (y la compra recién verificada,
    /// que el caller mete en `entitlements`).
    ///
    /// - Hay una activa → esa.
    /// - Apple lista uno de nuestros productos y no está vigente → nil, salvo la
    ///   suscripción vieja que `previous` ya sustituyó (`isSupersededExpiredListing`).
    /// - Lista vacía → se conserva `previous` si sigue vigente (lag de StoreKit).
    /// - `previous` ya caducó → nil.
    static func updatedLastVerified(
        entitlements: [TransactionFacts],
        previous: LastVerifiedLocal?,
        now: Date = .now
    ) -> LastVerifiedLocal? {
        if let active = entitlements.first(where: { isActiveLocalEntitlement($0, now: now) }) {
            return LastVerifiedLocal(productID: active.productID, expirationDate: active.expirationDate,
                                     originalID: active.originalID)
        }
        if listsAVerdictAgainst(previous, in: entitlements, now: now) { return nil }
        if let previous, !isLastVerifiedStillActive(previous, now: now) {
            return nil
        }
        return previous
    }

    /// NUNCA celebrar si sigue Free. Es la regla que el manager violaba con
    /// `didJustSubscribe = true` incondicional.
    static func shouldCelebratePurchase(isProUser: Bool) -> Bool {
        isProUser
    }

    enum RestoreOutcome: Equatable, Sendable {
        case restoredPro
        case noEntitlement
    }

    static func restoreOutcome(isProUser: Bool) -> RestoreOutcome {
        isProUser ? .restoredPro : .noEntitlement
    }
}
