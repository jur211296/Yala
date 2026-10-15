//
//  BudgetsCopyAndWiringTests.swift
//  YalaTests
//
//  Bugs de texto y de VoiceOver de Presupuestos (auditoría UX 2.2, lote 9), medidos en el simulador:
//  el detalle decía «Estado: Activos» y el editor «Activas» para un solo presupuesto; la estrella de Planificación se
//  leía «Plantillas favoritas»; el vacío de un tipo decía «Aún no tienes presupuestos» a quien tiene seis mensuales;
//  Ajustes › Presupuestos formateaba los importes con su propio formateador («S/ 1,800» frente a «S/ 1,800.00»); la
//  línea del límite de las gráficas se leía en inglés.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct BudgetsCopyTests {

    @Test("El vacío de cada tipo tiene su propio texto, distinto del genérico")
    func emptyTitlePerPeriodType() {
        let titles = BudgetPeriodType.allCases.map { L10n.Budgets.emptyTitle(for: $0) }
        #expect(Set(titles).count == BudgetPeriodType.allCases.count, "Dos tipos comparten texto: \(titles)")
        for title in titles {
            #expect(title != L10n.Budgets.emptyTitle)
            #expect(!title.hasPrefix("budgets."), "Clave sin traducir: \(title)")
        }
    }

    @Test("El estado de UN presupuesto no es el rótulo de la sección")
    func stateIsNotTheSectionHeader() {
        #expect(L10n.Budgets.state(isActive: true) != BudgetStatus.active.localizedName)
        #expect(L10n.Budgets.state(isActive: false) != BudgetStatus.inactive.localizedName)
        #expect(L10n.Budgets.state(isActive: true) != L10n.Budgets.state(isActive: false))
    }

    @Test("La línea del límite de las gráficas lleva el importe en el texto de VoiceOver")
    func chartLimitAccessibilityCarriesTheAmount() {
        let label = L10n.Budgets.chartLimitAccessibility("S/ 600.00")
        #expect(label.contains("S/ 600.00"))
        #expect(!label.hasPrefix("budgets."))
    }
}

struct BudgetsWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("El detalle y el editor nombran el estado en singular")
    func detailAndEditorUseTheSingularState() throws {
        let detail = try Self.source("Yala/App/Views/Planning/BudgetDetailView.swift")
        #expect(detail.contains("L10n.Budgets.state(isActive: budget.isActive)"))
        #expect(!Self.codeOnly(detail).contains("BudgetStatus.active.localizedName"))
        let editor = try Self.source("Yala/App/Views/Planning/BudgetEditorView.swift")
        #expect(!Self.codeOnly(editor).contains("\"common.active\""))
        #expect(editor.contains("L10n.Budgets.state(isActive: true)"))
    }

    @Test("La estrella de Planificación se lee «Presupuestos favoritos»")
    func planningStarReadsBudgetFavorites() throws {
        let planning = try Self.source("Yala/App/Views/Planning/PlanningView.swift")
        #expect(planning.contains(".accessibilityLabel(L10n.Settings.budgetsFavorites)"))
        #expect(!Self.codeOnly(planning).contains("favoriteTemplates"))
    }

    @Test("Ajustes › Presupuestos formatea con la preferencia de divisa de la app")
    func favoritesSettingsUseAppCurrencyFormatting() throws {
        let settings = try Self.source("Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift")
        #expect(settings.contains("appPreferences.currency(amount, currencyCode: currency)"))
        #expect(!Self.codeOnly(settings).contains("NumberFormatter"))
    }

    @Test("Las gráficas no dejan texto de VoiceOver en inglés y se abren por valor desde el detalle")
    func chartsWiring() throws {
        let charts = try Self.source("Yala/App/Views/Planning/BudgetChartsView.swift")
        #expect(!Self.codeOnly(charts).contains("\"Budget limit"))
        let detail = try Self.source("Yala/App/Views/Planning/BudgetDetailView.swift")
        #expect(detail.contains("NavigationLink(value: BudgetChartsNavigationID("))
        #expect(detail.contains(".navigationDestination(for: BudgetChartsNavigationID.self) { navID in"))
        #expect(detail.contains("BudgetChartsDestination(budgetID: navID.id, viewModel: viewModel)"))
        #expect(!Self.codeOnly(detail).contains("navigationDestination(isPresented:"))
        // La columna de detalle de Planificación necesita su pila para que el detalle empuje.
        let planning = try Self.source("Yala/App/Views/Planning/PlanningView.swift")
        let detailColumn = try #require(planning.range(of: "} detail: {"))
        let afterDetail = planning[detailColumn.upperBound...]
        let stack = try #require(afterDetail.range(of: "NavigationStack {"))
        let placeholder = try #require(afterDetail.range(of: "planning_detail_placeholder"))
        #expect(stack.lowerBound < placeholder.lowerBound, "El vacío de la columna de detalle no va dentro de su pila.")
    }

    @Test("Las gráficas piden sus movimientos al abrir, al navegar y al cambiar el período de la lista, y los sueltan al cerrar")
    func chartsRequestAndReleaseTheirWindow() throws {
        let charts = try Self.source("Yala/App/Views/Planning/BudgetChartsView.swift")
        #expect(charts.contains("viewModel.ensureTransactionsLoaded(from: historyStart)"))
        #expect(charts.contains(".onChange(of: localDateInterval.start) { _, start in\n            viewModel.ensureTransactionsLoaded(from: start)"))
        #expect(charts.contains(".onChange(of: viewModel.historyStart(for: budget))"))
        #expect(charts.contains(".onDisappear { viewModel.releaseRequestedTransactions() }"))
        let vm = try Self.source("Yala/App/ViewModels/BudgetsViewModel.swift")
        #expect(vm.contains("let needsWiderWindow = requiredTransactionsStart() < transactionsLoadedFrom"))
        #expect(vm.contains("scheduleRecalculation(reload: needsWiderWindow,"))
    }

    @Test("El vacío de la lista usa el texto del tipo elegido cuando hay presupuestos de otro tipo")
    func listEmptyStateWiring() throws {
        let list = try Self.source("Yala/App/Views/Planning/BudgetsListView.swift")
        #expect(list.contains(
            "viewModel.allBudgets.isEmpty ? nil : L10n.Budgets.emptyTitle(for: viewModel.selectedPeriodType)"))
    }
}
