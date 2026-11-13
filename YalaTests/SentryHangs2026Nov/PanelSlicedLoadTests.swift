//
//  PanelSlicedLoadTests.swift
//  YalaTests / SentryHangs2026Nov
//
//  YALA-IOS-K: el Panel leía TODOS los movimientos de una vez en el hilo principal (`loadData` → `performAndWait`), y con
//  un historial grande la app dejaba de responder más de 2 s. Ahora los lee por tramos ordenados y cede el hilo entre uno y
//  otro (`PanelViewModel.fetchTransactionsInSlices`).
//
//  Se fija: (1) entre tramo y tramo corre otro trabajo del hilo principal —sin ceder, ninguno—; (2) el resultado es el
//  mismo que la lectura de una vez: mismas filas, mismo orden, sin saltar ni repetir las que comparten fecha e instante
//  de creación en el borde de un tramo; y (3) la recarga del Panel acaba con todos.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-K · el Panel lee sus movimientos por tramos", .serialized)
@MainActor
struct PanelSlicedLoadTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PanelSliced-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personal = ModelConfiguration("PS-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("PS-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("PS-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema, configurations: personal, groups, meta)
    }

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// `count` movimientos con fechas distintas y, metido en el borde del primer tramo, un bloque de `tied` con la MISMA
    /// fecha y el mismo instante de creación: el caso en que avanzar por clave salta o repite filas.
    private func seed(_ container: ModelContainer, count: Int, tied: Int) throws {
        let context = ModelContext(container)
        let account = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        for i in 0..<count {
            let tx = TransactionItem(date: base.addingTimeInterval(-Double(i) * 3_600), amount: -Double(i + 1),
                                     currencyCode: "PEN", account: account)
            tx.createdAt = tx.date
            context.insert(tx)
        }
        // Cae alrededor de la fila `transactionSliceSize` del orden: el borde del primer tramo.
        let tiedDate = base.addingTimeInterval(-Double(PanelViewModel.transactionSliceSize - 5) * 3_600 - 1_800)
        for i in 0..<tied {
            let tx = TransactionItem(date: tiedDate, amount: -Double(10_000 + i), currencyCode: "PEN", account: account)
            tx.createdAt = tiedDate
            context.insert(tx)
        }
        try context.save()
    }

    private func panel(_ container: ModelContainer) -> PanelViewModel {
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(ModelContext(container), defaultCurrencyCode: "PEN", sessionState: SessionState())
        return viewModel
    }

    private func fullRead(_ container: ModelContainer) throws -> [TransactionItem] {
        try ModelContext(container).fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ]))
    }

    /// La clave de orden de cada fila y su importe (único por fila): compara orden y contenido sin depender del contexto.
    private func signature(_ txs: [TransactionItem]) -> [String] {
        txs.map { "\($0.date.timeIntervalSince1970)|\($0.createdAt.timeIntervalSince1970)|\($0.amount)" }
    }

    // MARK: - 1. Cede el hilo entre tramos

    @Test func aBigHistory_letsOtherMainThreadWorkRunWhileItLoads() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size * 2 + 300, tied: 0)
        let viewModel = panel(container)

        var ticks = 0
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                await Task.yield()
            }
        }
        let loaded = try #require(await viewModel.fetchTransactionsInSlices())
        let ticksWhileLoading = ticks
        ticker.cancel()

        #expect(loaded.count == size * 2 + 300)
        #expect(viewModel.lastLoadSlices >= 3)
        // Leído de una vez, el hilo no se suelta: el ticker no llega a correr hasta que la lectura termina.
        #expect(ticksWhileLoading >= 2, "el hilo principal no atendió nada mientras leía (ticks: \(ticksWhileLoading))")
    }

    // MARK: - 2. Mismo resultado que la lectura de una vez

    @Test func slicedRead_matchesTheSingleRead_evenWithTiesOnTheSliceBorder() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size * 2 + 100, tied: 40)
        let viewModel = panel(container)

        let sliced = try #require(await viewModel.fetchTransactionsInSlices())
        let single = try fullRead(container)

        #expect(sliced.count == single.count)
        #expect(Set(sliced.map(\.persistentModelID)).count == sliced.count)   // ninguna repetida
        // Mismo multiconjunto y mismo orden por clave (dentro de un empate el orden no está definido en ninguna lectura).
        #expect(signature(sliced).sorted() == signature(single).sorted())
        let keys = sliced.map { ($0.date, $0.createdAt) }
        #expect(zip(keys, keys.dropFirst()).allSatisfy { $0.0 > $1.0 || ($0.0 == $1.0 && $0.1 >= $1.1) })
    }

    /// Un tramo ENTERO con la misma clave no deja avanzar por clave: el resto se lee de una vez y no se pierde nada.
    @Test func aWholeSliceWithTheSameKey_stillReadsEverything() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size + 20, tied: size + 10)
        let viewModel = panel(container)

        let sliced = try #require(await viewModel.fetchTransactionsInSlices())
        #expect(sliced.count == size * 2 + 30)
        #expect(Set(sliced.map(\.persistentModelID)).count == sliced.count)
    }

    // MARK: - 3. Lo que cambia mientras se lee

    /// Otra tarea del hilo principal borra un movimiento del primer tramo mientras el Panel lee los siguientes (un borrado
    /// con «Deshacer» que vence, una página de la nube). No puede llegar a la lista: leer un `@Model` borrado aborta en el
    /// iPhone 27.x (card f8rj), y el simulador no lo enseña.
    @Test func aRowDeletedBetweenSlices_isNotInTheResult() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size * 2 + 50, tied: 0)
        let context = ModelContext(container)
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: SessionState())

        // El más reciente: cae en el primer tramo. La tarea corre en la primera cesión de la lectura.
        let newest = try #require(try context.fetch(FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])).first)
        let newestID = newest.persistentModelID
        let deleter = Task { @MainActor in
            context.delete(newest)
            try context.save()
        }
        let loaded = try #require(await viewModel.fetchTransactionsInSlices())
        try await deleter.value

        #expect(viewModel.lastLoadSlices >= 2)
        #expect(!loaded.contains { $0.persistentModelID == newestID })
        #expect(loaded.allSatisfy { !$0.isDeleted })
        #expect(loaded.count == size * 2 + 49)
    }

    /// Con cambios SIN guardar en el contexto (la recarga que pide `hasUnsavedChanges`), un tramo puede traer una fila de
    /// más o de menos. La lectura no puede darse por terminada por eso: sale lo mismo que leyendo de una vez.
    @Test func unsavedChanges_doNotCutTheReadShort() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size * 2 + 50, tied: 0)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: SessionState())

        // Sin guardar: uno nuevo arriba del todo y uno borrado dentro del primer tramo.
        context.insert(TransactionItem(date: base.addingTimeInterval(3_600), amount: -1, currencyCode: "PEN"))
        let inFirstSlice = try #require(try context.fetch(FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])).dropFirst(10).first)
        context.delete(inFirstSlice)

        let sliced = try #require(await viewModel.fetchTransactionsInSlices())
        let single = try context.fetch(FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)
        ])).filter { !$0.isDeleted }
        #expect(sliced.count == single.count)
        #expect(Set(sliced.map(\.persistentModelID)) == Set(single.map(\.persistentModelID)))
        context.rollback()
    }

    // MARK: - 4. La recarga del Panel acaba con todos

    @Test func panelReload_endsWithEveryTransaction() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try makeContainer(dir)
        let size = PanelViewModel.transactionSliceSize
        try seed(container, count: size + 700, tied: 12)
        let viewModel = panel(container)

        viewModel.reloadAndRecalculate()
        for _ in 0..<200 where viewModel.transactions.count < size + 712 {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(viewModel.transactions.count == size + 712)
        #expect(viewModel.isReady)
        #expect(viewModel.lastLoadSlices >= 2)
    }
}
