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
//  Card y1ru: el intento guarda también el NOMBRE con el que se pidió. Un reintento de «Crear» con el mismo nombre y la
//  misma sesión reusa la zona del intento (`reusableZone`) en vez de acuñar otra: si el primer toque ya se guardó, el
//  servidor contesta `yala_group_exists` y eso es el éxito; si no se guardó, se crea con esa zona. Con el nombre cambiado
//  se acuña una zona nueva (es otro grupo, o la persona corrigió el nombre: ver el docblock de `reusableZone`).
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
        /// El nombre con el que se pidió (card y1ru), recortado como lo recorta el servidor. Opcional: los registros de
        /// antes de la y1ru no lo llevan y nunca se reusan.
        var name: String? = nil
    }

    static let key = "groups.pendingCreations"
    static let ttl: TimeInterval = 7 * 24 * 60 * 60

    /// `UserDefaults` inyectable para tests (molde `PendingJoinStore.defaults`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static func record(zoneID: String, userID: String, name: String? = nil, now: Date = .now) {
        var entries = load()
        entries[zoneID] = Entry(zoneID: zoneID, userID: userID, createdAt: now, name: name.map(normalizedName))
        persist(entries)
    }

    /// Card y1ru · la zona de un intento vigente de ESTA sesión con el MISMO nombre, la más reciente. Es lo que reusa un
    /// reintento de «Crear»: el servidor deduplica por zona (`yala_group_exists`), así que reusarla convierte el reintento
    /// en idempotente. Con el nombre cambiado devuelve `nil` y se acuña otra zona: si el primer toque se guardó, quedan
    /// dos grupos con nombres distintos, que la persona ve y distingue; reusar la zona con el nombre nuevo daría por
    /// creado un grupo que en el servidor se llama como el primero.
    static func reusableZone(userID: String, name: String, now: Date = .now) -> String? {
        let wanted = normalizedName(name)
        return pending(now: now)
            .filter { $0.userID == userID && $0.name == wanted }
            .max { $0.createdAt < $1.createdAt }?
            .zoneID
    }

    /// El recorte de `create_group` (`btrim`): espacios a los dos lados.
    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
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
