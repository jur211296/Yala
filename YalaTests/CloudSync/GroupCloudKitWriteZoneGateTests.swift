//
//  GroupCloudKitWriteZoneGateTests.swift
//  YalaTests / CloudSync
//
//  Los DOS últimos sitios que decidían sobre una ZONA de Grupos mirando UNA sola fila `SplitGroup` (5.º y 6.º
//  de la familia; los cuatro anteriores son `GroupZoneCacheGate`, `performLocalCleanupAndDelete`,
//  `executeBatchStep`+`routesMembershipToBackend` y `applyGroupMeta`).
//
//   1. **El choke-point C2** — los CUATRO guards que deciden si algo sale hacia CKSyncEngine
//      (`SplitSyncManager.enqueueSave(modelID:group:)`, `enqueueDeletion(modelID:group:)`,
//      `recoverOwnedGroupZonesIfNeeded`, `recoverRecordsIfNeeded`) evaluaban `group.isBackendGroup ||
//      group.isMigratedFrozen` sobre la fila del PARÁMETRO. Con un duplicado MIXTO, el MISMO grupo pasaba o
//      no pasaba el guard según qué fila tuviera el caller en la mano ⇒ se encolaba a CKSyncEngine un record
//      de un grupo cuya verdad vive en el backend, que es exactamente lo que el guard existe para impedir —
//      y, en el caso C-3 (cambio de Apple ID), a la private DB de OTRA cuenta.
//
//   2. **El dedup era CIEGO AL CANAL** — `SplitGroupDeduplicationService.computeDedupPlan` elige keeper por
//      `createdAt` ASC y `isBackendGroup` no aparecía en el fichero: si el keeper resultaba ser la fila
//      NO-backend, al borrar la gemela marcada la zona salía de `GroupsSyncClient.backendGroupZoneIDs` (un
//      fetch de filas VIVAS) y con ella la pertenencia al canal nuevo, que es LOCAL-only y no se re-deriva de
//      nada. El keeper sigue siendo el más antiguo —criterio canónico del repo— pero ahora ADOPTA esa
//      evidencia antes de que se borre.
//
//  **Alcance declarado de lo que se puede probar aquí:** el guard C2 vive sobre `SplitSyncManager.shared`,
//  cuyos `CKSyncEngine` exigen un `CKContainer` con iCloud (device-only, ver la nota de
//  `SplitSyncManagerTests`) ⇒ el efecto del guard —encolar o no— NO es unit-asertable. Lo que sí lo es: la
//  DECISIÓN pura (`GroupFreezeLogic.zoneBlocksCloudKitWrites`) y el CABLEADO de los cuatro guards, que va por
//  source-scan (molde `AttestWiringTests`). El dedup sí es asertable entero.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el guard C2 y el dedup deciden por ZONA", .serialized)
struct GroupCloudKitWriteZoneGateTests {

    // MARK: - (1) La decisión pura del choke-point C2

    /// ANY-row: basta con que UNA fila de la zona bloquee. `inHandBlocks` cuenta siempre y es lo que degrada
    /// al comportamiento anterior cuando la zona no se pudo enumerar (sin contexto, o fetch que lanzó).
    ///
    /// MUTACIÓN: quitar el `|| rowsInZone.contains(true)` deja los dos primeros casos en rojo.
    @Test func zoneBlocksCloudKitWrites_isAnyRowOverTheZone() {
        // La gemela marcada arrastra a la zona aunque la fila en mano esté limpia. ÉSTE es el defecto.
        #expect(GroupFreezeLogic.zoneBlocksCloudKitWrites(inHandBlocks: false, rowsInZone: [false, true]))
        #expect(GroupFreezeLogic.zoneBlocksCloudKitWrites(inHandBlocks: false, rowsInZone: [true]))
        // Ninguna fila bloquea ⇒ la zona escribe por CloudKit con normalidad.
        #expect(!GroupFreezeLogic.zoneBlocksCloudKitWrites(inHandBlocks: false, rowsInZone: [false, false]))
        // La fila en mano manda por sí sola, y es la degradación: zona no enumerable ⇒ comportamiento previo.
        #expect(GroupFreezeLogic.zoneBlocksCloudKitWrites(inHandBlocks: true, rowsInZone: []))
        #expect(!GroupFreezeLogic.zoneBlocksCloudKitWrites(inHandBlocks: false, rowsInZone: []))
    }

    /// El predicado por FILA no cambia — lo que cambió es el cuantificador. `isFrozen` conserva la
    /// mitigación #9 (owner tras reinstall con `ckSystemFieldsData`) como NO congelado, y eso hay que
    /// re-afirmarlo aquí porque el fix de la zona la afecta: una fila #9 queda bloqueada **solo** si alguna
    /// gemela de su zona lleva la marca, y ahí la premisa de la #9 (que `isBackendGroup` se perdió en el
    /// reinstall) es falsa — la evidencia está en la gemela.
    @MainActor @Test func isFrozen_stillExemptsTheOwnerReinstallMitigation() {
        let migrated: Date? = Date(timeIntervalSince1970: 1)
        // #9: owner + systemFields + migrado ⇒ NO congelado por sí misma.
        let mitigation9 = GroupFreezeLogic.isFrozen(
            movedToBackendAt: migrated, isBackendGroup: false, isOwner: true, hasCKSystemFields: true)
        #expect(mitigation9 == false)
        // Sin systemFields sí congela; sin `movedToBackendAt` no hay migración que congelar.
        let noSystemFields = GroupFreezeLogic.isFrozen(
            movedToBackendAt: migrated, isBackendGroup: false, isOwner: true, hasCKSystemFields: false)
        #expect(noSystemFields == true)
        let notMigrated = GroupFreezeLogic.isFrozen(
            movedToBackendAt: nil, isBackendGroup: false, isOwner: true, hasCKSystemFields: true)
        #expect(notMigrated == false)
        // Pero en una zona MIXTA la #9 sí queda bloqueada: la gemela backend es la evidencia que la #9
        // asume perdida.
        #expect(GroupFreezeLogic.zoneBlocksCloudKitWrites(
            inHandBlocks: false, rowsInZone: [false, true]))
    }

    // MARK: - (2) El dedup adopta la evidencia de canal

    /// `@Model` directos sin `ModelContext` (R8, molde de `SplitGroupDeduplicationServiceTests`).
    @MainActor
    private func makeGroup(
        zone: String, createdAt: Date, isBackendGroup: Bool = false,
        movedToBackendAt: Date? = nil, rejoinRevokedAt: Date? = nil,
        backendReInviteToken: String? = nil
    ) -> SplitGroup {
        let g = SplitGroup()
        g.cloudKitZoneID = zone
        g.createdAt = createdAt
        g.isBackendGroup = isBackendGroup
        g.movedToBackendAt = movedToBackendAt
        g.rejoinRevokedAt = rejoinRevokedAt
        g.backendReInviteToken = backendReInviteToken
        return g
    }

    /// **La aserción que carga el peso.** Keeper = la más antigua y NO-backend; la gemela marcada se borra.
    /// Sin fusión, la zona perdía `isBackendGroup` —local-only, no re-derivable— y salía de
    /// `backendGroupZoneIDs`.
    ///
    /// MUTACIÓN: quitar el cálculo de `channelMerges` (o dejarlo siempre vacío) deja `merge` en nil.
    @MainActor @Test func computeDedupPlan_keeperAdoptsTheBackendFlagOfTheDiscardedTwin() {
        let keeper = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 100))
        let twin = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 200),
                             isBackendGroup: true)

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [twin, keeper])

        #expect(plan.toKeepIDs == [keeper.id], "el keeper sigue siendo el más antiguo (criterio canónico)")
        #expect(plan.toDeleteIDs == [twin.id])
        let merge = try? #require(plan.channelMerges.first)
        #expect(merge?.keeperID == keeper.id)
        #expect(merge?.isBackendGroup == true, "la zona habría perdido su pertenencia al canal backend")
    }

    /// `movedToBackendAt` (el más antiguo: es cuándo se migró) y `rejoinRevokedAt` (la revocación más
    /// reciente) también se heredan. Perder la revocación dejaría re-entrar con una credencial ya retirada.
    ///
    /// MUTACIÓN: quitar `movedToBackendAt` o `rejoinRevokedAt` del merge deja su aserción en rojo.
    @MainActor @Test func computeDedupPlan_keeperAdoptsMigrationAndRevocationEvidence() {
        let early = Date(timeIntervalSince1970: 50)
        let late = Date(timeIntervalSince1970: 900)
        let keeper = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 100))
        let twin = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 200),
                             movedToBackendAt: early, rejoinRevokedAt: late)

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [keeper, twin])

        let merge = try? #require(plan.channelMerges.first)
        #expect(merge?.movedToBackendAt == early)
        #expect(merge?.rejoinRevokedAt == late)
    }

    /// **La credencial NO se hereda.** `backendReInviteToken` habilita una re-entrada; heredarlo resucitaría
    /// en el keeper un acceso que la revocación de la gemela retiró (regla C-3: «con una sola viva, el humano
    /// nuevo entra COMO el anterior»). El `ChannelMerge` no lo lleva ni puede llevarlo.
    ///
    /// MUTACIÓN: añadir `backendReInviteToken` a `ChannelMerge` rompe la compilación de esta aserción, que es
    /// justamente el pin — el tipo es el que impide la fusión peligrosa.
    @MainActor @Test func computeDedupPlan_neverMergesTheReInviteCredential() throws {
        let keeper = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 100),
                               rejoinRevokedAt: .init(timeIntervalSince1970: 500))
        let twin = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 200),
                             isBackendGroup: true, backendReInviteToken: "tok-vivo")

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [keeper, twin])

        let merge = try #require(plan.channelMerges.first)
        // El merge solo transporta evidencia que RESTRINGE; su tipo no tiene sitio para la credencial.
        #expect(merge.isBackendGroup)
        #expect(merge.rejoinRevokedAt == Date(timeIntervalSince1970: 500),
                "la revocación del keeper sobrevive")
        #expect(keeper.backendReInviteToken == nil, "el keeper no adopta el token de la gemela")
    }

    /// Sin duplicado no hay fusión, y con un duplicado que no aporta nada tampoco: un merge no-op
    /// ensuciaría el plan. No-regresión del caso normal.
    @MainActor @Test func computeDedupPlan_emitsNoMergeWhenThereIsNothingToAdopt() {
        let solo = makeGroup(zone: "Zone-A", createdAt: .init(timeIntervalSince1970: 100))
        #expect(SplitGroupDeduplicationService.computeDedupPlan(groups: [solo]).channelMerges.isEmpty)

        let keeper = makeGroup(zone: "Zone-B", createdAt: .init(timeIntervalSince1970: 100),
                               isBackendGroup: true)
        let twin = makeGroup(zone: "Zone-B", createdAt: .init(timeIntervalSince1970: 200),
                             isBackendGroup: true)
        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [keeper, twin])
        #expect(plan.toDeleteIDs == [twin.id])
        #expect(plan.channelMerges.isEmpty, "el keeper ya lo tenía todo: no hay nada que adoptar")
    }

    // MARK: - Source-scan del cableado (el guard C2 no es unit-asertable)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// **Conteo esperado por sitio.** Los CUATRO guards C2 tienen que pasar por el helper por zona, y ninguno
    /// puede volver a evaluar el predicado por fila inline. Sin el conteo, un guard nuevo (o un renombrado)
    /// pasaría en verde sin comprobar nada — la familia de «Executed 0 tests».
    ///
    /// MUTACIÓN: devolver cualquiera de los cuatro a `group.isBackendGroup || group.isMigratedFrozen` deja
    /// las dos aserciones en rojo.
    @Test func sourceScan_allFourC2GuardsAskTheZone() throws {
        let manager = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        // 4 call-sites (enqueueSave, enqueueDeletion, zoneRecovery, recordRecovery) + la definición del
        // helper + su llamada a la primitiva pura de `GroupFreezeLogic`.
        let uses = manager.components(separatedBy: "zoneBlocksCloudKitWrites(").count - 1
        #expect(uses == 6, "los guards C2 que pasan por el helper por zona cambiaron: \(uses) (esperados 6)")
        #expect(!manager.contains("isBackendGroup || group.isMigratedFrozen)"),
                "un guard C2 volvió a decidir con la fila del parámetro")
        #expect(!manager.contains("$0.isBackendGroup || $0.isMigratedFrozen)"),
                "el filtro del zoneRecovery volvió a decidir por fila")
    }

    /// El helper tiene que degradar a la fila en mano —nunca abrir el paso— cuando no puede enumerar la zona,
    /// y cortar sin fetch cuando la fila ya bloquea (el `enqueueSave` tiene ~30 call-sites).
    ///
    /// MUTACIÓN: cambiar cualquiera de los dos `return inHandBlocks` por `return false` deja esto rojo.
    @Test func sourceScan_c2HelperFailsToTheRowInHand() throws {
        let manager = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        guard let start = manager.range(of: "private func zoneBlocksCloudKitWrites(_ group: SplitGroup) -> Bool {"),
              let end = manager.range(of: "\n    /// Enqueue a save, auto-routing", range: start.upperBound..<manager.endIndex)
        else {
            Issue.record("cambió la firma o el cierre del helper: el escáner no tiene sujeto")
            return
        }
        let body = String(manager[start.upperBound..<end.lowerBound])
        #expect(body.contains("if inHandBlocks { return true }"), "se perdió el corte sin fetch")
        #expect(body.components(separatedBy: "return inHandBlocks").count - 1 == 2,
                "el helper debe degradar a la fila en mano SIN contexto y con el fetch en error")
        #expect(!body.contains("return false"), "el helper abre el paso en un camino de error")
    }

    /// La fusión del dedup va ANTES del borrado: la evidencia vive SOLO en las filas que van a desaparecer.
    /// No es unit-asertable sin `ModelContext` (la primitiva pura devuelve el plan, no lo aplica).
    ///
    /// MUTACIÓN: mover el bucle de fusión por debajo del bucle de borrado deja esto rojo.
    @Test func sourceScan_dedupMergesBeforeDeleting() throws {
        let service = try Self.source("Yala/Services/Groups/SplitGroupDeduplicationService.swift")
        let merge = try #require(service.range(of: "mergesByKeeper[group.id]"),
                                 "el dedup ya no adopta la evidencia de canal del descartado")
        let delete = try #require(service.range(of: "toDeleteSet.contains(group.id)"))
        #expect(merge.lowerBound < delete.lowerBound,
                "la fusión debe correr ANTES del borrado, o la evidencia ya no existe")
        // Acotado al CÓDIGO: el docblock nombra la credencial a propósito, para explicar por qué NO se
        // fusiona. Lo que se prohíbe es tocarla.
        #expect(!service.contains("group.backendReInviteToken ="),
                "el dedup empezó a escribir la credencial de re-invitación: eso resucita un acceso revocado")
        #expect(!service.contains("let backendReInviteToken"),
                "`ChannelMerge` no puede transportar la credencial")
    }
}
