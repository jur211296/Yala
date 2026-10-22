//
//  ApproximateMarkPanelCoherenceTests.swift
//  YalaTests
//
//  El «≈» significa UNA sola cosa en el Panel: «la parte con tasa dudosa pesa en este número».
//  Decisión B de Jürgen del 2026-10-12 (`dos-criterios-de-aproximado-en-la-misma-pantalla`):
//  el panorama («Tienes X en N cuentas») y el P&L cambiario dejan el OR y pasan al mismo
//  `ApproximateMarkThreshold` que el «Disponible» del período.
//
//  El criterio de aceptación del ticket: con una sola divisa extranjera con tasa caducada, el
//  panorama y el hero coinciden. Los casos de abajo DISCRIMINAN: con el OR del panorama, el caso
//  pequeño sale «≈» arriba y limpio abajo, que es la pantalla que se contradecía.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El «≈» del panorama y del hero del Panel coinciden")
struct ApproximateMarkPanelCoherenceTests {

    private let calendar = Calendar.current
    private let staleRate = MockCurrencyConverter(
        fixedRate: 3.75, quality: .carriedForward(fromDateKey: "2026-04-09")
    )

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: d)) ?? Date()
    }

    private var april: DateInterval {
        let start = day(1)
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private var march: DateInterval {
        let start = calendar.date(byAdding: .month, value: -1, to: day(1)) ?? day(1)
        let end = calendar.date(byAdding: .second, value: -1, to: day(1)) ?? day(1)
        return DateInterval(start: start, end: end)
    }

    /// Un mes con 10.000 PEN de ingreso exacto y un gasto en dólares cuya tasa no era la del día.
    /// El gasto se guarda ya convertido con la misma tasa que el converter usa hoy, así que el
    /// «Disponible» del mes y el saldo vivo son el MISMO número: lo único que cambia entre las dos
    /// marcas es el criterio, que es lo que se prueba.
    private func scenario(usdSpent: Double) -> (Account, [TransactionItem]) {
        let account = Account(
            name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank"
        )
        let salary = YalaCategory(name: "Salary", colorHex: "#00FF00", isIncome: true)
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)

        let income = TransactionItem(
            date: day(2), amount: 10_000, currencyCode: "PEN", note: "", category: salary,
            account: account, tags: [], amountInPreferredCurrency: 10_000
        )
        income.preferredCurrencyCode = "PEN"

        let spent = TransactionItem(
            date: day(3), amount: -usdSpent, currencyCode: "USD", note: "", category: food,
            account: account, tags: [], amountInPreferredCurrency: -usdSpent * 3.75
        )
        spent.preferredCurrencyCode = "PEN"
        spent.isExchangeRateProvisional = true

        return (account, [income, spent])
    }

    private func marks(usdSpent: Double) -> (panorama: Bool, hero: Bool) {
        let (account, txs) = scenario(usdSpent: usdSpent)
        let panorama = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account], transactions: txs, preferredCurrencyCode: "PEN", converter: staleRate
        )
        let hero = HeroBucketsCalculator.calculate(
            transactions: txs, monthInterval: april, prevInterval: march, periodInterval: april,
            eligibleAccountIDs: [account.persistentModelID], currencyCode: "PEN", converter: staleRate
        )
        return (panorama.amountsAreApproximate, hero.periodNetApproximate)
    }

    @Test("Una divisa con tasa caducada que no pesa: ni el panorama ni el hero llevan «≈»")
    func smallStaleCurrency_neitherMarks() {
        // 100 USD → 375 PEN sobre un saldo de 9.625: 3,9 % ⇒ bajo el 5 %.
        let result = marks(usdSpent: 100)
        #expect(!result.hero, "premisa: el «Disponible» ya usaba el umbral")
        #expect(!result.panorama, """
            Con el OR por divisa el panorama salía «≈» y el «Disponible» de la misma pantalla no:
            el glifo significaba dos cosas. Desde la decisión B del 2026-10-12, una.
            """)
    }

    @Test("Una divisa con tasa caducada que sí pesa: los dos llevan «≈»")
    func largeStaleCurrency_bothMark() {
        // 2.000 USD → 7.500 PEN sobre un saldo de 2.500: 300 % ⇒ marca.
        let result = marks(usdSpent: 2_000)
        #expect(result.hero)
        #expect(result.panorama)
    }

    /// El saldo vivo es una RESTA (el gasto en dólares resta): el denominador es lo que se muestra,
    /// no la suma de magnitudes. 130 USD → 487,5 PEN: sobre el saldo mostrado (9.512,5) es un
    /// 5,12 % y marca; sobre `Σ|saldo|` (10.487,5) sería un 4,65 % y no marcaría.
    @Test("El denominador del panorama es el saldo que se muestra, no la suma de magnitudes")
    func panorama_denominatorIsTheShownBalance() {
        let result = marks(usdSpent: 130)
        #expect(result.panorama)
        #expect(result.hero)
    }

    @Test("Con todas las tasas del día, el panorama no lleva «≈»")
    func exactRates_noMark() {
        let (account, txs) = scenario(usdSpent: 2_000)
        let exact = MockCurrencyConverter(fixedRate: 3.75, quality: .exact)
        let panorama = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account], transactions: txs, preferredCurrencyCode: "PEN", converter: exact
        )
        #expect(!panorama.amountsAreApproximate)
    }
}

/// «Ver por moneda»: el «≈» de una fila significa solo «tasa de otro día», así que el formato del
/// copy no puede traer el suyo (decisión A de Jürgen del 2026-10-12,
/// `live-anchor-breakdown-doubles-the-approximate-glyph`). Con el glifo en el copy, la divisa con la
/// tasa dudosa salía «≈ ≈» y la buena «≈», y nadie distingue una de otra por cuántas veces sale.
@Suite("El desglose por moneda no trae «≈» en el copy")
struct LiveAnchorBreakdownGlyphTests {

    private static let key = "panel.liveAnchorEducation.breakdownRowConvertedFormat"

    @Test("En las 16 locales, el formato de la fila lleva el importe y ninguna marca de aproximado")
    func breakdownRowFormat_hasNoApproximateGlyph_inAnyLocale() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
            .appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(
            at: resources, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "lproj" }
        #expect(lprojs.count == 16, "el catálogo tiene 16 locales; si cambia, revisa este test")

        for lproj in lprojs {
            let content = try String(
                contentsOf: lproj.appendingPathComponent("Localizable.strings"), encoding: .utf8
            )
            let line = try #require(
                content.split(separator: "\n").first { $0.hasPrefix("\"\(Self.key)\"") },
                "falta la clave en \(lproj.lastPathComponent)"
            )
            #expect(line.contains("%@"), "\(lproj.lastPathComponent): sin importe")
            // «≈» es el glifo que antepone el formateador; «约» es el «aproximadamente» de zh-Hans,
            // que con el glifo daba «今天约 ≈ …», dos marcas distintas en la misma fila.
            #expect(!line.contains("≈"), "\(lproj.lastPathComponent): \(line)")
            #expect(!line.contains("约"), "\(lproj.lastPathComponent): \(line)")
        }
    }
}
