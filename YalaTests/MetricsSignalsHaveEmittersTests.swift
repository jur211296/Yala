//
//  MetricsSignalsHaveEmittersTests.swift
//  YalaTests
//
//  Lote 12.7 · card `tablero-hay-11-canarios-y-8-rastros-que-nadie-em-yf9t` (ticket `canarios-y-breadcrumbs-sin-emisor`).
//  Un canario sin emisor es un contador en cero para siempre, y el riesgo no es él: es el criterio de aceptación o la
//  línea del índice de cobertura que lo cita como red. El 2026-09-02 había 11 canarios y 8 rastros así; se retiraron
//  el 2026-10-25. Este scan impide que vuelva a pasar en silencio: un `case` de `MetricsCanary` o una función de
//  `GroupsSyncBreadcrumb` sin llamador real fuera de su fichero lo pone rojo.
//
//  «Llamador real» = una línea de código (no comentario) en `Yala/`, `YalaWidgets/` o `YalaShare/` que no sea el propio
//  fichero de la declaración. El propio fichero no cuenta: un envoltorio tipado que nadie llama (`inviteReEmittedFromStore`)
//  daba tres ocurrencias y parecía vivo.
//

import Foundation
import Testing

@Suite("Métricas · todo canario y rastro tiene emisor")
struct MetricsSignalsHaveEmittersTests {

    /// Los cuatro rastros del cambio de identidad de iCloud (C-3) se conservan sin emisor A PROPÓSITO: llevan en el
    /// propio código el aviso de que nadie los emite desde la Fase 3, que es lo que el ticket pedía.
    private static let documentedDeadBreadcrumbs: Set<String> = [
        "groupsIdentityChangeRetained",
        "groupsIdentityChangePurgeFailed",
        "groupsIdentityPurgeDeferred",
        "groupsIdentityPurgeResumed",
    ]

    @Test func everyMetricsCanaryHasAnEmitter() throws {
        let decl = "Yala/Services/Metrics/MetricsService.swift"
        let source = try Self.read(decl)
        let start = try #require(source.range(of: "enum MetricsCanary: String {"))
        let body = source[start.upperBound...]
        let end = try #require(body.range(of: "\n}"))
        let cases = body[..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
            .flatMap { $0.dropFirst(5).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            .map { String($0.prefix { $0.isLetter || $0.isNumber }) }
        #expect(cases.count > 50, "el escáner no leyó el enum: \(cases.count) casos")

        let code = try Self.codeLines(excluding: decl)
        let orphans = cases.filter { name in
            !code.contains { $0.range(of: "\\.\(name)\\b", options: .regularExpression) != nil }
        }
        #expect(orphans.isEmpty, "canarios sin emisor: \(orphans)")
    }

    @Test func everyGroupsSyncBreadcrumbHasACaller() throws {
        let decl = "Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift"
        let source = try Self.read(decl)
        let names = source.split(separator: "\n").compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("static func ") else { return nil }
            return String(t.dropFirst("static func ".count).prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        }
        #expect(names.count > 20, "el escáner no leyó el fichero: \(names.count) funciones")

        let code = try Self.codeLines(excluding: decl)
        let orphans = names.filter { name in
            !Self.documentedDeadBreadcrumbs.contains(name)
                && !code.contains { $0.contains("GroupsSyncBreadcrumb.\(name)(") }
        }
        #expect(orphans.isEmpty, "rastros sin llamador: \(orphans)")
        // Los documentados siguen existiendo; si se borran, se quitan también de la lista.
        for name in Self.documentedDeadBreadcrumbs { #expect(names.contains(name), "\(name)") }
    }

    // MARK: - Helpers

    private static func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func read(_ path: String) throws -> String {
        try String(contentsOf: root().appendingPathComponent(path), encoding: .utf8)
    }

    /// Líneas de código (sin comentarios de línea) de los tres targets que se publican, salvo `excluding`.
    private static func codeLines(excluding: String) throws -> [String] {
        var lines: [String] = []
        for dir in ["Yala", "YalaWidgets", "YalaShare"] {
            guard let it = FileManager.default.enumerator(at: root().appendingPathComponent(dir),
                                                          includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in it where url.pathExtension == "swift" {
                guard !url.path.hasSuffix(excluding) else { continue }
                let text = try String(contentsOf: url, encoding: .utf8)
                for line in text.split(separator: "\n") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("//") || t.hasPrefix("*") { continue }
                    lines.append(String(line))
                }
            }
        }
        return lines
    }
}
