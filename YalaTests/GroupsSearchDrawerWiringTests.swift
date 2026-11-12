//
//  GroupsSearchDrawerWiringTests.swift
//  YalaTests
//
//  Parpadeo del hero de Grupos (Jürgen, 2026-10-30, vídeo al entrar desde el Panel): con el buscador en el cajón de la
//  barra en modo `.automatic`, al volver a la pestaña la barra reservaba el alto del cajón vacío ~0,5 s y después lo
//  plegaba, y el resumen, los botones y la lista saltaban hacia arriba de golpe. Medido en el simulador (iOS 27.0) con
//  `simctl io recordVideo`; con `.always` el hero queda en su sitio desde el primer fotograma (vídeos del PR).
//
//  Source-scan: la lista de Grupos no lleva buscador (Jürgen, 2026-10-30: ya está la pestaña Buscar), y ninguna vista
//  vuelve al `.automatic`: las páginas de pestaña siguen montadas al cambiar de pestaña, que es donde salta.
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

    /// Desde el 2026-10-30 (Jürgen) la lista no tiene buscador: la búsqueda vive en la pestaña Buscar. Sin cajón en la
    /// barra no hay alto que reservar y plegar, que era el salto del resumen.
    @Test func groupsList_hasNoSearchDrawer() throws {
        let code = try Self.codeLines(Self.repoRoot.appending(path: "Yala/App/Views/Groups/GroupsContainerView.swift"))
        #expect(code.count > 200, "No se leyó la lista de Grupos: el scan no estaría mirando nada.")
        #expect(!code.contains { $0.contains(".searchable(") },
                "La lista de Grupos vuelve a tener buscador: si es a propósito, va fijo (`.always`) o el resumen salta.")
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
