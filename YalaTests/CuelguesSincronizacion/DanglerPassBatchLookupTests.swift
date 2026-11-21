//
//  DanglerPassBatchLookupTests.swift
//  YalaTests / CuelguesSincronizacion
//
//  YALA-IOS-13 (19-nov, 2.3 (4), iPhone 14): la app se congelaba por completo al terminar un ciclo de la nube. La pila
//  acaba en `CloudSyncEngine.reresolveDanglingRefs` → `EntityApplyMap.reresolveDangler` → `findTransactionItem` →
//  `fetchFirstOrThrow`: el pase final de las referencias colgadas buscaba DOS filas sueltas por dangler (la fila y su
//  destino), en tablas sin índice y en el hilo principal. Tras la primera bajada de la nube hay cientos de danglers
//  (movimientos que llegan antes que su categoría o su cuenta) y el pase corre al final de CADA ciclo, también tras
//  guardar un movimiento.
//
//  El arreglo de la página del apply (YALA-IOS-J, `ApplyPageBatchLookupTests`) no llegaba aquí: la caché vive solo dentro
//  de `applyPage`. Ahora el pase lee por lote antes del bucle (`EntityApplyMap.prepareDanglerLookups`).
//
//  Tres cosas que fijar: (1) el pase ya no hace una búsqueda suelta por dangler —testigo
//  `EntityApplyMap._testSingleRowFetches`—; (2) cada desenlace sigue igual: resuelto, fila que ya no existe, destino que
//  aún no llegó, lectura que falla; (3) la caché no sobrevive al pase.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-13 · el pase de refs colgadas busca por lote", .serialized)
@MainActor
struct DanglerPassBatchLookupTests {

    // MARK: - Infra (molde de ApplyPageBatchLookupTests: container on-disk con los tres stores)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DanglerPass-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration("DP-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("DP-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("DP-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, meta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private let txTable = "tx_items"
    private let draftTable = "inbox_drafts"

    private struct Seeded {
        let account: Account
        let categoryID: UUID
        /// Movimientos SIN categoría ni cuenta: los que tienen un dangler encima.
        let orphanTx: [UUID]
        /// Movimientos completos, de relleno (lo que un `fetch` sin índice recorre).
        let fillerTx: [UUID]
    }

    /// `orphans` movimientos sin categoría ni cuenta + `filler` completos, una cuenta y una categoría.
    private func seed(_ context: ModelContext, orphans: Int, filler: Int) throws -> Seeded {
        let account = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        let category = Category(name: "C", colorHex: "#000000", isIncome: false)
        let categoryID = UUID()
        category.syncID = categoryID
        context.insert(category)
        var orphanTx: [UUID] = []
        for i in 0..<orphans {
            let tx = TransactionItem(date: .now, amount: Double(i), currencyCode: "PEN", category: nil, account: nil)
            let sid = UUID()
            tx.syncID = sid
            context.insert(tx)
            orphanTx.append(sid)
        }
        var fillerTx: [UUID] = []
        for i in 0..<filler {
            let tx = TransactionItem(date: .now, amount: Double(i), currencyCode: "PEN", category: category, account: account)
            let sid = UUID()
            tx.syncID = sid
            context.insert(tx)
            fillerTx.append(sid)
        }
        try context.save()
        return Seeded(account: account, categoryID: categoryID, orphanTx: orphanTx, fillerTx: fillerTx)
    }

    private func dangler(_ table: String, row: UUID, column: String, target: UUID) -> SyncDanglingRef {
        SyncDanglingRef(entityTable: table, rowSyncID: row, column: column, targetUUID: target)
    }

    private func danglers(_ context: ModelContext) throws -> [SyncDanglingRef] {
        try context.fetch(FetchDescriptor<SyncDanglingRef>())
    }

    private func tx(_ sid: UUID, _ context: ModelContext) throws -> TransactionItem? {
        try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.syncID == sid })).first
    }

    // MARK: - 1. Testigo: el pase no busca dos filas por dangler

    @Test func theDanglerPass_doesNotLookUpTwoRowsPerDangler() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 300, filler: 200)
        // 150 que se resuelven (categoría que ya está), 150 que siguen colgados (categoría que no llegó).
        for (i, sid) in s.orphanTx.enumerated() {
            context.insert(dangler(txTable, row: sid, column: "category_ref", target: i < 150 ? s.categoryID : UUID()))
        }
        try context.save()

        EntityApplyMap._testSingleRowFetches = 0
        DanglerRelationshipBatch._testBulkAssigned = 0
        CloudSyncEngine().reresolveDanglingRefs(context: context)
        let singleFetches = EntityApplyMap._testSingleRowFetches

        // Sin el arreglo: una búsqueda de la fila y otra del destino por dangler, 600 para 300.
        #expect(singleFetches < 20, "búsquedas sueltas: \(singleFetches)")
        // Y los 150 que se resuelven se asignan en bloque, no uno a uno (cada asignación suelta reescribe la lista inversa).
        #expect(DanglerRelationshipBatch._testBulkAssigned == 150)
        #expect(try danglers(context).count == 150)
    }

    // MARK: - 2. Los desenlaces no cambian

    @Test func everyOutcome_isTheSameAsBefore() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 4, filler: 20)
        let missingCategory = UUID()
        let goneRow = UUID()

        // Borrador cuyo movimiento aprobado es un movimiento que YA está: el destino es una fila de la tabla grande.
        let draft = InboxDraft(note: "d")
        let draftID = UUID()
        draft.syncID = draftID
        context.insert(draft)

        context.insert(dangler(txTable, row: s.orphanTx[0], column: "category_ref", target: s.categoryID))       // resuelve
        context.insert(dangler(txTable, row: s.orphanTx[1], column: "account_ref", target: s.account.shortcutID)) // resuelve
        context.insert(dangler(txTable, row: s.orphanTx[2], column: "category_ref", target: missingCategory))     // sigue
        context.insert(dangler(txTable, row: goneRow, column: "category_ref", target: s.categoryID))              // fila ida
        context.insert(dangler(draftTable, row: draftID, column: "approved_transaction_ref", target: s.fillerTx[7]))
        try context.save()

        CloudSyncEngine().reresolveDanglingRefs(context: context)

        #expect(try tx(s.orphanTx[0], context)?.category?.syncID == s.categoryID)
        #expect(try tx(s.orphanTx[1], context)?.account?.shortcutID == s.account.shortcutID)
        #expect(try tx(s.orphanTx[2], context)?.category == nil)
        #expect(draft.approvedTransaction?.syncID == s.fillerTx[7])
        let left = try danglers(context)
        #expect(left.count == 1)
        #expect(left.first?.rowSyncID == s.orphanTx[2])
        #expect(left.first?.targetUUID == missingCategory)
        #expect(context.hasChanges == false, "el pase guarda lo que resuelve")
    }

    @Test func aTableThatCannotBeRead_keepsItsDanglers_andTheOthersStillResolve() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 2, filler: 5)
        let draft = InboxDraft(note: "d")
        let draftID = UUID()
        draft.syncID = draftID
        context.insert(draft)
        context.insert(dangler(txTable, row: s.orphanTx[0], column: "category_ref", target: s.categoryID))
        context.insert(dangler(draftTable, row: draftID, column: "account_ref", target: s.account.shortcutID))
        try context.save()

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        CloudSyncEngine().reresolveDanglingRefs(context: context)

        // La lectura por lote que falla deja la tabla sin cubrir y la búsqueda suelta lanza como antes: `.unreadable`,
        // el dangler se conserva. «No pude leer» nunca es «la fila ya no existe».
        let left = try danglers(context)
        #expect(left.count == 1)
        #expect(left.first?.rowSyncID == s.orphanTx[0])
        #expect(draft.account?.shortcutID == s.account.shortcutID)

        // Control positivo: con la lectura de vuelta, el mismo pase lo resuelve.
        EntityApplyMap._testThrowOnFetchOf = []
        CloudSyncEngine().reresolveDanglingRefs(context: context)
        #expect(try danglers(context).isEmpty)
        #expect(try tx(s.orphanTx[0], context)?.category?.syncID == s.categoryID)
    }

    /// Las refs de movimientos se asignan en bloque desde la lista de la categoría, la subcategoría y la cuenta: el otro
    /// lado queda igual que con la asignación suelta, sin duplicados aunque el movimiento ya apuntara al destino.
    @Test func bulkAssignment_leavesBothSidesOfTheRelationshipRight() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 3, filler: 10)
        let category = try #require(try context.fetch(FetchDescriptor<Yala.Category>()).first { $0.syncID == s.categoryID })
        let sub = Subcategory(name: "S", iconName: "x", category: category)
        let subID = sub.shortcutID
        context.insert(sub)
        // Un movimiento que YA apunta a la categoría: su dangler está viejo y no tiene que duplicarlo en la lista.
        let already = try #require(try tx(s.orphanTx[2], context))
        already.category = category
        context.insert(dangler(txTable, row: s.orphanTx[0], column: "category_ref", target: s.categoryID))
        context.insert(dangler(txTable, row: s.orphanTx[0], column: "subcategory_ref", target: subID))
        context.insert(dangler(txTable, row: s.orphanTx[1], column: "account_ref", target: s.account.shortcutID))
        context.insert(dangler(txTable, row: s.orphanTx[2], column: "category_ref", target: s.categoryID))
        try context.save()
        let before = category.transactions?.count ?? 0

        CloudSyncEngine().reresolveDanglingRefs(context: context)

        let row0 = try #require(try tx(s.orphanTx[0], context))
        #expect(row0.category === category)
        #expect(row0.subcategory?.shortcutID == subID)
        #expect(try tx(s.orphanTx[1], context)?.account === s.account)
        #expect(category.transactions?.count == before + 1, "solo entra el que no estaba")
        #expect(category.transactions?.filter { $0.syncID == s.orphanTx[2] }.count == 1)
        #expect(sub.transactions?.map { $0.syncID } == [s.orphanTx[0]])
        #expect(s.account.transactions?.contains { $0.syncID == s.orphanTx[1] } == true)
        #expect(try danglers(context).isEmpty)

        // Lo mismo leído del disco, en un contexto nuevo.
        let fresh = ModelContext(context.container)
        let sid0 = s.orphanTx[0]
        let stored = try fresh.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.syncID == sid0 })).first
        #expect(stored?.category?.syncID == s.categoryID)
        #expect(stored?.subcategory?.shortcutID == subID)
    }

    /// Las tablas pequeñas se leen enteras solo si algún dangler las consulta: un borrador cuyo movimiento aprobado no
    /// llega nunca no hace leer cuentas, categorías y subcategorías en cada ciclo (hallazgo del revisor, 2026-11-20).
    @Test func wholeTables_areReadOnlyWhenADanglerNeedsThem() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 1, filler: 1)
        let draft = InboxDraft(note: "d")
        let draftID = UUID()
        draft.syncID = draftID
        context.insert(draft)
        let onlyTx = dangler(draftTable, row: draftID, column: "approved_transaction_ref", target: UUID())
        let toCategory = dangler(txTable, row: s.orphanTx[0], column: "category_ref", target: s.categoryID)
        context.insert(onlyTx)
        context.insert(toCategory)
        try context.save()

        let narrow = EntityApplyMap.prepareDanglerLookups(for: [onlyTx], context: context)
        #expect(narrow.wholeTable(Account.self) == nil)
        #expect(narrow.wholeTable(Yala.Category.self) == nil)
        #expect(narrow.wholeTable(Subcategory.self) == nil)
        #expect(narrow.lookup(InboxDraft.self, draftID) != nil, "la fila origen sí va por IN")

        let wide = EntityApplyMap.prepareDanglerLookups(for: [onlyTx, toCategory], context: context)
        #expect(wide.wholeTable(Yala.Category.self) != nil)
        #expect(wide.wholeTable(Account.self) == nil)
    }

    // MARK: - 3. La caché no sobrevive al pase

    @Test func theLookups_areGoneAfterThePass() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 1, filler: 1)
        context.insert(dangler(txTable, row: s.orphanTx[0], column: "category_ref", target: UUID()))
        try context.save()

        CloudSyncEngine().reresolveDanglingRefs(context: context)
        #expect(EntityApplyMap.pageLookups == nil)

        // Una categoría que llega DESPUÉS del pase se ve en el siguiente: nada quedó cacheado como «no está».
        let late = Category(name: "Tarde", colorHex: "#000000", isIncome: false)
        let lateID = UUID()
        late.syncID = lateID
        context.insert(late)
        for d in try danglers(context) { d.targetUUID = lateID }
        try context.save()
        CloudSyncEngine().reresolveDanglingRefs(context: context)
        #expect(try danglers(context).isEmpty)
        #expect(try tx(s.orphanTx[0], context)?.category?.syncID == lateID)
    }

    // MARK: - 4. Medición (evidencia del encargo; el umbral es holgado a propósito)

    /// 4.000 movimientos y 800 danglers, la forma de una primera bajada de la nube cortada a mitad. Imprime el tiempo del
    /// pase en el hilo principal para el informe; el umbral solo caza la vuelta al fila a fila.
    @Test func measure_thePassOverAFirstDownload() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let s = try seed(context, orphans: 800, filler: 3200)
        for (i, sid) in s.orphanTx.enumerated() {
            let even = i.isMultiple(of: 2)
            let target = i < 400 ? (even ? s.categoryID : s.account.shortcutID) : UUID()
            context.insert(dangler(txTable, row: sid, column: even ? "category_ref" : "account_ref", target: target))
        }
        try context.save()

        let clock = ContinuousClock()
        let elapsed = clock.measure { CloudSyncEngine().reresolveDanglingRefs(context: context) }
        print("MEDICION_DANGLERS 4000tx 800danglers: \(elapsed)")
        #expect(try danglers(context).count == 400)
        #expect(elapsed < .seconds(3), "el pase tardó \(elapsed)")
    }
}
