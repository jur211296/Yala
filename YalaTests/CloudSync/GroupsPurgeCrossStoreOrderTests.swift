//
//  GroupsPurgeCrossStoreOrderTests.swift
//  YalaTests / CloudSync
//
//  **El borrado del dominio Grupos no es una transacción: es un ORDEN.** Ticket
//  `groups-purge-save-crosses-two-stores-without-atomicity`.
//
//  `DataWipeService.deleteLocalGroupsRows` hacía un solo `save()` que abarcaba tres stores —los cinco `Split*`
//  (`groups.sqlite`), el outbox y el cursor que le pasa el llamador (`syncmeta.sqlite`) y, en «Empiezo de cero»,
//  `GroupBridgePreference` (`personal.sqlite`)—, y los docblocks lo llamaban «UNA transacción». **Medido el
//  2026-10-01** con tres stores on-disk y uno de ellos en solo lectura: el `save()` falla, pero los otros dos
//  quedan escritos. Con el de Grupos cerrado salía `SplitGroup = 1, GroupSyncCursor = 0` — «cursor borrado +
//  filas vivas», el par que al volver a entrar re-emite un upsert con HLC nuevo por fila y pisa en el servidor lo
//  que hayan editado los demás miembros (lo fija `GroupsDetachHistoryReplayTests`).
//
//  El arreglo es un `save()` por tramo en este orden: outbox → `GroupBridgePreference` → filas de Grupos →
//  cursor. Y todas las lecturas delante, para que un `fetch` que lanza siga sin escribir nada. Las tres reglas que
//  fijan los casos de aquí:
//   · el cursor nunca se va con filas de Grupos vivas;
//   · en «Empiezo de cero», tras cualquier fallo quedan filas de Grupos: son el testigo con el que sus reintentos
//     saben que falta borrar (`ContentView.checkHasExistingData` cuenta `SplitGroup`);
//   · en el desasociar, el único corte con las filas ya fuera es «cursor vivo» y SIN outbox: con dead-letters el
//     Merkle de Grupos salta el grupo y ese par dejaría de repararse solo.
//
//  **Por qué el fallo se inyecta con `allowsSave: false`**: es un fallo del `save()` REAL, dentro de Core Data,
//  store a store — no un `throw` en `alsoDeleting`, que corre antes del `save()`. Se probó también con un lock
//  exclusivo de SQLite desde otra conexión: Core Data espera sin tope, así que no sirve como fallo inyectable.
//
//  **Por qué cada caso prueba `attempts` contenedores**: en qué orden comitea Core Data los stores de un `save()`
//  cruzado cambia de un contenedor a otro. Con el `save()` único un intento podía salir limpio y el siguiente dejar
//  el par peligroso; un caso de un solo contenedor dejaba vivo ese mutante (medido).
//
//  **El oráculo se lee de un contenedor NUEVO** sobre los mismos ficheros: es lo que hay en disco, que es lo que
//  ve el arranque siguiente.
//
//  MUTACIONES verificadas a exit 65: ver el ticket (`tickets/done/…`, sección «Resuelto»).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el borrado del dominio se corta en el orden que no daña", .serialized)
@MainActor
struct GroupsPurgeCrossStoreOrderTests {

    // MARK: - Infra

    private enum Store { case personal, groups, syncMeta }

    /// Cuántos contenedores prueba cada caso cuyo veredicto, con un orden equivocado, dependería del orden de
    /// commit de Core Data. Con el `save()` único el par peligroso salía en 6 de 20.
    private static let attempts = 12

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GPCS-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("GPCS: Error: \(error)") }
    }

    /// Los tres stores de producción sobre `dir`, con `readOnly` en solo lectura. Cada llamada es un contenedor
    /// NUEVO —nombres de configuración únicos—, que es lo que permite leer el disco sin el contexto del borrado.
    private func makeContext(_ dir: URL, readOnly: Store? = nil) throws -> ModelContext {
        let tag = "GPCS-\(UUID().uuidString.prefix(8))"
        let personal = ModelConfiguration(
            "\(tag)-P", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"),
            allowsSave: readOnly != .personal, cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "\(tag)-G", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"),
            allowsSave: readOnly != .groups, cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "\(tag)-M", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"),
            allowsSave: readOnly != .syncMeta, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    /// Un dominio de Grupos en los tres stores: grupo y gasto, override del bridge, el cursor y —salvo que se pida
    /// sin él— una dead-letter del outbox (lo único que «Empiezo de cero» deja borrar; una fila viva la para su
    /// cinturón, y el desasociar no llega al borrado con filas vivas).
    private func seed(_ dir: URL, withDeadLetter: Bool = true) throws {
        let context = try makeContext(dir)
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        context.insert(group)
        context.insert(SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 20, expenseDescription: "Cena"))
        context.insert(GroupBridgePreference(groupZoneID: group.cloudKitZoneID, bridgeOverride: false))
        if withDeadLetter {
            context.insert(GroupSyncOutbox(
                syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                fieldsJSON: "{}", author: "a", rejectedReason: "upstream_400:x"))
        }
        context.insert(GroupSyncCursor(groupCursorsJSON: "{\"g1\":5}"))
        try context.save()
    }

    private struct Disk: Equatable, CustomStringConvertible {
        var groups = 0, expenses = 0, cursors = 0, outbox = 0, bridgePrefs = 0
        var description: String {
            "grupos=\(groups) gastos=\(expenses) cursor=\(cursors) outbox=\(outbox) override=\(bridgePrefs)"
        }
    }

    private func disk(_ dir: URL) throws -> Disk {
        let context = try makeContext(dir)
        return Disk(
            groups: try context.fetchCount(FetchDescriptor<SplitGroup>()),
            expenses: try context.fetchCount(FetchDescriptor<SplitExpense>()),
            cursors: try context.fetchCount(FetchDescriptor<GroupSyncCursor>()),
            outbox: try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()),
            bridgePrefs: try context.fetchCount(FetchDescriptor<GroupBridgePreference>()))
    }

    private static let untouched = Disk(groups: 1, expenses: 1, cursors: 1, outbox: 1, bridgePrefs: 1)

    /// La regla que el ticket existe para cumplir, en los dos llamadores y en todo corte.
    private func expectNoCursorGoneWithLiveRows(_ after: Disk, attempt: Int) {
        #expect(!(after.cursors == 0 && after.groups > 0), """
            Intento \(attempt): el borrado dejó el cursor borrado con las filas de Grupos VIVAS (\(after)). Al \
            volver a entrar en la cuenta, el drain re-barre el History sin ancla y re-emite un upsert con HLC nuevo \
            por fila: pisa en el servidor lo que hayan editado los demás miembros.
            """)
    }

    // MARK: - Desasociar

    @Test("Desasociar con el store de Grupos que no guarda: el cursor sigue junto a las filas")
    func detach_groupsStoreFails_keepsCursorWithRows() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir)
            let context = try makeContext(dir, readOnly: .groups)

            #expect(throws: (any Error).self) { try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context) }

            let after = try disk(dir)
            expectNoCursorGoneWithLiveRows(after, attempt: attempt)
            // El outbox va primero y entra; lo demás sigue en su sitio.
            #expect(after == Disk(groups: 1, expenses: 1, cursors: 1, outbox: 0, bridgePrefs: 1),
                    "intento \(attempt): \(after)")
            #expect(!context.hasChanges, "el tramo que falla deja el contexto limpio")
        }
    }

    @Test("Desasociar con el sync-meta que no guarda y una dead-letter: no se escribe nada")
    func detach_syncMetaFailsWithDeadLetter_writesNothing() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir)
            let context = try makeContext(dir, readOnly: .syncMeta)

            #expect(throws: (any Error).self) { try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context) }

            // Con las filas fuera y la dead-letter dentro, el Merkle saltaría el grupo y nada lo re-bajaría: por
            // eso el outbox va delante de las filas, y aquí es él quien falla primero.
            let after = try disk(dir)
            expectNoCursorGoneWithLiveRows(after, attempt: attempt)
            #expect(!(after.groups == 0 && after.outbox > 0), "intento \(attempt): filas fuera con dead-letter: \(after)")
            #expect(after == Self.untouched, "intento \(attempt): \(after)")
        }
    }

    @Test("Desasociar con el sync-meta que no guarda y sin outbox: el par REPARABLE, y el reintento lo termina")
    func detach_syncMetaFailsWithoutOutbox_leavesTheRepairablePair_andRetryFinishes() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir, withDeadLetter: false)
            let context = try makeContext(dir, readOnly: .syncMeta)

            #expect(throws: (any Error).self) { try CloudSessionSignOut.purgeGroupsDomainForDetach(context: context) }

            // «Filas borradas + cursor vivo», sin outbox: el único corte con las filas ya fuera. Local, y con
            // salida — el reintento que arma el desasociar, y el Merkle de Grupos si la persona vuelve a entrar.
            let after = try disk(dir)
            expectNoCursorGoneWithLiveRows(after, attempt: attempt)
            #expect(after == Disk(groups: 0, expenses: 0, cursors: 1, outbox: 0, bridgePrefs: 1),
                    "intento \(attempt): \(after)")
            #expect(!context.hasChanges, "el tramo que falla deja el contexto limpio")

            // El reintento (`retryDetachPurge`) es la misma función sobre lo que quedó: idempotente.
            try CloudSessionSignOut.purgeGroupsDomainForDetach(context: try makeContext(dir))
            #expect(try disk(dir) == Disk(groups: 0, expenses: 0, cursors: 0, outbox: 0, bridgePrefs: 1))
        }
    }

    @Test("Una lectura que falla ANTES de guardar no escribe nada en disco")
    func readFailureBeforeAnySave_writesNothing() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        try seed(dir)
        let context = try makeContext(dir)
        struct FalloDeLectura: Error {}

        // `alsoDeleting` es la lectura del outbox y del cursor. Corre delante del primer `save()`: si se moviera
        // detrás, un fetch que lanza dejaría escrito lo de antes.
        #expect(throws: FalloDeLectura.self) {
            try DataWipeService.deleteLocalGroupsRows(in: context, includingBridgePreferences: true) {
                throw FalloDeLectura()
            }
        }
        #expect(try disk(dir) == Self.untouched)
        #expect(!context.hasChanges)
    }

    @Test("Control positivo: con los tres stores escribibles el desasociar vacía filas, outbox y cursor")
    func detach_allStoresWritable_purgesEverything() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        try seed(dir)

        try CloudSessionSignOut.purgeGroupsDomainForDetach(context: try makeContext(dir))

        #expect(try disk(dir) == Disk(groups: 0, expenses: 0, cursors: 0, outbox: 0, bridgePrefs: 1))
    }

    // MARK: - «Empiezo de cero» (`wipeLocalGroupsDomain`, el escritor de sus tres llamadores)

    private func wipeForFreshStart(_ context: ModelContext, defaults: UserDefaults) throws {
        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, retireCloudSession: {}, resetSyncState: {}, witness: .quiet)
    }

    /// El fallo tiene que venir del `save()`, no del cinturón de filas sin subir: con el cinturón, «no se tocó
    /// nada» se cumpliría por el input.
    private func expectSaveFailure(_ body: () throws -> Void) {
        do {
            try body()
            Issue.record("el borrado tenía que lanzar")
        } catch is DataWipeService.GroupsDomainWipeError {
            Issue.record("lanzó el cinturón de filas sin subir, no el save(): el caso no mide el orden")
        } catch {}
    }

    /// Lo que «Empiezo de cero» tiene que conservar tras CUALQUIER fallo: filas de Grupos (el testigo de que falta
    /// borrar), el cursor (la barrera del bug 31dded30) y el sello sin escribir.
    private func expectFreshStartRetriable(_ after: Disk, defaults: UserDefaults, attempt: Int) {
        expectNoCursorGoneWithLiveRows(after, attempt: attempt)
        #expect(after.groups > 0, """
            Intento \(attempt): el borrado falló con las filas de Grupos ya fuera (\(after)). Los reintentos de \
            «Empiezo de cero» cuentan `SplitGroup` para saber si queda algo por borrar: darían esto por hecho y nadie \
            escribiría el sello ni quitaría lo que quedó.
            """)
        #expect(after.cursors == 1, "«Empiezo de cero» conserva el cursor: es la barrera del bug 31dded30")
        #expect(!defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart),
                "sin borrado no hay relevo: el sello no se escribe")
    }

    @Test("«Empiezo de cero» con el store de Grupos que no guarda: quedan las filas, y el reintento termina")
    func freshStart_groupsStoreFails_keepsTheWitness_andRetryFinishes() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir)
            let defaults = makeIsolatedDefaults()
            let context = try makeContext(dir, readOnly: .groups)

            expectSaveFailure { try wipeForFreshStart(context, defaults: defaults) }

            let after = try disk(dir)
            expectFreshStartRetriable(after, defaults: defaults, attempt: attempt)
            #expect(after == Disk(groups: 1, expenses: 1, cursors: 1, outbox: 0, bridgePrefs: 0),
                    "intento \(attempt): outbox y override van antes que las filas: \(after)")

            try wipeForFreshStart(try makeContext(dir), defaults: defaults)
            #expect(try disk(dir) == Disk(groups: 0, expenses: 0, cursors: 1, outbox: 0, bridgePrefs: 0))
            #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart))
        }
    }

    @Test("«Empiezo de cero» con el store personal que no guarda: quedan las filas, y el reintento termina")
    func freshStart_personalStoreFails_keepsTheWitness_andRetryFinishes() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir)
            let defaults = makeIsolatedDefaults()
            let context = try makeContext(dir, readOnly: .personal)

            expectSaveFailure { try wipeForFreshStart(context, defaults: defaults) }

            let after = try disk(dir)
            expectFreshStartRetriable(after, defaults: defaults, attempt: attempt)
            #expect(after == Disk(groups: 1, expenses: 1, cursors: 1, outbox: 0, bridgePrefs: 1),
                    "intento \(attempt): \(after)")

            try wipeForFreshStart(try makeContext(dir), defaults: defaults)
            #expect(try disk(dir) == Disk(groups: 0, expenses: 0, cursors: 1, outbox: 0, bridgePrefs: 0))
            #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart))
        }
    }

    @Test("«Empiezo de cero» con el sync-meta que no guarda: no se escribe nada")
    func freshStart_syncMetaFails_writesNothing() throws {
        for attempt in 1...Self.attempts {
            let dir = try freshDir()
            defer { cleanup(dir) }
            try seed(dir)
            let defaults = makeIsolatedDefaults()
            let context = try makeContext(dir, readOnly: .syncMeta)

            expectSaveFailure { try wipeForFreshStart(context, defaults: defaults) }

            let after = try disk(dir)
            expectFreshStartRetriable(after, defaults: defaults, attempt: attempt)
            #expect(after == Self.untouched, "intento \(attempt): \(after)")
        }
    }
}
