//
//  PanelNecesariasAccesibilidadWiringTests.swift
//  YalaTests
//
//  Mejoras necesarias 2.3 · Panel (revisión por vistas, PN-7 y PN-8): lo que los XCUITest no alcanzan.
//
//  - PN-7: los XCUITest miran la ayuda de la gráfica de saldo. Las otras ayudas con monto (flujo, categoría, etiqueta,
//    pagos) salen de la MISMA función, y la conversión de «Tu saldo hoy» no se abre con toques sintéticos. Aquí se fija
//    que todos los montos de esas frases pasan por la máscara: con uno solo que se salte, el ojo vuelve a fugar.
//  - PN-8: que los dos ↻ de configuración solo PREGUNTAN, y que restablecer va dentro de la alerta. Si el botón vuelve a
//    llamar al reset directo, el XCUITest de «Configurar Panel» lo caza; el de la hoja ▦ de cada sección, solo esto.
//
//  Source-scan a conciencia (molde de `ApproximateMarkWiringTests`): fija el cableado, no el render.
//

import Foundation
import Testing

@Suite("Mejoras necesarias 2.3 · Panel — máscara y Restablecer (source-scan)")
struct PanelNecesariasAccesibilidadWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin las líneas que son comentario entero: los comentarios nombran a propósito lo que estos tests cuentan.
    private static func code(_ path: String) throws -> String {
        try source(path).split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - PN-7

    @Test("Cada monto de «Con tus datos» pasa por la máscara, en pantalla y en VoiceOver")
    func widgetInfoYourData_everyAmountGoesThroughTheMask() throws {
        let src = try Self.code("Yala/App/Views/Panel/InfoSheets/WidgetInfoSheet.swift")

        // La única salida de un monto de la frase es `money`, y `money` pasa por `showing`.
        #expect(src.contains("showing(appPreferences.currency(value, currencyCode: currency, isEstimate: isEstimate))"))
        #expect(src.components(separatedBy: "appPreferences.currency(").count - 1 == 1,
                "Un monto formateado fuera de `money` saldría sin máscara en la ayuda.")
        // Lo que se ve y lo que se oye, cada uno con su máscara.
        #expect(src.contains("personalLine(showing: { AmountPrivacy.text($0, hidden: masksAmounts) })"))
        #expect(src.contains("personalLine(showing: { AmountPrivacy.spoken($0, hidden: masksAmounts) })"))
        #expect(src.contains(".accessibilityLabel(spoken)"))
        // El ojo se lee de la preferencia: abierta desde el ▦ de la sección, la hoja no hereda el entorno del Panel.
        #expect(src.contains("private var masksAmounts: Bool { isInPanel && appPreferences.panelAmountsHidden }"))
        #expect(src.contains(".environment(\\.amountsHidden, masksAmounts)"),
                "La vista previa de la ayuda tiene que llevar la misma máscara que su frase.")
    }

    @Test("«Tu saldo hoy» enmascara también la conversión de cada moneda")
    func liveAnchorSheet_convertedRowIsMasked() throws {
        let src = try Self.code("Yala/App/Views/Panel/Sheets/BalanceLiveAnchorEducationSheet.swift")

        #expect(src.contains("@Environment(\\.amountsHidden) private var amountsHidden"))
        #expect(src.contains("AmountPrivacy.text(convertedFormatted, hidden: amountsHidden)"))
        #expect(src.contains("AmountPrivacy.spoken(convertedFormatted, hidden: amountsHidden)"))
        #expect(!src.contains("breakdownRowConvertedFormat(convertedFormatted)"),
                "La conversión vuelve a pintarse con la cifra sin pasar por la máscara.")
    }

    // MARK: - PN-8

    @Test("Los dos ↻ de configuración preguntan; restablecer va dentro de la alerta")
    func configResets_askBeforeResetting() throws {
        let cases: [(path: String, reset: String)] = [
            ("Yala/App/Views/Panel/PanelSectionsConfigView.swift", "appPreferences.resetPanelSectionsOrder()"),
            ("Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift", "viewModel.resetSectionPreferences(kind)"),
        ]
        for item in cases {
            let src = try Self.code(item.path)
            #expect(src.components(separatedBy: item.reset).count - 1 == 1,
                    "\(item.path): restablecer tiene que tener una sola llamada, la de la alerta.")
            guard let alert = src.range(of: ".alert("),
                  let call = src.range(of: item.reset) else {
                Issue.record("\(item.path): falta la alerta o la llamada de restablecer.")
                continue
            }
            #expect(alert.lowerBound < call.lowerBound, "\(item.path): restablecer se llama fuera de la alerta.")
            #expect(src.contains("confirmingReset = true"), "\(item.path): ↻ ya no pide confirmación.")
            #expect(src.contains("Button(L10n.Action.cancel, role: .cancel) {}"), "\(item.path): la alerta no ofrece Cancelar.")
            #expect(src.contains("accessibilityName: L10n.Action.done"),
                    "\(item.path): el ✓ solo cierra y tiene que decir «Listo», no «Guardar».")
        }
    }
}
