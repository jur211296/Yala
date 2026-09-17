//
//  GroupsDetachHistoryReplayTests.swift
//  YalaTests / CloudSync
//
//  Desasociar la cuenta de grupos borra las filas `Split*` LOCALMENTE. El SwiftData History de esos
//  deletes sobrevive al relanzamiento, así que la pregunta que fijan estos tests no es «¿salió algo del
//  teléfono hoy?» —el canal está cortado, no puede— sino «¿puede salir MAÑANA?».
//
//  Hasta el 2026-09-11 podía, y lo único que lo impedía era un efecto colateral del ORDEN dentro de
//  `syncCycleOnce`: el drain corre antes del pull, así que al re-asociar las zonas todavía no estaban
//  repobladas y `backendGroupZoneIDs` salía vacío. Bastaba con que ese primer drain lanzara —su `catch`
//  traga y no escribe cursor— para que el ciclo siguiera al pull, repoblara las zonas y el drain de
//  después tradujera a tombstone cada delete EMISIBLE — los de `SplitExpense`, `SplitShare` y
//  `SplitSettlement`; `SplitGroup` va `updateOnly` y `SplitMember` es pull-only, así que esos dos no salen.
//  Server-side un tombstone de gasto lo borra PARA TODOS LOS MIEMBROS.
//
//  El arreglo es UNO y no depende del orden: `DataWipeService.deleteLocalGroupsRows` firma su transacción
//  con `GroupsSyncClient.outboxSaveAuthor`, y el drain descarta por autor ANTES de traducir ⇒ estos deletes
//  dejan de ser traducibles mire el History desde donde lo mire. Conservar además el ancla del drain se
//  probó y se retiró: no protege estos deletes (son posteriores al ancla) y clavaba un suelo del corte de
//  purga del History. Lo que sigue cargando peso es que el borrado sea UNA transacción — el test (4) mide
//  el daño del par que la atomicidad impide.
//
//  Ticket: `detach-history-replay-can-tombstone-groups-on-next-launch`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// iCloud-KV de juguete: el «Empiezo de cero» escribe ahí el `onboardingMode` y no queremos tocar el del
/// Apple ID de la máquina. Molde de `RecordingKVStore` (`HandoverGroupsDomainTests`), que es `private`.
private final class MemoryKVStore: BeaconKeyValueStore, @unchecked Sendable {
    private var strings: [String: String] = [:]
    func setBool(_ value: Bool, forKey key: String) {}
    func setDouble(_ value: Double, forKey key: String) {}
    func setString(_ value: String, forKey key: String) { strings[key] = value }
    func bool(forKey key: String) -> Bool { false }
    func string(forKey key: String) -> String? { strings[key] }
    func double(forKey key: String) -> Double { 0 }
    func removeObject(forKey key: String) { strings[key] = nil }
    @discardableResult func synchronize() -> Bool { true }
}

@Suite("Grupos · el desasociar no deja History convertible en tombstones", .serialized)
@MainActor
struct GroupsDetachHistoryReplayTests {

    // MARK: - Infra (molde de `GroupsDrainHistoryStoreAnchorTests`: 3 stores ON-DISK, History real)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GDHR-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GDHR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GDHR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GDHR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// `outboxMirror: nil` — sin él, un `GroupsSyncClient()` pelado escribe en el espejo REAL del App
    /// Group (`GroupsOutboxMirror()`), que es estado compartido entre suites.
    private func makeClient() -> GroupsSyncClient { GroupsSyncClient(outboxMirror: nil) }

    private func outbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    private func tombstones(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try outbox(context).filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
    }

    private func clearOutbox(_ context: ModelContext) throws {
        // Bajo el autor del canal, como el propio push al confirmar el 2xx: esta transacción es de
        // `syncMetaSchema`, así que no es del store de Grupos y no mueve el ancla del drain de ninguna forma.
        try saveUnderOutboxAuthor(context) {
            for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        }
    }

    /// Espeja `GroupBackendMembershipService.saveUnderOutboxAuthor` (el camino REAL de `createGroup` y del
    /// apply de un pull: lo del canal se persiste bajo su autor para que el drain no lo re-emita).
    private func saveUnderOutboxAuthor(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    @discardableResult
    private func makeBackendGroup(_ context: ModelContext, zone: String? = nil) throws -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        if let zone { group.cloudKitZoneID = zone }
        try saveUnderOutboxAuthor(context) { context.insert(group) }
        return group
    }

    /// Cursores del PULL con contenido REAL. Sin esto, `groupCursorsJSON` ya vale `"{}"` por su default
    /// (`GroupSyncCursor.swift`) y toda aserción de «se soltó» pasa con la línea del reseteo borrada — la
    /// aserción que no puede fallar. Molde de `HandoverGroupsDomainTests.wipeLocalGroupsDomain_cursorKeeps…`.
    @discardableResult
    private func seedPullCursors(_ context: ModelContext, _ client: GroupsSyncClient,
                                 json: String) throws -> String {
        try saveUnderOutboxAuthor(context) {
            try client.loadOrCreateCursor(context).groupCursorsJSON = json
        }
        return json
    }

    /// Un gasto escrito por LA PERSONA: autor por defecto, que es justo lo que el drain traduce.
    @discardableResult
    private func addExpense(
        _ context: ModelContext, zone: String, amount: Double = 20
    ) throws -> SplitExpense {
        let expense = SplitExpense(groupZoneID: zone, amount: amount, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: "m1")
        context.insert(expense)
        try context.save()
        return expense
    }

    // MARK: - (1) CONTROL POSITIVO: en este mismo andamio, un borrado de verdad SÍ emite tombstone

    /// Sin esto, «cero tombstones» no dice nada: un fixture que no llegue a traducir nada da cero por
    /// razones que no tienen que ver con el arreglo (zona no backend, drain que no ve el store, ancla
    /// mal puesta). Aquí la persona borra UN gasto desde la app —autor por defecto, zona viva— y el
    /// tombstone TIENE que salir: ese borrado sí debe viajar y borrarlo para todos es lo correcto.
    @Test func borrarUnGastoDesdeLaApp_siEmiteSuTombstone() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()

        let group = try makeBackendGroup(context)
        let expense = try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)          // arranque del canal: crea cursor y emite el upsert
        try clearOutbox(context)                    // como si ya hubiera subido

        context.delete(expense)
        try context.save()                          // autor POR DEFECTO: el borrado de la persona
        client.drainOnce(context: context)

        let rows = try tombstones(context)
        #expect(rows.count == 1, "el borrado de un gasto por la persona debe viajar como tombstone")
        #expect(rows.first?.syncID == expense.id)
        #expect(rows.first?.groupID == group.cloudKitZoneID)
    }

    // MARK: - (2) El escenario del ticket, entero

    /// Desasociar con filas vivas → el primer `drainOnce` del arranque siguiente NO llega a anclar (el
    /// fallo que el `catch` de `performDrain` traga, reproducido con `_testSuppressTokenAdvance`) → se
    /// re-asocia y el pull repuebla las zonas → el drain siguiente vuelve a mirar el History.
    ///
    /// **Cero tombstones.** Con el agujero abierto salía uno por cada `Split*` borrado.
    ///
    /// MUTACIÓN: quitar `context.author = GroupsSyncClient.outboxSaveAuthor` de
    /// `DataWipeService.deleteLocalGroupsRows` deja este test en rojo.
    @Test func desasociar_luegoDrainQueNoAncla_luegoReasociar_noEmiteNingunTombstone() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()

        let group = try makeBackendGroup(context)
        let zone = group.cloudKitZoneID
        let expenseA = try addExpense(context, zone: zone, amount: 20)
        let expenseB = try addExpense(context, zone: zone, amount: 35)
        client.drainOnce(context: context)
        try clearOutbox(context)

        // El desasociar: filas `Split*` + outbox + la mitad del cursor que es del PULL.
        try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)

        // El primer drain del arranque siguiente CORRE pero no deja ancla (el fallo del ticket).
        client._testSuppressTokenAdvance = true
        client.drainOnce(context: context)
        client._testSuppressTokenAdvance = false

        // Re-asociar: el pull repuebla la zona. Lo que importa del pull es exactamente esto — que
        // `backendGroupZoneIDs` vuelva a contener la zona— y el apply lo escribe bajo el autor del canal.
        try makeBackendGroup(context, zone: zone)

        // Relanzamiento: cliente nuevo, sin nada en memoria.
        makeClient().drainOnce(context: context)

        // El outbox ENTERO, no solo los tombstones: el cursor se fue con las filas, así que este drain
        // re-barre el History completo y tampoco puede salir de ahí un upsert del corpus viejo.
        let rows = try outbox(context)
        #expect(rows.isEmpty, """
            El desasociar dejó \(rows.count) escritura(s) encoladas hacia el servidor \
            (\(rows.map { "\($0.entityType)/\($0.opRaw)" }.joined(separator: ", "))). Un tombstone de \
            gasto lo borra para TODOS los miembros del grupo. Con el agujero abierto salen DOS, uno por \
            gasto (\(expenseA.id) y \(expenseB.id)): el grupo no cuenta porque su emisión es `updateOnly`.
            """)
    }

    // MARK: - (3) El par coherente de esta frontera: filas, outbox y cursor se van JUNTOS

    /// «Filas borradas + cursor borrado», en UNA transacción. Los dos tienen que irse y tienen que irse a
    /// la vez: el cursor del PULL vivo con las filas muertas es el par que PIERDE datos al re-asociar (el
    /// server solo mandaría deltas nuevos y los grupos no volverían), y el cursor muerto con las filas
    /// vivas es el que re-emite el corpus viejo — lo que mide el test de abajo.
    ///
    /// Conservar el ANCLA del drain (`historyTokenData` y compañía) se probó en este mismo ticket y se
    /// retiró: no protege estos deletes —son posteriores al ancla, así que `fetchHistory` los devuelve
    /// igual— y dejaba clavado uno de los cuatro suelos del corte de purga del History. Lo que los protege
    /// es la firma, y eso lo mide el test (2).
    ///
    /// MUTACIÓN: quitar el borrado del cursor deja en rojo su aserción; quitar el del outbox, la suya.
    @Test func desasociar_borraFilasOutboxYCursorEnLaMismaTransaccion() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()

        let group = try makeBackendGroup(context)
        try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)

        // Precondiciones: hay las tres cosas que tienen que desaparecer.
        try seedPullCursors(context, client, json: #"{"zona-1":7}"#)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) > 0)
        #expect(try outbox(context).count > 0, "el drain encoló el upsert del gasto")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 1)

        try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context)

        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        #expect(try outbox(context).isEmpty, "el outbox de la cuenta que se suelta no se queda")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 0, """
            El cursor se va con las filas: dejarlo vivo haría que al re-asociar el server mandara solo \
            deltas nuevos y los grupos no volvieran a materializarse.
            """)
        #expect(!context.hasChanges, "una sola transacción: no queda nada sucio que otro save comitee")
    }

    // MARK: - (4) Por qué los dos tienen que irse JUNTOS (semántica del drain)

    /// El par prohibido, medido en este mismo andamio: **cursor borrado con las filas VIVAS**. Sin ancla,
    /// `fetchHistory` cae al escaneo COMPLETO del History y el drain vuelve a pasar por el traductor
    /// transacciones ya consumidas; como las filas siguen ahí, el `case` de insert/update SÍ resuelve la
    /// fila viva y sale **un upsert del gasto que el servidor ya tenía**, con HLC nuevo — que gana por LWW
    /// y pisa lo que otros miembros hayan cambiado.
    ///
    /// Es el contraste que da sentido al test de arriba: con las filas borradas el mismo escaneo completo
    /// no emite nada (no hay fila que resolver), y por eso la atomicidad es lo que carga el peso.
    ///
    /// No lleva mutación: fija un contrato del drain, no una línea de este arreglo.
    @Test func cursorBorradoConLasFilasVivas_reEmiteLoQueYaHabiaSubido() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()

        let group = try makeBackendGroup(context)
        try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)
        try clearOutbox(context)                    // el gasto ya subió y el servidor lo confirmó

        // Solo el cursor: las filas del grupo siguen VIVAS.
        try saveUnderOutboxAuthor(context) {
            for cursor in try context.fetch(FetchDescriptor<GroupSyncCursor>()) { context.delete(cursor) }
        }
        makeClient().drainOnce(context: context)

        let rows = try outbox(context)
        #expect(rows.count == 1, "sin ancla el drain re-barre el History entero")
        #expect(rows.first?.opRaw == SyncOutboxOp.upsert.rawValue, """
            Re-emitido como upsert con HLC NUEVO: el corpus viejo vuelve a salir del teléfono y pisa por \
            LWW lo que otros miembros hayan cambiado.
            """)
    }

    // MARK: - (5) El «Empiezo de cero» del Welcome hereda la firma, y su cursor sigue INTACTO

    /// El otro call-site de `deleteLocalGroupsRows`. Su par correcto en una frontera de USUARIO es otro
    /// —outbox muerto + cursor VIVO ENTERO, incluidos sus cursores del pull, que son la barrera que impide
    /// que el corpus del anterior baje al device del nuevo— y este test fija que la firma del borrado no
    /// se lo ha cambiado.
    @Test func empiezoDeCero_firmaSusDeletes_ySuCursorSigueIntacto() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()
        let defaults = UserDefaults(suiteName: "test.detach.replay.\(UUID().uuidString)")!

        let group = try makeBackendGroup(context)
        let zone = group.cloudKitZoneID
        try addExpense(context, zone: zone)
        client.drainOnce(context: context)
        try clearOutbox(context)

        let cursorsBefore = try seedPullCursors(context, client, json: #"{"zona-1":5}"#)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, retireCloudSession: {}, resetSyncState: {})

        #expect(try client.loadOrCreateCursor(context).groupCursorsJSON == cursorsBefore,
                "el handover conserva el cursor del pull ENTERO (regla 2.7): es la barrera del corpus")

        // La zona vuelve (el humano nuevo entra y su pull la repuebla) y el drain mira el History.
        try makeBackendGroup(context, zone: zone)
        makeClient().drainOnce(context: context)

        #expect(try tombstones(context).isEmpty, """
            El «Empiezo de cero» dejó tombstones encolados: son de los grupos del humano ANTERIOR y \
            viajarían con el JWT del nuevo.
            """)
    }
}
