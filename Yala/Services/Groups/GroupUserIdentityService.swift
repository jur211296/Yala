//
//  GroupUserIdentityService.swift
//  Yala
//
//  Cache in-memory del record name de iCloud del usuario, y los IDs deterministas de los records
//  por-usuario (p. ej. `SplitMember`).
//
//  Fase 2 bis: el ESCRITOR de `cachedRecordName` ya NO vive aquí. Vive en
//  `GroupICloudIdentitySeed` (`Yala/Services/CloudSync/Groups/`), con la key y el fetch, porque este
//  fichero se vació de CloudKit en la Fase 3 y la propiedad se conserva: dejar el `UserDefaults.set`
//  dentro de `currentUserRecordName()` era dejar la key sin nadie que la escribiera en cuanto el método
//  muriera. Lo que queda aquí es el CACHE (in-memory, dueño de la propiedad) y `deterministicUUID`.
//
//  Fase 3: se fue `fetchFreshRecordName()` —el fetch DIRECTO a `CKContainer` del boot-guard de identidad,
//  cuyo único llamador era `SplitSyncManager`— y con él el `import CloudKit`. También
//  `deterministicMemberID`, que ya estaba sin call-sites. **Esto es lo que deja al canal superviviente
//  sin ningún fetch a CloudKit propio**: la identidad la siembra `GroupICloudIdentitySeed`, que sí lo
//  conserva a propósito (ver su docblock).
//

import CryptoKit
import Foundation

@MainActor
final class GroupUserIdentityService {

    static let shared = GroupUserIdentityService()

    private(set) var cachedRecordName: String?

    private init() {
        cachedRecordName = GroupICloudIdentitySeed.persistedRecordName
    }

    /// Fachada histórica del seed. Sus tres consumidores están VIVOS y son del canal superviviente
    /// (`GroupService.createGroup`, `ensureCurrentUserMemberExists`, `refreshCurrentUserFlags`), así que la
    /// Fase 3 no la toca. Delega en el escritor del canal nuevo: mismo coalescing, misma persistencia,
    /// mismo error propagado.
    func currentUserRecordName() async throws -> String {
        try await GroupICloudIdentitySeed.seedIfNeeded()
    }

    /// Escritura del cache in-memory. La llama SOLO `GroupICloudIdentitySeed.adopt(_:)`, que es quien
    /// persiste — separar el par (cache, `UserDefaults`) en dos dueños los desincronizaría.
    func applySeededRecordName(_ recordName: String) {
        cachedRecordName = recordName
    }

    func clearCache() {
        cachedRecordName = nil
        GroupICloudIdentitySeed.forgetPersisted()
    }

    #if DEBUG
    /// Test-only: fija la identidad cacheada sin tocar CKContainer (los tests de
    /// GroupJoinReconciler necesitan que `currentUserRecordName()` resuelva
    /// determinístico y offline). No persiste en UserDefaults.
    func _testSetCachedRecordName(_ name: String?) {
        cachedRecordName = name
    }
    #endif

    /// `nonisolated`: primitiva pura (solo CryptoKit, sin estado del actor). Compartida con
    /// `GroupBackendIdentityLogic` (canal backend), que corre fuera del main actor.
    nonisolated static func deterministicUUID(namespace: String, name: String) -> UUID {
        let data = Data("\(namespace):\(name)".utf8)
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
