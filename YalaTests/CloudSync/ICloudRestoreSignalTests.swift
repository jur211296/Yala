//
//  ICloudRestoreSignalTests.swift
//  YalaTests
//
//  La señal que le dice al guard cross-cuenta «estas filas las está bajando el propio dueño ahora».
//
//  Dos mitades y ninguna cubre a la otra: la TABLA (cuándo la señal está viva) y el CABLEADO (quién la
//  enciende y quién la lee). La segunda es un source-scan porque lo que decide aquí es QUIÉN llama y en
//  qué orden — molde `AttestWiringTests` / `OwnerKeyValueWiringTests`: la lógica pura puede ser perfecta
//  y sus tests verdes mientras nadie la invoca donde hace falta, o mientras alguien la invoca donde NO.
//

import Foundation
import Testing

@testable import Yala

@Suite("La restauración en curso · la tabla")
struct ICloudRestoreInProgressLogicTests {

    @Test("sin haber pedido restaurar, la señal está SIEMPRE apagada")
    func withoutTheRequest_neverFires() {
        for first in [true, false] {
            for quiescent in [true, false] {
                #expect(!ICloudRestoreInProgressLogic.isRestoringNow(
                    restoreRequestedThisSession: false,
                    hasCompletedFirstImport: first,
                    isImportQuiescent: quiescent), """
                    Un import de CloudKit ocurre en cualquier arranque; sin el acto explícito del \
                    usuario, tomarlo por una restauración abre el guard cross-cuenta de par en par.
                    """)
            }
        }
    }

    @Test("pedido el restore, la señal vive hasta que el import ASIENTA")
    func afterTheRequest_livesUntilTheImportSettles() {
        // Aún no ha llegado el primer importEvent: es el instante en el que la pantalla de restaurar
        // está contando filas en vivo, o sea el centro exacto del escenario.
        #expect(ICloudRestoreInProgressLogic.isRestoringNow(
            restoreRequestedThisSession: true,
            hasCompletedFirstImport: false, isImportQuiescent: false))

        // Y la quiescencia SOLA no cierra la ventana: es `true` ANTES del primer import, así que
        // preguntar solo por ella diría «ya terminó» cuando no ha empezado — la misma asimetría que
        // documenta `waitForImportQuiescence`.
        #expect(ICloudRestoreInProgressLogic.isRestoringNow(
            restoreRequestedThisSession: true,
            hasCompletedFirstImport: false, isImportQuiescent: true), """
            Con solo la quiescencia, la señal se apagaría justo antes de que empiece la descarga: el \
            usuario que vuelve atrás en los primeros segundos volvería a ver el bloqueo.
            """)

        // Importando todavía (llegó un evento, no hay quietud).
        #expect(ICloudRestoreInProgressLogic.isRestoringNow(
            restoreRequestedThisSession: true,
            hasCompletedFirstImport: true, isImportQuiescent: false))
    }

    @Test("con el import asentado la señal se apaga: esas filas ya son corpus como cualquier otro")
    func settledImport_closesTheWindow() {
        #expect(!ICloudRestoreInProgressLogic.isRestoringNow(
            restoreRequestedThisSession: true,
            hasCompletedFirstImport: true, isImportQuiescent: true), """
            La ventana tiene que CERRARSE. Si la señal se quedara viva toda la sesión, el guard \
            cross-cuenta quedaría desarmado hasta que el usuario matara la app.
            """)
    }
}

@Suite("La restauración en curso · el latch de sesión", .serialized)
struct ICloudRestoreSessionSignalTests {

    @Test("nace apagada y solo la enciende el arranque de la búsqueda")
    @MainActor
    func latchStartsOffAndOnlyTheSearchTurnsItOn() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        #expect(!ICloudRestoreSessionSignal.restoreRequestedThisSession)
        ICloudRestoreSessionSignal.noteRestoreStarted()
        #expect(ICloudRestoreSessionSignal.restoreRequestedThisSession)
    }
}

@Suite("La restauración en curso · el cableado (source-scan)")
struct ICloudRestoreSignalWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Código SIN líneas de comentario: los docblocks de este subsistema nombran a propósito lo que
    /// prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let restoreView = "Yala/App/Views/Onboarding/WelcomeRestoreView.swift"
    private static let signInView = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let signal = "Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift"
    private static let guardLogic = "Yala/App/Logic/CrossAccountEntryGuardLogic.swift"

    @Test("MUTACIÓN: el guard del sign-in LEE la señal, y la lee viva")
    func theGuardReadsTheSignal() throws {
        let view = try Self.code(Self.signInView)
        #expect(view.contains("restoreInProgress: ICloudRestoreSessionSignal.isRestoringNow"), """
            El único call-site de producción del guard dejó de consultar la señal. La lógica pura \
            seguiría siendo correcta y sus 8 tests verdes, y el dueño que restaura volvería a tener \
            bloqueada la entrada a su propia cuenta.
            """)
    }

    @Test("MUTACIÓN: `restoreInProgress` NO tiene valor por defecto")
    func theParameterHasNoDefault() throws {
        let logic = try Self.code(Self.guardLogic)
        #expect(logic.contains("restoreInProgress: Bool\n"), "el parámetro sigue existiendo")
        #expect(!logic.contains("restoreInProgress: Bool ="), """
            Un default sería `false` y cualquier puerta NUEVA al guard heredaría el bug en silencio — \
            la familia exacta del `attestProvider: { nil }` de `.claude/rules/gateway-attest.md`. Sin \
            default, quien añada un call-site tiene que DECIDIR, y lo comprueba el compilador.
            """)
    }

    /// **El conteo es lo que carga el peso de este suite.** La señal abre —acotadamente— un guard de
    /// frontera de cuenta: encenderla desde un segundo sitio (un `onAppear` de más, un camino de
    /// migración que «también importa datos») desarma el guard sin tocar ni una línea de la lógica pura
    /// y con toda la suite en verde.
    @Test("MUTACIÓN: la señal se enciende en UN solo sitio de producción, y es la pantalla de restaurar")
    func onlyOneProductionCallSiteTurnsItOn() throws {
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var callSites: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            // La propia definición no es un call-site.
            guard url.lastPathComponent != "ICloudRestoreSessionSignal.swift" else { continue }
            let body = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if body.contains("noteRestoreStarted()") { callSites.append(url.lastPathComponent) }
        }
        #expect(callSites == ["WelcomeRestoreView.swift"], """
            Encendedores de la señal encontrados: \(callSites.sorted()). Tiene que haber EXACTAMENTE \
            uno y ser la pantalla de restaurar: cualquier otro sitio la enciende sin que el usuario \
            haya pedido una restauración, y con ella encendida el guard deja adoptar sobre el corpus \
            de otro humano.
            """)
    }

    /// El ORDEN, que ningún test de comportamiento caza: `startSearch` tiene dos `return` tempranos —sin
    /// cuenta de iCloud y tras un wipe— y en los dos NO hay import. Encender antes de ellos abriría la
    /// ventana sin corpus que la justifique.
    @Test("MUTACIÓN: la señal se enciende DESPUÉS de los dos estados que no importan nada")
    func theSignalFiresAfterTheEarlyReturns() throws {
        let view = try Self.code(Self.restoreView)
        let disabled = try #require(view.range(of: "state = .iCloudDisabled"))
        let wiped = try #require(view.range(of: "state = .wiped"))
        let note = try #require(
            view.range(of: "ICloudRestoreSessionSignal.noteRestoreStarted()"),
            "la pantalla de restaurar dejó de encender la señal: el fix queda inerte")

        #expect(disabled.upperBound < note.lowerBound && wiped.upperBound < note.lowerBound, """
            La señal se enciende antes de los `return` de «iCloud no disponible» y «este device fue \
            borrado». En los dos no hay ningún import de CloudKit, así que la ventana quedaría abierta \
            sin nada que la justifique — y esa ventana es un guard de frontera de cuenta.
            """)
    }

    /// El sesgo fail-closed no es una opinión del docblock: es que el latch viva en memoria. Persistido,
    /// un kill del proceso a mitad del restore dejaría la puerta entornada en el arranque siguiente.
    @Test("MUTACIÓN: el latch NO se persiste")
    func theLatchIsNeverPersisted() throws {
        let code = try Self.code(Self.signal)
        #expect(!code.contains("UserDefaults"), """
            El latch pasó a persistirse. Su modo de fallo tiene que ser APAGARSE: en memoria, un kill \
            del proceso cierra la ventana; en disco, la deja abierta en el arranque siguiente, cuando \
            ya no hay ningún import que la justifique.
            """)
        #expect(!code.contains("SharedContainerService") && !code.contains("suiteName"),
                "ni por el App Group, que es la otra vía de persistencia del repo")
    }
}
