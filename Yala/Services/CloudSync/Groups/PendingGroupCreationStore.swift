//
//  PendingGroupCreationStore.swift
//  Yala
//
//  Card 5d22 (ticket `creategroup-throw-after-commit-loses-owner`): un `create_group` que el servidor GUARDA pero cuya
//  respuesta no llega —un timeout, un 5xx de vuelta, un cuerpo que no se lee— dejaba al creador sin ser dueño de su
//  propio grupo. `GroupBackendMembershipService.createGroup` es server-first y solo escribe `isOwner` tras un RPC con
//  éxito; el pull trae la fila del grupo pero no la propiedad (`isOwner` es local y `owner_user_id` no está en el
//  manifest), así que la persona veía su grupo como si fuera de otro hasta intentar salir de él.
//
//  «Lo creó» frente a «lo rechazó» no se puede distinguir desde un error de transporte, y no hace falta: la zona es un
//  UUID que acuña ESTE teléfono justo antes del RPC (`SplitGroup.cloudKitZoneID`), así que una fila de esa zona que
//  baje después solo puede venir de su propio `create_group`. Antes del RPC se apunta `{zona, sub}`; un rechazo
//  definitivo lo borra, un error ambiguo lo deja, y cuando el pull trae la zona con la MISMA sesión se adopta como en el
//  éxito (`GroupBackendMembershipService.adoptPendingCreations`). El `sub` es lo que impide atribuir el grupo a otra
//  cuenta que entre después en el teléfono.
//
//  Un registro por zona en `UserDefaults` (molde `PendingJoinStore`): sin PII más allá del `sub`, que el teléfono ya
//  guarda en la sesión. Caduca a los 7 días: si en una semana la zona no bajó, el servidor no la tiene.
//

import Foundation

nonisolated enum PendingGroupCreationStore {

    struct Entry: Codable, Equatable, Sendable {
        /// La zona del grupo (`p_group_id`), acuñada aquí.
        let zoneID: String
        /// El `sub` de la sesión que lanzó el `create_group`; el servidor fuerza el `member_key` del dueño a ese valor.
        let userID: String
        let createdAt: Date
    }

    static let key = "groups.pendingCreations"
    static let ttl: TimeInterval = 7 * 24 * 60 * 60

    /// `UserDefaults` inyectable para tests (molde `PendingJoinStore.defaults`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static func record(zoneID: String, userID: String, now: Date = .now) {
        var entries = load()
        entries[zoneID] = Entry(zoneID: zoneID, userID: userID, createdAt: now)
        persist(entries)
    }

    static func remove(zoneID: String) {
        var entries = load()
        guard entries.removeValue(forKey: zoneID) != nil else { return }
        persist(entries)
    }

    /// Los registros vigentes. Retira los caducados en el mismo gesto, para que no esperen a nadie.
    static func pending(now: Date = .now) -> [Entry] {
        let entries = load()
        let alive = entries.filter { abs(now.timeIntervalSince($0.value.createdAt)) < ttl }
        if alive.count != entries.count { persist(alive) }
        return alive.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// Frontera de persona: lo retira todo (`DataWipeService.removeGroupsDomainPreferenceKeys`). El `sub` ya impide
    /// adoptar con otra cuenta; esto evita además que un registro ajeno se quede hasta caducar.
    static func clearAll(in store: UserDefaults) {
        store.removeObject(forKey: key)
    }

    private static func load() -> [String: Entry] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Entry].self, from: data)
        } catch {
            // Ilegible: no prueba nada de nadie. Se retira, que es el lado que no atribuye un grupo a nadie.
            #if DEBUG
            print("PendingGroupCreationStore: Error decoding entries: \(error)")
            #endif
            defaults.removeObject(forKey: key)
            return [:]
        }
    }

    private static func persist(_ entries: [String: Entry]) {
        guard !entries.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(entries), forKey: key)
        } catch {
            #if DEBUG
            print("PendingGroupCreationStore: Error encoding entries: \(error)")
            #endif
        }
    }
}
