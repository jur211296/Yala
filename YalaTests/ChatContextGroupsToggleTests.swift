//
//  ChatContextGroupsToggleTests.swift
//  YalaTests
//
//  Ticket `chat-total-ignores-the-panel-groups-toggle` (decisión A de Jürgen, 2026-10-09): el saldo total del
//  contexto de Yala IA (`FullFinancialContextBuilder`, `balances.total_balance`) sigue el ajuste «Grupos en el
//  total» del Panel (`AppPreferences.includeGroupsInPanelTotal`), y las cuentas de Grupos siguen listadas en
//  `balances.accounts` en los dos valores.
//
//  La paridad se mide contra la función REAL del Panel (`PanelViewModel.displayedBalanceInDefaultCurrency`), con
//  sus preferencias en un `UserDefaults` aislado. Esa función lee el filtro de cuentas de `SessionState.shared`,
//  así que la suite va serializada y lo deja vacío y restaurado.
//
//  Sin `ModelContext`: `@Model` en memoria, como `ChatContextPanelParityAndMonthToDateTests`.
//

import Testing
import Foundation
import SwiftData
@testable import Yala

@MainActor
@Suite(.serialized)
struct ChatContextGroupsToggleTests {

    // MARK: - Fixtures

    private let now: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .distantPast
    }()

    private func account(_ name: String, system: Bool = false) -> Account {
        Account(
            name: name,
            currencyCode: "USD",
            colorHex: "#000",
            iconName: "creditcard",
            type: system ? "system" : "bank",
            excludeFromStatistics: false,
            isSystemAccount: system
        )
    }

    private let salary = YalaCategory(name: "Salary", colorHex: "#000", isIncome: true)
    private let food = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)

    private func tx(_ amount: Double, _ account: Account) -> TransactionItem {
        let tx = TransactionItem(
            date: now.addingTimeInterval(-86_400),
            amount: amount,
            currencyCode: "USD",
            category: amount < 0 ? food : salary,
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.account = account
        return tx
    }

    /// Checking 1000 · Grupos USD 250 (la cuenta sistema del bridge de Grupos).
    private func scenario() -> (accounts: [Account], txs: [TransactionItem]) {
        let checking = account("Checking")
        let groups = account("Grupos USD", system: true)
        return ([checking, groups], [tx(1_000, checking), tx(250, groups)])
    }

    private func chatContext(
        _ accounts: [Account],
        _ txs: [TransactionItem],
        includeGroupsInTotal: Bool,
        builder: FullFinancialContextBuilder? = nil
    ) -> FullFinancialContext {
        (builder ?? FullFinancialContextBuilder()).buildFromArrays(
            transactions: txs,
            budgets: [],
            accounts: accounts,
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            includeGroupsInTotal: includeGroupsInTotal,
            now: now
        )
    }

    /// El total del Panel con el ajuste en `includeGroups`: la función real, sin filtro de cuentas, con las cuentas
    /// que le llegan en producción (las no excluidas de estadísticas, `computeEligibleAccounts`).
    private func panelTotal(_ accounts: [Account], _ txs: [TransactionItem], includeGroups: Bool) throws -> Double {
        let suite = "test.chatGroupsToggle.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = AppPreferences(defaults: defaults)
        prefs.includeGroupsInPanelTotal = includeGroups

        let session = SessionState.shared
        let savedIDs = session.selectedAccountIDs
        let savedExclude = session.isExcludeMode
        session.selectedAccountIDs = []
        session.isExcludeMode = false
        defer {
            session.selectedAccountIDs = savedIDs
            session.isExcludeMode = savedExclude
        }

        let panel = PanelViewModel()
        panel.setAppPreferences(prefs)
        let breakdown = panel.displayedBalanceInDefaultCurrency(
            accounts: accounts.filter { !$0.excludeFromStatistics },
            transactions: txs,
            defaultCurrencyCode: "USD"
        )
        return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
    }

    // MARK: - Paridad con el Panel en los dos valores del ajuste

    @Test func groupsToggleOff_chatTotalIsThePanels_withoutTheGroupsAccount() throws {
        let (accounts, txs) = scenario()

        let context = chatContext(accounts, txs, includeGroupsInTotal: false)
        let panel = try panelTotal(accounts, txs, includeGroups: false)

        #expect(panel == 1_000)
        #expect(context.balances.totalBalance == panel)
        #expect(context.balances.totalIncludesGroups == false)
        // La cuenta de Grupos sigue listada, con su saldo y su tipo, para que el modelo pueda nombrarla.
        #expect(context.balances.accounts.map(\.name).sorted() == ["Checking", "Grupos USD"])
        let groups = context.balances.accounts.first { $0.name == "Grupos USD" }
        #expect(groups?.balance == 250)
        #expect(groups?.type == "system")
    }

    @Test func groupsToggleOn_chatTotalIsThePanels_withTheGroupsAccount() throws {
        let (accounts, txs) = scenario()

        let context = chatContext(accounts, txs, includeGroupsInTotal: true)
        let panel = try panelTotal(accounts, txs, includeGroups: true)

        #expect(panel == 1_250)
        #expect(context.balances.totalBalance == panel)
        #expect(context.balances.totalIncludesGroups == true)
        #expect(context.balances.accounts.map(\.name).sorted() == ["Checking", "Grupos USD"])
    }

    /// El default del builder es el default del ajuste: encendido. Quien no lo pasa (los tests de antes, el golden
    /// del conector) sigue sumando lo que sumaba.
    @Test func builderDefault_isTheSettingsDefault_on() throws {
        let (accounts, txs) = scenario()
        let context = FullFinancialContextBuilder().buildFromArrays(
            transactions: txs, budgets: [], accounts: accounts, tags: [], scheduledPayments: [],
            currencyCode: "USD", currencyDisplay: "$", converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es", country: "US", includeAnomalies: false, now: now
        )
        #expect(context.balances.totalBalance == 1_250)
        #expect(context.balances.totalIncludesGroups == true)

        let suite = "test.chatGroupsToggle.default.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(AppPreferences(defaults: defaults).includeGroupsInPanelTotal == true)
    }

    // MARK: - La caché de 60 s no sirve un total hecho con el ajuste de antes

    @Test func cache_doesNotServeATotalBuiltWithTheOtherSetting() {
        let (accounts, txs) = scenario()
        let builder = FullFinancialContextBuilder()

        #expect(chatContext(accounts, txs, includeGroupsInTotal: true, builder: builder).balances.totalBalance == 1_250)
        // Mismo builder y mismo instante (dentro del TTL): el usuario apagó el ajuste entre dos preguntas.
        #expect(chatContext(accounts, txs, includeGroupsInTotal: false, builder: builder).balances.totalBalance == 1_000)
        #expect(chatContext(accounts, txs, includeGroupsInTotal: true, builder: builder).balances.totalBalance == 1_250)
    }

    // MARK: - El JSON que ve el modelo y el prompt que lo explica

    @Test func json_carriesTheFlag_withTheKeyThePromptNames() throws {
        let (accounts, txs) = scenario()
        let data = try JSONEncoder().encode(chatContext(accounts, txs, includeGroupsInTotal: false).balances)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["total_includes_groups"] as? Bool == false)
        #expect(object["total_balance"] as? Double == 1_000)

        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Services/ChatAssistantService.swift"),
            encoding: .utf8
        )
        let rule = try #require(source.split(separator: "\n").first { $0.contains("15b. SALDO TOTAL:") })
        let keys = FullFinancialContext.BalancesSection.CodingKeys.self
        #expect(rule.contains("`balances.\(keys.totalIncludesGroups.rawValue)`"))
        #expect(rule.contains("`balances.\(keys.totalBalance.rawValue)`"))
        #expect(rule.contains("`balances.\(keys.accounts.rawValue)`"))
        // Las cuentas de Grupos se reconocen por su `type`, el que les pone `GroupBridgeSystemEntities`.
        #expect(rule.contains("`type` \\\"system\\\""))
        // Las reglas 16 y 17 no se renumeran: el banco las busca literalmente.
        #expect(source.contains("\"16. Tono: \\(toneInstruction)\""))
        #expect(source.contains("\"17. Enfoque: \\(focusInstruction)\""))
    }

    // MARK: - Cableado: la hoja inyecta las preferencias y el ViewModel las lee al preguntar

    @Test func viewModel_readsTheSettingAtAskTime() throws {
        let suite = "test.chatGroupsToggle.vm.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = AppPreferences(defaults: defaults)

        let vm = ChatAssistantViewModel(defaults: defaults)
        #expect(vm.includeGroupsInTotal == true)  // sin preferencias, el default del ajuste, como el Panel
        vm.setAppPreferences(prefs)
        prefs.includeGroupsInPanelTotal = false
        #expect(vm.includeGroupsInTotal == false)
        prefs.includeGroupsInPanelTotal = true
        #expect(vm.includeGroupsInTotal == true)
    }

    @Test func wiring_sheetInjectsPreferences_andBothQuestionsPassTheSetting() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func read(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }

        let sheet = try read("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains("viewModel.setAppPreferences(appPreferences)"))

        let vm = try read("Yala/App/ViewModels/ChatAssistantViewModel.swift")
        let calls = Array(vm.components(separatedBy: "service.processQuestion(").dropFirst())
        #expect(calls.count == 2)
        for call in calls {
            let args = try #require(call.components(separatedBy: ")\n").first)
            #expect(args.contains("includeGroupsInTotal: includeGroupsInTotal,"))
        }

        let service = try read("Yala/Services/ChatAssistantService.swift")
        #expect(service.contains("includeAnomalies: needsAnomalies,\n            includeGroupsInTotal: includeGroupsInTotal\n"))
    }
}
