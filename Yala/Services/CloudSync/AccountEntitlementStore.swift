//
//  AccountEntitlementStore.swift
//  Yala
//
//  Caché local del entitlement Pro de la CUENTA de Yala (C-8, 2026-07-27). Molde
//  `CloudClaimActionStore`: UserDefaults, `defaults` inyectable, `@MainActor` porque la sesión que
//  lo alimenta (`CloudAuthService`) lo es.
//
//  Por qué se cachea: el derecho debe sobrevivir a un arranque sin red. El `expiresAt` lo firma
//  Apple y lo verifica el gateway, así que un snapshot vigente es tan legítimo offline como lo que
//  StoreKit concede en local — pero SOLO para su dueño (`userID` va DENTRO del snapshot y
//  `ProEntitlementLogic` lo compara con la sesión viva).
//
//  UNA sola entrada, no un diccionario por cuenta: el device tiene una sesión de nube a la vez, y
//  guardar el historial de cuentas anteriores sería una fuga sin ninguna ganancia. Cambiar de cuenta
//  PISA la entrada; cerrar sesión la BORRA (`CloudSessionSignOut`).
//

import Foundation

@MainActor
final class AccountEntitlementStore {

    /// Instancia de producción (UserDefaults.standard). Los tests inyectan su propio `defaults`.
    static let shared = AccountEntitlementStore()

    private let defaults: UserDefaults
    private static let key = "cloudSync.accountEntitlement"

    /// `defaults` inyectable (nunca `.standard` directo en tests — regla del repo).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Snapshot cacheado, o `nil` si no hay ninguno / está corrupto. Un JSON ilegible se trata como
    /// ausente (el refresco lo repone) — jamás como "sin derecho" persistente.
    func read() -> AccountEntitlementSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(AccountEntitlementSnapshot.self, from: data)
        } catch {
            #if DEBUG
            print("AccountEntitlementStore: snapshot ilegible, se descarta: \(error)")
            #endif
            return nil
        }
    }

    /// Persiste el snapshot (idempotente — pisa el anterior, incluido el de otra cuenta).
    func write(_ snapshot: AccountEntitlementSnapshot) {
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.key)
        } catch {
            #if DEBUG
            print("AccountEntitlementStore: Error guardando snapshot: \(error)")
            #endif
        }
    }

    /// Borra la caché. Lo llaman las FRONTERAS de cuenta (sign-out, entrada secundaria): el derecho
    /// de una cuenta jamás debe sobrevivir a la salida de esa cuenta.
    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
