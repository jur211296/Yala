//
//  PendingLeaveShareTracker.swift
//  Yala
//
//  FU-02 cleanup F5c: tracker persistente para retries de `leaveShare` que fallaron
//  por network/CloudKit error. Reintentos en boot-time (AppBootstrapper paso 16.7).
//
//  Persistencia: JSON-encoded `Set<PendingLeaveShareEntry>` en UserDefaults.
//  Cuando `leaveShare` falla (e.g. airplane mode), capturamos (zoneName, ownerName)
//  ANTES del `delete(group)` local y los persistimos. Al próximo boot, el retry
//  reconstruye el call sin necesidad del SplitGroup vivo (ya borrado local).
//

import Foundation

/// Tupla mínima persistible para reconstruir `leaveShareByZone(zoneName:ownerName:)`
/// sin requerir un SplitGroup vivo (cleanup local ya lo borró).
struct PendingLeaveShareEntry: Hashable, Codable {
    let zoneName: String
    let zoneOwnerName: String
}

@MainActor
enum PendingLeaveShareTracker {
    static let userDefaultsKey = "yala.groups.pendingLeaveShareZones"

    /// UserDefaults storage. `nonisolated(unsafe)` para permitir inyección en tests.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// Añade entry al set. Idempotente.
    static func add(_ entry: PendingLeaveShareEntry) {
        var current = all()
        current.insert(entry)
        persist(current)
    }

    /// Quita entry del set. No-op si no existía.
    static func remove(_ entry: PendingLeaveShareEntry) {
        var current = all()
        current.remove(entry)
        persist(current)
    }

    /// Lee el set completo. Vacío si no hay persistencia o JSON corrupto.
    static func all() -> Set<PendingLeaveShareEntry> {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode(Set<PendingLeaveShareEntry>.self, from: data)) ?? []
    }

    /// Limpia el set entero. Usado en tests.
    static func clear() {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Private

    private static func persist(_ set: Set<PendingLeaveShareEntry>) {
        guard !set.isEmpty else {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(set) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }
}
