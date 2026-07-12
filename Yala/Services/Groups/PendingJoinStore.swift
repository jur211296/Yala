//
//  PendingJoinStore.swift
//  Yala
//
//  Persiste el "join intent": acepté el CKShare de la zona X y mi SplitMember
//  debe nacer y exportarse. Es estado de SYNC, no de UI — por eso es un store
//  SEPARADO de `PendingInviteStore` (aquel se limpia al PRESENTAR el invite;
//  este solo se limpia cuando el member existe y quedó encolado, o al expirar).
//
//  Motivo (bug 2026-07-11): `acceptShare` solo creaba el member si el
//  `SplitGroup` local ya existía — pero la zona compartida tarda ≥60s en bajar
//  (ventana export-only) y no había reconciliador posterior: el member jamás
//  nacía y el owner nunca recibía la solicitud. El intent persistente permite a
//  `GroupJoinReconciler` reintentarlo en accept/remoteInsert/boot/foreground.
//
//  Persistencia: JSON-encoded `[String: PendingJoinEntry]` (keyed por zoneName)
//  en UserDefaults. Multi-entry: dos accepts en sucesión son legítimos y el
//  segundo no debe borrar el intent no-reconciliado del primero. Cap 8 entries
//  (evict de la más vieja), TTL 7 días por entry (24h sería el mismo agujero
//  con delay). Patrón espejo de `PendingInviteStore`.
//

import Foundation

/// Datos mínimos para reconciliar la unión a un grupo cuando su zona por fin
/// materializa localmente. `displayName` es PII: se persiste local (igual que
/// `AppPreferences.userName`) pero JAMÁS se loguea.
struct PendingJoinEntry: Codable, Equatable {
    let zoneName: String
    /// `metadata.share.recordID.zoneID.ownerName` — diagnóstico y contraste con
    /// el `cloudKitZoneOwnerName` del grupo al reconciliar.
    let zoneOwnerName: String
    /// Nombre tecleado por el invitado en el onboarding; nil hasta
    /// `performSilentSetup`. El reconciliador lo aplica solo si el member recién
    /// nace o su displayName es el default (no pisa renames manuales).
    var displayName: String?
    /// Moneda detectada por REGIÓN en `performSilentSetup` cuando el grupo aún
    /// no había llegado (detectCurrencyFromGroup() == nil). Al reconciliar, si
    /// la pref actual sigue siendo esta, se re-aplica la moneda del grupo.
    var regionFallbackCurrency: String?
    let createdAt: Date

    init(
        zoneName: String,
        zoneOwnerName: String,
        displayName: String? = nil,
        regionFallbackCurrency: String? = nil,
        createdAt: Date = .now
    ) {
        self.zoneName = zoneName
        self.zoneOwnerName = zoneOwnerName
        self.displayName = displayName
        self.regionFallbackCurrency = regionFallbackCurrency
        self.createdAt = createdAt
    }
}

@MainActor
enum PendingJoinStore {
    static let userDefaultsKey = "yala.groups.pendingJoins"

    /// TTL por entry. 7 días: el escenario objetivo es "el invitado vuelve a
    /// abrir la app días después y la zona recién materializa".
    static let ttl: TimeInterval = 7 * 24 * 60 * 60

    /// Cap de entries simultáneas; al superarlo se purga la más vieja.
    static let maxEntries = 8

    /// UserDefaults storage. `nonisolated(unsafe)` para permitir inyección en tests.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    // MARK: - API

    /// Upsert por zoneName. Si ya hay intent para esa zona, lo reemplaza
    /// (conservar el más nuevo re-arma el TTL — correcto: el usuario re-aceptó).
    static func save(_ entry: PendingJoinEntry) {
        var entries = load()
        entries[entry.zoneName] = entry
        if entries.count > maxEntries {
            // Evict de las más viejas hasta volver al cap.
            let sorted = entries.values.sorted { $0.createdAt < $1.createdAt }
            for stale in sorted.prefix(entries.count - maxEntries) {
                entries.removeValue(forKey: stale.zoneName)
            }
        }
        persist(entries)
    }

    /// Entries vigentes (purga las expiradas al leer, con telemetría por cada una).
    /// `now` inyectable para tests.
    static func all(now: Date = .now) -> [PendingJoinEntry] {
        var entries = load()
        let expired = entries.values.filter { now.timeIntervalSince($0.createdAt) >= ttl }
        if !expired.isEmpty {
            for _ in expired { TelemetryService.track(.groupJoinIntentExpired) }
            for entry in expired { entries.removeValue(forKey: entry.zoneName) }
            persist(entries)
        }
        return entries.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// La entry vigente para una zona, o nil si no hay / expiró.
    static func entry(zoneName: String, now: Date = .now) -> PendingJoinEntry? {
        all(now: now).first { $0.zoneName == zoneName }
    }

    /// Propaga el nombre tecleado en el onboarding a todas las entries vigentes
    /// (el invitado fresh solo tiene una; el nombre es global, no por grupo).
    static func updateDisplayName(_ name: String, now: Date = .now) {
        var entries = load()
        var changed = false
        for (key, var entry) in entries where now.timeIntervalSince(entry.createdAt) < ttl {
            entry.displayName = name
            entries[key] = entry
            changed = true
        }
        if changed { persist(entries) }
    }

    /// Registra la moneda fallback detectada por región (solo si la entry existe).
    static func updateRegionFallbackCurrency(_ code: String, zoneName: String) {
        var entries = load()
        guard var entry = entries[zoneName] else { return }
        entry.regionFallbackCurrency = code
        entries[zoneName] = entry
        persist(entries)
    }

    /// Limpia el intent de una zona. Llamado SOLO cuando el member quedó
    /// asegurado y encolado (reconcile OK), en leaveGroup/deleteGroupData de esa
    /// zona, o por TTL. NUNCA al presentar UI.
    static func clear(zoneName: String) {
        var entries = load()
        guard entries.removeValue(forKey: zoneName) != nil else { return }
        persist(entries)
    }

    /// Wipe total: sign-out / `AppRouter.resetAll()`.
    static func clearAll() {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Persistencia

    private static func load() -> [String: PendingJoinEntry] {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([String: PendingJoinEntry].self, from: data)
        } catch {
            #if DEBUG
            print("PendingJoinStore: Error decoding entries: \(error)")
            #endif
            return [:]
        }
    }

    private static func persist(_ entries: [String: PendingJoinEntry]) {
        if entries.isEmpty {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            defaults.set(data, forKey: userDefaultsKey)
        } catch {
            #if DEBUG
            print("PendingJoinStore: Error encoding entries: \(error)")
            #endif
        }
    }
}
