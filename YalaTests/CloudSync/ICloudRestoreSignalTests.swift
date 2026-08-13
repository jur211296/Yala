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

    private static let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    /// Atajo: la ventana recién abierta y con el import dando señales de vida, que es el caso normal.
    private static func isRestoring(
        startedAt: Date? = t0,
        firstImport: Bool = false,
        quiescent: Bool = false,
        activity: Bool = true,
        afterSeconds: TimeInterval = 5
    ) -> Bool {
        ICloudRestoreInProgressLogic.isRestoringNow(
            restoreStartedAt: startedAt,
            hasCompletedFirstImport: firstImport,
            isImportQuiescent: quiescent,
            hasObservedImportActivity: activity,
            now: t0.addingTimeInterval(afterSeconds))
    }

    @Test("sin haber pedido restaurar, la señal está SIEMPRE apagada")
    func withoutTheRequest_neverFires() {
        for first in [true, false] {
            for quiescent in [true, false] {
                for activity in [true, false] {
                    #expect(!Self.isRestoring(
                        startedAt: nil, firstImport: first,
                        quiescent: quiescent, activity: activity), """
                        Un import de CloudKit ocurre en cualquier arranque; sin el acto explícito del \
                        usuario, tomarlo por una restauración abre el guard cross-cuenta de par en par.
                        """)
                }
            }
        }
    }

    @Test("pedido el restore, la señal vive mientras el import no ASIENTA")
    func afterTheRequest_livesUntilTheImportSettles() {
        // Aún no ha llegado el primer importEvent completo: es el instante en el que la pantalla de
        // restaurar está contando filas en vivo, o sea el centro exacto del escenario.
        #expect(Self.isRestoring(firstImport: false, quiescent: false))

        // Y la quiescencia SOLA no cierra la ventana: es `true` ANTES del primer import, así que
        // preguntar solo por ella diría «ya terminó» cuando no ha empezado — la misma asimetría que
        // documenta `waitForImportQuiescence`.
        #expect(Self.isRestoring(firstImport: false, quiescent: true), """
            Con solo la quiescencia, la señal se apagaría justo antes de que empiece la descarga: el \
            usuario que vuelve atrás en los primeros segundos volvería a ver el bloqueo.
            """)

        // Importando todavía (llegó un evento, no hay quietud).
        #expect(Self.isRestoring(firstImport: true, quiescent: false))
    }

    @Test("con el import asentado la señal se apaga: esas filas ya son corpus como cualquier otro")
    func settledImport_closesTheWindow() {
        #expect(!Self.isRestoring(firstImport: true, quiescent: true), """
            La ventana tiene que CERRARSE. Si la señal se quedara viva toda la sesión, el guard \
            cross-cuenta quedaría desarmado hasta que el usuario matara la app.
            """)
    }

    // MARK: - Las dos salidas que hacen el sesgo REALMENTE fail-closed
    //
    // Reportadas por la sesión hermana el 2026-08-13 sobre `d3c14350`, y medidas: el primer término
    // era un latch que nunca se apaga y el segundo, `!(A && B)`, devuelve `true` cuando A se
    // desconoce. O sea que la ausencia de información se leía como «sí, está restaurando» — el sesgo
    // declarado («ante la duda, false») estaba INVERTIDO respecto al implementado.

    /// EL caso que abría el guard. `hasCompletedFirstImport` solo se enciende en la rama de import
    /// EXITOSO (`iCloudSyncService.swift:265-272`, dentro del `else if let endDate`), y hay un
    /// escenario en el que no llega NUNCA: el propio docblock de `waitForImportQuiescence` lo dice —
    /// «un store que NADA importa nunca dispara `.importEvent`».
    ///
    /// Camino completo: tocar «Restaurar desde iCloud» (la búsqueda arranca ⇒ latch ON) → no hay
    /// backup → volver atrás → firmar con OTRA cuenta sobre un device con el corpus del dueño. Con la
    /// señal pegada el guard devuelve `.proceed` y se adopta sobre datos ajenos: es exactamente el
    /// incidente que `CrossAccountEntryGuardLogic` existe para impedir.
    @Test("sin NINGUNA actividad de import, la señal se apaga sola pasada la gracia")
    func noImportActivityAtAll_closesTheWindow() {
        // Dentro de la gracia sigue viva: CloudKit puede tardar en emitir su primer evento y apagarla
        // aquí devolvería el bloqueo al dueño legítimo que sí está restaurando.
        #expect(Self.isRestoring(activity: false, afterSeconds: 30))

        #expect(!Self.isRestoring(activity: false, afterSeconds: 61), """
            No hay NI UN `.importEvent` y ha pasado la gracia: no hay ninguna restauración en curso \
            que justifique la ventana. Con la señal pegada, cualquiera puede firmar sobre el corpus \
            de otro humano — el guard cross-cuenta queda desarmado hasta que se mate la app.
            """)
    }

    /// El tope duro es la red que no depende de NADA: ni de que un callback corra, ni de que CloudKit
    /// emita, ni de que la pantalla se desmonte por donde esperamos. Si nada la apagó, se apaga sola.
    @Test("y aunque el import dé señales de vida, la ventana tiene tope")
    func hardCap_closesTheWindowNoMatterWhat() {
        #expect(Self.isRestoring(activity: true, afterSeconds: 599))
        #expect(!Self.isRestoring(activity: true, afterSeconds: 601), """
            Un import que lleva diez minutos sin asentar no es una restauración en curso: es un \
            estado atascado. Mantener la puerta abierta indefinidamente por él es el sesgo inverso al \
            declarado.
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

        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)
        ICloudRestoreSessionSignal.noteRestoreStarted()
        #expect(ICloudRestoreSessionSignal.restoreStartedAt != nil)
    }

    /// El reintento de la pantalla vuelve a llamar a `noteRestoreStarted`. Si eso reiniciara el reloj,
    /// el tope duro dejaría de ser un tope: sería una ventana extensible tocando un botón.
    @Test("re-arrancar la búsqueda NO reinicia el reloj de la ventana")
    @MainActor
    func restartingTheSearchDoesNotExtendTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        ICloudRestoreSessionSignal.noteRestoreStarted(now: t0)
        ICloudRestoreSessionSignal.noteRestoreStarted(now: t0.addingTimeInterval(300))
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == t0)
    }

    /// El apagado explícito: cuando el flujo termina —gane o pierda— la ventana se cierra sin esperar
    /// a la caducidad.
    @Test("terminar el flujo cierra la ventana")
    @MainActor
    func finishingTheFlowClosesTheWindow() {
        ICloudRestoreSessionSignal._testReset()
        defer { ICloudRestoreSessionSignal._testReset() }

        ICloudRestoreSessionSignal.noteRestoreStarted()
        ICloudRestoreSessionSignal.noteRestoreFinished()
        #expect(ICloudRestoreSessionSignal.restoreStartedAt == nil)
        #expect(!ICloudRestoreSessionSignal.isRestoringNow)
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

    private static let progressView = "Yala/App/Views/Onboarding/RestoreProgressView.swift"

    /// El apagado explícito al terminar el flujo. **Ningún test de comportamiento lo caza**: la
    /// caducidad de la lógica pura cierra la ventana igual, solo que tarda. Lo que se pierde al
    /// quitarlo es la PRECISIÓN —hasta diez minutos con un guard de frontera de cuenta abierto de
    /// más— y eso solo lo ve un escáner.
    @Test("MUTACIÓN: la pantalla de progreso apaga la señal al terminar, gane o pierda")
    func theProgressViewClosesTheWindowWhenTheFlowEnds() throws {
        let code = try Self.code(Self.progressView)
        #expect(code.contains("ICloudRestoreSessionSignal.noteRestoreFinished()"), """
            La pantalla de restaurar dejó de cerrar la ventana al terminar. La señal seguiría viva \
            hasta caducar, con el guard cross-cuenta abierto de más todo ese rato.
            """)

        // Y el ORDEN: va ANTES del `guard !Task.isCancelled`, porque si la vista se desmontó justo en
        // ese instante el early-return se llevaría el apagado por delante.
        let apagado = try #require(code.range(of: "ICloudRestoreSessionSignal.noteRestoreFinished()"))
        let espera = try #require(code.range(of: "await iCloudSyncService.shared.waitForImportQuiescence"))
        let cancelado = try #require(
            code.range(of: "guard !Task.isCancelled", range: espera.upperBound..<code.endIndex))
        #expect(espera.upperBound < apagado.lowerBound && apagado.upperBound < cancelado.lowerBound, """
            El apagado tiene que ir entre la espera y el primer `guard !Task.isCancelled` posterior. \
            Detrás del guard, un desmontaje en ese instante se lo lleva.
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
