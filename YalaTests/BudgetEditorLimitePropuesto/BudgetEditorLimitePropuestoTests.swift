//
//  BudgetEditorLimitePropuestoTests.swift
//  YalaTests
//
//  «Ajusta el límite a lo real» abre el editor del presupuesto con el límite propuesto ya escrito (Jürgen, 21-nov-2026):
//  qué límite enseña el editor y que la hoja de Salud financiera se lo pase. Nada se guarda hasta tocar Guardar: el
//  límite solo llega al campo.
//

import Foundation
import Testing
@testable import Yala

@Suite("Editor de presupuesto · límite propuesto")
struct BudgetEditorLimitePropuestoTests {

    @Test("Con un límite propuesto, el editor lo enseña en lugar del guardado")
    func conPropuesta_ensenaLaPropuesta() {
        #expect(BudgetEditorInitialLimit.value(saved: 1_000, proposed: 1_200) == 1_200)
    }

    @Test("Sin propuesta, el editor enseña el límite guardado, como siempre")
    func sinPropuesta_ensenaElGuardado() {
        #expect(BudgetEditorInitialLimit.value(saved: 1_000, proposed: nil) == 1_000)
    }

    @Test("Una propuesta que no es un límite válido no pisa el guardado", arguments: [0.0, -50, .nan, .infinity])
    func propuestaInvalida_ensenaElGuardado(_ propuesta: Double) {
        #expect(BudgetEditorInitialLimit.value(saved: 1_000, proposed: propuesta) == 1_000)
    }
}

@Suite("Editor de presupuesto · límite propuesto · cableado")
struct BudgetEditorLimitePropuestoCableadoTests {

    private static let editor = "Yala/App/Views/Planning/BudgetEditorView.swift"
    private static let hoja = "Yala/App/Views/Panel/Sheets/SaludFinanciera/SaludFinancieraDetalleView.swift"

    @Test("El editor escribe en el campo el límite que decide `BudgetEditorInitialLimit` al cargar un presupuesto existente")
    func editor_cargaElLimitePropuesto() throws {
        let fuente = try Self.fuente(Self.editor)
        #expect(fuente.contains("var proposedLimit: Double? = nil"))
        #expect(fuente.contains(
            "limitAmount = AmountInputHelper.formatWithGrouping(BudgetEditorInitialLimit.value(saved: budget.limitAmount, proposed: proposedLimit))"
        ), "loadBudgetData ya no escribe el límite propuesto en el campo.")
    }

    @Test("La hoja abre el editor con el límite de la propuesta, y el límite viaja en el `item` de la hoja")
    func hoja_pasaElLimitePropuesto() throws {
        let fuente = try Self.fuente(Self.hoja)
        #expect(fuente.contains("abrirEditor(peor.id, limite: propuesta.limite)"),
                "«Ajusta el límite a lo real» ya no pasa el límite propuesto.")
        #expect(fuente.contains("@State private var presupuestoAEditar: AjusteDeLimite?"))
        #expect(fuente.contains("BudgetEditorView(budget: ajuste.budget, proposedLimit: ajuste.limite)"),
                "La hoja abre el editor sin el límite propuesto.")
        #expect(fuente.contains("AjusteDeLimite(budget: $0, limite: limite)"))
    }

    /// El fichero sin comentarios, con los espacios colapsados: una llamada puede ir en varias líneas.
    static func fuente(_ ruta: String, file: StaticString = #filePath) throws -> String {
        let raiz = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let texto = try String(contentsOf: raiz.appending(path: ruta), encoding: .utf8)
            .split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: " ")
        return texto.replacing(/\s+/, with: " ").replacing("( ", with: "(").replacing(" )", with: ")")
    }
}
