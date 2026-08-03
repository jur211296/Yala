//
//  CloudKitGroupMetaApplyLogicTests.swift
//  YalaTests / CloudSync
//
//  El sexto y último miembro de la familia «decidir sobre una ZONA de Grupos mirando UNA sola fila
//  `SplitGroup`» (los cinco anteriores: `GroupZoneCacheGate`, `performLocalCleanupAndDelete`,
//  `executeBatchStep`+`routesMembershipToBackend`, `GroupsSyncClient.applyGroupMeta`, y el par choke-point
//  C2 + dedup). Todos ellos trataban el SÍNTOMA —decidir/borrar/rutar mirando una fila de una zona con
//  duplicado—; ninguno cerraba de dónde salía la segunda fila.
//
//  `SplitSyncManager.applyGroupMeta` resolvía con `#Predicate { $0.id == modelID }` —identidad LOCAL— y la
//  identidad de un grupo es la ZONA. Una fila born-remote del pull backend nace con un UUID FRESCO y su
//  `cloudKitZoneID` pisado con el `group_id` del server, así que era INVISIBLE a ese fetch ⇒ el canal
//  CloudKit insertaba una GEMELA vía `CKRecordTranslator.group(from:)`, que nunca setea `isBackendGroup` ⇒
//  **el duplicado nacía ya MIXTO.**
//
//  **Pero es ENDURECIMIENTO, no un bug vivo, y eso se MIDIÓ:** el escenario exige un record CloudKit de una
//  zona que ya tiene fila born-backend, y esa misma precondición activa el guard G6-3 (`SplitSyncManager:1785`)
//  ⇒ el record se descarta antes de llegar. La única vía que quedaba es el FAIL-ABIERTO de
//  `backendGroupZoneNames`, que es lo que `.skipBackendZone` cierra desde dentro. Se enunció como «el
//  PRODUCTOR»; la medición lo corrige.
//
//  **Alcance declarado:** `applyGroupMeta` es `private` sobre un singleton con `CKSyncEngine` vivo y su
//  entrada es un `CKRecord` que solo llega por un fetch real ⇒ el comportamiento NO es unit-asertable. Lo
//  asertable es la tabla de decisión (`CloudKitGroupMetaApplyLogic`) y el CABLEADO, por source-scan.
//

import Foundation
import Testing

@testable import Yala

@Suite("SplitSyncManager · applyGroupMeta resuelve por ZONA")
struct CloudKitGroupMetaApplyLogicTests {

    // MARK: - La tabla de decisión

    /// **La aserción que carga el peso.** Zona con fila(s) pero ninguna que case el `modelID` del record:
    /// antes eso caía a `insert` y fabricaba la gemela. Ahora actualiza la canónica.
    ///
    /// MUTACIÓN: quitar el `if !zoneRowsAreBackend.isEmpty { return .updateCanonicalZoneRow }` → `.insert`.
    @Test func zoneRowWins_soTheTwinIsNeverInserted() {
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [false], hasRowMatchingID: false) == .updateCanonicalZoneRow)
        // Y también cuando la zona ya trae duplicado: se actualiza la canónica, no se añade una tercera.
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [false, false], hasRowMatchingID: false) == .updateCanonicalZoneRow)
    }

    /// El salto por CANAL va PRIMERO, antes que cualquier escritura: es defensa en profundidad del guard
    /// G6-3, que decide con `backendGroupZoneNames` y **falla ABIERTO** (su `catch` devuelve `[]`).
    /// Criterio ANY-row, igual que el resto de la familia.
    ///
    /// MUTACIÓN: mover el `contains(true)` por debajo del caso de la zona → `.updateCanonicalZoneRow`.
    @Test func backendZoneIsSkippedBeforeAnyWrite() {
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [true], hasRowMatchingID: false) == .skipBackendZone)
        // ANY-row: basta con que UNA de las filas lo sea, aunque la canónica no lo esté.
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [false, true], hasRowMatchingID: false) == .skipBackendZone)
        // Y gana también sobre el fallback por `id`.
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [true], hasRowMatchingID: true) == .skipBackendZone)
    }

    /// El fallback por `id` cubre la fila local cuya zona todavía no cuadra; `CKRecordTranslator.update` le
    /// escribe el `cloudKitZoneID` del record y la converge. Sin él, esa fila se duplicaría.
    ///
    /// MUTACIÓN: devolver siempre `.insert` en la última línea → `.insert` con `hasRowMatchingID: true`.
    @Test func idFallbackConvergesTheRowWhoseZoneDoesNotMatchYet() {
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [], hasRowMatchingID: true) == .updateRowMatchingID)
    }

    /// Sin zona y sin `id`, el grupo llega por primera vez a este device. No-regresión del caso normal.
    @Test func emptyEverywhereStillInserts() {
        #expect(CloudKitGroupMetaApplyLogic.resolve(
            zoneRowsAreBackend: [], hasRowMatchingID: false) == .insert)
    }

    // MARK: - Source-scan del cableado

    private static func managerSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(
            contentsOf: root.appendingPathComponent("Yala/Services/Groups/SplitSyncManager.swift"),
            encoding: .utf8)
    }

    private static func applyGroupMetaBody(_ src: String) -> String? {
        let signature = "private func applyGroupMeta(_ record: CKRecord, modelID: UUID, context: ModelContext, engineName: String) {"
        guard let start = src.range(of: signature) else { return nil }
        let rest = src[start.upperBound...]
        guard let end = rest.range(of: "\n    private func ") else { return nil }
        return String(rest[..<end.lowerBound])
    }

    /// El cableado: la fila se busca por ZONA y la decisión la toma la tabla pura. `$0.id == modelID` sigue
    /// presente —es el fallback— pero ya no puede ser lo PRIMERO que se consulta.
    ///
    /// MUTACIÓN: devolver el cuerpo a resolver solo por `id` deja las tres aserciones en rojo.
    @Test func sourceScan_applyGroupMetaResolvesByZoneFirst() throws {
        let body = try #require(Self.applyGroupMetaBody(try Self.managerSource()),
                                "cambió la firma o el cierre de applyGroupMeta: el escáner no tiene sujeto")
        let zoneFetch = try #require(body.range(of: "$0.cloudKitZoneID == zoneName"),
                                     "applyGroupMeta volvió a resolver sin mirar la zona")
        let idFetch = try #require(body.range(of: "$0.id == modelID"),
                                   "se perdió el fallback por `id`")
        #expect(zoneFetch.lowerBound < idFetch.lowerBound, "la zona debe consultarse ANTES que el `id`")
        #expect(body.contains("sortBy: [SortDescriptor(\\.createdAt, order: .forward)]"),
                "la fila canónica de la zona volvería a elegirla el store")
        #expect(body.contains("CloudKitGroupMetaApplyLogic.resolve("),
                "la decisión volvió a estar inline en vez de en la tabla pura")
    }

    /// El salto por canal tiene que ir ANTES de cualquier escritura, y eso ningún test de la tabla lo fija:
    /// la tabla puede ser correcta y el caller ignorar su resultado.
    ///
    /// MUTACIÓN: mover el `if resolution == .skipBackendZone` por debajo del `if let existing` deja esto rojo.
    @Test func sourceScan_backendSkipRunsBeforeTheWrites() throws {
        let body = try #require(Self.applyGroupMetaBody(try Self.managerSource()))
        let skip = try #require(body.range(of: "resolution == .skipBackendZone"),
                                "el caller dejó de consultar el salto por canal")
        let update = try #require(body.range(of: "CKRecordTranslator.update(existing, from: record)"))
        let insert = try #require(body.range(of: "context.insert(newGroup)"))
        #expect(skip.lowerBound < update.lowerBound && skip.lowerBound < insert.lowerBound,
                "el salto por canal debe cortar ANTES de actualizar o insertar")
    }

    /// **Conteo esperado.** Los otros cuatro `apply*` del manager SIGUEN resolviendo por `id`, y eso es
    /// correcto: la identidad de un gasto, un share, una liquidación o un member SÍ es su `id`. Sin este
    /// pin, «arreglar» los cuatro por simetría rompería la resolución de las hijas.
    ///
    /// MUTACIÓN: cambiar cualquiera de los cuatro a resolver por zona deja el conteo en rojo.
    @Test func sourceScan_theOtherFourApplyMethodsStillResolveByID() throws {
        let src = try Self.managerSource()
        for entity in ["SplitExpense", "SplitMember", "SplitShare", "SplitSettlement"] {
            #expect(src.contains("FetchDescriptor<\(entity)>(predicate: #Predicate { $0.id == modelID })"),
                    "apply\(entity) dejó de resolver por `id`, que es su identidad correcta")
        }
    }
}
