//
//  GroupsAttestTabNoticeTests.swift
//  YalaTests
//
//  El aviso FIJO de la pestaña Grupos cuando el veredicto de App Attest es terminal (ticket
//  `groups-tab-does-not-say-this-phone-cannot-sync-groups`, decisión de Jürgen del 2026-09-15, opción 1).
//
//  Dos mitades, y ninguna cubre a la otra: la tabla de la decisión, que es pura, y el CABLEADO —de dónde salen sus
//  tres entradas y cuándo se vuelve a mirar—, que vive en un `var body` de SwiftUI y solo alcanza un source-scan.
//

import Testing
import Foundation
@testable import Yala

// MARK: - 1 · La decisión

@Suite("Aviso de attest en la pestaña Grupos · la decisión")
struct GroupsAttestTabNoticeLogicTests {

    typealias L = GroupsAttestTabNoticeLogic

    @Test("Las CUATRO condiciones a la vez, y solo las cuatro")
    func theNoticeNeedsAllFour() {
        #expect(L.showsNotice(verdictIsTerminal: true, channelIsCompiled: true,
                              hasLiveSession: true, hasGroupsConsent: true))
        // La tabla entera: con cualquiera de las cuatro caída, no hay aviso. Recorrerla completa es lo que mata
        // al mutante que sustituye un `&&` por un `||` o que se deja un operando fuera.
        for terminal in [true, false] {
            for canal in [true, false] {
                for sesion in [true, false] {
                    for consent in [true, false] {
                        let esperado = terminal && canal && sesion && consent
                        #expect(L.showsNotice(verdictIsTerminal: terminal,
                                              channelIsCompiled: canal,
                                              hasLiveSession: sesion,
                                              hasGroupsConsent: consent) == esperado, """
                            terminal=\(terminal) canal=\(canal) sesión=\(sesion) consent=\(consent) \
                            debía dar \(esperado)
                            """)
                    }
                }
            }
        }
    }

    /// **Documentación ejecutable, no cobertura nueva**: las tres celdas de aquí ya las recorre el bucle de arriba,
    /// así que ningún mutante de `showsNotice` mata a una sin matar a las otras. Se queda porque nombra el daño —el
    /// aviso MINTIENDO— que las tres condiciones «de más» existen para impedir, y eso un bucle de booleanos no dice.
    @Test("Las tres poblaciones a las que el veredicto es cierto y la frase sería mentira")
    func theVerdictAloneIsNotEnough() {
        // La racha describe al teléfono y sobrevive al cierre de sesión a propósito, así que quien cerró sesión
        // ayer vería «este teléfono no puede sincronizar tus grupos» sobre un tab que ya le pide iniciar sesión.
        #expect(!L.showsNotice(verdictIsTerminal: true, channelIsCompiled: true,
                               hasLiveSession: false, hasGroupsConsent: true))
        // Con Grupos sin compilar, la racha sería entera del motor personal, que no sube un solo gasto de grupo.
        #expect(!L.showsNotice(verdictIsTerminal: true, channelIsCompiled: false,
                               hasLiveSession: true, hasGroupsConsent: true))
        // Y la tercera, que cazó la review: con sesión pero sin el consent aceptado, esta persona no tiene ningún
        // cambio de grupos esperando, y el tab le está pidiendo justo que acepte.
        #expect(!L.showsNotice(verdictIsTerminal: true, channelIsCompiled: true,
                               hasLiveSession: true, hasGroupsConsent: false))
    }
}

// MARK: - 1b · El aviso del store

/// **El único momento de recálculo que no depende de un gesto**, y por eso se prueba con comportamiento y no con un
/// source-scan: el store avisa cuando la racha cambia en disco. Sin esto, el 401 que llega con la pestaña Grupos
/// delante no se ve hasta salir y volver — medido en el simulador el 2026-09-15.
///
/// `.serialized` y con la tienda aislada, como sus vecinas del veredicto: el helper cambia un estático.
@MainActor
@Suite("Aviso de attest en la pestaña Grupos · el store avisa", .serialized)
struct GroupsAttestStreakNotificationTests {

    /// Cuenta los avisos que emite el store mientras vive.
    private final class Contador {
        private(set) var veces = 0
        private var token: (any NSObjectProtocol)?
        init() {
            token = NotificationCenter.default.addObserver(
                forName: GroupsAttestStreakStore.didChangeNotification,
                object: nil, queue: nil) { [self] _ in veces += 1 }
        }
        func stop() { if let token { NotificationCenter.default.removeObserver(token) }; token = nil }
    }

    @Test("MUTACIÓN: un rechazo que SE ESCRIBE avisa; uno de la misma hora, que no cambia nada, no")
    func rejectionsNotifyOnlyWhenTheStreakChanges() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let contador = Contador(); defer { contador.stop() }
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let hora = GroupsAttestVerdictLogic.countingInterval

        GroupsAttestStreakStore.recordRejection(now: t0)
        #expect(contador.veces == 1, "el primer rechazo escribió la racha y nadie se enteró")

        // Dentro de la MISMA hora la racha no cambia (`recordingRejection` devuelve la anterior), así que tampoco
        // hay nada que anunciar: un loop en backoff reintenta cada pocos minutos y avisaría sin información.
        GroupsAttestStreakStore.recordRejection(now: t0.addingTimeInterval(hora / 2))
        #expect(contador.veces == 1, "un rechazo que no suma avisó igual: el aviso dejó de significar «cambió»")

        GroupsAttestStreakStore.recordRejection(now: t0.addingTimeInterval(hora))
        #expect(contador.veces == 2, "el segundo rechazo contado no avisó")
    }

    @Test("MUTACIÓN: los tres relojes del seam de QA dejan la racha TERMINAL, y están en el borde")
    func theUITestSeedReallyReachesTheVerdict() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Los MISMOS tres relojes que `AppBootstrapper` usa con `-uitest-groups-attest-terminal`. El source-scan
        // de al lado fija que ese literal siga ahí; esto fija que signifique algo.
        for hoursAgo in [25.0, 24.0, 23.0] {
            GroupsAttestStreakStore.recordRejection(now: now.addingTimeInterval(-hoursAgo * 3600))
        }
        #expect(GroupsAttestStreakStore.isTerminal(now: now), """
            la siembra del XCUITest dejó de producir un veredicto terminal: sus dos casos medirían una pantalla \
            correcta y el rojo culparía al aviso.
            """)
        #expect(GroupsAttestStreakStore.current()?.rejections == 3, "los tres rechazos tienen que CONTAR, no solaparse")
        // **Está en el borde exacto**: 25 h → 24 h → 23 h deja exactamente `countingInterval` entre rechazos, así que
        // subir ese intervalo deja la racha en UN rechazo y el aviso no sale nunca. Si este `#expect` cae, el seam
        // necesita relojes nuevos — no es el aviso lo que se rompió.
        #expect(GroupsAttestVerdictLogic.countingInterval <= 3600, """
            el intervalo de conteo subió por encima de la hora: los relojes del seam de QA (25/24/23 h) dejaron de \
            contar tres rechazos.
            """)
    }

    @Test("MUTACIÓN: borrar la racha avisa, y borrarla cuando no hay nada no")
    func acceptanceNotifiesOnlyWhenThereWasAStreak() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let contador = Contador(); defer { contador.stop() }

        // Sin racha no hay nada que borrar ni nada que anunciar: `recordAcceptance` sale por su primer guard.
        GroupsAttestStreakStore.recordAcceptance()
        #expect(contador.veces == 0, "un acierto sin racha previa avisó de un cambio que no ocurrió")

        try racha.seedTerminal()
        GroupsAttestStreakStore.recordAcceptance()
        #expect(contador.veces == 1, """
            el acierto borró la racha sin avisar: la pestaña Grupos seguiría enseñando el aviso de un teléfono que \
            ya sincroniza.
            """)
        #expect(!GroupsAttestStreakStore.isTerminal(), "control: la racha se borró de verdad")
    }
}

// MARK: - 2 · El cableado (source-scan)

/// **Por qué source-scan y no una vista bajo test.** Las tres entradas se leen dentro de `GroupsContainerView`, que
/// es un `View` con seis `@Environment` y un `ModelContext` vivo; y lo que hay que fijar no es lo que la función pura
/// devuelve —eso ya está arriba— sino de dónde salen sus argumentos y en qué momentos se vuelve a preguntar. Un
/// mutante que cambie `hasLiveSession:` por `true`, o que borre una de las cuatro llamadas al recálculo, deja la
/// suite de arriba **entera en verde**.
@Suite("Aviso de attest en la pestaña Grupos · el cableado (source-scan)")
struct GroupsAttestTabNoticeWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador que ACABA en `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let tabPath = "Yala/App/Views/Groups/GroupsContainerView.swift"

    @Test("MUTACIÓN: el aviso lee sus CUATRO fuentes canónicas, y tres de ellas VIVAS")
    func theNoticeReadsAllFourSources() throws {
        let tab = try Self.source(Self.tabPath)
        let gate = Self.squashed(try Self.body(
            of: "private var showsAttestTerminalNotice: Bool {", in: tab))
        #expect(gate.contains(Self.squashed("""
            GroupsAttestTabNoticeLogic.showsNotice(
                verdictIsTerminal: attestVerdictIsTerminal,
                channelIsCompiled: CloudSyncFlags.groupsBackendCompiledCapability,
                hasLiveSession: CloudAuthService.shared.hasSession,
                hasGroupsConsent: GroupsConsentState.isAccepted)
            """)), """
            el aviso dejó de leer alguna de sus cuatro fuentes canónicas. Con `hasLiveSession:` fijo a `true`, el \
            tab le cuenta una avería de Grupos a quien ni siquiera tiene sesión.
            """)
        // **El canal va por la capacidad COMPILADA y no por el getter compuesto**, por lo mismo que los cuatro
        // teardowns de `CloudSignOutFlowLogic.path`: el término remoto es fail-closed ante un snapshot ausente, así
        // que el primer arranque de un teléfono restaurado —que hereda la racha y no la key de attest— se quedaba
        // SIN aviso mientras el cierre de sesión sí se lo enseñaba. Es el bug del ticket, y la review lo cazó vivo.
        #expect(!gate.contains("CloudSyncFlags.groupsBackendEnabled"), """
            el aviso volvió al getter COMPUESTO del canal: con el snapshot de remote-config ausente o corrupto se \
            apaga solo, y justo en el arranque donde más falta hace.
            """)
        // Y las tres vivas están en el `var` del body, no congeladas en el `@State`: ahí es donde se arregla que
        // iniciar sesión en caliente saque el aviso y que una sesión muerta lo retire.
        let refresh = Self.squashed(try Self.body(
            of: "private func refreshAttestTerminalNotice() {", in: tab))
        #expect(refresh.contains(Self.squashed("attestVerdictIsTerminal = GroupsAttestStreakStore.isTerminal()")),
                "el recálculo dejó de leer el veredicto, que es lo único que no se puede leer reactivamente")
        #expect(!refresh.contains("hasSession"), """
            la sesión volvió al `@State`: congelada ahí, iniciar sesión desde el CTA de la lista no saca el aviso \
            —ese sheet se cierra en sitio, sin `onAppear`— y una sesión que el SDK borra lo deja puesto.
            """)
    }

    @Test("MUTACIÓN: el aviso se pinta gateado por el estado, y cuelga del tab como `safeAreaInset`")
    func theBannerIsGatedAndMounted() throws {
        let tab = try Self.source(Self.tabPath)
        let banner = Self.squashed(try Self.body(
            of: "private var groupsAttestTerminalBanner: some View {", in: tab))
        #expect(banner.contains("if showsAttestTerminalNotice {"), """
            el aviso dejó de estar gateado por su estado: se pintaría siempre, también en el teléfono que sí sincroniza.
            """)
        #expect(banner.contains("L10n.Groups.Errors.attestUnavailableTitle"), """
            el aviso dejó de usar el MISMO título que los gestos que pueden perder algo: la avería pasaría a \
            llamarse de dos maneras distintas.
            """)
        #expect(banner.contains("L10n.Groups.attestTerminalBanner"), "el aviso perdió el cuerpo que dice qué hacer")
        #expect(banner.contains("accessibilityIdentifier(\"groups_attest_terminal_banner\")"),
                "sin su identificador, el XCUITest del aviso no lo encuentra y el rojo culpa a la pantalla")
        #expect(Self.squashed(tab).contains(
            Self.squashed(".safeAreaInset(edge: .top) { groupsAttestTerminalBanner }")), """
            el aviso dejó de colgar del tab: existe como vista y no lo monta nadie.
            """)
    }

    @Test("MUTACIÓN: el recálculo corre en los CINCO momentos, cada uno anclado a su sitio")
    func theRefreshRunsAtEveryObservableMoment() throws {
        let tab = try Self.source(Self.tabPath)
        // **Cada momento se ancla por su SITIO, y el conteo se queda solo como red contra una llamada de más.**
        // Contar a secas no distingue un momento de otro: mover la llamada de `case .active` al `.onDisappear`
        // deja el total en 5 y el test verde, con «volver de background» —el salto de reloj que hace terminal a
        // una racha de ayer— ya perdido. Cada llamada que falte es una ventana en la que el aviso se queda viejo.
        // La DECLARACIÓN lleva el mismo literal que las llamadas (`refreshAttestTerminalNotice()`), así que se
        // resta: contarla dentro daba 5 y escondía que una llamada se hubiera perdido. Lo cazó este mismo test.
        #expect(tab.contains("private func refreshAttestTerminalNotice() {"), "desapareció el recálculo entero")
        let apariciones = tab.components(separatedBy: "refreshAttestTerminalNotice()").count - 1
        let llamadas = apariciones - 1
        #expect(llamadas == 5, """
            el recálculo del aviso se llama \(llamadas) veces y deberían ser 5: entrar al tab, el refresco que ese \
            `onAppear` lanza, volver de background, el pull-to-refresh y el aviso del propio store.
            """)
        for (sitio, literal) in [
            // El `onAppear` aporta DOS momentos y van en un solo literal: el recálculo síncrono, que ya tiene la
            // racha de arranques anteriores, y el de dentro del `Task`, que llega cuando el refresco remoto
            // contesta. Anclarlos por separado no se puede —el primero es la misma llamada sin nada alrededor— y
            // un literal que solo dijera `viewModel.setContext(modelContext)` no ancla ningún recálculo.
            ("entrar al tab y al contestar su refresco", """
                Task {
                    await viewModel.refreshFromCloud(force: false)
                    refreshAttestTerminalNotice()
                }
                refreshAttestTerminalNotice()
                """),
            ("volver de background", """
                viewModel.setBackground(false)
                viewModel.reloadAndRecalculate()
                refreshAttestTerminalNotice()
                """),
            ("el pull-to-refresh", """
                .refreshable {
                    await viewModel.refreshFromCloud(force: true)
                    refreshAttestTerminalNotice()
                }
                """),
        ] {
            #expect(Self.squashed(tab).contains(Self.squashed(literal)),
                    "el recálculo del aviso ya no corre al \(sitio): ahí el aviso se queda viejo")
        }
        // **El quinto va aparte porque es el único que no depende de un gesto**, y sin él la pestaña se queda muda
        // mientras la persona la mira — que es justo cuando llega el 401. Medido en el simulador el 2026-09-15: con
        // la racha escrita un segundo después del arranque, el aviso NO salía hasta salir del tab y volver.
        #expect(Self.squashed(tab).contains(Self.squashed("""
            .onReceive(NotificationCenter.default.publisher(
                for: GroupsAttestStreakStore.didChangeNotification)) { _ in
                refreshAttestTerminalNotice()
            }
            """)), "la pestaña dejó de escuchar al store: el 401 que llega con el tab delante no se vería")
    }

    @Test("MUTACIÓN: el seam del XCUITest siembra la racha REAL, y bajo uitest vive fuera del almacén real")
    func theUITestSeamIsRealAndSelfCleaning() throws {
        let bootstrapper = Self.squashed(try Self.source("Yala/App/AppBootstrapper.swift"))
        #expect(bootstrapper.contains(Self.squashed("""
            if UITestHooks.groupsAttestTerminal {
                let now = Date.now
                for hoursAgo in [25.0, 24.0, 23.0] {
                    GroupsAttestStreakStore.recordRejection(now: now.addingTimeInterval(-hoursAgo * 3600))
                }
            }
            """)), "la siembra del veredicto dejó de escribir la racha por el camino de producción")
        // **Y el desvío, que es lo que impide que la racha sobreviva a la corrida.** Va en el arranque TEMPRANO y
        // no aquí: la racha no está en `DataWipeService.removeUserPreferenceKeys` a propósito —describe al
        // teléfono— así que `-uitest-reset` no la borra, y sin el desvío una corrida con el seam dejaba el
        // veredicto terminal puesto para todo arranque MANUAL del simulador y para el host de unit tests, que
        // comparte bundle. Lo cazó una lente adversarial el 2026-09-15.
        #expect(bootstrapper.contains("UITestEphemeralDefaults.applyEphemeralAttestStreak()"), """
            el arranque de uitest dejó de desviar la racha a su suite: vuelve a escribirse en el \
            `UserDefaults.standard` real del simulador, donde no la limpia nadie.
            """)
        let efimeros = Self.squashed(try Self.source("Yala/App/UITestEphemeralDefaults.swift"))
        #expect(efimeros.contains(Self.squashed("""
            defaults.removeObject(forKey: GroupsAttestStreakStore.key)
            guard let suite = UserDefaults(suiteName: suiteName) else { return }
            suite.removePersistentDomain(forName: suiteName)
            GroupsAttestStreakStore.defaults = suite
            """)), """
            el desvío perdió una de sus dos mitades: la purga es lo único que limpia los simuladores que ya \
            corrieron la versión anterior, y el desvío es lo que impide que esta corrida vuelva a ensuciarlo.
            """)
        // **La paridad del nombre del arg.** Con un typo a un lado, el seam vale `false`: el caso que prueba la
        // AUSENCIA del aviso —racha sí, sesión no— pasaría en verde sin haber sembrado nada que discriminar.
        let launcher = try Self.source("YalaUITests/Support/XCUIApplication+Yala.swift")
        let hooks = try Self.source("Yala/App/UITestHooks.swift")
        let arg = "-uitest-groups-attest-terminal"
        #expect(launcher.contains("args.append(\"\(arg)\")"), "el lanzador del XCUITest no pasa `\(arg)`")
        #expect(hooks.contains("hasArg(\"\(arg)\")"), "`UITestHooks` no lee `\(arg)`")
    }
}
