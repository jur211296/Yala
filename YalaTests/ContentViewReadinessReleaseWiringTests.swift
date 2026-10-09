//
//  ContentViewReadinessReleaseWiringTests.swift
//  YalaTests
//
//  **La matriz del shell libera FUERA de la actualización de la vista** (ticket
//  `queued-offer-after-dismiss-flakes-on-a-cold-simulator`, 2026-10-08). Liberar es `markReady(.contentView)`, que sube
//  la `revision` del router; hecho dentro de una acción de `onChange`, el `.onChange(of: revision)` de `ContentView` a
//  veces no veía el bump (1 de 7-16 arranques, medido con instrumentación) y lo retenido —oferta, aviso de bandeja,
//  invitación— no salía hasta relanzar la app.
//
//  No hay forma de reproducir la entrega de un `onChange` desde un unit test: la red de comportamiento son los
//  XCUITest del registro del ticket. Esto fija el CABLEADO que la sostiene, por source-scan del cuerpo entero.
//

import Foundation
import Testing

@Suite("ContentView · la matriz libera fuera de la actualización")
struct ContentViewReadinessReleaseWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios —también los de cola— y con los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// El cuerpo entre llaves balanceadas que abre la primera `{` tras `marker`, sin las llaves de fuera.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let tail = source[start.upperBound...]
        let open = try #require(tail.firstIndex(of: "{"), "sin llave tras el marcador: \(marker)")
        var depth = 0
        var index = open
        while index < tail.endIndex {
            if tail[index] == "{" { depth += 1 }
            if tail[index] == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = tail.index(after: index)
        }
        return String(tail[tail.index(after: open)..<index]).trimmingCharacters(in: .whitespaces)
    }

    private static func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    @Test func update_blocksNow_andReleasesOneMainActorTurnLater() throws {
        // El cuerpo ENTERO: un `contains` dejaría pasar un `markReady` antepuesto, o el guard invertido (que aplazaría
        // el BLOQUEO y abriría una vuelta en la que se drena con el shell ya tapado).
        let vista = try Self.code("Yala/App/ContentView.swift")
        let update = try Self.body(of: "private func updateContentViewReadiness()", in: vista)
        #expect(update == "guard ContentViewReadinessLogic.blocker(state: currentShellReadinessState()) == nil else { "
            + "applyContentViewReadiness() return } "
            + "Task { @MainActor in applyContentViewReadiness() }")
    }

    @Test func markReady_livesOnlyInTheImmediateApply() throws {
        // El bump que se perdía es este `markReady`. Si otro sitio lo llamara —en `ContentView` o en un modificador
        // suyo, o con un `.routerConsumer(.contentView)`, que marca listo en su `.task`—, volvería a liberar sin
        // pasar por el aplazamiento.
        let enumerator = try #require(FileManager.default.enumerator(
            at: Self.repoRoot.appendingPathComponent("Yala"), includingPropertiesForKeys: nil))
        var markReadyCount = 0
        var consumerCount = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            let source = try Self.code(relative)
            markReadyCount += Self.occurrences(of: "markReady(.contentView", in: source)
            consumerCount += Self.occurrences(of: "routerConsumer(.contentView", in: source)
        }
        #expect(markReadyCount == 1)
        #expect(consumerCount == 0)
        let vista = try Self.code("Yala/App/ContentView.swift")
        let apply = try Self.body(of: "private func applyContentViewReadiness()", in: vista)
        // La condición entera: invertida, liberaría con el shell tapado.
        #expect(apply.contains("let ready = currentBlocker == nil "
            + "if ready { AppRouter.shared.markReady(.contentView, in: navigation.id) }"))
    }

    @Test func immediateApply_hasOnlyTheTwoCallersThatMayUseIt() throws {
        // Dos en `updateContentViewReadiness` (bloquear en el acto y la vuelta aplazada) y uno en el derribo B4-04 de
        // `drainContentViewIntents`, que drena en la misma llamada y no espera al `onChange`. Un cuarto sería un
        // `onChange` liberando dentro de la actualización otra vez.
        let vista = try Self.code("Yala/App/ContentView.swift")
        // Sin paréntesis: una referencia pasada como cierre (`.onAppear(perform: applyContentViewReadiness)`) también
        // cuenta. 3 llamadas + la declaración.
        #expect(Self.occurrences(of: "applyContentViewReadiness", in: vista) == 4)
        let drain = try Self.body(of: "private func drainContentViewIntents()", in: vista)
        #expect(drain.contains("dismissWelcomeChainForSupersedingIntent(for: next.id) applyContentViewReadiness() }"))
    }

    @Test func observers_recomputeThroughTheDeferredRelease() throws {
        // Los 28 `onChange` de `ReadinessGateObservers` son justo los que corrían dentro de la actualización.
        let vista = try Self.code("Yala/App/ContentView.swift")
        #expect(vista.contains("recompute: updateContentViewReadiness )"))
        #expect(!vista.contains("recompute: applyContentViewReadiness"))
    }
}
