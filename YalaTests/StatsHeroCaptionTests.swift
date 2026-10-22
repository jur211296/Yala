//
//  StatsHeroCaptionTests.swift
//  YalaTests
//
//  Fija QUÉ dice el rótulo del hero en las cuatro pestañas de Estadísticas.
//
//  El ticket pedía un rótulo fijo por pestaña —Distribución "Saldo de cuentas",
//  las otras tres "Neto del período"—. Medido el 2026-09-07, esa premisa es
//  falsa: ninguna de las cuatro cifras es siempre la misma magnitud, así que un
//  rótulo fijo mentiría. Estos tests fijan los estados donde mentía, que son
//  justamente los que un rótulo fijo pasaría en verde.
//
//  Sin ModelContext ni Bundle: la lógica es pura y devuelve casos del enum.
//

import Foundation
import Testing

@testable import Yala

struct StatsHeroCaptionTests {

    // MARK: - Distribución

    @Test("Distribución en modo Balance rotula un saldo de cuentas")
    func distributionBalanceModeIsStock() {
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: true, natures: []) == .accountsBalance)
        // El modo manda sobre los chips: con los DOS marcados sigue siendo saldo.
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: true, natures: [.income, .expense]) == .accountsBalance)
    }

    @Test("Distribución sin chips y fuera de modo Balance rotula GASTOS, no un saldo")
    func distributionEmptyNaturesMeansExpense() {
        // El caso que un rótulo fijo "Saldo de cuentas" rompía: sin chips,
        // `TopSpendingCategoriesCalculator` aplica `?? [.expense]`, así que el pie
        // —y el hero— son de gastos.
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: []) == .expensePeriod)
    }

    @Test("Distribución fuera de modo Balance sigue al chip de naturaleza")
    func distributionFollowsNatureChip() {
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [.expense]) == .expensePeriod)
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [.income]) == .incomePeriod)
    }

    @Test("Distribución con las dos naturalezas y sin modo Balance no es ni neto ni un lado")
    func distributionBothNaturesIsTotal() {
        // El pie suma con `abs`, así que la cifra es magnitudes sumadas. Alcanzable
        // con los dos chips y un filtro dimensional activo.
        #expect(StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [.income, .expense]) == .totalPeriod)
    }

    // MARK: - Tendencias

    @Test("Tendencias rotula según la métrica, no siempre el neto")
    func trendsFollowsMetric() {
        #expect(StatsHeroCaptionLogic.trends(metric: .balance) == .netPeriod)
        #expect(StatsHeroCaptionLogic.trends(metric: .income) == .incomePeriod)
        #expect(StatsHeroCaptionLogic.trends(metric: .expense) == .expensePeriod)
    }

    @Test("Toda métrica de Tendencias tiene rótulo: ningún caso cae en un default")
    func trendsCoversEveryMetric() {
        // Si mañana entra una métrica nueva en `TrendMetric`, este test obliga a
        // decidir su rótulo en vez de heredar uno silenciosamente.
        for metric in TrendMetric.allCases {
            let caption = StatsHeroCaptionLogic.trends(metric: metric)
            #expect(StatsHeroCaption.allCases.contains(caption))
        }
        #expect(TrendMetric.allCases.count == 3)
    }

    // MARK: - Insights

    @Test("Insights siempre rotula el neto del período")
    func insightsIsAlwaysNet() {
        #expect(StatsHeroCaptionLogic.insights == .netPeriod)
    }

    // MARK: - Registros

    @Test("Registros sin filtro de naturaleza rotula el neto")
    func recordsWithoutNatureFilterIsNet() {
        #expect(StatsHeroCaptionLogic.records(natures: []) == .netPeriod)
        // Las dos marcadas no filtran nada (`FilterService` solo aplica con una),
        // así que la cifra sigue siendo un neto de verdad.
        #expect(StatsHeroCaptionLogic.records(natures: [.income, .expense]) == .netPeriod)
    }

    @Test("Registros con un chip activo deja de ser un neto y el rótulo lo dice")
    func recordsWithNatureFilterIsOneSide() {
        // `recordsSummary.balance` = income - expense sobre lo YA filtrado: con un
        // solo lado, el otro es 0 y la cifra es ese lado, no un neto.
        #expect(StatsHeroCaptionLogic.records(natures: [.income]) == .incomePeriod)
        #expect(StatsHeroCaptionLogic.records(natures: [.expense]) == .expensePeriod)
    }

    // MARK: - Contrato del enum

    @Test("Los cinco rótulos resuelven a texto no vacío y distinto entre sí")
    func everyCaptionHasDistinctText() {
        let texts = StatsHeroCaption.allCases.map(\.text)
        for text in texts {
            #expect(!text.isEmpty)
            // Si la key faltara en el bundle, `ls()` devuelve la key cruda.
            #expect(!text.hasPrefix("stats.hero."))
        }
        #expect(Set(texts).count == StatsHeroCaption.allCases.count)
    }
}
