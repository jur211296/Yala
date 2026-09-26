//
//  ForceFetchCancellationWiringTests.swift
//  YalaTests
//
//  El cableado de `force-fetch-and-wait-ignores-cancellation`, en las tres mitades que un test de
//  comportamiento NO puede alcanzar:
//
//   1. **Que la primitiva siga ENVUELTA en cancelación y siga usando la caja.** Lo que la caja HACE lo
//      prueba `ForceFetchWaitBoxTests` con comportamiento; lo que aquí se fija es el CABLEADO — que
//      `forceFetchAndWait` no vuelva a resolver a pelo, sin envoltorio y sin caja.
//   2. **El poll de arranque que gira EN CALIENTE sobre un `Task` cancelado.**
//      `awaitPersonalImportForBootSave` es privada y sin seam; su hermana `.cloudEngine` ya lo cierra.
//   3. **El orden del motivo en los dos borrados de `ContentView`**, que también son privados.
//
//  Molde: `AttestWiringTests` / `ICloudRestoreSignalWiringTests`. Y la lección de
//  `.claude/rules/testing.md` L167: cuando el source-scan es la única red, **se fija el cuerpo ENTERO
//  normalizado paso a paso**, no dos literales sueltos.
//

import Foundation
import Testing

@testable import Yala

@Suite("La espera del import de iCloud observa cancelación · el cableado (source-scan)")
struct ForceFetchCancellationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    /// Código sin comentarios: los docblocks de este subsistema nombran a propósito lo que prohíben, y
    /// contar la prosa haría que documentar el invariante lo «cumpliera». Se quitan las líneas de
    /// comentario **y la cola `//…` de una línea de código** — sin lo segundo, un `// ojo` al final de
    /// una línea escaneada pone el test rojo sin que producción cambie (regla L167 de
    /// `.claude/rules/testing.md`: los scans que CUENTAN filtran comentarios).
    ///
    /// **`entre:` acota el tramo, y esa mitad no es cosmética.** La primera versión de este fichero
    /// escaneaba el `AppBootstrapper` entero y sus cuatro pasos del poll casaban con la rama HERMANA
    /// —`.cloudEngine`, que tiene el `do`/`catch` byte-idéntico y está más abajo—, así que el mutante
    /// que el propio test dice cazar **sobrevivía**. Medido el 2026-09-21. Es la trampa de siempre: un
    /// tramo sin acotar lo cumple el vecino.
    private static func code(_ path: String, entre desde: String? = nil, y hasta: String? = nil) throws -> String {
        var bruto = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        if let desde, let inicio = bruto.range(of: desde) { bruto = String(bruto[inicio.lowerBound...]) }
        if let hasta, let fin = bruto.range(of: hasta) { bruto = String(bruto[..<fin.lowerBound]) }
        return bruto
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { linea -> String in
                let sinCola = linea.range(of: "//").map { String(linea[..<$0.lowerBound]) } ?? String(linea)
                return sinCola.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let service = "Yala/Services/iCloudSyncService.swift"
    private static let bootstrapper = "Yala/App/AppBootstrapper.swift"
    private static let contentView = "Yala/App/ContentView.swift"

    /// Cada paso, en orden, y el orden se comprueba: un `contains` suelto pasa con las líneas barajadas.
    private static func expectOrdered(_ pasos: [String], in code: String, _ queSePierde: String) throws {
        var desde = code.startIndex
        for paso in pasos {
            let encontrado = code.range(of: paso, range: desde..<code.endIndex)
            #expect(encontrado != nil, """
                Falta —o quedó fuera de orden— este paso: `\(paso)`.
                \(queSePierde)
                """)
            guard let encontrado else { return }
            desde = encontrado.upperBound
        }
    }

    // MARK: - 1 · La primitiva

    @Test("MUTACIÓN: la espera se envuelve en cancelación y suelta las TRES cosas que retiene")
    func theWaitIsWrappedAndReleasesEverything() throws {
        let code = try Self.code(Self.service)

        try Self.expectOrdered([
            "func forceFetchAndWait(timeout: TimeInterval = 15) async -> Bool {",
            "guard isAccountAvailable else { return false }",
            "if hasCompletedFirstImport { return true }",
            "let box = ForceFetchWaitBox()",
            "return await withTaskCancellationHandler {",
            "await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in",
            "let observer = NotificationCenter.default.addObserver(",
            "forName: .iCloudFirstImportCompleted, object: nil, queue: .main",
            ") { _ in box.resolve(true) }",
            "let timeoutTask = Task {",
            "try? await Task.sleep(for: .seconds(timeout))",
            "box.resolve(false)",
            "box.arm(continuation: continuation, observer: observer, timeoutTask: timeoutTask)",
            "} onCancel: {",
            "box.resolve(false)",
        ], in: code, """
            Sin el `withTaskCancellationHandler` alrededor, un `Task` cancelado vuelve a quedarse \
            clavado hasta el tope (15 s en el arranque, 90 s en el restore) con la pantalla ya cerrada. \
            Y sin la caja, las tres vías que compiten —notificación, tope y cancelación— pueden hacer \
            un doble `resume` de la continuation, que es un CRASH y no un test rojo.
            """)

        try Self.expectOrdered([
            "func resolve(_ value: Bool) {",
            "lock.lock()",
            "guard !didResolve else { lock.unlock(); return }",
            "didResolve = true",
            "let continuation = self.continuation",
            "let observer = self.observer",
            "let timeoutTask = self.timeoutTask",
            "self.continuation = nil",
            "self.observer = nil",
            "self.timeoutTask = nil",
            "if continuation == nil { pendingValue = value }",
            "lock.unlock()",
            "if let observer { NotificationCenter.default.removeObserver(observer) }",
            "timeoutTask?.cancel()",
            "continuation?.resume(returning: value)",
        ], in: code, """
            La resolución única perdió un paso. Los tres que ningún test de comportamiento caza: \
            `removeObserver` (el observer se queda vivo), `timeoutTask?.cancel()` (el sleep de 15/90 s \
            sigue durmiendo tras el desenlace feliz — el trabajo fantasma que este ticket cierra) y el \
            `pendingValue`, que es lo único que resuelve la espera cuando la cancelación llega ANTES \
            de que exista la continuation.
            """)

        try Self.expectOrdered([
            "func arm(continuation: CheckedContinuation<Bool, Never>,",
            "observer: NSObjectProtocol,",
            "timeoutTask: Task<Void, Never>) {",
            "lock.lock()",
            "if let pendingValue {",
            "lock.unlock()",
            "NotificationCenter.default.removeObserver(observer)",
            "timeoutTask.cancel()",
            "continuation.resume(returning: pendingValue)",
            "return",
            "self.continuation = continuation",
            "self.observer = observer",
            "self.timeoutTask = timeoutTask",
            "lock.unlock()",
        ], in: code, """
            `arm(...)` dejó de cobrar el valor que `resolve(_:)` guardó antes de que hubiera \
            continuation. Su modo de fallo es el PEOR de los dos posibles: la espera no resuelve NUNCA.
            """)
    }

    // MARK: - 2 · El poll de arranque

    @Test("MUTACIÓN: el poll de boot-save no gira en caliente sobre un `Task` cancelado")
    func theBootSavePollDoesNotBusySpin() throws {
        // **Acotado a SU función.** Sin el corte, los cuatro pasos casan con el `do`/`catch`
        // byte-idéntico de la rama `.cloudEngine` que vive más abajo, y el mutante sobrevive.
        let code = try Self.code(Self.bootstrapper,
                                 entre: "private func awaitPersonalImportForBootSave",
                                 y: "private func awaitPersonalStoreReady")

        try Self.expectOrdered([
            "_ = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)",
            "while gateDecision() == .wait && Date().timeIntervalSince(start) < totalPollCap {",
            "do {",
            "try await Task.sleep(for: .seconds(pollInterval))",
            "} catch {",
            "return false",
        ], in: code, """
            El poll volvió al `try? await Task.sleep`, que sobre un `Task` cancelado devuelve al \
            instante: el bucle gira EN CALIENTE los 120 s del tope. Y el `catch` devuelve `false`, no \
            `true` ni un `break`: un `Task` que se fue no autoriza un boot-save ni cuenta como un DEFER \
            del gate. Desde que `forceFetchAndWait` observa cancelación, este bucle se ALCANZA 15 s \
            antes que antes.
            """)

        // Y la mitad hermana, que es el precedente, medida en SU tramo: si alguien la relaja, este
        // `catch` se queda solo. Fijar solo su `while` no servía — el mutante que le devuelve el
        // `try?` dejaba la aserción verde.
        let hermana = try Self.code(Self.bootstrapper,
                                    entre: "private func awaitPersonalStoreReady",
                                    y: "/// Espera acotada a que el canal de Grupos")
        try Self.expectOrdered([
            "while !safe() && waited < quiescenceHardCap {",
            "do {",
            "try await Task.sleep(for: .seconds(pollInterval))",
            "} catch {",
            "return false",
        ], in: hermana, """
            La rama `.cloudEngine` de `awaitPersonalStoreReady` volvió a girar en caliente sobre un \
            `Task` cancelado. Es el precedente del `catch` de arriba: las dos mitades del mismo \
            `switch` tienen que tratar igual la cancelación, o una de las dos se queda sola.
            """)
    }

    // MARK: - 3 · El motivo de los dos borrados

    @Test("MUTACIÓN: un borrado cancelado dice `cancelled`, no `importNotQuiescent`")
    func theWipeReasonKeepsSayingCancelled() throws {
        let code = try Self.code(Self.contentView)

        let bloque = "if ICloudPersonalCorpusProbe.mirrorWillSync() { "
            + "let quiescent = await iCloudSyncService.shared.waitForImportQuiescence(timeout: 30) "
            + "guard !Task.isCancelled else { return \"cancelled\" } "
            + "guard quiescent else { return \"importNotQuiescent\" } }"

        // La tercera, la re-espera tras subir los cambios de grupos, devuelve el motivo envuelto en `.stop(…)` desde
        // el 2026-09-26 (ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`): el envoltorio lleva
        // además lo que la persona aceptó perder. Se cuenta con su forma, y el orden que fija es el mismo.
        let bloqueEnvuelto = "if ICloudPersonalCorpusProbe.mirrorWillSync() { "
            + "let quiescent = await iCloudSyncService.shared.waitForImportQuiescence(timeout: 30) "
            + "guard !Task.isCancelled else { return .stop(\"cancelled\") } "
            + "guard quiescent else { return .stop(\"importNotQuiescent\") } }"

        let ocurrencias = code.components(separatedBy: bloque).count - 1
            + code.components(separatedBy: bloqueEnvuelto).count - 1
        // TRES desde el 2026-09-26: la tercera es la re-espera tras subir los cambios de grupos
        // (`drainGroupsBeforeFreshStart`, ticket `fresh-start-wipe-kills-unsent-group-writes-silently`).
        #expect(ocurrencias == 3, """
            Esperaba las TRES puertas de quiescencia con el chequeo de cancelación DELANTE del motivo \
            (`performICloudCorpusWipe`, `performDeviceCorpusWipe` y la re-espera tras la subida de \
            grupos); encontré \(ocurrencias). \
            Desde que la espera observa cancelación devuelve `false` también al cancelarla, así que con \
            el `guard ... else { return "importNotQuiescent" }` pegado a la espera el motivo que se le \
            enseña al usuario pasa a ser «el import no se asentó» cuando lo que pasó fue que el `Task` \
            se fue.
            """)
    }
}
