//
//  BridgeModeResolver.swift
//  Yala
//
//  Singleton @MainActor que resuelve el modo efectivo del bridge per-grupo,
//  con cache `[zoneID: Bool?]` para evitar N fetches durante bulk operations
//  (ej. import histórico, batch bridge en sync remoto).
//
//  Delega la regla pura a `BridgeResolverLogic.computeEffective(global:override:)`.
//  Mutaciones (`setOverride`, `clearOrphanOverrides`) invalidan cache selectivamente.
//

import Foundation
import SwiftData

@MainActor
final class BridgeModeResolver {
    static let shared = BridgeModeResolver()

    /// Cache de overrides por `groupZoneID`.
    /// Valor `nil` = entry presente en DB pero override == nil (heredar global).
    /// Key ausente = todavía no fetched (next read llena la entry).
    /// TODO V1.1: observar `NSPersistentStoreRemoteChange` o `@Query<GroupBridgePreference>`
    /// para invalidar entries cuando llegan records cross-device via CloudKit sync. Hoy
    /// el cache solo se invalida en mutaciones locales — un toggle remoto deja cached
    /// stale hasta app cold restart. Mitigación parcial: app launches inician con cache
    /// vacío, y el cleanup boot-time elimina huérfanos.
    private var cache: [String: Bool?] = [:]

    /// Inyectada en bootstrap. Los callers (bridge, sheets) no necesitan pasarla.
    private var appPreferences: AppPreferences?

    private init() {}

    // MARK: - Setup

    func setAppPreferences(_ prefs: AppPreferences) {
        self.appPreferences = prefs
    }

    // MARK: - Read

    /// Resuelve si el bridge debe crear TX real para `group` en el current user.
    /// Lectura: cache hit → resolver puro; miss → fetch single `GroupBridgePreference`
    /// y poblar cache. Lectura barata aunque haya 100s de TX en bridge loop.
    /// Defensivo: si `AppPreferences` no fue inyectado todavía (boot temprano), devuelve
    /// `true` (default ON) preservando comportamiento legacy.
    func isBridgeEnabled(
        for group: SplitGroup,
        context: ModelContext
    ) -> Bool {
        guard let appPreferences else { return true }
        let zoneID = group.cloudKitZoneID
        let override: Bool?
        if let cached = cache[zoneID] {
            override = cached
        } else {
            override = fetchOverride(forZoneID: zoneID, context: context)
            cache[zoneID] = override
        }
        return BridgeResolverLogic.computeEffective(
            global: appPreferences.bridgeGroupExpensesToPersonalAccounts,
            override: override
        )
    }

    /// Lectura del override (solo el explicit value, sin aplicar el global). Útil para UI
    /// que necesita mostrar "heredando global vs override explícito".
    func override(forZoneID zoneID: String, context: ModelContext) -> Bool? {
        if let cached = cache[zoneID] {
            return cached
        }
        let value = fetchOverride(forZoneID: zoneID, context: context)
        cache[zoneID] = value
        return value
    }

    // MARK: - Write

    /// Upsert override para `group`. Crea `GroupBridgePreference` si no existe,
    /// actualiza el existente. Borra el record cuando `override == nil` y existe
    /// (para no acumular entries irrelevantes; el resolver puro trata "no record"
    /// como "heredar global" sin diferencia funcional).
    func setOverride(
        for group: SplitGroup,
        override: Bool?,
        in context: ModelContext
    ) throws {
        let zoneID = group.cloudKitZoneID
        let existing = fetchAllRecords(forZoneID: zoneID, context: context)

        if let value = override {
            if let record = existing.first {
                record.bridgeOverride = value
            } else {
                context.insert(GroupBridgePreference(groupZoneID: zoneID, bridgeOverride: value))
            }
            // Si por alguna razón hay duplicados, dedup local (boot dedup service
            // los limpia globalmente; aquí pre-empt para que el cache quede consistente).
            for extra in existing.dropFirst() {
                context.delete(extra)
            }
        } else {
            for record in existing {
                context.delete(record)
            }
        }
        try context.save()
        cache[zoneID] = override
    }

    /// Limpia overrides cuyo `groupZoneID` ya no corresponde a un grupo activo del
    /// user (zonas abandonadas via `leaveGroup`/`softDelete` o grupos `isHiddenForAll`).
    /// Defensivo idempotente — se llama en boot-time post-dedup y desde
    /// `GroupService.leaveGroup`/`softDelete` tras success.
    /// - Parameter activeZoneIDs: zoneIDs vivos del user.
    /// - Returns: cantidad de records borrados.
    @discardableResult
    func clearOrphanOverrides(
        activeZoneIDs: Set<String>,
        in context: ModelContext
    ) throws -> Int {
        let all = (try? context.fetch(FetchDescriptor<GroupBridgePreference>())) ?? []
        let allZoneIDs = Set(all.map(\.groupZoneID))
        let orphanZoneIDs = BridgeResolverLogic.computeOrphanZoneIDs(
            allPreferenceZoneIDs: allZoneIDs,
            activeZoneIDs: activeZoneIDs
        )
        guard !orphanZoneIDs.isEmpty else { return 0 }

        let toDelete = all.filter { orphanZoneIDs.contains($0.groupZoneID) }
        for record in toDelete {
            context.delete(record)
            cache.removeValue(forKey: record.groupZoneID)
        }
        try context.save()
        return toDelete.count
    }

    /// Invalidación manual del cache. Si `zoneID == nil` limpia todo (útil tras wipe).
    func invalidateCache(forZoneID zoneID: String? = nil) {
        if let zoneID {
            cache.removeValue(forKey: zoneID)
        } else {
            cache.removeAll()
        }
    }

    /// Cleanup específico por zoneID — útil desde `GroupService.leaveGroup`/
    /// `softDelete` donde sabemos exactamente qué zone limpiar. Más eficiente que
    /// `clearOrphanOverrides` (no requiere fetch del set activo). Idempotente.
    /// - Returns: cantidad de records borrados (0 si no había override para esa zone).
    @discardableResult
    func clearOverride(forZoneID zoneID: String, in context: ModelContext) throws -> Int {
        let records = fetchAllRecords(forZoneID: zoneID, context: context)
        guard !records.isEmpty else { return 0 }
        for record in records {
            context.delete(record)
        }
        try context.save()
        cache.removeValue(forKey: zoneID)
        return records.count
    }

    // MARK: - Internal

    private func fetchOverride(forZoneID zoneID: String, context: ModelContext) -> Bool? {
        let records = fetchAllRecords(forZoneID: zoneID, context: context)
        // Si hay duplicados, devolver el del keeper (oldest). Boot dedup limpiará.
        return records.sorted { $0.createdAt < $1.createdAt }.first?.bridgeOverride
    }

    private func fetchAllRecords(forZoneID zoneID: String, context: ModelContext) -> [GroupBridgePreference] {
        let descriptor = FetchDescriptor<GroupBridgePreference>(
            predicate: #Predicate { $0.groupZoneID == zoneID }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BridgeModeResolver: fetch failed for zone=\(zoneID): \(error)")
            #endif
            return []
        }
    }
}
