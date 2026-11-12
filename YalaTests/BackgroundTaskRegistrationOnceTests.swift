//
//  BackgroundTaskRegistrationOnceTests.swift
//  YalaTests
//
//  Card 7e60 (iPhone 14, iOS 27.2, 2026-11-05): con el primer crash del cierre de sesión arreglado salió el de detrás.
//  El cambio de almacén en caliente vuelve a correr `AppBootstrapper.bootstrap` en el mismo proceso, y el segundo
//  `BGTaskScheduler.register` del mismo identificador lanza `NSInternalInconsistencyException`: Yala se cerraba sola.
//  `BGTaskScheduler` no se puede llamar desde un test (registrar después del arranque también aborta), así que el
//  cableado solo lo fija leer el fuente.
//

import Foundation
import Testing

@testable import Yala

@Suite("Las tareas de fondo se registran una vez por proceso (source-scan)")
struct BackgroundTaskRegistrationOnceTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// El cuerpo de `registerTasks()` sin comentarios, línea a línea y sin vacías.
    private static func registerTasksBody() throws -> [String] {
        let src = try String(
            contentsOf: root.appendingPathComponent("Yala/App/BackgroundTaskManager.swift"), encoding: .utf8)
        let lines = src.components(separatedBy: "\n")
        let start = try #require(lines.firstIndex { $0.contains("func registerTasks() {") })
        return lines[(start + 1)...]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    @Test("La primera línea corta si ya se registró, y la segunda lo apunta, antes de cualquier register")
    func registerTasks_returnsEarlyAfterTheFirstCall() throws {
        let body = try Self.registerTasksBody()
        #expect(body.count > 2)
        #expect(body[0] == "guard !didRegisterTasks else { return }")
        #expect(body[1] == "didRegisterTasks = true")
        #expect(body[2].contains("BGTaskScheduler.shared.register("))
    }

    @Test("Solo `registerTasks()` registra tareas, y el arranque la llama en un único sitio")
    func onlyRegisterTasksRegisters() throws {
        var registerFiles: [String] = []
        let base = Self.root.appendingPathComponent("Yala")
        let walker = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        for case let file as URL in walker where file.pathExtension == "swift" {
            let code = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if code.contains("BGTaskScheduler.shared.register(") { registerFiles.append(file.lastPathComponent) }
        }
        #expect(registerFiles == ["BackgroundTaskManager.swift"])
    }
}
