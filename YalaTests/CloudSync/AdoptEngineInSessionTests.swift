//
//  AdoptEngineInSessionTests.swift
//  YalaTests
//
//  Decisión owner (2026-09-06), ticket `reentry-killswitch-closes-both-doors` §2: el motor de sync
//  arranca EN SESIÓN también en la re-entrada, como ya hacía el alta. Hasta entonces
//  `startAdoptWithExistingSession` era el único entrypoint del controller que no lo intentaba, así que
//  el relanzamiento era lo ÚNICO que dejaba algo sincronizando — y en un móvil recién instalado ese
//  relanzamiento no arregla nada, porque el store ya nació neutro.
//
//  Va por source-scan, como el chip gemelo del alta (`BornCloudSignUpServiceTests`): lo que hay que
//  fijar es QUIÉN se invoca de verdad en el flujo de producción, y `startRuntimeIfStable()` es privado
//  y su efecto (una `Task` que llama a `CloudSyncRuntime.startShared`) no es observable desde un test
//  de unidad sin montar red, sesión y container.
//

import Foundation
import Testing

@testable import Yala

@Suite("Adopt: el motor arranca en sesión, no en el relanzamiento")
struct AdoptEngineInSessionTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static let controllerPath = "Yala/Services/CloudSync/CloudMigrationController.swift"

    private static func controllerSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(controllerPath), encoding: .utf8)
    }

    /// Cuerpo de un `func` del controller, de su llave de apertura a la de cierre, **sin líneas de
    /// comentario**. Las dos acotaciones importan: sin la primera comprobaría que el símbolo existe en
    /// el fichero (lo hace: hay otros tres call-sites); sin la segunda bastaría con NOMBRARLO en un
    /// comentario para pintar el test de verde, y este chip añadió justamente un comentario que lo
    /// nombra.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("La re-entrada arranca el motor en la misma sesión")
    func adoptStartsTheEngineInSession() throws {
        let adopt = try Self.body(of: "func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {",
                                  in: try Self.controllerSource())
        #expect(adopt.contains("startRuntimeIfStable()"), """
            `startAdoptWithExistingSession` tiene que arrancar el motor. Sin esta línea la re-entrada
            vuelve a depender del relanzamiento, y en un móvil recién instalado no hay nada que
            relanzar: el store ya montó neutro.
            """)
    }

    /// El orden no es cosmético: `startRuntimeIfStable()` decide leyendo la fase JOURNALEADA
    /// (`readJournalDecisionInputs`) y el modo persistido. Llamarlo antes del `refresh()` final lo
    /// haría decidir sobre el estado previo al drive del adopt — el momento exacto en el que la fase
    /// todavía no es estable y el par todavía no está escrito, así que se retiraría sin arrancar nada
    /// y el chip quedaría verde en el test de arriba y muerto en producción.
    @Test("El arranque va DESPUÉS del refresh que asienta la fase")
    func engineStartsAfterTheFinalRefresh() throws {
        let adopt = try Self.body(of: "func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {",
                                  in: try Self.controllerSource())
        let start = try #require(adopt.range(of: "startRuntimeIfStable()"))
        let lastRefresh = try #require(adopt.range(of: "refresh()", options: .backwards))
        #expect(lastRefresh.lowerBound < start.lowerBound, """
            el arranque tiene que ir tras el `refresh()` final: antes de él la fase journaleada aún no
            es estable y el gate del motor se retiraría sin arrancar.
            """)
    }

    /// **Control positivo del método de medición.** Si el acotador devolviera el fichero entero —o
    /// nada— los dos tests de arriba pasarían igual sin el arreglo, porque `startRuntimeIfStable()`
    /// aparece en otros tres sitios del mismo fichero. Este caso prueba que el corte discrimina de
    /// verdad: un método que NO lo llama tiene que salir sin él.
    @Test("El acotador discrimina: un método sin el arranque sale sin él")
    func bodyExtraction_isDiscriminating() throws {
        let source = try Self.controllerSource()
        let reset = try Self.body(of: "func resetAfterRollback() async {", in: source)
        #expect(!reset.isEmpty, "el acotador devolvió vacío: no está midiendo nada")
        #expect(!reset.contains("startRuntimeIfStable()"), """
            `resetAfterRollback` no arranca el motor (deja la máquina lista para reintentar, no en un
            terminal de éxito). Si aparece aquí, el acotador está devolviendo más que el cuerpo pedido
            y los tests de este suite son falsos verdes.
            """)
        // Y el contraste con uno que sí lo llama, para que el control mida los dos sentidos.
        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {", in: source)
        #expect(resume.contains("startRuntimeIfStable()"),
                "`resume()` sí lo llama: si esto falla, el acotador se está quedando corto")
    }

    /// **El término que la review adversarial encontró que faltaba.** La fase estable no basta:
    /// `notStarted` LO ES —device adoptado— y es también la que el adopt journalea ANTES de ejecutar su
    /// efecto (`MigrationRunner` guarda y luego drena). Un `.adoptBackendAccount` que falla de forma
    /// retomable deja `(notStarted, pendiente)` y falla EN SILENCIO: `runGuarded` traga
    /// `Stop.effectFailed` porque «el próximo resume() retoma». Sin este término, la llamada nueva
    /// arrancaría el motor sobre una migración a medias, con el executor y el runtime compitiendo por
    /// el mismo outbox y el mismo cursor de History.
    ///
    /// `MigrationBootDecision.decide` ya aplica esta regla («un efecto pendiente FUERZA `.resume`
    /// aunque la fase sea estable»); esta función era el único consumidor de la fase que no la
    /// respetaba, y no se notaba porque sus tres call-sites previos llamaban justo tras drenar.
    @Test("El motor no arranca con efectos pendientes, aunque la fase sea estable")
    func engineDoesNotStartWithPendingEffects() throws {
        let gate = try Self.body(of: "private func startRuntimeIfStable() {",
                                 in: try Self.controllerSource())
        #expect(gate.contains("!hasPending"), """
            el guard tiene que mirar los efectos pendientes, no solo la fase. `notStarted` es estable y
            es justo la fase en la que un adopt fallido deja su efecto vivo.
            """)
        // Y que de verdad LO LEE del journal, en vez de recibir un `false` de cortesía.
        #expect(gate.contains("readJournalDecisionInputs()"),
                "el par (fase, pendientes) se lee del journal en el momento de decidir")
    }

    /// Control del término anterior en la dirección contraria: el dato SIEMPRE estuvo disponible —la
    /// función que lo provee devuelve la tupla entera— así que lo que fallaba era descartarlo, no una
    /// carencia del journal. Si alguien "simplifica" `readJournalDecisionInputs` a devolver solo la
    /// fase, este test lo dice antes de que el guard se quede sin su término.
    @Test("El journal expone los pendientes: descartarlos era una decisión, no una carencia")
    func journalAlwaysExposedThePendingFlag() throws {
        let reader = try Self.body(of: "private func readJournalDecisionInputs() -> (phase: MigrationPhase, hasPending: Bool)? {",
                                   in: try Self.controllerSource())
        #expect(reader.contains("snapshot.pendingCount > 0"),
                "`hasPending` sale del conteo de efectos del journal")
    }

    /// El comentario que justifica el chip cita el gate que lo hace seguro. Si alguien retira ese
    /// término del gate, esta afirmación deja de ser cierta y hay que enterarse: con el mirror de
    /// CloudKit montado, arrancar el motor es motor + mirror escribiendo el mismo store.
    @Test("El gate que protege el caso con marcador sigue mirando el mount")
    func theGateStillChecksTheMount() throws {
        let runtime = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/Services/CloudSync/CloudSyncRuntime.swift"),
            encoding: .utf8)
        let canRun = try Self.body(of: "static func canRunDomain() -> Bool {", in: runtime)
        #expect(canRun.contains("personalMountMismatch"), """
            `canRunDomain` tiene que seguir bloqueando el arranque cuando este proceso montó el store
            personal con el mirror vivo. Es lo único que hace inocuo el arranque en sesión del adopt
            para la puerta de Ajustes (marcador presente ⇒ mount con mirror ⇒ relanzamiento).
            """)
    }
}
