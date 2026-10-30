//
//  LoadTimesFixesTests.swift
//  YalaTests
//
//  Los arreglos de carga del encargo `eficiencia-carga-por-vista` (2026-10-30). Cada uno quitaba trabajo repetido del
//  hilo principal sin cambiar lo que se ve; estos tests impiden que vuelva:
//  1. el rango de fechas de Registros/Estadísticas sale de una pasada min/max y da lo mismo que ordenar;
//  2. `LanguageManager.sharedDefaults` es una sola instancia (antes, una nueva en cada texto traducido);
//  3. el Panel no reconcilia el orden de cuentas antes de su primera carga (guardaba un orden VACÍO en una preferencia
//     sincronizada en cada arranque en frío), y lo reconcilia al quedar listo;
//  4. ni el Panel ni Registros ni Estadísticas piden un segundo cálculo por observar los arrays que su propia recarga
//     acaba de escribir (source-scan: son vistas y no se montan aquí).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Carga por vista · los arreglos del 2026-10-30", .serialized)
struct LoadTimesFixesTests {

    // MARK: - 1 · Rango de fechas

    @Test("El rango de fechas es el mínimo y el máximo aunque el array no venga ordenado")
    func transactionDateRange_isMinAndMax_inAnyOrder() throws {
        let context = try makeTestContext()
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let middle = Date(timeIntervalSince1970: 1_710_000_000)
        let late = Date(timeIntervalSince1970: 1_720_000_000)
        // Insertadas desordenadas: el fetch del ViewModel ordena por fecha, pero la función no debe depender de eso.
        for date in [middle, late, early] {
            context.insert(TransactionItem(date: date, amount: -10, currencyCode: "PEN"))
        }
        try context.save()

        let viewModel = DetailContainerViewModel()
        viewModel.setContext(context)
        let range = viewModel.computeTransactionDateRange()

        #expect(viewModel.allTransactions.count == 3)
        #expect(range.start == early)
        #expect(range.end == late)
    }

    // MARK: - 2 · Una sola instancia del almacén del idioma

    @Test("`LanguageManager.sharedDefaults` devuelve siempre la misma instancia")
    func sharedDefaults_isOneInstance() {
        #expect(LanguageManager.sharedDefaults === LanguageManager.sharedDefaults)
    }

    // MARK: - 3 y 4 · Cableado de las vistas (source-scan)

    @Test("El Panel no reconcilia el orden de cuentas antes de su primera carga, y lo hace al quedar listo")
    func panel_reconcilesAccountsOrderOnlyWhenReady() throws {
        let source = try Self.source("Yala/App/Views/Panel/PanelView.swift")
        let start = try #require(source.range(of: "private func reconcileAccountsSortOrder() {"))
        let body = Self.normalized(source[start.lowerBound...])
        #expect(body.hasPrefix(
            "private func reconcileAccountsSortOrder() { guard viewModel.isReady else { return } "
                + "let currentOrder = appPreferences.accountsSortOrderNames"))
        let code = Self.normalized(source[...])
        #expect(code.contains(
            ".onChange(of: [viewModel.isReady ? 1 : 0, viewModel.accounts.count]) { _, _ in reconcileAccountsSortOrder() }"))
    }

    @Test("Los observadores del Panel no recalculan por los conteos que escribe su propia recarga")
    func panelCountObservers_doNotWatchLoadedArrays() throws {
        let source = try Self.source("Yala/App/Views/Panel/PanelDataObservers.swift")
        let start = try #require(source.range(of: "struct PanelDataCountObservers"))
        let end = try #require(source.range(of: "struct PanelDataFilterObservers"))
        let body = Self.normalized(source[start.lowerBound..<end.lowerBound])
        for array in ["accounts", "transactions", "budgets", "allSubcategories"] {
            #expect(!body.contains("viewModel.\(array).count"), "volvió el observador de \(array).count")
        }
        // Control: el escaneo lee el modificador de verdad.
        #expect(body.contains(".onChange(of: sessionState.formattingVersion)"))
    }

    @Test("Registros y Estadísticas no recalculan por observar `allTransactions`",
          arguments: ["Yala/App/Views/Records/RecordsStandaloneView.swift",
                      "Yala/App/Views/Statistics/DetailContainerView.swift"])
    func recordsAndStatistics_doNotWatchAllTransactions(path: String) throws {
        let code = Self.normalized(try Self.source(path)[...])
        #expect(!code.contains(".onChange(of: dataViewModel.allTransactions)"))
        // Control: la recarga por `dataVersion` sigue ahí.
        #expect(code.contains(".onChange(of: sessionState.dataVersion)"))
    }

    // MARK: - Ayudas

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios, líneas recortadas y unidas por espacio.
    private static func normalized(_ text: Substring) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }
}
