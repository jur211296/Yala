//
//  StatisticsEntryFreshnessTests.swift
//  YalaTests
//
//  G1 de la decisión 28 (revisión 2.3, Estadísticas con diez años). Medido en el iPhone 14: cada entrada a Estadísticas
//  hacía dos pasadas completas (la del `onAppear` y la del cambio de pestaña, 150 ms después) y cambiar a Resumen o a
//  Distribución otra más, sobre los mismos datos. Ahora entrar calcula solo si algo cambió desde la última pasada
//  completa, o si una quedó a medias.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Estadísticas · calcular al entrar solo si hace falta (G1)", .serialized)
struct StatisticsEntryFreshnessTests {

    private func stamp(
        dataVersion: Int = 7,
        storeSaves: Int = 3,
        day: Date = Date(timeIntervalSince1970: 1_793_000_000),
        session: SessionState,
        comparisonMode: ComparisonMode = .month,
        currency: String = "PEN",
        stats: Bool = true,
        feed: Bool = true,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced,
        firstWeekday: Int = 2
    ) -> StatisticsCalculationStamp {
        StatisticsCalculationStamp(
            dataVersion: dataVersion,
            storeSaves: storeSaves,
            day: day,
            sessionFilters: PanelSessionFilterKey(session),
            comparisonMode: comparisonMode,
            currencyCode: currency,
            includeGroupTransactionsInStats: stats,
            includeGroupTransactionsInFeed: feed,
            insightsTone: tone,
            insightsFocus: focus,
            firstWeekday: firstWeekday
        )
    }

    @Test("La primera entrada calcula")
    func firstEntry_calculates() {
        #expect(StatisticsEntryFreshness.needsCalculation(last: nil, now: stamp(session: SessionState()), hasInterruptedWork: false))
    }

    @Test("Volver sin que nada cambie no calcula")
    func reentryWithoutChanges_skips() {
        let session = SessionState()
        let last = stamp(session: session)
        #expect(!StatisticsEntryFreshness.needsCalculation(last: last, now: stamp(session: session), hasInterruptedWork: false))
    }

    @Test("Un cálculo a medias obliga aunque la firma no cambie")
    func interruptedWork_forcesCalculation() {
        let session = SessionState()
        let last = stamp(session: session)
        #expect(StatisticsEntryFreshness.needsCalculation(last: last, now: stamp(session: session), hasInterruptedWork: true))
    }

    @Test("Cada cosa que lee la pasada y puede cambiar sin observador obliga a calcular")
    func eachInputChange_forcesCalculation() {
        let session = SessionState()
        let last = stamp(session: session)
        let changed: [(String, StatisticsCalculationStamp)] = [
            ("dataVersion", stamp(dataVersion: 8, session: session)),
            ("guardado sin aviso", stamp(storeSaves: 4, session: session)),
            ("otro día", stamp(day: Date(timeIntervalSince1970: 1_793_086_400), session: session)),
            ("comparación", stamp(session: session, comparisonMode: .year)),
            ("divisa", stamp(session: session, currency: "USD")),
            ("grupos en estadísticas", stamp(session: session, stats: false)),
            ("grupos en registros", stamp(session: session, feed: false)),
            ("tono", stamp(session: session, tone: .sarcastic)),
            ("enfoque", stamp(session: session, focus: .saver)),
            ("primer día de la semana", stamp(session: session, firstWeekday: 1)),
        ]
        for (name, now) in changed {
            #expect(
                StatisticsEntryFreshness.needsCalculation(last: last, now: now, hasInterruptedWork: false),
                "Con «\(name)» cambiado tenía que calcular"
            )
        }
    }

    @Test("Un guardado o un cambio de datos pide recargar los movimientos, no solo recalcular")
    func dataChange_asksForAReload() {
        let session = SessionState()
        let last = stamp(session: session)
        #expect(StatisticsEntryFreshness.needsReload(last: last, now: stamp(storeSaves: 4, session: session)))
        #expect(StatisticsEntryFreshness.needsReload(last: last, now: stamp(dataVersion: 8, session: session)))
        // Un filtro o el día no cambian los movimientos guardados: recalcular basta.
        #expect(!StatisticsEntryFreshness.needsReload(last: last, now: stamp(session: session, tone: .sarcastic)))
        #expect(!StatisticsEntryFreshness.needsReload(last: nil, now: stamp(session: session)))
    }

    @Test("Otro período o un filtro de sesión obliga a calcular")
    func sessionFilterChange_forcesCalculation() {
        let session = SessionState()
        let last = stamp(session: session)
        session.searchText = "café"
        #expect(StatisticsEntryFreshness.needsCalculation(last: last, now: stamp(session: session), hasInterruptedWork: false))
    }
}
