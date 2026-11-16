//
//  BarridoFinal23Source.swift
//  YalaTests
//
//  Lector de fuentes para los scans de cableado del lote de bugs del barrido final de 2.3.
//

import Foundation

nonisolated enum BarridoFinal23Source {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/BarridoFinal23
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios y con los espacios colapsados a uno.
    static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
