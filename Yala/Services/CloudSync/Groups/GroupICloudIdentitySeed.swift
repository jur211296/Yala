//
//  GroupICloudIdentitySeed.swift
//  Yala
//
//  ESCRITOR ÚNICO de la identidad iCloud del container de Grupos (`CKRecord.ID.recordName` del usuario),
//  persistida en `groups_currentUserRecordName` y expuesta como `GroupUserIdentityService.cachedRecordName`.
//
//  Por qué vive AQUÍ y no con el transporte (Fase 2 bis): su único escritor estaba DENTRO de
//  `GroupUserIdentityService.currentUserRecordName()`, el método que hace el fetch a `CKContainer` y que la
//  Fase 3 borra junto al transporte CloudKit. Conservar la propiedad `cachedRecordName` —lo que el plan
//  pedía— no basta: hay que conservar QUIÉN LA ESCRIBE, o en una instalación fresca (device nuevo,
//  reinstalación, restore) queda `nil` para siempre.
//
//  Lo que se pierde si queda nil, medido: el rebind de un grupo MIGRADO. `migrate_group` sube los members
//  no-owner como placeholders `user_id NULL` y la ÚNICA forma de reclamarlos es
//  `join_group(token, p_legacy_member_key)` con el recordName CloudKit-era del propio usuario
//  (`GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin`). Sin él, el usuario re-entra como member
//  NUEVO y su historial de la era CloudKit queda atribuido a una fila fantasma. No se puede derivar del
//  canal backend: la RLS solo entrega el grupo a quien ya está reclamado por `user_id`, así que el
//  `member_key` legacy no puede BAJAR antes del rebind que lo necesita.
//
//  Alcance CloudKit: solo `CKContainer(identifier:).userRecordID()`. Ni zonas, ni engine, ni `CKSyncEngine`
//  ⇒ no arrastra nada del transporte. El identificador se lee de `SwiftDataConfiguration`, NO de
//  `CKConstants` (que muere con `CloudKitConstants.swift`).
//
//  Fecha de caducidad conocida: el commit 2 de la Fase 4 retira el entitlement del container de Grupos ⇒ a
//  partir de ahí el fetch falla siempre y el rebind legacy muere con él, esta vez por decisión de release.
//
//  Logs fuera de `#if DEBUG` (excepción SplitSync consciente) y SIN PII: el recordName JAMÁS se loguea.
//

import CloudKit
import Foundation
import OSLog

@MainActor
enum GroupICloudIdentitySeed {

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    /// SSOT de la key de `UserDefaults`. Vive junto a su escritor a propósito: separar la key del `set` es
    /// exactamente cómo se llegó a tener una key sin nadie que la escribiera.
    static let defaultsKey = "groups_currentUserRecordName"

    // MARK: - Dependencias inyectables (default = cadena real de producción)

    /// Fetch de la identidad iCloud. Default = `CKContainer` del container de Grupos. Inyectable para que el
    /// camino de instalación fresca se pueda ejercitar SIN red y sin inyectar el cache (inyectar el cache
    /// reproduce el bug tapado: es lo que hacen las suites que no cazaron esto).
    static var recordNameFetcher: @MainActor () async throws -> String = {
        try await CKContainer(identifier: SwiftDataConfiguration.groupsCloudKitContainerIdentifier)
            .userRecordID().recordName
    }

    /// Store de persistencia. Inyectable por la regla de tests (nunca `UserDefaults.standard` en tests).
    static var defaults: UserDefaults = .standard

    /// Coalescing del fetch en vuelo: N llamadas concurrentes (boot + tap de invitación + refresh de flags)
    /// comparten UNA sola ida a CloudKit. Vino con el fetch desde `GroupUserIdentityService`.
    private static var inflight: Task<String, Error>?

    // MARK: - Lectura

    /// El valor persistido, o `nil` si nunca se sembró. Lo lee el `init` de `GroupUserIdentityService`.
    static var persistedRecordName: String? {
        defaults.string(forKey: defaultsKey)
    }

    // MARK: - Escritura

    /// Siembra la identidad si aún no está cacheada y devuelve el recordName. Idempotente y coalescente:
    /// con el cache poblado NO sale a la red. Propaga el error del fetch (cero silencios) — el caller decide
    /// si es fatal (crear grupo) o best-effort (seed de boot, refresh de flags).
    @discardableResult
    static func seedIfNeeded() async throws -> String {
        if let cached = GroupUserIdentityService.shared.cachedRecordName, !cached.isEmpty { return cached }
        if let inflight { return try await inflight.value }

        let task = Task { try await recordNameFetcher() }
        inflight = task
        defer { inflight = nil }

        let recordName = try await task.value
        adopt(recordName)
        return recordName
    }

    /// Variante best-effort para el seed de boot: la identidad iCloud es deseable pero NO bloqueante (el
    /// canal backend resuelve por `sub`). Loguea el motivo en vez de silenciarlo — el `try?` de antes no
    /// dejaba rastro de por qué el device se quedaba sin identidad.
    static func seedIfNeededBestEffort() async {
        do {
            _ = try await seedIfNeeded()
        } catch {
            logger.error("GroupIdentity: seed de iCloud falló: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Persiste el recordName y refresca el cache in-memory. Síncrono y SIN CloudKit: es la mitad del
    /// escritor que tiene que seguir viva cuando el fetch se vaya con el transporte.
    static func adopt(_ recordName: String) {
        guard !recordName.isEmpty else {
            logger.error("GroupIdentity: seed vacío ignorado (no se persiste una identidad en blanco)")
            return
        }
        GroupUserIdentityService.shared.applySeededRecordName(recordName)
        defaults.set(recordName, forKey: defaultsKey)
    }

    /// Olvida la identidad sembrada: cancela el fetch en vuelo y borra lo persistido. La mitad in-memory la
    /// limpia el caller (`GroupUserIdentityService.clearCache()`), que es su dueño.
    static func forgetPersisted() {
        inflight?.cancel()
        inflight = nil
        defaults.removeObject(forKey: defaultsKey)
    }

    #if DEBUG
    /// Test-only: devuelve el seam a su estado de fábrica (fetcher real, defaults estándar, sin inflight).
    static func _testReset() {
        inflight?.cancel()
        inflight = nil
        defaults = .standard
        recordNameFetcher = {
            try await CKContainer(identifier: SwiftDataConfiguration.groupsCloudKitContainerIdentifier)
                .userRecordID().recordName
        }
    }
    #endif
}
