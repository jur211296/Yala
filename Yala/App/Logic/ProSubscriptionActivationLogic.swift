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
    }

    /// Última compra/entitlement local que aplicamos. Sobrevive a un
    /// `currentEntitlements` vacío (el reopen Free del ticket) hasta su expiry.
    nonisolated struct LastVerifiedLocal: Equatable, Sendable {
        var productID: String
        var expirationDate: Date?
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

    /// Unión: entitlements actuales O la última verificación vigente.
    /// Vacío en `currentEntitlements` NO apaga Pro si `lastVerified` sigue vivo —
    /// eso es lo que convertía un `.success` (y un reopen) en Free.
    /// Si Apple lista uno de NUESTROS productos y no está vigente (revocado /
    /// caducado), el cache no puede resucitarlo.
    static func localActive(
        entitlements: [TransactionFacts],
        lastVerified: LastVerifiedLocal?,
        now: Date = .now
    ) -> Bool {
        if entitlements.contains(where: { isActiveLocalEntitlement($0, now: now) }) {
            return true
        }
        if entitlements.contains(where: { knownProductIDs.contains($0.productID) }) {
            return false
        }
        return isLastVerifiedStillActive(lastVerified, now: now)
    }

    /// Qué persistir después de ver entitlements (y la compra recién verificada,
    /// que el caller mete en `entitlements`).
    ///
    /// - Hay una activa → esa.
    /// - Apple lista uno de nuestros productos y no está vigente → nil.
    /// - Lista vacía → se conserva `previous` si sigue vigente (lag de StoreKit).
    /// - `previous` ya caducó → nil.
    static func updatedLastVerified(
        entitlements: [TransactionFacts],
        previous: LastVerifiedLocal?,
        now: Date = .now
    ) -> LastVerifiedLocal? {
        if let active = entitlements.first(where: { isActiveLocalEntitlement($0, now: now) }) {
            return LastVerifiedLocal(productID: active.productID, expirationDate: active.expirationDate)
        }
        let sawKnownProduct = entitlements.contains { knownProductIDs.contains($0.productID) }
        if sawKnownProduct { return nil }
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
