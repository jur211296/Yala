//
//  RenderScrollCableadoTests.swift
//  YalaTests
//
//  Lote 5 de eficiencia (26-nov-2026): el scroll del Panel y de Registros pide menos pasadas fuera de pantalla. Medido en
//  el iPhone 14 con 16 k movimientos (pasada D, Hitches). Tres piezas lo sostienen, y las tres son cableado que ningún
//  cálculo ve:
//
//  1. La fila de lista (`ListRowCardModifier`) dibuja su fondo y su sombra con la forma, sin recortar el contenido ni
//     ponerle una sombra de vista (esa se calculaba fuera de pantalla una vez por fila y por fotograma).
//  2. Las píldoras de acción rápida del Panel llevan la sombra en el relleno de la cápsula, no en el botón.
//  3. Los dos botones flotantes de cristal van en un solo `GlassEffectContainer`. Fue la pieza que más pesó.
//

import Foundation
import Testing

@testable import Yala

@Suite("Render del scroll · cableado (source-scan)")
struct RenderScrollCableadoTests {

    private static func repoFile(_ path: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// Sin comentarios y con los espacios colapsados.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// El cuerpo entre la primera llave después de `start` y su pareja.
    private static func block(from start: String.Index, in code: String) -> String {
        guard let open = code[start...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" { depth -= 1; if depth == 0 { return String(code[open...index]) } }
            index = code.index(after: index)
        }
        return ""
    }

    private static func body(of declaration: String, in path: String) throws -> String {
        let code = codeOnly(try repoFile(path))
        let start = try #require(code.range(of: declaration), "no está «\(declaration)» en \(path)")
        return block(from: start.upperBound, in: code)
    }

    // MARK: - 1. Fila de lista

    @Test func filaDeLista_noRecortaNiPoneSombraDeVista() throws {
        let modifier = try Self.body(of: "struct ListRowCardModifier: ViewModifier", in: "Yala/App/Theme/ViewModifiers.swift")
        let start = try #require(modifier.range(of: "func body(content: Content) -> some View"))
        let body = Self.block(from: start.upperBound, in: modifier)
        #expect(!body.isEmpty)
        #expect(!body.contains(".clipShape("), "recortar la fila vuelve a pedir una pasada fuera de pantalla por fila")
        #expect(!body.contains(".shadow(color:"), "la sombra de vista se calcula fuera de pantalla en cada fotograma")
    }

    @Test func filaDeLista_dibujaFondoYSombraConLaForma() throws {
        let modifier = try Self.body(of: "struct ListRowCardModifier: ViewModifier", in: "Yala/App/Theme/ViewModifiers.swift")
        // La misma forma, el color de la tarjeta (sin el contorno de `.thCard`, que el recorte ya se comía) y la sombra de
        // siempre (`DS.ListRow`), ahora como estilo del relleno.
        #expect(modifier.contains(".background { RoundedRectangle(cornerRadius: radius, style: .continuous) .fill(theme.card.shadow(.drop("))
        #expect(modifier.contains("color: .black.opacity(theme.shadowOpacity)"))
        #expect(modifier.contains("radius: DS.ListRow.shadowRadius"))
        #expect(modifier.contains("y: DS.ListRow.shadowY"))
        #expect(modifier.contains(".padding(.vertical, DS.ListRow.paddingV)"))
        #expect(modifier.contains(".padding(.horizontal, DS.ListRow.paddingH)"))
    }

    // MARK: - 2. Píldoras de acción rápida

    @Test func pildoras_sombraEnElRelleno_noEnElBoton() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Panel/Components/PanelQuickActionsRow.swift"))
        #expect(code.contains("Capsule().fill(theme.accent.shadow(Self.pillShadow))"), "la principal")
        #expect(code.contains("Capsule() .fill(theme.card.shadow(Self.pillShadow))"), "las secundarias")
        #expect(!code.contains(".buttonStyle(.plain) .shadow("), "la sombra de vista sobre el botón vuelve")
    }

    @Test func pildoras_conservanLaSombraPequenaDelDS() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Panel/Components/PanelQuickActionsRow.swift"))
        #expect(code.contains(
            "private static let pillShadow: ShadowStyle = .drop( color: DS.Shadow.small.color, radius: DS.Shadow.small.radius, "
                + "x: DS.Shadow.small.x, y: DS.Shadow.small.y )"
        ))
    }

    // MARK: - 3. Botones flotantes

    @Test func botonesFlotantes_vanEnUnSoloContenedorDeCristal() throws {
        let body = try Self.body(of: "var body: some View", in: "Yala/App/Views/Shared/FABStackView.swift")
        let container = try #require(body.range(of: "GlassEffectContainer(spacing: DS.Spacing.xs)"))
        let inside = Self.block(from: container.upperBound, in: body)
        #expect(inside.contains("fabButtons(fabBackground)"), "los dos círculos tienen que ir dentro del contenedor")
        #expect(!body.replacingOccurrences(of: inside, with: "").contains("fabButtons("), "y solo dentro")
    }

    @Test func botonesFlotantes_losDosCirculosSalenDeLaMismaPieza() throws {
        let buttons = try Self.body(of: "private func fabButtons(_ fabBackground: Color) -> some View",
                                    in: "Yala/App/Views/Shared/FABStackView.swift")
        #expect(buttons.contains("aiFAB.transition(Self.fabScaleTransition)"))
        #expect(buttons.contains("transactionFAB(background: fabBackground)"))
        #expect(buttons.contains("fabLayout {"))
    }

    @MainActor @Test func botonesFlotantes_elEspaciadoDelContenedorNoLosFunde() {
        // El contenedor funde dos cristales que quedan a menos de su espaciado. Entre los dos botones hay `md`; el del
        // contenedor tiene que quedar por debajo o se verían como una sola gota.
        #expect(DS.Spacing.xs < DS.Spacing.md)
    }
}
