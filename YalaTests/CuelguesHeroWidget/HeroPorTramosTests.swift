//
//  HeroPorTramosTests.swift
//  YalaTests / CuelguesHeroWidget
//
//  Sentry YALA-IOS-N (2026-11-18): el hero del Panel recorría el historial entero en el hilo principal
//  (`calculateHeroWidget` → `HeroBucketsCalculator.calculate`) y con un historial grande la app dejaba de responder unos
//  segundos. Ahora, pasado un tramo, el Panel lo recorre por tramos y cede el hilo entre uno y otro.
//
//  Se fija: (1) sumar por tramos da las mismas cifras que de una vez, con las filas que separan las reglas de ingreso y
//  gasto; (2) el Panel por tramos pinta el mismo hero que el Panel de una vez sobre el mismo almacén; (3) mientras el
//  hero se calcula, el hilo principal atiende otras tareas —sin tramos, ninguna—; y (4) salir del Panel corta el hero a
//  medias y deja apuntado que hay que volver a calcular.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-N · el hero del Panel se calcula por tramos", .serialized)
@MainActor
struct HeroPorTramosTests {

    /// El Panel la guarda `weak`: sin alguien que la retenga, no calcula nada.
    private let session = SessionState()

    private func panel(_ container: ModelContainer, slice: Int) -> PanelViewModel {
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.heroSliceSize = slice
        viewModel.setContext(ModelContext(container), defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    /// Espera a que la recarga haya traído `count` movimientos y el hero haya terminado.
    private func waitUntilSettled(_ viewModel: PanelViewModel, count: Int) async throws {
        for _ in 0..<1_500 {
            if viewModel.transactions.count == count, viewModel.lastHeroSlices > 0, !viewModel.isHeroCalculating {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("el Panel no terminó: \(viewModel.transactions.count) de \(count)")
    }

    // MARK: - 1. Por tramos, las mismas cifras

    @Test(arguments: [1, 7, 333, 5_000])
    func porTramos_daLasMismasCifrasQueDeUnaVez(slice: Int) throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let now = Date.now
        try CuelguesFixture.seed(container, count: 1_500, now: now)
        let context = ModelContext(container)
        let all = try CuelguesFixture.allTransactions(context)
        let ids = Set(try context.fetch(FetchDescriptor<Account>()).map(\.persistentModelID))
        let calendar = Calendar.current
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        let monthInterval = DateInterval(start: month.start, end: month.end.addingTimeInterval(-1))
        let prevStart = try #require(calendar.date(byAdding: .month, value: -1, to: month.start))
        let prevInterval = DateInterval(start: prevStart, end: month.start.addingTimeInterval(-1))
        let period = DateInterval(start: now.addingTimeInterval(-40 * 86_400), end: now)
        let periodPrev = DateInterval(start: now.addingTimeInterval(-80 * 86_400), end: now.addingTimeInterval(-40 * 86_400 - 1))

        let whole = HeroBucketsCalculator.calculate(
            transactions: all, monthInterval: monthInterval, prevInterval: prevInterval, periodInterval: period,
            periodPrevInterval: periodPrev, eligibleAccountIDs: ids, currencyCode: "PEN"
        )
        var accumulator = HeroBucketsCalculator.Accumulator(
            monthInterval: monthInterval, prevInterval: prevInterval, periodInterval: period,
            periodPrevInterval: periodPrev, eligibleAccountIDs: ids, currencyCode: "PEN"
        )
        var start = all.startIndex
        while start < all.endIndex {
            let end = min(start + slice, all.endIndex)
            accumulator.add(all[start..<end])
            start = end
        }
        #expect(accumulator.buckets == whole)
        // El fixture discrimina: hay ingresos y gastos en el mes, en el período y en el anterior.
        #expect(whole.monthIncome != 0 && whole.monthExpense != 0)
        #expect(whole.periodIncome != 0 && whole.periodExpense != 0 && whole.periodPrevExpense != 0)
        #expect(whole.prevHasAnyTx)
    }

    // MARK: - 2. El Panel por tramos pinta el mismo hero

    @Test func elPanelPorTramos_pintaElMismoHeroQueDeUnaVez() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let count = 3_000
        try CuelguesFixture.seed(container, count: count, now: .now, spacing: 1_800)

        let sliced = panel(container, slice: 250)
        let whole = panel(container, slice: 100_000)
        sliced.reloadAndRecalculate()
        whole.reloadAndRecalculate()
        try await waitUntilSettled(sliced, count: count)
        try await waitUntilSettled(whole, count: count)

        #expect(sliced.lastHeroSlices >= count / 250)
        #expect(whole.lastHeroSlices == 1)
        #expect(sliced.heroWidget == whole.heroWidget)
        #expect(sliced.heroPeriodWidget == whole.heroPeriodWidget)
        #expect(sliced.heroPeriodWidget.periodHadMovements == true)
    }

    // MARK: - 3. Cede el hilo mientras calcula

    @Test func mientrasCalculaElHero_elHiloPrincipalAtiendeOtrasTareas() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let count = 4_000
        try CuelguesFixture.seed(container, count: count, now: .now, spacing: 1_800)
        let viewModel = panel(container, slice: 200)
        viewModel.reloadAndRecalculate()
        try await waitUntilSettled(viewModel, count: count)

        // Un recálculo sin recarga (cambiar el período, un filtro): solo el cálculo.
        viewModel.recalculateData()
        for _ in 0..<200 where !viewModel.isHeroCalculating {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(viewModel.isHeroCalculating, "el hero no se calculó por tramos")
        let measured = try await CuelguesFixture.measureMainThread(while: { viewModel.isHeroCalculating })
        // Sin ceder, el hero acaba en un solo bloque y aquí no se atiende nada.
        #expect(measured.turns >= 5, "el hilo principal solo atendió \(measured.turns) tareas mientras calculaba")
        #expect(viewModel.lastHeroSlices >= count / 200)
    }

    // MARK: - 4. Salir del Panel corta el hero a medias

    @Test func salirDelPanel_cortaElHeroAMedias() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let count = 3_000
        try CuelguesFixture.seed(container, count: count, now: .now, spacing: 1_800)
        let viewModel = panel(container, slice: 100)
        viewModel.reloadAndRecalculate()
        try await waitUntilSettled(viewModel, count: count)

        viewModel.recalculateData()
        for _ in 0..<200 where !viewModel.isHeroCalculating {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(viewModel.isHeroCalculating)
        viewModel.cancelRecalculation()
        #expect(!viewModel.isHeroCalculating)
        #expect(viewModel.hasInterruptedWork, "volver al Panel tiene que recalcular lo que se cortó")
    }

    // MARK: - 5. El espejo de iCloud funde cambios a mitad

    /// Lo que funde el espejo no pasa por `ModelContext.didSave`: el hero lo ve por el aviso de cambio remoto, deja lo que
    /// tenía a medias (pudo borrarse) y lo vuelve a calcular tras recargar.
    @Test func unCambioDelEspejoAMitad_cortaYRecalculaTrasRecargar() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        let count = 3_000
        try CuelguesFixture.seed(container, count: count, now: .now, spacing: 1_800)
        let viewModel = panel(container, slice: 10)   // 300 tramos: el aviso llega con el hero a medias
        viewModel.reloadAndRecalculate()
        try await waitUntilSettled(viewModel, count: count)
        let expected = viewModel.heroPeriodWidget

        viewModel.recalculateData()
        for _ in 0..<200 where !viewModel.isHeroCalculating {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(viewModel.isHeroCalculating)
        let cuts = viewModel.debugHeroCutsByRemoteChange
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        for _ in 0..<200 where viewModel.debugHeroCutsByRemoteChange == cuts {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(viewModel.debugHeroCutsByRemoteChange == cuts + 1, "el hero siguió con lo que tenía en la mano")
        // La recarga pedida vuelve a calcular el hero entero, con las mismas cifras.
        try await Task.sleep(for: .milliseconds(200))
        try await waitUntilSettled(viewModel, count: count)
        #expect(viewModel.heroPeriodWidget == expected)
    }
}
