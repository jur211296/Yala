//
//  GroupUserIdentityService.swift
//  Yala
//
//  Fetches the current iCloud user record name for the Groups CloudKit container
//  and provides deterministic IDs for per-user records (e.g., SplitMember).
//

import CloudKit
import CryptoKit
import Foundation

@MainActor
final class GroupUserIdentityService {

    static let shared = GroupUserIdentityService()

    private let defaultsKey = "groups_currentUserRecordName"
    private var inflightFetch: Task<String, Error>?

    private(set) var cachedRecordName: String?

    private init() {
        cachedRecordName = UserDefaults.standard.string(forKey: defaultsKey)
    }

    func currentUserRecordName() async throws -> String {
        if let cachedRecordName, !cachedRecordName.isEmpty { return cachedRecordName }
        if let inflightFetch { return try await inflightFetch.value }

        let task = Task { () throws -> String in
            let id = try await CKContainer(identifier: CKConstants.containerID).userRecordID()
            return id.recordName
        }

        inflightFetch = task
        defer { inflightFetch = nil }

        let name = try await task.value
        cachedRecordName = name
        UserDefaults.standard.set(name, forKey: defaultsKey)
        return name
    }

    func clearCache() {
        cachedRecordName = nil
        inflightFetch?.cancel()
        inflightFetch = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
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

    static func deterministicUUID(namespace: String, name: String) -> UUID {
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
