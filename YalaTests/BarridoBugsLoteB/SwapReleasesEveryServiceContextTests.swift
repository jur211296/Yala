//
//  SwapReleasesEveryServiceContextTests.swift
//  YalaTests
//
//  Barrido del iPhone 14 (14-nov), lote B, card p9q0: cerrar sesión en una cuenta en la nube terminaba en «Ya casi está ·
//  Vuelve a abrir Yala». Medido en las consolas del barrido: ningún evento del espejo de iCloud, así que el cambio en
//  caliente no se saltó por el espejo; abortó porque el almacén seguía vivo. Los dos avisos de Grupos (recordatorio de
//  deudas y tope de gasto) reciben el contexto en el chequeo de avisos del arranque y `releaseModelContextsForSwap` no
//  los soltaba: un `ModelContext` retiene su contenedor.
//
//  Escaneo de fuente: todo `Tipo.shared.setContext(<contexto>)` del árbol `Yala/` tiene su `setContext(nil)` dentro de
//  `releaseModelContextsForSwap`. Lo que no cubre, dicho: un servicio que guarde el contexto con otro nombre de método.
//

import Foundation
import Testing

@Suite("Lote B · el cambio en caliente suelta el contexto de todos los servicios (p9q0)")
struct SwapReleasesEveryServiceContextTests {

    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func swiftFiles(under folder: String) throws -> [URL] {
        let root = repo.appendingPathComponent(folder)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Tipos cuyo `.shared` recibe un contexto no nulo en algún sitio de `Yala/`.
    private static func typesThatReceiveAContext() throws -> Set<String> {
        let pattern = try NSRegularExpression(pattern: #"\b([A-Z][A-Za-z0-9]+)\.shared\.setContext\((?!nil\))"#)
        var types = Set<String>()
        for file in try swiftFiles(under: "Yala") {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) { types.insert(String(text[range])) }
            }
        }
        // Los alias del arranque (`let budgetAlertService = BudgetAlertService.shared`) también reciben contexto.
        let boot = try String(contentsOf: repo.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        for (alias, type) in try aliases(in: boot) where boot.contains("\(alias).setContext(context") {
            types.insert(type)
        }
        return types
    }

    private static func aliases(in boot: String) throws -> [(alias: String, type: String)] {
        let pattern = try NSRegularExpression(pattern: #"let ([a-z][A-Za-z0-9]+) = ([A-Z][A-Za-z0-9]+)\.shared"#)
        return pattern.matches(in: boot, range: NSRange(boot.startIndex..., in: boot)).compactMap { match in
            guard let a = Range(match.range(at: 1), in: boot), let t = Range(match.range(at: 2), in: boot) else { return nil }
            return (String(boot[a]), String(boot[t]))
        }
    }

    private static func releaseBody() throws -> String {
        let boot = try String(contentsOf: repo.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let start = try #require(boot.range(of: "func releaseModelContextsForSwap() {"))
        let end = try #require(boot.range(of: "func rebootstrapAfterSwap(", range: start.upperBound..<boot.endIndex))
        return String(boot[start.upperBound..<end.lowerBound])
    }

    @Test func everyServiceThatReceivesAContext_releasesItBeforeTheSwap() throws {
        let types = try Self.typesThatReceiveAContext()
        // Control: el escáner ve los del barrido y los de siempre. Sin esto, un patrón roto pasaría en verde.
        #expect(types.isSuperset(of: ["GroupSettlementReminderService", "GroupBudgetAlertService", "GroupService",
                                       "BudgetAlertService", "DraftService"]))
        let body = try Self.releaseBody()
        let boot = try String(contentsOf: Self.repo.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)
        let aliasOf = Dictionary(try Self.aliases(in: boot).map { ($0.type, $0.alias) }, uniquingKeysWith: { a, _ in a })
        for type in types.sorted() {
            let released = body.contains("\(type).shared.setContext(nil)")
                || aliasOf[type].map { body.contains("\($0).setContext(nil)") } == true
            #expect(released, "\(type) recibe el contexto y releaseModelContextsForSwap no lo suelta: el cambio en caliente abortaría")
        }
    }

    /// Los dos del barrido, nombrados: el test genérico de arriba podría quedarse sin ellos si cambiara la forma de pasarles
    /// el contexto.
    @Test func theTwoGroupsNoticesFromTheSweep_areReleased() throws {
        let body = try Self.releaseBody()
        #expect(body.contains("GroupSettlementReminderService.shared.setContext(nil)"))
        #expect(body.contains("GroupBudgetAlertService.shared.setContext(nil)"))
    }
}
