//
//  ProEntitlementLogic.swift
//  Yala
//
//  Lógica PURA de «¿este usuario tiene Pro?» cuando el derecho puede venir de DOS sitios
//  (bug C-8 de la auditoría de escenarios, 2026-07-27).
//
//  El hallazgo: `isProUser` salía solo de `StoreKit.Transaction.currentEntitlements`, que está
//  scoped al Apple ID firmado en App Store. Quien migra a la nube justamente para no depender de
//  Apple y entra con su cuenta de Yala en un device con OTRO Apple ID VE SUS DATOS Y PIERDE PRO
//  SOBRE ELLOS — con el límite de creación aplicado a un corpus que ya lo excede.
//
//  Las dos fuentes y su jerarquía:
//   - LOCAL (`currentEntitlements`): la suscripción del Apple ID de este device. Manda siempre que
//     esté activa — a quien paga en ESTE device jamás se le quita Pro por un fallo de red.
//   - CUENTA (`/account/entitlement`): la suscripción vinculada a la cuenta de Yala, verificada
//     server-side contra la firma de Apple. El `expiresAt` cacheado también viene de Apple, así que
//     vale OFFLINE hasta esa fecha: no regala nada que StoreKit no concediera en local.
//
//  DARK por defecto: con `resolutionEnabled == false` (hoy en producción, hasta desplegar el
//  gateway) el veredicto es EXACTAMENTE el de antes del fix.
//

import Foundation

/// Entitlement de la CUENTA tal y como se cachea en el device. `nonisolated` + `Codable` porque el
/// snapshot cruza aislamiento (bajo `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` un `Codable` que
/// viaje entre contextos debe declararlo explícito).
nonisolated struct AccountEntitlementSnapshot: Codable, Equatable {
    /// Cuenta DUEÑA del derecho (`sub`). Es parte del snapshot a propósito: una caché sin dueño se
    /// aplicaría a la siguiente cuenta que entre en el device — la clase exacta de fuga del handover.
    let userID: String
    let product: String?
    /// Expiración firmada por Apple. `nil` = sin suscripción vinculada.
    let expiresAt: Date?
    /// Cuándo se leyó del backend (gobierna el refresco, no la validez).
    let refreshedAt: Date
}

nonisolated enum ProEntitlementLogic {

    /// Tope de la gracia offline. El `expiresAt` lo firma Apple, pero un snapshot cacheado no puede
    /// valer indefinidamente sin volver a hablar con el backend: una fecha lejana (bug de unidades,
    /// backend comprometido, plan anual) daría Pro perpetuo a un device que ya no puede revalidar
    /// nada. 30 días es holgado para un viaje sin red y corto frente a la vida de una suscripción.
    static let offlineGrace: TimeInterval = 30 * 24 * 3600

    /// Hasta cuándo vale un snapshot SIN volver a consultar: lo que Apple firmó, acotado por la
    /// gracia offline desde la última lectura real del backend.
    static func effectiveExpiry(_ snapshot: AccountEntitlementSnapshot) -> Date? {
        guard let expiresAt = snapshot.expiresAt else { return nil }
        return min(expiresAt, snapshot.refreshedAt.addingTimeInterval(offlineGrace))
    }

    /// Reglas EN ORDEN:
    /// 1. `localActive` → `true` SIEMPRE. La suscripción del Apple ID de este device es la verdad
    ///    más fuerte y no depende de red: jamás degradar a Free a quien acaba de pagar aquí.
    /// 2. `!resolutionEnabled` → `false`. DARK: byte-idéntico al comportamiento previo al fix.
    /// 3. Sin sesión de nube (`sessionUserID == nil`) → `false`. Sin cuenta no hay derecho de cuenta.
    /// 4. `snapshot.userID != sessionUserID` → `false`. La caché es de OTRA cuenta: no vale para
    ///    esta ni un segundo (mismo invariante que la purga de frontera de cuenta).
    /// 5. `effectiveExpiry > now` → `true`. Vigente según Apple Y dentro de la gracia offline.
    static func isPro(
        localActive: Bool,
        snapshot: AccountEntitlementSnapshot?,
        sessionUserID: String?,
        resolutionEnabled: Bool,
        now: Date = .now
    ) -> Bool {
        if localActive { return true }
        guard resolutionEnabled, let sessionUserID else { return false }
        guard let snapshot, snapshot.userID == sessionUserID else { return false }
        guard let expiry = effectiveExpiry(snapshot) else { return false }
        return expiry > now
    }

    /// ¿Hay que consultar el backend? Reglas EN ORDEN:
    /// 1. Sin sesión → `false` (no hay a quién preguntar).
    /// 2. Sin caché → `true` (primera vez en esta cuenta).
    /// 3. Caché de otra cuenta → `true` (cambió el dueño; la vieja no se reutiliza jamás).
    /// 4. **Caché sin derecho vigente → `true`, sin esperar al intervalo.** Es la regla que impide
    ///    el peor bug de esta capa: una mensual que renueva a las 11:30 deja el snapshot caducado a
    ///    las 11:31, y con el throttle a secas el pagador se quedaría en Free hasta 6 h — con red,
    ///    con la renovación ya cobrada y con el flujo destructivo de downgrade esperándole. El
    ///    intervalo acota el tráfico del estado ESTABLE, no puede gobernar el borde de renovación.
    /// 5. Más vieja que `minInterval` → `true`. La validez NO depende de esto (la gobierna
    ///    `effectiveExpiry`), así que una caché "vieja" pero vigente sigue dando Pro sin red.
    static func shouldRefresh(
        snapshot: AccountEntitlementSnapshot?,
        sessionUserID: String?,
        minInterval: TimeInterval = 6 * 3600,
        now: Date = .now
    ) -> Bool {
        guard let sessionUserID else { return false }
        guard let snapshot else { return true }
        if snapshot.userID != sessionUserID { return true }
        if let expiry = effectiveExpiry(snapshot), expiry <= now { return true }
        if snapshot.expiresAt == nil { return true }
        return now.timeIntervalSince(snapshot.refreshedAt) >= minInterval
    }
}
