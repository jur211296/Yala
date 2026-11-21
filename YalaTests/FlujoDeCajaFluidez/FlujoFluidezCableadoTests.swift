//
//  FlujoFluidezCableadoTests.swift
//  YalaTests
//
//  El cableado de la fluidez de Reportes (encargo del 20-nov-2026), leído del código: el Flujo de caja pasa su firma
//  al recalcular y la Comparativa no calcula si no se ve. Sin esto, un cambio que vuelva a llamar al cálculo a secas
//  devolvería la lentitud sin ningún rojo en los tests de la lógica.
//

import Foundation
import Testing

@Suite
struct FlujoFluidezCableadoTests {

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios, con los espacios colapsados.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? "" : trimmed
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @Test func elFlujoDeCaja_pasaSuFirmaAlRecalcular() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Reports/CashFlow/CashFlowTableView.swift"))
        #expect(code.contains("let firma = FlujoRecalculoFirma("))
        #expect(code.contains("firma: firma"))
        #expect(code.contains("storeSaves: StoreSaveCounter.shared.count"))
        #expect(code.contains("planRevision: viewModel.planRevision"))
        // Un solo sitio llama al cálculo: todos los disparadores pasan por la misma función con firma.
        #expect(code.components(separatedBy: "viewModel.recalculate(").count == 2)
    }

    /// Jürgen, 20-nov-2026: en la Comparativa la marca de cambio de cada fila, la de «Te quedó», la columna «Cambio» y
    /// los chips de con qué comparar salen siempre, con o sin «Mostrar variaciones». Con el ajuste apagado no veía
    /// ninguna marca y pidió «un chip de variación con color».
    @Test func laComparativa_noDependeDeMostrarVariaciones() throws {
        for path in [
            "Yala/App/Views/Reports/PivotRowView.swift",
            "Yala/App/Views/Reports/NetFlowSummaryView.swift",
            "Yala/App/Views/Reports/FinancialReportView.swift",
        ] {
            let code = Self.codeOnly(try Self.repoFile(path))
            #expect(!code.contains("showVariations"), "\(path) vuelve a leer «Mostrar variaciones».")
        }
        let row = Self.codeOnly(try Self.repoFile("Yala/App/Views/Reports/PivotRowView.swift"))
        #expect(row.contains("if showsComparison { ComparisonChangeBadge(change: change)"))
        let net = Self.codeOnly(try Self.repoFile("Yala/App/Views/Reports/NetFlowSummaryView.swift"))
        #expect(net.contains("if showsComparison { ComparisonChangeBadge("))
    }

    @Test func laComparativa_soloCalculaSiSeVe_yCalculaAlAparecer() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Reports/FinancialReportView.swift"))
        #expect(code.contains("comparativaPendiente = true guard effectiveReportTab == .comparativa, isRootPageShown else { return }"))
        #expect(code.contains(".onAppear { recalculateComparativaIfNeeded() }"))
        #expect(code.contains("if shown { recalculateComparativaIfNeeded() }"))
        // El `onAppear` de la pantalla entera ya no calcula la Comparativa (corría también con el Flujo de caja delante).
        #expect(code.contains(".onAppear { cashFlowViewModel.setContext(modelContext) }"))
        // El rebote: el scroll de cada pestaña es la raíz de la pila, sin `VStack` ni guía por encima.
        #expect(code.contains("NavigationStack { tabContent .yalaScreenBackground()"))
        #expect(code.contains("ContextualGuideBanner.comparative() .padding(.horizontal, DS.Spacing.lg) filterBar"))
    }
}
