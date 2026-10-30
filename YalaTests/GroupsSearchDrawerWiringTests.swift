//
//  GroupsSearchDrawerWiringTests.swift
//  YalaTests
//
//  Parpadeo del hero de Grupos (Jürgen, 2026-10-30, vídeo al entrar desde el Panel): con el buscador en el cajón de la
//  barra en modo `.automatic`, al volver a la pestaña la barra reservaba el alto del cajón vacío ~0,5 s y después lo
//  plegaba, y el resumen, los botones y la lista saltaban hacia arriba de golpe. Medido en el simulador (iOS 27.0) con
//  `simctl io recordVideo`; con `.always` el hero queda en su sitio desde el primer fotograma (vídeos del PR).
//
//  Source-scan: la lista de Grupos lleva el cajón fijo, y ninguna vista vuelve al `.automatic`: las páginas de pestaña
//  siguen montadas al cambiar de pestaña, que es donde salta.
//

import Foundation
import Testing

@Suite("Buscador de Grupos sin cajón que se pliega — cableado (source-scan)")
struct GroupsSearchDrawerWiringTests {

    private static let repoRoot: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent()

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func codeLines(_ url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
    }

    @Test func groupsList_keepsTheSearchDrawerAlwaysVisible() throws {
        let code = try Self.codeLines(Self.repoRoot.appending(path: "Yala/App/Views/Groups/GroupsContainerView.swift"))
        let searchable = try #require(code.firstIndex { $0.hasPrefix(".searchable(") },
                                      "La lista de Grupos ya no tiene buscador: revisa este test.")
        let placement = code[searchable..<min(searchable + 4, code.count)]
            .first { $0.contains("placement:") }
        #expect(placement == "placement: .navigationBarDrawer(displayMode: .always),",
                "El buscador de Grupos tiene que ir fijo: con otro modo el hero salta al volver a la pestaña.")
    }

    @Test func noView_usesTheAutomaticDrawer() throws {
        let views = Self.repoRoot.appending(path: "Yala/App/Views")
        let files = try #require(FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        #expect(files.count > 100, "El recorrido no encontró las vistas: el scan no estaría mirando nada.")
        let offenders = try files.filter { url in
            try Self.codeLines(url).contains { $0.contains(".navigationBarDrawer(displayMode: .automatic)") }
        }
        #expect(offenders.isEmpty, "Cajón de búsqueda que se pliega en: \(offenders.map(\.lastPathComponent))")
    }
}
