//
//  StoreKitManager+Attest.swift
//  Yala
//
//  Expone la transacción firmada de la suscripción activa para que el gateway verifique el
//  entitlement Pro server-side (firma de Apple), sin confiar en un flag spoofable del cliente.
//

import StoreKit

extension StoreKitManager {
    /// JWS firmado por Apple de la suscripción auto-renovable activa (no revocada, vigente).
    /// `jwsRepresentation` vive en `VerificationResult`, así que re-iteramos los entitlements
    /// (ocurre 1× por refresh de token, ~cada 15 min). El gateway lo verifica offline contra G3.
    func fetchActiveTransactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result, txn.productType == .autoRenewable else { continue }
            guard txn.revocationDate == nil, (txn.expirationDate ?? .distantFuture) > .now else { continue }
            return result.jwsRepresentation
        }
        return nil
    }
}
