//
//  EstadisticasMemoriaTests.swift
//  YalaTests
//
//  Encargo de fluidez de Estadísticas (24-nov-2026): cambiar de chip sin cambiar datos, período ni filtros no vuelve a
//  calcular lo que la página ya calculó; cambiar cualquiera de ellos sí. Fija `StatisticsPageMemory` (la memoria de
//  Tendencias, Distribución y el Sankey) y `StatsMoneyTodayMemory` («Tu dinero hoy» de los heros).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct EstadisticasMemoriaTests {

    // MARK: - StatisticsPageMemory

    @Test func sinNadaGuardado_tocaCalcular() {
        let memory = StatisticsPageMemory<Int, String>()
        #expect(memory.recall(1) == nil)
    }

    @Test func mismaFirma_devuelveLoGuardado() {
        var memory = StatisticsPageMemory<Int, String>()
        memory.remember("tarjetas", for: 7)
        #expect(memory.recall(7) == "tarjetas")
        // Volver otra vez con lo mismo sigue sin calcular.
        #expect(memory.recall(7) == "tarjetas")
    }

    @Test func otraFirma_tocaCalcular_yLoNuevoSustituyeALoViejo() {
        var memory = StatisticsPageMemory<Int, String>()
        memory.remember("de ayer", for: 1)
        #expect(memory.recall(2) == nil)
        memory.remember("de hoy", for: 2)
        #expect(memory.recall(2) == "de hoy")
        #expect(memory.recall(1) == nil, "Solo se recuerda el último cálculo: volver a la firma vieja recalcula.")
    }

    // MARK: - Firmas reales: cambiar de chip no cambia la firma; cambiar un filtro, sí

    private static let dia = Date(timeIntervalSince1970: 1_790_000_000)

    private func trendsKey(
        generation: Int = 3,
        period: DetailPeriod = .thisMonth,
        metric: TrendMetric = .balance,
        natures: Set<TransactionNature> = [],
        grouping: AccountCardGrouping = .byCard,
        search: String = ""
    ) -> TrendsCardsKey {
        TrendsCardsKey(
            dataGeneration: generation,
            detailPeriod: period,
            interval: DateInterval(start: Self.dia, duration: 86_400 * 30),
            customDateRange: nil,
            selectedAccounts: [],
            selectedCategories: [],
            selectedSubcategories: [],
            selectedTags: [],
            selectedNeeds: [],
            selectedCurrencies: [],
            amountCondition: .any,
            searchText: search,
            excludedFilterSets: .none,
            selectedMetric: metric,
            comparisonMode: .month,
            selectedTransactionNatures: natures,
            currencyCode: "PEN",
            includeGroupTransactionsInStats: true,
            firstWeekday: 2,
            cashFlowAccountGrouping: grouping
        )
    }

    @Test func tendencias_volverConLoMismo_noRecalcula() {
        var memory = StatisticsPageMemory<TrendsCardsKey, String>()
        memory.remember("tarjetas", for: trendsKey())
        // Resumen → Tendencias → Distribución → Tendencias: la firma se arma de nuevo cada vez y sale igual.
        #expect(memory.recall(trendsKey()) == "tarjetas")
    }

    @Test(arguments: [
        "datos", "período", "métrica", "naturaleza", "agrupación", "búsqueda",
    ])
    func tendencias_cambiarUnaEntrada_recalcula(_ cambio: String) {
        var memory = StatisticsPageMemory<TrendsCardsKey, String>()
        memory.remember("tarjetas", for: trendsKey())
        let otra: TrendsCardsKey
        switch cambio {
        case "datos": otra = trendsKey(generation: 4)
        case "período": otra = trendsKey(period: .lastMonth)
        case "métrica": otra = trendsKey(metric: .expense)
        case "naturaleza": otra = trendsKey(natures: [.income])
        case "agrupación": otra = trendsKey(grouping: .byLine)
        default: otra = trendsKey(search: "taxi")
        }
        #expect(memory.recall(otra) == nil, "Cambiar \(cambio) tiene que recalcular las tarjetas.")
    }

    // MARK: - «Tu dinero hoy»

    private func moneyInputs(
        generation: Int = 5,
        selected: Set<PersistentIdentifier> = [],
        currency: String = "PEN",
        closedAt: Date? = nil
    ) -> StatsHeroMoneyInputs {
        StatsHeroMoneyInputs(
            needed: true,
            generation: generation,
            transactionCount: 120,
            accountScopes: ["a|bank||true"],
            currencyCode: currency,
            includeGroups: true,
            overrides: "",
            selectedAccountIDs: selected,
            excludedAccountIDs: [],
            closedAt: closedAt
        )
    }

    @Test func dineroHoy_lasCuatroPaginasConLoMismo_calculanUnaVez() {
        let memory = StatsMoneyTodayMemory()
        let cifra = StatsMoneyTodayLogic.Figure(value: 1_234, isApproximate: false)
        // Resumen, Tendencias, Distribución y Registros montan su hero con las mismas entradas, y se vuelve a Resumen.
        for _ in 0..<5 {
            let figura = memory.figure(for: moneyInputs(), day: Self.dia) { cifra }
            #expect(figura == cifra)
        }
        #expect(memory.computations == 1)
    }

    @Test func dineroHoy_otrosDatosOtraDivisaOtroDia_recalcula() {
        let memory = StatsMoneyTodayMemory()
        let cifra = StatsMoneyTodayLogic.Figure(value: 1, isApproximate: false)
        _ = memory.figure(for: moneyInputs(), day: Self.dia) { cifra }
        _ = memory.figure(for: moneyInputs(generation: 6), day: Self.dia) { cifra }
        _ = memory.figure(for: moneyInputs(generation: 6, currency: "USD"), day: Self.dia) { cifra }
        _ = memory.figure(for: moneyInputs(generation: 6, currency: "USD"), day: Self.dia.addingTimeInterval(86_400)) {
            cifra
        }
        _ = memory.figure(
            for: moneyInputs(generation: 6, currency: "USD", closedAt: Self.dia),
            day: Self.dia.addingTimeInterval(86_400)
        ) { cifra }
        #expect(memory.computations == 5)
    }

    @Test func dineroHoy_devuelveLoQueCalculoParaEsasEntradas() {
        let memory = StatsMoneyTodayMemory()
        let a = memory.figure(for: moneyInputs(), day: Self.dia) {
            StatsMoneyTodayLogic.Figure(value: 100, isApproximate: false)
        }
        let b = memory.figure(for: moneyInputs(generation: 9), day: Self.dia) {
            StatsMoneyTodayLogic.Figure(value: 250, isApproximate: true)
        }
        #expect(a.value == 100)
        #expect(b.value == 250 && b.isApproximate)
    }
}
