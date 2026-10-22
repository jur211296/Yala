//
//  PanelWakesOnNewRatesTests.swift
//  YalaTests
//
//  Que el Panel se entere de las tasas nuevas, recalcule UNA vez y apague el «≈».
//  Ticket `panel-no-recalcula-al-llegar-tasas-nuevas`.
//
//  Tres piezas, porque la cadena tiene tres eslabones y cada uno se puede romper por separado:
//  1. el ViewModel: `exchangeRatesDidUpdate()` produce un recálculo, y una ráfaga sigue siendo uno;
//  2. el converter: con la fila buena en disco e invalidada la caché —lo que hace el receptor del
//     arranque al postear—, el mismo cálculo del saldo deja de ser aproximado;
//  3. la vista: `.onReceive` de `.yalaExchangeRatesUpdated` llama al método (source-scan: el
//     `onReceive` es vista y no se puede montar aquí).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1 · El ViewModel recalcula una vez por evento

@MainActor
@Suite("Panel · las tasas nuevas despiertan el recálculo", .serialized)
struct PanelWakesOnNewRatesTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene, o el cálculo sale por su
    /// `guard` sin contar nada.
    private let session = SessionState()

    private func makePanel() throws -> PanelViewModel {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        // El `applicationState` del host de unit tests no es fiable: el freno se inyecta.
        viewModel.isApplicationActive = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    /// Espera a que `performCalculation` haya corrido `target` veces, con tope. Sondea en vez de dormir
    /// un plazo fijo: el recálculo llega tras el freno de 150 ms.
    private func waitForRuns(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<100 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("Llegan tasas nuevas → el Panel recalcula, y solo una vez")
    func newRates_recalculateOnce() async throws {
        let viewModel = try makePanel()
        let flagBefore = SessionState.shared.needsExchangeRateWidgetRefresh
        defer { SessionState.shared.needsExchangeRateWidgetRefresh = flagBefore }
        let before = viewModel.debugCalculationRuns

        viewModel.exchangeRatesDidUpdate()
        try await waitForRuns(viewModel, reaching: before + 1)
        // Margen para que un segundo recálculo, si lo hubiera, llegue a contarse.
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugCalculationRuns == before + 1)
    }

    @Test("Una ráfaga de avisos (los tres escritores de Ajustes seguidos) es UN recálculo")
    func burstOfUpdates_coalescesIntoOne() async throws {
        let viewModel = try makePanel()
        let flagBefore = SessionState.shared.needsExchangeRateWidgetRefresh
        defer { SessionState.shared.needsExchangeRateWidgetRefresh = flagBefore }
        let before = viewModel.debugCalculationRuns

        viewModel.exchangeRatesDidUpdate()
        viewModel.exchangeRatesDidUpdate()
        viewModel.exchangeRatesDidUpdate()
        try await waitForRuns(viewModel, reaching: before + 1)
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugCalculationRuns == before + 1)
    }

    @Test("El widget de tipo de cambio queda marcado para rehacerse")
    func newRates_markTheRateWidgetStale() throws {
        let viewModel = try makePanel()
        let flagBefore = SessionState.shared.needsExchangeRateWidgetRefresh
        defer { SessionState.shared.needsExchangeRateWidgetRefresh = flagBefore }
        SessionState.shared.needsExchangeRateWidgetRefresh = false

        viewModel.exchangeRatesDidUpdate()

        #expect(SessionState.shared.needsExchangeRateWidgetRefresh)
    }

    @Test("Control: sin aviso no hay recálculo (el contador no avanza solo)")
    func noUpdate_noRecalculation() async throws {
        let viewModel = try makePanel()
        let before = viewModel.debugCalculationRuns

        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugCalculationRuns == before)
    }
}

// MARK: - 2 · Con la fila buena en disco, el saldo deja de ser aproximado

@MainActor
@Suite("Panel · la marca «≈» se apaga con la tasa del día")
struct PanelApproximateMarkClearsTests {

    private static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let rates: [String: Double] = ["USD": 1.0, "PEN": 3.75, "EUR": 0.92]

    /// Saldo de una cuenta en USD, mostrado en PEN, con SOLO la fila de ayer en disco: el converter
    /// baja un escalón y el saldo sale aproximado. Converter propio, no `.shared`.
    private func makeScenario() throws -> (ModelContext, CurrencyConverter, Account, TransactionItem) {
        let schema = Schema([ExchangeRate.self, TransactionItem.self, Account.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))

        let yesterday = Date.now.addingTimeInterval(-86_400)
        context.insert(
            try ExchangeRate(
                dateKey: Self.dayKey.string(from: yesterday), base: "USD", ratesDictionary: Self.rates))

        let account = Account(
            name: "Dólares", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard.fill",
            type: "bank")
        context.insert(account)
        let income = TransactionItem(date: yesterday, amount: 100, currencyCode: "USD", account: account)
        context.insert(income)
        try context.save()

        let converter = CurrencyConverter()
        converter.setContext(context)
        return (context, converter, account, income)
    }

    private func breakdown(
        _ account: Account, _ tx: TransactionItem, _ converter: CurrencyConverter
    ) -> LiveBalanceCalculator.Breakdown {
        LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [account], transactions: [tx], preferredCurrencyCode: "PEN", converter: converter)
    }

    private func persistToday(_ context: ModelContext) throws {
        context.insert(
            try ExchangeRate(
                dateKey: Self.dayKey.string(from: .now), base: "USD", ratesDictionary: Self.rates))
        try context.save()
    }

    @Test("Fila de hoy en disco + caché invalidada (el receptor del aviso) → el saldo deja de ser «≈»")
    func todaysRowAndInvalidation_clearTheMark() throws {
        let (context, converter, account, tx) = try makeScenario()
        #expect(breakdown(account, tx, converter).amountsAreApproximate, "premisa: sin la fila de hoy es «≈»")

        try persistToday(context)
        converter.invalidateLatestRatesCache()

        #expect(!breakdown(account, tx, converter).amountsAreApproximate)
    }

    /// Por qué hace falta que alguien reaccione al aviso: sin invalidar, la caché sigue sirviendo el
    /// escalón de ayer con la fila buena ya en disco. Es lo que veía el Panel antes del arreglo.
    @Test("Control: con la fila de hoy en disco pero sin reaccionar al aviso, la marca se queda")
    func todaysRowWithoutInvalidation_keepsTheMark() throws {
        let (context, converter, account, tx) = try makeScenario()
        #expect(breakdown(account, tx, converter).amountsAreApproximate)

        try persistToday(context)

        #expect(breakdown(account, tx, converter).amountsAreApproximate)
    }
}

// MARK: - 3 · La vista escucha el aviso (source-scan)

@Suite("Panel · cableado del aviso de tasas (source-scan)")
struct PanelExchangeRateObserverWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo normalizado: sin comentarios, líneas recortadas y unidas por espacio.
    private static func normalized(_ text: Substring) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }

    @Test("El observador recibe `.yalaExchangeRatesUpdated` y llama a `exchangeRatesDidUpdate()`")
    func observerBody_isExactlyTheWiring() throws {
        let source = try Self.source("Yala/App/Views/Panel/PanelDataObservers.swift")
        let start = try #require(source.range(of: "struct PanelExchangeRateObserver: ViewModifier {"))
        let body = Self.normalized(source[start.lowerBound...])

        #expect(
            body.hasPrefix(
                "struct PanelExchangeRateObserver: ViewModifier { let viewModel: PanelViewModel "
                    + "func body(content: Content) -> some View { content "
                    + ".onReceive(NotificationCenter.default.publisher(for: .yalaExchangeRatesUpdated)) { _ in "
                    + "viewModel.exchangeRatesDidUpdate() } } }"))
    }

    @Test("El Panel monta el observador")
    func panelDataObservers_mountTheObserver() throws {
        let source = try Self.source("Yala/App/Views/Panel/PanelDataObservers.swift")
        let start = try #require(source.range(of: "struct PanelDataObservers: ViewModifier {"))
        let end = try #require(source.range(of: "struct PanelDataCountObservers"))
        let body = Self.normalized(source[start.lowerBound..<end.lowerBound])

        #expect(body.contains(".modifier(PanelExchangeRateObserver(viewModel: viewModel))"))

        let shell = try Self.source("Yala/App/Views/Panel/PanelShell.swift")
        #expect(shell.contains(".modifier(PanelDataObservers("))
    }

    @Test("`exchangeRatesDidUpdate()` marca el widget y recalcula SIN recargar")
    func viewModelMethod_recalculatesWithoutReload() throws {
        let source = try Self.source("Yala/App/ViewModels/PanelViewModel.swift")
        let start = try #require(source.range(of: "func exchangeRatesDidUpdate() {"))
        let body = Self.normalized(source[start.lowerBound...])

        #expect(
            body.hasPrefix(
                "func exchangeRatesDidUpdate() { SessionState.shared.needsExchangeRateWidgetRefresh = true "
                    + "recalculateData() }"))
    }
}
