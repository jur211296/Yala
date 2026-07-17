//
//  PendingInviteStore.swift
//  Yala
//
//  Persiste el invite de grupo pendiente (share URL + branded fields) para que
//  sobreviva a background y a kill del proceso. Los intents
//  `.presentGroupInviteOnboarding` / `.presentGroupReconnect` son transient:
//  `AppRouter.resetTransients()` los dropea en `.background` y la cola in-memory
//  se pierde en cold launch. El store re-emite vía
//  `AppBootstrapper.acceptShareFromURL` en cold launch + foreground,
//  re-resolviendo el `CKShare.Metadata` fresco desde la URL (el metadata opaco
//  nunca se serializa).
//
//  Persistencia: JSON-encoded `PendingInviteEntry` en UserDefaults, TTL 24h,
//  single entry (last-write-wins). Patrón espejo de `PendingLeaveShareTracker`.
//

import Foundation

/// Datos mínimos persistibles para reconstruir el procesamiento de un invite
/// sin el `CKShare.Metadata` opaco (no Codable). El `mode` del reconnect NO se
/// persiste — se re-deriva por `AppBootstrapper.inviteRouteDecision` en cada
/// re-proceso (es la fuente de verdad; un mode persistido sería stale).
struct PendingInviteEntry: Codable, Equatable {
    let shareURLString: String
    let branded: InviteLinkService.BrandedMetadata
    let createdAt: Date

    init(
        shareURL: URL,
        branded: InviteLinkService.BrandedMetadata,
        createdAt: Date = .now
    ) {
        self.shareURLString = shareURL.absoluteString
        self.branded = branded
        self.createdAt = createdAt
    }

    /// Reconstruye la URL del share para re-procesar vía `acceptShareFromURL`.
    /// Nil si la URL persistida es inválida.
    func resolved() -> (url: URL, branded: InviteLinkService.BrandedMetadata)? {
        guard let url = URL(string: shareURLString) else { return nil }
        return (url, branded)
    }
}

@MainActor
enum PendingInviteStore {
    static let userDefaultsKey = "yala.groups.pendingInvite"

    /// TTL tras el cual la entry se considera expirada y se purga al leerla. 24h,
    /// espejo del `DeferredIntentBuffer`.
    static let ttl: TimeInterval = 24 * 60 * 60

    /// UserDefaults storage. `nonisolated(unsafe)` para permitir inyección en tests.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    // MARK: - API

    /// Persiste el invite pendiente. Single entry — last-write-wins (un segundo
    /// invite reemplaza al primero; solo hay un invite presentándose a la vez).
    static func save(_ entry: PendingInviteEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entry) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }

    /// La entry pendiente, o nil si no hay / está expirada (la purga) / corrupta.
    /// `now` inyectable para tests.
    static func current(now: Date = .now) -> PendingInviteEntry? {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(PendingInviteEntry.self, from: data) else {
            return nil
        }
        if now.timeIntervalSince(entry.createdAt) >= ttl {
            MetricsService.invitePendingExpired()
            clear()
            return nil
        }
        return entry
    }

    /// Limpia la entry. Llamado al presentar el invite (consumo), en error
    /// permanente de fetch, y en `AppRouter.resetAll()` (wipe).
    static func clear() {
        defaults.removeObject(forKey: userDefaultsKey)
    }
}
