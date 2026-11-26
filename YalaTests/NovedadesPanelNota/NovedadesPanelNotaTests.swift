//
//  NovedadesPanelNotaTests.swift
//  YalaTests
//
//  Encargo del 22-nov-2026 (decisiones 118, 137 y 30 de Jürgen):
//   • Novedades 2.3: ocho tarjetas, la primera el iPhone Duo, en los 16 idiomas.
//   • Panel progresivo: al entrar, solo los Primeros pasos; el saldo grande llega con la cuenta.
//   • Nota de salud, lote 2: la cuarta parte «Lo que te queda», con su curva amable.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Novedades 2.3

@Suite("Novedades 2.3 · tarjetas y textos")
struct Novedades23Tests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func keys(_ table: String, _ locale: String) throws -> [String: String] {
        let url = repoRoot().appending(path: "Yala/Resources/\(locale).lproj/\(table).strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String], "\(locale)/\(table).strings no es un diccionario de textos")
    }

    @Test("2.3 trae ocho tarjetas y la primera anuncia el iPhone Duo")
    func version23_hasEightCards_duoFirst() throws {
        let features = try #require(WhatsNewConfig.features(for: "2.3.0"))
        #expect(features.count == 8)
        #expect(features.first?.icon == "rectangle.split.2x1.fill")
        #expect(L10n.Novedades23.claves.first == "duo")
        #expect(Set(features.map(\.icon)).count == features.count, "Dos tarjetas con el mismo icono")
    }

    @Test("Cada tarjeta resuelve su texto (ninguna sale con la clave cruda)")
    func everyCard_resolvesItsText() throws {
        let features = try #require(WhatsNewConfig.features(for: "2.3"))
        for feature in features {
            #expect(!feature.title.hasPrefix("novedades23."), "Título crudo: \(feature.title)")
            #expect(!feature.description.hasPrefix("novedades23."), "Descripción cruda: \(feature.description)")
        }
    }

    @Test("Los 16 idiomas tienen las 16 claves, y la del Duo nombra el iPhone Duo", arguments: locales)
    func everyLocale_hasEveryKey(_ locale: String) throws {
        let strings = try Self.keys("Novedades23", locale)
        for clave in L10n.Novedades23.claves {
            let title = try #require(strings["novedades23.\(clave).title"], "\(locale): falta el título de \(clave)")
            let desc = try #require(strings["novedades23.\(clave).description"],
                                    "\(locale): falta la descripción de \(clave)")
            #expect(!title.isEmpty && !desc.isEmpty)
        }
        #expect(strings.count == L10n.Novedades23.claves.count * 2, "\(locale): claves de más o de menos")
        #expect(strings["novedades23.duo.title"]?.contains("iPhone Duo") == true, "\(locale): el Duo no se nombra")
    }

    /// Lo que la app publicada no hace en producción no se anuncia: Yala web y sus navegadores, el conector de IA,
    /// Gmail y el correo del banco (Paso 0 del encargo).
    @Test("No se anuncia nada que no esté en producción", arguments: ["es", "en"])
    func nothingOutsideProduction_isAnnounced(_ locale: String) throws {
        let all = try Self.keys("Novedades23", locale).values.joined(separator: " ").lowercased()
        for word in ["gmail", "yala web", "navegador", "browser", "claude", "chatgpt", "yalainbox"] {
            #expect(!all.contains(word), "\(locale): se anuncia «\(word)»")
        }
    }
}

// MARK: - Panel: llegada solo con Primeros pasos

@Suite("Panel progresivo · el saldo llega con la cuenta")
struct PanelLlegadaSoloPrimerosPasosTests {

    @Test("Al entrar (mazo a medias, sin cuenta) no sale el saldo grande")
    func arrival_hidesTheBalanceHero() {
        let gate = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: false,
                                               recordStepResolved: false, planningShown: false)
        #expect(gate.showsBalanceHero == false)
    }

    @Test("Con la cuenta hecha, el saldo vuelve")
    func withTheAccount_theBalanceShows() {
        let gate = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: true,
                                               recordStepResolved: false, planningShown: false)
        #expect(gate.showsBalanceHero)
    }

    @Test("Sin mazo a medias, el Panel de siempre")
    func withoutTheDeck_alwaysShows() {
        #expect(PrimerosPasosPanelGate.inactive.showsBalanceHero)
    }

    @Test("El Panel pinta el saldo detrás de la puerta")
    func panelView_gatesTheHero() throws {
        let url = Novedades23Tests.repoRoot().appending(path: "Yala/App/Views/Panel/PanelView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let gate = try #require(source.range(of: "if panelGate.showsBalanceHero {"))
        let hero = try #require(source.range(of: "PanelHeroSection("))
        #expect(gate.upperBound < hero.lowerBound, "El hero tiene que ir dentro de la puerta")
        #expect(source.components(separatedBy: "PanelHeroSection(").count == 2, "Otro hero sin puerta")
    }
}

// MARK: - Nota de salud: «Lo que te queda»

@Suite("Nota de salud · lote 2 · curva de «Lo que te queda»")
struct NotaSaludTeQuedaCurvaTests {

    @Test("20 % o más vale 100; 0 %, 50; en medio, en línea", arguments: [
        (0.20, 100), (0.50, 100), (0.10, 75), (0.0, 50), (0.04, 60),
    ])
    func positiveRates(_ rate: Double, _ expected: Int) {
        #expect(FinancialScoreCalculator.savingsScore(rate: rate) == expected)
    }

    @Test("Gastar más de lo que entra baja de 50 con suelo de 30", arguments: [
        (-0.05, 45), (-0.10, 40), (-0.20, 30), (-1.0, 30), (-5.0, 30),
    ])
    func negativeRates(_ rate: Double, _ expected: Int) {
        #expect(FinancialScoreCalculator.savingsScore(rate: rate) == expected)
    }

    @Test("Los pesos suman 1 y las tres de siempre conservan su proporción (40 : 25 : 35)")
    func weights() {
        let w = FinancialScoreCalculator.self
        #expect(abs(w.weightBudget + w.weightRhythm + w.weightCommitments + w.weightSavings - 1) < 1e-9)
        let three = w.weightBudget + w.weightRhythm + w.weightCommitments
        #expect(abs(w.weightBudget / three - 0.40) < 1e-9)
        #expect(abs(w.weightRhythm / three - 0.25) < 1e-9)
        #expect(abs(w.weightCommitments / three - 0.35) < 1e-9)
    }

    @Test("La parte que más sube la nota puede ser «Lo que te queda»")
    func weakestPart_canBeSavings() {
        let score = FinancialScore(total: 80, budget: 95, activity: 100, bills: 95, savings: 40)
        #expect(FinancialScoreCalculator.weakestPart(of: score) == .savings)
        #expect(FinancialScoreCopy.cardMessage(for: score) == L10n.NotaSaludTeQueda.pasoTarjeta)
    }

    @Test("Sin datos no es una parte «que falta»: el aviso de qué falta no la nombra")
    func savingsNil_isNotAMissingPart() {
        let score = FinancialScore(total: nil, budget: nil, activity: 80, bills: nil)
        #expect(!score.partsWithoutData.contains(.savings))
    }
}

@Suite("Nota de salud · lote 2 · cálculo de «Lo que te queda»", .serialized)
@MainActor
struct NotaSaludTeQuedaCalculoTests {

    private let calendar = Calendar.current
    /// Martes 17 de marzo de 2026, 12:00.
    private var now: Date { day(17) }

    private func day(_ d: Int, month: Int = 3) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12))!
    }

    private struct Escenario {
        var income: Double = 1000
        var expenses: [Double] = []
        /// Un gasto con categoría de gasto pero importe positivo (una devolución): resta del gasto.
        var refund: Double? = nil
        /// Un ingreso sin categoría: el signo manda.
        var uncategorizedIncome: Double? = nil
        /// Un gasto en una cuenta que no guarda su historial.
        var excludedExpense: Double? = nil
        /// Un gasto fechado mañana: todavía no salió.
        var futureExpense: Double? = nil
        var countsSavings = true
        /// Filas sueltas: importe con signo, fecha exacta, si su conversión es dudosa y si es la pata de un gasto de grupo.
        var extras: [Extra] = []
        var period: DetailPeriod = .thisMonth
        var includeBridgedGroupTx = true
    }

    private struct Extra {
        var amount: Double
        var date: Date
        var provisional = false
        var groupLeg = false
    }

    /// 00:00:00 de un día de marzo de 2026 (o del mes dado).
    private func midnight(_ d: Int, month: Int = 3) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d))!
    }

    private func score(_ e: Escenario, context: ModelContext) -> FinancialScore {
        let account = makeTestAccount(context: context, name: "Principal", currencyCode: "USD")
        let hidden = makeTestAccount(context: context, name: "Oculta", currencyCode: "USD")
        hidden.excludeFromStatistics = true
        let food = makeTestCategory(context: context, name: "Comida")
        let salary = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        var txs: [TransactionItem] = []
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory?, _ acc: Account) {
            let t = TransactionItem(
                date: date, amount: amount, currencyCode: "USD", note: nil, category: category, account: acc,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "USD"
            )
            context.insert(t)
            txs.append(t)
        }
        if e.income > 0 { tx(e.income, day(1), salary, account) }
        for (i, amount) in e.expenses.enumerated() { tx(-amount, day(2 + i), food, account) }
        if let refund = e.refund { tx(refund, day(10), food, account) }
        if let extra = e.uncategorizedIncome { tx(extra, day(11), nil, account) }
        if let excluded = e.excludedExpense { tx(-excluded, day(12), food, hidden) }
        if let future = e.futureExpense { tx(-future, day(18), food, account) }
        for extra in e.extras {
            let t = TransactionItem(
                date: extra.date, amount: extra.amount, currencyCode: "USD", note: nil,
                category: extra.amount >= 0 ? salary : food, account: account,
                amountInPreferredCurrency: extra.amount, preferredCurrencyCode: "USD"
            )
            t.isExchangeRateProvisional = extra.provisional
            if extra.groupLeg { t.splitExpenseID = UUID().uuidString }
            context.insert(t)
            txs.append(t)
        }
        return FinancialScoreCalculator.calculate(
            transactions: txs, budgets: [], scheduledPayments: [], accounts: [account, hidden],
            paidAmounts: [:], period: e.period, preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter(), now: now, calendar: calendar,
            includeBridgedGroupTx: e.includeBridgedGroupTx, countsSavings: e.countsSavings
        )
    }

    @Test("Queda el 20 %: vale 100, con las cifras de lo que entró y salió")
    func keeps20Percent() throws {
        let s = score(Escenario(expenses: [500, 300]), context: try makeTestContext())
        #expect(s.savings == 100)
        let f = try #require(s.savingsFigures)
        #expect(f.income == 1000)
        #expect(f.expense == 800)
        #expect(f.left == 200)
    }

    @Test("Sale más de lo que entra: baja de 50")
    func spendsMore() throws {
        let s = score(Escenario(expenses: [1100]), context: try makeTestContext())
        #expect(s.savings == 40)
    }

    @Test("Sin ingresos en el período, la parte no cuenta")
    func noIncome_doesNotCount() throws {
        let s = score(Escenario(income: 0, expenses: [100]), context: try makeTestContext())
        #expect(s.savings == nil)
        #expect(s.savingsFigures == nil)
    }

    @Test("En «Solo gastos» no cuenta aunque haya ingresos")
    func expensesOnly_doesNotCount() throws {
        let s = score(Escenario(expenses: [500], countsSavings: false), context: try makeTestContext())
        #expect(s.savings == nil)
    }

    @Test("Una devolución en una categoría de gasto resta del gasto (regla con signo del hero)")
    func refund_subtractsFromExpense() throws {
        let s = score(Escenario(expenses: [1000], refund: 200), context: try makeTestContext())
        #expect(s.savingsFigures?.expense == 800)
        #expect(s.savings == 100)
    }

    @Test("Un ingreso sin categoría cuenta como ingreso por su signo")
    func uncategorizedIncome_counts() throws {
        let s = score(Escenario(expenses: [900], uncategorizedIncome: 500), context: try makeTestContext())
        #expect(s.savingsFigures?.income == 1500)
    }

    @Test("Una cuenta que no guarda su historial queda fuera, y lo fechado después de hoy también")
    func excludedAndFuture_areLeftOut() throws {
        let s = score(Escenario(expenses: [500], excludedExpense: 400, futureExpense: 300),
                      context: try makeTestContext())
        #expect(s.savingsFigures?.expense == 500)
    }

    // MARK: Medianoche (ítem `periodo-que-cierra-en-medianoche` de la checklist)

    @Test("Este mes: las 00:00 del día 1 cuentan; las 00:00 de mañana, no")
    func thisMonth_midnights() throws {
        let s = score(Escenario(income: 0, extras: [
            Extra(amount: 1000, date: midnight(1)),
            Extra(amount: -300, date: midnight(1)),
            Extra(amount: -500, date: midnight(18)),
        ]), context: try makeTestContext())
        let f = try #require(s.savingsFigures)
        #expect(f.income == 1000)
        #expect(f.expense == 300)
    }

    @Test("Mes pasado: las 00:00 del día 1 de este mes no entran en el mes pasado")
    func lastMonth_excludesTheFirstMidnightOfThisMonth() throws {
        let s = score(Escenario(income: 0, extras: [
            Extra(amount: 2000, date: midnight(15, month: 2)),
            Extra(amount: -400, date: midnight(28, month: 2)),
            Extra(amount: -900, date: midnight(1)),
            Extra(amount: 700, date: midnight(1)),
        ], period: .lastMonth), context: try makeTestContext())
        let f = try #require(s.savingsFigures)
        #expect(f.income == 2000)
        #expect(f.expense == 400)
    }

    // MARK: La marca «≈» por cifra (ítem `marca-aproximado-sobre-lo-mostrado`)

    @Test("Cada cifra lleva su marca: el gasto dudoso marca «salió» y lo que queda, no «entró»")
    func approximate_perSide() throws {
        let s = score(Escenario(income: 0, extras: [
            Extra(amount: 1000, date: day(1)),
            Extra(amount: -700, date: day(2)),
            Extra(amount: -100, date: day(3), provisional: true),
        ]), context: try makeTestContext())
        let f = try #require(s.savingsFigures)
        #expect(f.incomeIsApproximate == false)
        #expect(f.expenseIsApproximate)   // 100 de 800: 12,5 %
        #expect(f.isApproximate)          // 100 de 200 que quedan
    }

    @Test("Lo que queda se mide sobre la resta, no con un «o» de los dos lados")
    func approximate_netIsNotAnOr() throws {
        let s = score(Escenario(income: 0, extras: [
            Extra(amount: 9600, date: day(1)),
            Extra(amount: 400, date: day(2), provisional: true),
            Extra(amount: -9800, date: day(3)),
        ]), context: try makeTestContext())
        let f = try #require(s.savingsFigures)
        #expect(f.incomeIsApproximate == false)   // 400 de 10.000: 4 %, no marca
        #expect(f.expenseIsApproximate == false)
        #expect(f.isApproximate)                  // 400 de los 200 que quedan
    }

    // MARK: Gastos de grupo (ítem `gasto-de-grupo-cuenta-mi-parte-una-vez`)

    @Test("Con «Incluir gastos de grupo» apagado, la pata de un gasto de grupo no cuenta")
    func groupLeg_followsTheStatsToggle() throws {
        let extras = [Extra(amount: -300, date: day(4), groupLeg: true)]
        let on = score(Escenario(expenses: [200], extras: extras), context: try makeTestContext())
        let off = score(Escenario(expenses: [200], extras: extras, includeBridgedGroupTx: false),
                        context: try makeTestContext())
        #expect(on.savingsFigures?.expense == 500)
        #expect(off.savingsFigures?.expense == 200)
    }

    @Test("«Lo que te queda» no desbloquea la nota: con solo Ritmo y esa parte, todavía no hay nota (PN-2)")
    func savingsDoesNotUnlockTheTotal() throws {
        let s = score(Escenario(expenses: [500]), context: try makeTestContext())
        #expect(s.savings == 100)
        #expect(s.activity != nil)
        #expect(s.budget == nil && s.bills == nil)
        #expect(s.total == nil)
    }

    @Test("Sin la parte nueva, la nota total es la de antes (40 : 25 : 35)")
    func withoutSavings_totalIsTheOldOne() {
        // Ritmo 100, Compromisos 75, sin presupuestos: (100·0,25 + 75·0,35) / 0,60 = 85,4 → 85, como antes.
        let w = FinancialScoreCalculator.self
        let total = (100 * w.weightRhythm + 75 * w.weightCommitments) / (w.weightRhythm + w.weightCommitments)
        #expect(Int(total.rounded()) == 85)
    }
}

// MARK: - Textos de «Lo que te queda»

@Suite("Nota de salud · lote 2 · textos en los 16 idiomas")
struct NotaSaludTeQuedaTextosTests {

    static let claves = ["name", "partDetail", "sheetExplanation", "headline.high", "headline.mid", "headline.low",
                         "headline.empty", "cta", "cardStep", "lead.left", "lead.over", "lead.empty", "capsule.empty"]

    private static func placeholders(_ s: String) throws -> [String] {
        let regex = try Regex(#"%(\d+\$)?[@d]"#)
        return s.matches(of: regex).map { String(s[$0.range]) }.sorted()
    }

    @Test("Todas las claves, con los mismos huecos que en español", arguments: Novedades23Tests.locales)
    func everyLocale(_ locale: String) throws {
        let reference = try Novedades23Tests.keys("NotaSaludTeQueda", "es")
        let strings = try Novedades23Tests.keys("NotaSaludTeQueda", locale)
        #expect(strings.count == Self.claves.count, "\(locale): claves de más o de menos")
        for clave in Self.claves {
            let value = try #require(strings["teQueda.\(clave)"], "\(locale): falta teQueda.\(clave)")
            #expect(!value.isEmpty)
            #expect(try Self.placeholders(value) == Self.placeholders(reference["teQueda.\(clave)"] ?? ""),
                    "\(locale) · \(clave): los huecos no coinciden")
        }
    }

    @Test("Las frases con cifras se arman sin claves crudas y con el % pegado a su número")
    func phrasesFormat() {
        let frase = L10n.NotaSaludTeQueda.fraseQueda(entro: "S/ 1,000", salio: "S/ 800", queda: "S/ 200", porcentaje: 20)
        #expect(frase.contains("S/ 200"))
        #expect(frase.contains("20\u{00A0}%"))
        #expect(!frase.hasPrefix("teQueda."))
        #expect(!L10n.NotaSaludTeQueda.nombre.hasPrefix("teQueda."))
    }
}
