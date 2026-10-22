//
//  SplitGroupDeduplicationService.swift
//  Yala
//
//  Removes duplicate SplitGroup records sharing the same `cloudKitZoneID`.
//  Same shape as `CategoryDeduplicationService` / `NotificationService.deduplicateNotifications`.
//
//  Why duplicates appear: a SplitGroup can be created via two paths with distinct
//  `id` UUIDs but identical `cloudKitZoneID`:
//    (a) CloudKit sync via `SplitSyncManager.applyGroupMeta` (id from `record.recordID`)
//    (b) Local create / accept-share path (id is fresh `UUID()`)
//  Members/Expenses/Settlements link by `groupZoneID: String` (no @Relationship),
//  so deleting a duplicate SplitGroup does not affect them — they continue resolving
//  to the canonical group via the zoneID.
//
//  Decision: keeper = oldest by `createdAt` (most likely the original).
//  Cascade-delete CloudKit is accepted: the duplicate's record is removed from CK
//  via SwiftData CKSyncEngine; other devices observe the delete and converge.
//
//  ⚠️ Esa última frase se escribió cuando CloudKit era el único canal, y para el BACKEND es falsa y
//  destructiva: allí la identidad de `split_groups` es la ZONA —o sea, la fila SUPERVIVIENTE— así que
//  propagar el borrado del duplicado no «converge», borra el grupo para TODOS los miembros. Y el
//  `context.save()` de abajo va con el autor por DEFECTO, que es justo el que captura el drain de Grupos.
//  Lo que lo impide hoy es el `guard !updateOnly` del `case .delete` de `GroupsSyncClient.translateChange`:
//  esta limpieza es LOCAL y tiene que seguir siéndolo. No la conviertas en una escritura remota.
//

import Foundation
import SwiftData

@MainActor
enum SplitGroupDeduplicationService {

    /// Pure-logic plan — testable without `ModelContext` (R8: avoid `makeTestContext()`).
    struct DedupPlan: Equatable {
        let toKeepIDs: [UUID]
        let toDeleteIDs: [UUID]
        let duplicateZoneCounts: [DuplicateZone]
        /// Evidencia que el keeper tiene que ADOPTAR de las filas descartadas ANTES de que desaparezcan.
        /// Solo se emite para las zonas donde de verdad cambia algo.
        let channelMerges: [ChannelMerge]

        struct DuplicateZone: Equatable {
            let zoneID: String
            let count: Int
        }

        /// Lo que el keeper hereda de sus gemelas. **Solo evidencia que RESTRINGE, nunca una credencial que
        /// habilite** — ver el porqué en `computeDedupPlan`.
        struct ChannelMerge: Equatable {
            let keeperID: UUID
            let isBackendGroup: Bool
            let movedToBackendAt: Date?
            let rejoinRevokedAt: Date?
        }
    }

    /// Computes which SplitGroups to keep / delete given an array. Pure function.
    ///
    /// **El keeper sigue siendo el más antiguo, y eso es deliberado**: `createdAt` ASC es el criterio
    /// CANÓNICO del repo para elegir la fila de una zona (`GroupService.group(for:)`,
    /// `GroupsSyncClient.fetchSplitGroupRows`, `executeBatchStep`, `performRemovedSelfCleanup`), y hacer que
    /// aquí ganara otra crearía una quinta regla distinta para la misma pregunta.
    ///
    /// Lo que se arregla es que el plan era **CIEGO AL CANAL**: si el keeper resultaba ser la fila NO-backend,
    /// al borrar la gemela marcada la zona salía de `GroupsSyncClient.backendGroupZoneIDs` —un fetch de
    /// `isBackendGroup == true` sobre filas VIVAS— y con ella la pertenencia al canal nuevo, que es local-only
    /// y no se puede re-derivar de nada local. Ahora el keeper ADOPTA esa evidencia antes de que se borre.
    ///
    /// **Qué se fusiona y qué NO, que es la parte delicada.** Se fusiona lo que RESTRINGE: `isBackendGroup`
    /// (OR), `movedToBackendAt` (el más antiguo — es cuándo se migró) y `rejoinRevokedAt` (la revocación más
    /// reciente; perderla dejaría re-entrar con una credencial ya retirada). **NO se fusiona
    /// `backendReInviteToken`**: es la CREDENCIAL de re-invitación, y heredarla RESUCITARÍA en el keeper un
    /// acceso que la revocación de la gemela retiró — exactamente el fallo que la regla C-3 de
    /// `.claude/rules/swiftdata-cloudkit.md` describe («con una sola viva, el humano nuevo entra COMO el
    /// anterior»). Tampoco `markerEnqueuedFlag`: su OR se saltaría un encolado necesario y su AND lo
    /// duplicaría, así que no hay fusión correcta y se deja por fila.
    static func computeDedupPlan(groups: [SplitGroup]) -> DedupPlan {
        let byZone = Dictionary(grouping: groups, by: \.cloudKitZoneID)
        var toKeep: [UUID] = []
        var toDelete: [UUID] = []
        var dupZones: [DedupPlan.DuplicateZone] = []
        var merges: [DedupPlan.ChannelMerge] = []

        for (zoneID, dups) in byZone {
            let sorted = dups.sorted { $0.createdAt < $1.createdAt }
            guard let keeper = sorted.first else { continue }
            toKeep.append(keeper.id)
            guard dups.count > 1 else { continue }
            toDelete.append(contentsOf: sorted.dropFirst().map(\.id))
            dupZones.append(.init(zoneID: zoneID, count: dups.count))

            let mergedBackend = dups.contains(where: \.isBackendGroup)
            let mergedMoved = dups.compactMap(\.movedToBackendAt).min()
            let mergedRevoked = dups.compactMap(\.rejoinRevokedAt).max()
            // Solo si el keeper GANA algo: un merge no-op ensuciaría el plan y sus tests.
            if mergedBackend != keeper.isBackendGroup
                || mergedMoved != keeper.movedToBackendAt
                || mergedRevoked != keeper.rejoinRevokedAt {
                merges.append(.init(keeperID: keeper.id, isBackendGroup: mergedBackend,
                                    movedToBackendAt: mergedMoved, rejoinRevokedAt: mergedRevoked))
            }
        }
        return DedupPlan(toKeepIDs: toKeep, toDeleteIDs: toDelete,
                         duplicateZoneCounts: dupZones, channelMerges: merges)
    }

    /// Boot-time cleanup. Idempotent — no-op when no duplicates.
    /// - Returns: number of duplicate SplitGroup records removed.
    @discardableResult
    static func deduplicateSplitGroups(in context: ModelContext) -> Int {
        // Gate de quiescencia: aunque borra `SplitGroup` (store de grupos), comparte el MISMO
        // `NSPersistentStoreCoordinator` que el store personal → un `save()` durante el import del
        // restore dispara el `_assertionFailure`. Diferir (idempotente: re-corre en bootstrap/quiescencia).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("SplitGroupDedup.deduplicate", "import not quiescent")
            return 0
        }
        let groups: [SplitGroup]
        do {
            groups = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("SplitGroupDedup: fetch failed: \(error)")
            #endif
            return 0
        }

        let plan = computeDedupPlan(groups: groups)
        guard !plan.toDeleteIDs.isEmpty else { return 0 }

        // La fusión va ANTES del borrado: la evidencia de canal vive SOLO en las filas que están a punto de
        // desaparecer y no se puede re-derivar de nada local. Un solo `save()` abajo las comitea juntas.
        let mergesByKeeper = Dictionary(plan.channelMerges.map { ($0.keeperID, $0) }, uniquingKeysWith: { a, _ in a })
        for group in groups {
            guard let merge = mergesByKeeper[group.id] else { continue }
            group.isBackendGroup = merge.isBackendGroup
            group.movedToBackendAt = merge.movedToBackendAt
            group.rejoinRevokedAt = merge.rejoinRevokedAt
        }

        let toDeleteSet = Set(plan.toDeleteIDs)
        for group in groups where toDeleteSet.contains(group.id) {
            context.delete(group)
        }

        do {
            SaveBreadcrumb.willSave("SplitGroupDedup.deduplicate")
            try context.save()
            SaveBreadcrumb.didSave("SplitGroupDedup.deduplicate")
            #if DEBUG
            print("SplitGroupDedup: removed \(plan.toDeleteIDs.count) duplicates across \(plan.duplicateZoneCounts.count) zones")
            #endif
            for dup in plan.duplicateZoneCounts {
                #if DEBUG
                print("SplitGroupDedup:   zone=\(dup.zoneID) count=\(dup.count)")
                #endif
                MetricsService.cloudkitDuplicateDetected(
                    model: "SplitGroup",
                    count: dup.count,
                    context: .bootCleanup,
                    keySuffix: dup.zoneID
                )
            }
        } catch {
            #if DEBUG
            print("SplitGroupDedup: save failed: \(error)")
            #endif
        }
        return plan.toDeleteIDs.count
    }
}
