//
//  LargeTextSecondaryScreensWiringTests.swift
//  YalaTests
//
//  Mejoras necesarias 2.3, lote 05 (texto grande en pantallas secundarias): lo que los XCUITest no alcanzan.
//
//  `LargeTextSecondaryScreensUITests` mide en el árbol de accesibilidad Distribución, el mes del flujo de caja, la barra
//  de selección de la Bandeja, Ajustes y las listas de Etiquetas y Cuentas. Cuatro piezas no se pueden medir así: la
//  fila de la tabla de la Comparativa y «Te quedó» leen a VoiceOver una frase propia (sus textos no están en el árbol),
//  y «¿Ya lo apuntaste?» y la tarjeta de borrador del chat no tienen semilla de XCUITest. Aquí se fija que las cuatro
//  eligen su forma apilada por el tamaño de texto, y que el alto de las dos listas ya no es una cuenta a mano.
//
//  Source-scan a conciencia (molde de `PanelNecesariasAccesibilidadWiringTests`): fija el cableado, no el render. El
//  render, en las capturas antes y después del PR.
//

import Foundation
import Testing

@Suite("Mejoras necesarias 2.3 · texto grande en pantallas secundarias (source-scan)")
struct LargeTextSecondaryScreensWiringTests {

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Las cuatro piezas sin medida en XCUITest eligen su forma apilada por el tamaño de texto",
          arguments: [
              "Yala/App/Views/Reports/PivotRowView.swift",
              "Yala/App/Views/Reports/NetFlowSummaryView.swift",
              "Yala/App/Views/Inbox/GroupDraftLinkCandidatesView.swift",
              "Yala/App/Views/Chat/ChatTransactionDraftCard.swift",
          ])
    func stacksAtAccessibilitySizes(path: String) throws {
        let src = try Self.code(path)
        #expect(src.contains("@Environment(\\.dynamicTypeSize) private var dynamicTypeSize"), "\(path) no lee el tamaño de texto.")
        #expect(src.contains("if dynamicTypeSize.isAccessibilitySize {"), "\(path) ya no tiene forma apilada.")
    }

    @Test("La fila de la Comparativa apilada no reserva la columna de la cifra ni le da prioridad sobre el nombre")
    func pivotRow_stackedHasNoAmountColumn() throws {
        let src = try Self.code("Yala/App/Views/Reports/PivotRowView.swift")
        guard let stacked = src.range(of: "if dynamicTypeSize.isAccessibilitySize {"),
              let flat = src.range(of: "} else {", range: stacked.upperBound..<src.endIndex) else {
            Issue.record("No se encuentran las dos formas de la fila.")
            return
        }
        let stackedBranch = src[stacked.upperBound..<flat.lowerBound]
        #expect(!stackedBranch.contains(".layoutPriority(1)"),
                "Apilada, la prioridad de la cifra vuelve a dejar al nombre sin sitio.")
        #expect(!stackedBranch.contains("minWidth: widths.current"))
        #expect(stackedBranch.contains("variationChip(minWidth: nil)"))
    }

    @Test("Etiquetas y Cuentas no fijan el alto de su lista con una cuenta a mano")
    func reorderableLists_measureTheirContent() throws {
        let tags = try Self.code("Yala/App/Views/Settings/TagsSettingsListView.swift")
        #expect(tags.components(separatedBy: ".contentSizedListHeight(estimated:").count - 1 == 2,
                "Las dos listas de Etiquetas (activas e inactivas) miden su contenido.")
        #expect(!tags.contains(".frame(height: CGFloat(viewModel."))

        let accounts = try Self.code("Yala/App/Views/Settings/AccountsSettingsListView.swift")
        #expect(accounts.contains(".contentSizedListHeight(estimated: cards.reduce(0)"))
        #expect(!accounts.contains(".frame(height: cards.reduce(0)"))

        let modifier = try Self.code("Yala/App/DesignSystem/ContentSizedListHeight.swift")
        #expect(modifier.contains(
            ".frame(height: dynamicTypeSize.isAccessibilitySize ? max(estimated, contentHeight) : estimated)"),
                "A tamaño normal el alto tiene que seguir siendo el de siempre, y con texto grande el medido.")
    }
}
