//
//  HeroBarridoBuild8Tests.swift
//  YalaTests / BugsBarridoBuild8
//
//  Tres hallazgos del barrido de la build 8 (24-nov-2026) sobre los heros:
//  - «Ver detalle ›» del Panel ocultaba los montos: el toque caía en el ojo. Ahora es un botón que abre Estadísticas.
//  - Con texto de accesibilidad, la cifra grande de Estadísticas, Registros y «Te falta pagar» salía más pequeña que sus
//    líneas de debajo. Ahora crece como la del Panel y lo de alrededor se topa en AX2.
//  - Al cambiar de período en Estadísticas con datos pesados, el hero dejaba unos segundos las cifras del período
//    anterior. Ahora sale en esqueleto hasta que termina la pasada del período elegido.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

@Suite("Barrido build 8 · cifras de otro período en el hero de Estadísticas")
struct StatsHeroPendingTests {

    private let thisMonth = StatsHeroPeriodKey(period: .thisMonth, customRange: nil)
    private let lastMonth = StatsHeroPeriodKey(period: .lastMonth, customRange: nil)

    @Test func afterChangingThePeriod_untilItsPassEnds_theFiguresArePending() {
        #expect(StatsHeroPendingLogic.isPending(hasCalculatedOnce: true, calculated: thisMonth, current: lastMonth))
        #expect(!StatsHeroPendingLogic.isPending(hasCalculatedOnce: true, calculated: lastMonth, current: lastMonth))
    }

    /// Antes de la primera pasada tapa la página `StatisticsLoadingSkeleton`: el hero no se marca aparte.
    @Test func beforeTheFirstPass_theHeroIsNotMarked() {
        #expect(!StatsHeroPendingLogic.isPending(hasCalculatedOnce: false, calculated: nil, current: thisMonth))
    }

    /// Con «Personalizado», otro rango es otro período; en los demás, un rango guardado de antes no cuenta.
    @Test func theCustomRange_countsOnlyForCustom() {
        let a = DateInterval(start: Date(timeIntervalSince1970: 1_700_000_000), duration: 86_400 * 10)
        let b = DateInterval(start: Date(timeIntervalSince1970: 1_700_000_000), duration: 86_400 * 20)
        #expect(StatsHeroPeriodKey(period: .custom, customRange: a) != StatsHeroPeriodKey(period: .custom, customRange: b))
        #expect(StatsHeroPeriodKey(period: .thisMonth, customRange: a) == StatsHeroPeriodKey(period: .thisMonth, customRange: b))
    }
}

@Suite("Barrido build 8 · cableado de los heros (source-scan)")
struct HeroBarridoBuild8WiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Solo código: un comentario que nombre la pieza no cuenta como usarla.
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    // MARK: «Ver detalle ›»

    /// «Ver detalle» es un botón con su acción, y el Panel le pasa la que abre Estadísticas.
    @Test func seeDetail_isAButton_thatOpensStatistics() throws {
        let hero = try Self.source("Yala/App/Views/Panel/HeroMonthView.swift")
        #expect(hero.contains("var onSeeDetail: (() -> Void)?"))
        let body = try #require(hero.range(of: "private func detailHint(showsText: Bool)"))
        let detailHint = hero[body.lowerBound...].prefix(700)
        #expect(detailHint.contains("Button {"))
        #expect(detailHint.contains("onSeeDetail()"))
        let section = try Self.source("Yala/App/Views/Panel/Sections/PanelHeroSection.swift")
        #expect(section.contains("onSeeDetail: { navigation.navigateToDetail(.insights) }"))
    }

    // MARK: Texto de accesibilidad

    static let heroesWithScaledFigure = [
        "Yala/App/Views/Statistics/StatsHeroView.swift",
        "Yala/App/Views/Planning/ScheduledPaymentsListView.swift",
    ]

    /// La cifra va con `HeroFigureFonts` (crece con techo), nunca con el token fijo, y lo de alrededor se topa en AX2.
    @Test(arguments: heroesWithScaledFigure)
    func theFigure_growsWithAccessibilityText(_ path: String) throws {
        let code = try Self.source(path)
        #expect(!code.contains("font: DS.Typography.panelHeroAmount,"), "\(path) pinta la cifra con el token fijo")
        #expect(code.contains("HeroFigureFonts()"))
        #expect(code.contains(".dynamicTypeSize(...HeroFigureFonts.sidesMaxTypeSize)"))
    }

    /// Las piezas del techo son las del Panel: si una cambia, la otra también.
    @Test func theCeiling_isThePanels() throws {
        let panel = try Self.source("Yala/App/Views/Panel/HeroMonthView.swift")
        #expect(panel.contains("private static let figureMaxSize: CGFloat = 60"))
        #expect(HeroFigureFonts.maxSize == 60)
        #expect(panel.contains("private static let sidesMaxTypeSize = DynamicTypeSize.accessibility2"))
        #expect(HeroFigureFonts.sidesMaxTypeSize == .accessibility2)
    }

    // MARK: Período viejo

    /// El contenedor dice al hero si sus cifras son de otro período, y el hero las tapa con el esqueleto.
    @Test func statistics_marksTheHeroWhileThePeriodIsCalculating() throws {
        let container = try Self.source("Yala/App/Views/Statistics/DetailContainerView.swift")
        #expect(container.contains(".environment(\\.statsHeroFiguresPending, StatsHeroPendingLogic.isPending("))
        // El período de las cifras se apunta al TERMINAR la pasada, con lo que ella leyó.
        #expect(container.contains("let period = StatsHeroPeriodKey(period: inputs.period, customRange: inputs.customRange)"))
        let hero = try Self.source("Yala/App/Views/Statistics/StatsHeroView.swift")
        #expect(hero.components(separatedBy: ".yalaSkeleton(figuresPending)").count - 1 == 3)
    }
}
