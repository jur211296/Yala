//
//  HeroClaroLogicTests.swift
//  YalaTests
//
//  El hero claro de Estadísticas, Registros y Flujo de caja (encargo del 2026-11-16): qué explica el «?» de cada cifra,
//  cuándo sale, que el ejemplo de cada hoja cuadra y que las cinco pantallas montan las piezas (rótulo con «?», cifra
//  pegada al rótulo, ingresos y gastos rotulados).
//

import Foundation
import Testing

@testable import Yala

@Suite("Hero claro · lógica")
struct HeroClaroLogicTests {

    // MARK: - Qué explica el «?»

    /// La explicación sigue a la MISMA magnitud que el rótulo: si Distribución enseña el saldo, la hoja habla del saldo.
    @Test func eachCaption_opensTheExplanationOfItsOwnFigure() {
        #expect(HeroClaroLogic.topic(for: .netPeriod) == .net)
        #expect(HeroClaroLogic.topic(for: .expensePeriod) == .expense)
        #expect(HeroClaroLogic.topic(for: .incomePeriod) == .income)
        #expect(HeroClaroLogic.topic(for: .totalPeriod) == .total)
        #expect(HeroClaroLogic.topic(for: .accountsBalance) == .accountsBalance)
    }

    /// Ningún rótulo de Estadísticas se queda sin hoja, y dos rótulos distintos no comparten explicación.
    @Test func everyCaption_hasADistinctTopic() {
        let topics = StatsHeroCaption.allCases.map(HeroClaroLogic.topic(for:))
        #expect(Set(topics.map { "\($0)" }).count == StatsHeroCaption.allCases.count)
    }

    /// Las cuatro pestañas, por el mismo camino que eligen su rótulo.
    @Test func statisticsTabs_pickTheTopicOfWhatTheyShow() {
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.insights(expensesOnly: false)) == .net)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.insights(expensesOnly: true)) == .expense)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.trends(metric: .income)) == .income)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.distribution(isBalanceMode: true, natures: [])) == .accountsBalance)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.distribution(isBalanceMode: false, natures: [])) == .expense)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.distribution(
            isBalanceMode: false, natures: [.income, .expense])) == .total)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.records(natures: [.income], expensesOnly: false)) == .income)
        #expect(HeroClaroLogic.topic(for: StatsHeroCaptionLogic.records(natures: [], expensesOnly: false)) == .net)
    }

    /// «Al 30 tendrías» solo en el mes en curso y con cuentas que sumen; si no, el rótulo es lo que queda del mes.
    @Test func cashFlow_explainsMonthEndOnlyForTheCurrentMonthWithAccounts() {
        #expect(HeroClaroLogic.cashFlowTopic(isCurrentMonth: true, hasMonthEnd: true) == .cashFlowMonthEnd)
        #expect(HeroClaroLogic.cashFlowTopic(isCurrentMonth: true, hasMonthEnd: false) == .cashFlowMonth)
        #expect(HeroClaroLogic.cashFlowTopic(isCurrentMonth: false, hasMonthEnd: true) == .cashFlowMonth)
        #expect(HeroClaroLogic.cashFlowTopic(isCurrentMonth: false, hasMonthEnd: false) == .cashFlowMonth)
    }

    /// Como en el Panel: con «Mostrar ayudas» apagado no hay «?», y sin cifra tampoco.
    @Test func helpButton_followsShowHints_andNeedsAFigure() {
        #expect(HeroClaroLogic.showsHelp(showHints: true, showsFigure: true))
        #expect(!HeroClaroLogic.showsHelp(showHints: false, showsFigure: true))
        #expect(!HeroClaroLogic.showsHelp(showHints: true, showsFigure: false))
    }

    // MARK: - El ejemplo cuadra

    /// El resultado del ejemplo es la cuenta que la hoja explica con las filas de encima. Un ejemplo que no cuadra
    /// enseñaría justo lo contrario de lo que promete.
    @Test(arguments: HeroClaroLogic.Topic.allCases)
    func example_resultIsTheExplainedArithmetic(_ topic: HeroClaroLogic.Topic) throws {
        let rows = HeroClaroLogic.example(for: topic)
        let result = try #require(rows.last)
        #expect(result.isResult)
        #expect(rows.dropLast().allSatisfy { !$0.isResult })
        let parts = rows.dropLast().map(\.value)
        let expected: Double
        switch topic {
        case .net:
            expected = parts[0] - parts[1]                 // ingresos − gastos
        case .expense, .income, .accountsBalance:
            expected = parts.reduce(0, +)                  // suma con signo (la devolución resta)
        case .total:
            expected = parts.map(abs).reduce(0, +)         // ingresos y gastos sumados, sin restar
        case .cashFlowMonthEnd:
            expected = parts[0] + parts[1] - parts[2]      // hoy + falta entrar − falta salir
        case .cashFlowMonth:
            expected = abs(parts[0] - parts[1])            // lo que faltaría
        }
        #expect(result.value == expected)
    }

    /// El ejemplo del mes del flujo de caja enseña el caso que la frase nombra («te faltaría»): sale más de lo que entra.
    @Test func cashFlowMonthExample_isAShortfall() {
        let rows = HeroClaroLogic.example(for: .cashFlowMonth)
        #expect(rows[1].value > rows[0].value)
        #expect(rows.last?.label == .netShortfall)
    }

    /// El de los gastos lleva una devolución en negativo: es la regla de `ingreso-gasto.md` («una devolución resta»).
    @Test func expenseExample_showsARefundSubtracting() {
        let rows = HeroClaroLogic.example(for: .expense)
        #expect(rows.contains { $0.label == .refund && $0.value < 0 })
    }
}

@Suite("Hero claro · cableado (source-scan)")
struct HeroClaroWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        // Solo código: un comentario que nombre la pieza no cuenta como montarla.
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    static let heroes = [
        "Yala/App/Views/Statistics/InsightsTabView.swift",
        "Yala/App/Views/Statistics/TrendsTabView.swift",
        "Yala/App/Views/Statistics/CategoriesTabView.swift",
        "Yala/App/Views/Statistics/RecordsTabView.swift",
        "Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
    ]

    /// Cada hero lleva su «?» y cuelga la hoja que lo explica.
    @Test(arguments: heroes)
    func eachHero_hasItsHelpButton_andPresentsTheSheet(_ path: String) throws {
        let code = try Self.source(path)
        #expect(code.contains("HeroInfoButton("), "\(path) no monta el «?».")
        #expect(code.contains(".heroInfoSheet($heroInfo"), "\(path) no presenta la hoja del «?».")
    }

    /// Sin el hueco: la cifra va pegada al rótulo (`HeroClaroHeader`). `SummaryHeaderStack` lo pone a Resumen y a
    /// Registros; las otras tres lo montan ellas. Volver a `HeroHeader {` devolvería el hueco.
    @Test func noGapBeforeTheFigure() throws {
        let summary = try Self.source("Yala/App/Views/Shared/SummaryHeaderStack.swift")
        #expect(summary.contains("HeroClaroHeader {"))
        #expect(!summary.contains("HeroHeader {"))
        for path in [
            "Yala/App/Views/Statistics/TrendsTabView.swift",
            "Yala/App/Views/Statistics/CategoriesTabView.swift",
            "Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
        ] {
            let code = try Self.source(path)
            #expect(code.contains("HeroClaroHeader {"), "\(path) no usa el hero claro.")
            #expect(!code.contains("HeroHeader {"), "\(path) sigue con el hero del hueco.")
        }
    }

    /// Ingresos y gastos rotulados en las tres pestañas que los enseñan bajo la cifra.
    @Test(arguments: [
        "Yala/App/Views/Statistics/InsightsTabView.swift",
        "Yala/App/Views/Statistics/TrendsTabView.swift",
        "Yala/App/Views/Statistics/RecordsTabView.swift",
    ])
    func incomeAndExpense_areLabelled(_ path: String) throws {
        let code = try Self.source(path)
        #expect(code.contains("HeroFlowAmountCaption(text: L10n.CashFlow.income)"), "\(path): ingresos sin rótulo.")
        #expect(code.contains("HeroFlowAmountCaption(text: L10n.CashFlow.expense)"), "\(path): gastos sin rótulo.")
    }

    /// El análisis de cuenta reutiliza la tarjeta de «Últimos registros» del Panel en sus dos listas, no una copia.
    @Test func accountAnalysis_reusesThePanelRecordsCard() throws {
        let code = try Self.source("Yala/App/Views/Panel/Sheets/AccountDetailSheet.swift")
        #expect(code.components(separatedBy: "RecentRecordsWidget(").count - 1 == 2)
    }
}

@Suite("Hero claro · textos")
struct HeroClaroStringsTests {

    private static let locales = [
        "es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt", "pt-PT", "zh-Hans",
    ]

    private static func keys(in locale: String) throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String])
        return dict.filter { $0.key.hasPrefix("heroClaro.") }
    }

    /// Las mismas claves en los 16 idiomas, con texto propio (nunca la clave cruda).
    @Test(arguments: locales)
    func everyLocale_hasEveryKey(_ locale: String) throws {
        let reference = try Self.keys(in: "es-419")
        let here = try Self.keys(in: locale)
        #expect(reference.count == 30)
        #expect(Set(here.keys) == Set(reference.keys), "\(locale) no tiene las mismas claves que es-419.")
        for (key, value) in here {
            #expect(!value.isEmpty && value != key, "\(locale): \(key) sin traducir.")
        }
    }

    /// Fuera del español, ninguna frase se quedó en español.
    @Test(arguments: ["en", "en-GB", "de", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "zh-Hans"])
    func translations_areNotSpanish(_ locale: String) throws {
        let spanish = try Self.keys(in: "es-419")
        let here = try Self.keys(in: locale)
        let copied = here.filter { spanish[$0.key] == $0.value && $0.value.count > 8 }
        #expect(copied.isEmpty, "\(locale) copia el español en \(copied.keys.sorted())")
    }
}
