//
//  PasteButtonTapWiringTests.swift
//  YalaTests
//
//  Que el «Pegar» del sistema (`PasteButton`) reciba su toque.
//
//  Medido el 2026-11-05 en el iPhone de pruebas (iOS 27.2), QA de Grupos (L12-16): en «Pega tu enlace
//  de invitación» el botón no hacía nada con el dedo. `.dismissKeyboardOnTap()` (un `.onTapGesture`
//  con `contentShape`) colgaba del `ScrollView`, padre del botón, y se quedaba con el toque. Sin el
//  gesto, pegaba; con el gesto en una capa de FONDO (hermana del contenido), pega y tocar fuera sigue
//  ocultando el teclado. El simulador no lo reproduce: allí el `PasteButton` ignora todo toque
//  sintético, así que esto solo lo fija leer el fuente.
//

import Foundation
import Testing

@testable import Yala

@Suite("Cableado del «Pegar» del sistema (source-scan)")
struct PasteButtonTapWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func swiftFiles(under path: String) throws -> [URL] {
        let base = root.appendingPathComponent(path)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test("Una pantalla con PasteButton solo oculta el teclado desde una capa de fondo")
    func pasteButtonScreensDismissKeyboardFromABackgroundLayer() throws {
        var screens = 0
        for file in try Self.swiftFiles(under: "Yala/App") {
            // Solo código: un comentario que nombre el modificador no cuenta.
            let src = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            guard src.contains("PasteButton(") else { continue }
            screens += 1
            let all = src.components(separatedBy: ".dismissKeyboardOnTap()").count - 1
            let inBackground = src.components(separatedBy: "Color.clear.dismissKeyboardOnTap()").count - 1
            #expect(all == inBackground, """
                \(file.lastPathComponent) tiene un PasteButton y \(all - inBackground) \
                `.dismissKeyboardOnTap()` fuera de una capa de fondo. Colgado de un padre del botón, \
                el gesto se queda con su toque y «Pegar» no hace nada en el iPhone. Ponlo en \
                `.background { Color.clear.dismissKeyboardOnTap() }` del contenido.
                """)
        }
        #expect(screens > 0, "Ya no hay ningún PasteButton en Yala/App: revisa si este test sigue haciendo falta.")
    }
}
