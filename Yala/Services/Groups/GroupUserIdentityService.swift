//
//  GroupUserIdentityService.swift
//  Yala
//
//  Fetches the current iCloud user record name for the Groups CloudKit container
//  and provides deterministic IDs for per-user records (e.g., SplitMember).
//
//  Fase 2 bis: el ESCRITOR de `cachedRecordName` ya NO vive aquí. Vive en
//  `GroupICloudIdentitySeed` (`Yala/Services/CloudSync/Groups/`), con la key y el fetch, porque este
//  fichero se vacía de CloudKit en la Fase 3 y la propiedad se conserva: dejar el `UserDefaults.set`
//  dentro de `currentUserRecordName()` era dejar la key sin nadie que la escribiera en cuanto el método
//  muriera. Lo que queda aquí es el CACHE (in-memory, dueño de la propiedad) y `deterministicUUID`.
//

import CloudKit
import CryptoKit
import Foundation

@MainActor
final class GroupUserIdentityService {

    static let shared = GroupUserIdentityService()

    private(set) var cachedRecordName: String?

    private init() {
        cachedRecordName = GroupICloudIdentitySeed.persistedRecordName
    }

    /// Fachada histórica del seed, conservada mientras el transporte CloudKit siga vivo (`createGroup`,
    /// `ensureCurrentUserMemberExists`, `refreshCurrentUserFlags`). Delega en el escritor del canal nuevo:
    /// mismo coalescing, misma persistencia, mismo error propagado. La Fase 3 puede borrar ESTE método sin
    /// dejar la identidad sin escritor — el seed de boot ya entra por `GroupICloudIdentitySeed`.
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

    /// Boot-guard GAP 1: fetch DIRECTO a CKContainer que NO lee ni escribe el cache.
    /// El boot-guard compara el valor fresco CONTRA `cachedRecordName` — si este
    /// método actualizara el cache, la limpieza correría con el cache ya renovado
    /// (orden roto: `decide` vería match). Tras la limpieza, `clearCache()` deja que
    /// `currentUserRecordName()` repueble lazy bajo la identidad nueva.
    func fetchFreshRecordName() async throws -> String {
        try await CKContainer(identifier: CKConstants.containerID).userRecordID().recordName
    }

    #if DEBUG
    /// Test-only: fija la identidad cacheada sin tocar CKContainer (los tests de
    /// GroupJoinReconciler necesitan que `currentUserRecordName()` resuelva
    /// determinístico y offline). No persiste en UserDefaults.
    func _testSetCachedRecordName(_ name: String?) {
        cachedRecordName = name
    }
    #endif

    func deterministicMemberID(groupZoneID: String) async throws -> UUID {
        let recordName = try await currentUserRecordName()
        return Self.deterministicUUID(namespace: "SplitMember", name: "\(groupZoneID):\(recordName)")
    }

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
