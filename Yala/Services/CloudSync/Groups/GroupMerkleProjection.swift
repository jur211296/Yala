//
//  GroupMerkleProjection.swift
//  Yala
//
//  Proyección MERKLE del canal de GRUPOS (endurecimiento pre-flag B1, [R1]). SEPARADA de la proyección de
//  EMISIÓN (`GroupEntityEmissionMap`): el server hashea TODAS las columnas de dominio del manifest
//  (`merkleColumnsGroup()` = Object.keys(spec.columns), gateway/src/groups/canon.ts), mientras que la
//  emisión OMITE deliberadamente dos cosas (que romperían el push si viajaran):
//    (a) `split_groups.created_at` — el column-grant del UPDATE no la incluye (hallazgo #1 de G1);
//    (b) `group_members` ENTERA — es pull-only (el cliente jamás la empuja).
//  Reusar el emission map para el Merkle daría un root DIVERGENTE en CADA grupo, permanente. Por eso esta
//  proyección AÑADE `split_groups.created_at` y una emisión NUEVA de `group_members`, y para las 3 tablas
//  de contenido REUSA la emisión (que ya == columnas del manifest).
//
//  REGLA DE ENSAMBLADO A-4 (CONGELADA — se REUSAN las primitivas de `SyncMerkle`, canal 1 SIN hlc):
//    leaf = sha256(utf8(identidad_lc) ‖ sha256(utf8(payload_c1)));  entity = sha256(concat(leaves ordenados
//    por identidad UTF-8 asc)); vacía = sha256("");  root = sha256(concat(entityHash orden UTF-8 asc de tabla)).
//  El payload_c1 lo produce `encodeGroupCanonC1` — espejo del guard de `gateway/src/groups/canon.ts`, que
//  a diferencia del codec personal NO trata `user_id` como server-authored (es columna de DOMINIO en
//  `group_members`). Se REUSA `Canonc1Codec.encodeValue` por-campo (misma regla por-tipo) y solo cambia el
//  guard de keys server-authored.
//
//  IDENTIDAD del leaf POR ENTIDAD ([R6], lowercase del STRING CRUDO — el server hace `.toLowerCase()` sobre
//  la keyset column, routes.ts): `split_groups` → `group_id` (= `cloudKitZoneID`, string arbitrario);
//  `group_members` → `member_key` (`SplitMember.memberKey`, OPCIONAL — nil ⇒ SKIP del leaf con breadcrumb,
//  jamás crash); resto → `sync_id` (UUID lowercased). NO se asume UUID para group_id/member_key.
//
//  SUPUESTO documentado: filas VIVAS locales ≈ filas server no-deleted. El apply del pull BORRA la fila
//  local al aplicar un tombstone (`applyExpense`/`applyMember`/… con `op == .tombstone` → `context.delete`),
//  así que todo lo que queda local es "vivo" — el Canal 1 del server también EXCLUYE `deleted=true`. La
//  simetría se mantiene mientras el apply drene sus tombstones (garantizado por el cursor por-grupo).
//

import CryptoKit
import Foundation
import SwiftData

@MainActor
enum GroupMerkleProjection {

    // MARK: - Nombres de tabla (las 5, orden irrelevante — el ensamblado ordena por UTF-8)

    static let entityTables: [String] = [
        "split_groups", "group_members", "split_expenses", "split_shares", "split_settlements",
    ]

    // MARK: - Guard server-authored del canal de GRUPOS (espejo de GROUP_SERVER_AUTHORED, canon.ts)

    /// Columnas que JAMÁS son leaves del Canal 1 de Grupos. **A diferencia del personal, `user_id` NO está
    /// aquí** (es columna de dominio de `group_members`). Espejo EXACTO de `GROUP_SERVER_AUTHORED`.
    nonisolated static let groupServerAuthoredKeys: Set<String> = [
        "server_seq", "hlc", "field_hlcs", "deleted", "deleted_hlc", "schema_version", "updated_at",
        "owner_user_id", "group_id", "sync_id",
    ]

    // MARK: - Emisiones MERKLE por entidad (columnas COMPLETAS del manifest)

    /// `split_expenses`/`split_shares`/`split_settlements`: la emisión ya == columnas del manifest → se REUSA.
    static let splitExpense = GroupEntityEmissionMap.splitExpense
    static let splitShare = GroupEntityEmissionMap.splitShare
    static let splitSettlement = GroupEntityEmissionMap.splitSettlement

    /// `split_groups`: emisión (10 columnas grantables) + `created_at` (el manifest la conserva para el PULL).
    static let splitGroup = EntityEmission<SplitGroup>(
        table: "split_groups",
        emitters: GroupEntityEmissionMap.splitGroup.emitters + [
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
        ]
    )

    /// `group_members`: proyección NUEVA (pull-only, sin emisión). Columnas del manifest §group_members.
    /// Identidad del leaf = `member_key` (fuera del payload). `user_id` (uuid_lower) → `.uuid` (o `.null`).
    static let groupMember = EntityEmission<SplitMember>(
        table: "group_members",
        emitters: [
            ColumnEmitter("user_id") { m, _ in Emit.refFromString(m.userID) },
            ColumnEmitter("display_name") { m, _ in .string(m.displayName) },
            ColumnEmitter("role") { m, _ in .string(m.role) },
            ColumnEmitter("status") { m, _ in .string(m.status) },
            ColumnEmitter("joined_at") { m, _ in .timestamp(m.joinedAt) },
        ]
    )

    /// Catálogo type-erased (tabla → columnas del leaf Merkle) para el test gemelo de paridad contra el
    /// manifest COMPLETO (las 5, sin restas — a diferencia del catálogo de EMISIÓN).
    static var catalog: [String: (columns: Set<String>, groups: [String: String])] {
        [
            splitExpense.table: (splitExpense.columns, splitExpense.groupByColumn),
            splitShare.table: (splitShare.columns, splitShare.groupByColumn),
            splitSettlement.table: (splitSettlement.columns, splitSettlement.groupByColumn),
            splitGroup.table: (splitGroup.columns, splitGroup.groupByColumn),
            groupMember.table: (groupMember.columns, groupMember.groupByColumn),
        ]
    }

    // MARK: - Resultado del cómputo local

    struct EntitySummary: Equatable {
        let count: Int
        let hashHex: String
    }

    struct LocalGroupMerkle: Equatable {
        /// tabla → (count de filas vivas, entityHash hex). SIEMPRE las 5 tablas.
        let entities: [String: EntitySummary]
        let rootHex: String
    }

    // MARK: - Payload canónico c1 del leaf (proyección FULL de la fila)

    /// Payload c1 del leaf: proyección FULL (TODAS las columnas de la emisión Merkle de la entidad; grupos
    /// NO tienen `local_day` que excluir). Espejo de `SyncMerkle.channel1Payload` pero con el guard de
    /// GRUPOS (que admite `user_id`). `internal` para tests de paridad de proyección.
    static func channel1Payload<M>(model: M, emission: EntityEmission<M>) throws -> String {
        var fields: [String: CanonValue] = [:]
        let calendar = Calendar(identifier: .gregorian)  // irrelevante: grupos no derivan `local_day`
        for emitter in emission.emitters {
            fields[emitter.column] = emitter.build(model, calendar)
        }
        return try encodeGroupCanonC1(fields, groupedColumns: Set(emission.groupByColumn.keys))
    }

    /// Serializa el mapa columna→CanonValue al string canónico c1 con el guard de GRUPOS. Espejo byte-a-byte
    /// de `encodeGroupCanonC1` (gateway/src/groups/canon.ts): mismas primitivas por-valor
    /// (`Canonc1Codec.encodeValue`) + orden por bytes UTF-8, pero el guard de keys NO incluye `user_id`.
    static func encodeGroupCanonC1(_ fields: [String: CanonValue], groupedColumns: Set<String>) throws -> String {
        for key in fields.keys where groupServerAuthoredKeys.contains(key) {
            throw Canonc1Error.serverAuthoredKey(key)
        }
        let sortedKeys = fields.keys.sorted(by: Canonc1Codec.utf8BytesLess)
        var entries: [String] = []
        entries.reserveCapacity(sortedKeys.count)
        for key in sortedKeys {
            guard let fragment = try Canonc1Codec.encodeValue(
                fields[key]!, inCoherenceGroup: groupedColumns.contains(key)) else { continue }
            entries.append(Canonc1Codec.encodeJSONString(key) + ":" + fragment)
        }
        return "{" + entries.joined(separator: ",") + "}"
    }

    // MARK: - Cómputo local del árbol de UN grupo

    /// Computa el árbol Merkle local (Canal 1) del grupo `groupID`: para cada una de las 5 tablas, las filas
    /// VIVAS de ESE grupo → proyección FULL → leaf (identidad lowercased por-entidad); entityHash + root con
    /// las primitivas A-4 de `SyncMerkle`. Fetches CONCRETOS por tipo (regla `#Predicate`).
    static func computeLocalMerkle(groupID gid: String, context: ModelContext) -> LocalGroupMerkle {
        var digests: [String: Data] = [:]
        var entities: [String: EntitySummary] = [:]

        let expenseLeaves = collectLeaves(
            SplitExpense.self, emission: splitExpense, groupID: gid,
            groupFilter: #Predicate { $0.groupZoneID == gid }, identity: { $0.id.uuidString.lowercased() },
            context: context)
        let shareLeaves = collectLeaves(
            SplitShare.self, emission: splitShare, groupID: gid,
            groupFilter: #Predicate { $0.groupZoneID == gid }, identity: { $0.id.uuidString.lowercased() },
            context: context)
        let settlementLeaves = collectLeaves(
            SplitSettlement.self, emission: splitSettlement, groupID: gid,
            groupFilter: #Predicate { $0.groupZoneID == gid }, identity: { $0.id.uuidString.lowercased() },
            context: context)
        let groupLeaves = collectLeaves(
            SplitGroup.self, emission: splitGroup, groupID: gid,
            groupFilter: #Predicate { $0.cloudKitZoneID == gid }, identity: { $0.cloudKitZoneID.lowercased() },
            context: context)
        // group_members: identidad = member_key OPCIONAL; nil → SKIP con breadcrumb (jamás keyea un leaf).
        let memberLeaves = collectMemberLeaves(groupID: gid, context: context)

        let computed: [(String, [(String, Data)])] = [
            (splitExpense.table, expenseLeaves),
            (splitShare.table, shareLeaves),
            (splitSettlement.table, settlementLeaves),
            (splitGroup.table, groupLeaves),
            (groupMember.table, memberLeaves),
        ]
        for (table, leaves) in computed {
            let digest = SyncMerkle.entityDigest(leaves)
            digests[table] = digest
            entities[table] = EntitySummary(count: leaves.count, hashHex: SyncMerkle.hexString(digest))
        }
        return LocalGroupMerkle(
            entities: entities, rootHex: SyncMerkle.hexString(SyncMerkle.rootDigest(entityDigests: digests)))
    }

    /// Leaves de UNA entidad de contenido/meta del grupo. Una fila cuyo payload el codec rechaza se SALTA con
    /// rastro (mejor una divergencia detectable que un crash del verificador — hueco documentado, molde
    /// `SyncMerkle.collectLeaves`).
    private static func collectLeaves<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, groupID: String,
        groupFilter: Predicate<M>, identity: (M) -> String, context: ModelContext
    ) -> [(String, Data)] {
        let models: [M]
        do {
            models = try context.fetch(FetchDescriptor<M>(predicate: groupFilter))
        } catch {
            #if DEBUG
            print("GroupMerkleProjection.collectLeaves<\(M.self)> fetch falló: \(error)")
            #endif
            return []
        }
        var leaves: [(String, Data)] = []
        for model in models {
            let id = identity(model)
            do {
                let payload = try channel1Payload(model: model, emission: emission)
                leaves.append((id, SyncMerkle.leafDigest(syncID: id, payload: payload)))
            } catch {
                #if DEBUG
                print("GroupMerkleProjection: payload de \(emission.table) no canonicalizable (fila saltada): \(error)")
                #endif
                CloudSyncBreadcrumb.encodeRejected(entity: emission.table, reason: "group-merkle:\(error)")
            }
        }
        return leaves
    }

    /// Leaves de `group_members` (pull-only): identidad = `SplitMember.memberKey` (OPCIONAL). Una fila SIN
    /// `memberKey` (member CloudKit preexistente no adoptado — mundo born-backend DARK no lo produce) NO puede
    /// keyear su leaf → SKIP con breadcrumb `memberKeyMissing` (jamás crash). Residual G6 (grupos migrados).
    private static func collectMemberLeaves(groupID gid: String, context: ModelContext) -> [(String, Data)] {
        let models: [SplitMember]
        do {
            models = try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == gid }))
        } catch {
            #if DEBUG
            print("GroupMerkleProjection.collectMemberLeaves fetch falló: \(error)")
            #endif
            return []
        }
        var leaves: [(String, Data)] = []
        for model in models {
            guard let memberKey = model.memberKey, !memberKey.isEmpty else {
                GroupsSyncBreadcrumb.groupsMerkleMemberKeyMissing()
                continue
            }
            let id = memberKey.lowercased()
            do {
                let payload = try channel1Payload(model: model, emission: groupMember)
                leaves.append((id, SyncMerkle.leafDigest(syncID: id, payload: payload)))
            } catch {
                #if DEBUG
                print("GroupMerkleProjection: payload de group_members no canonicalizable (fila saltada): \(error)")
                #endif
                CloudSyncBreadcrumb.encodeRejected(entity: "group_members", reason: "group-merkle:\(error)")
            }
        }
        return leaves
    }
}
