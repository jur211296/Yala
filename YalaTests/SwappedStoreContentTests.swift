//
//  SwappedStoreContentTests.swift
//  YalaTests
//
//  Card 7e60 (QA en el iPhone 14, 2026-11-05): cerrar sesión en la nube cerraba Yala. El cierre cambia el almacén en
//  caliente y la hoja de Ajustes, todavía montada, volvía a aparecer y leía el almacén soltado. El simulador monta con
//  espejo y se salta el cambio en caliente, así que el cableado solo lo fija leer el fuente; la decisión, la tabla.
//

import Foundation
import Testing

@testable import Yala

@Suite("Contenido de una hoja tras cambiar el almacén en caliente")
struct SwappedStoreContentTests {

    // MARK: - La decisión

    @Test("Con el mismo almacén montado, el contenido sigue")
    func sameGeneration_withContainer_isNotStale() {
        #expect(!SwappedStoreContentLogic.isStale(mountedGeneration: 0, currentGeneration: 0, hostHasContainer: true))
        #expect(!SwappedStoreContentLogic.isStale(mountedGeneration: 3, currentGeneration: 3, hostHasContainer: true))
    }

    @Test("En la ventana del cambio (host sin almacén), el contenido se suelta")
    func noContainer_isStale() {
        #expect(SwappedStoreContentLogic.isStale(mountedGeneration: 0, currentGeneration: 0, hostHasContainer: false))
    }

    @Test("Con otro almacén montado (cambio consumado o repuesto), el contenido se suelta")
    func otherGeneration_isStale() {
        #expect(SwappedStoreContentLogic.isStale(mountedGeneration: 0, currentGeneration: 1, hostHasContainer: true))
        #expect(SwappedStoreContentLogic.isStale(mountedGeneration: 2, currentGeneration: 1, hostHasContainer: true))
    }

    // MARK: - El cableado (source-scan)

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Solo código: quita los comentarios de línea, para que nombrar el modificador en prosa no cuente.
    private static func code(_ src: String) -> String {
        src.components(separatedBy: "\n")
            .map { line in
                guard let range = line.range(of: "//") else { return line }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    @Test("Ajustes suelta su contenido tras el cambio, fuera de lo que lee el almacén y dentro del tamaño de la hoja")
    func profileSheet_detachesBeforePresentationSizing() throws {
        let src = Self.code(try Self.source("Yala/App/Views/Profile/ProfileView.swift"))
        let detach = try #require(src.range(of: ".detachesFromSwappedStore()"))
        let sizing = try #require(src.range(of: ".presentationSizing(.page)"))
        #expect(detach.upperBound <= sizing.lowerBound)
        // Pegados: nada entre los dos que pudiera volver a leer el almacén por fuera del corte.
        let between = src[detach.upperBound..<sizing.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(between.isEmpty)
        // Y el `setContext` que tumbaba la app queda dentro (antes) del corte.
        let setContext = try #require(src.range(of: "viewModel.setContext(modelContext)"))
        #expect(setContext.upperBound <= detach.lowerBound)
    }

    @Test("El modificador decide con la generación del ENTORNO y el almacén del host, y deja de pintar el contenido")
    func modifier_readsTheHostAndDropsTheContent() throws {
        let src = Self.code(try Self.source("Yala/App/Views/Shared/DetachesFromSwappedStoreModifier.swift"))
        // La generación montada viene del entorno (un `@State` rehecho tras el cambio guardaría la nueva).
        #expect(src.contains("@Environment(\\.mountedStoreGeneration) private var mountedGeneration"))
        #expect(!src.contains("@State"))
        #expect(src.contains("currentGeneration: host.generation"))
        #expect(src.contains("hostHasContainer: host.container != nil"))
        #expect(src.contains("SwappedStoreContentLogic.isStale("))
        // La rama suelta pinta un vacío, y `content` solo sale en la otra.
        let stale = try #require(src.range(of: "hostHasContainer: host.container != nil) {"))
        let clear = try #require(src.range(of: "Color.clear"))
        let orElse = try #require(src.range(of: "} else {"))
        #expect(stale.upperBound <= clear.lowerBound && clear.upperBound <= orElse.lowerBound)
        #expect(src[orElse.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("content"))
    }

    @Test("La raíz de la ventana publica la generación con la que montó, junto al almacén")
    func windowRoot_publishesTheMountedGeneration() throws {
        let src = Self.code(try Self.source("Yala/App/YalaApp.swift"))
        let lines = src.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let model = try #require(lines.firstIndex(of: ".modelContainer(container)"))
        #expect(lines[model - 1] == ".id(containerHost.generation)")
        #expect(lines[model + 1] == ".environment(\\.mountedStoreGeneration, containerHost.generation)")
    }
}
