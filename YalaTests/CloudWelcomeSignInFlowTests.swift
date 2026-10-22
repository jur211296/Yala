//
//  CloudWelcomeSignInFlowTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Welcome sign-in nube — ruteo de /account/exists")
struct CloudWelcomeSignInFlowExistsRouteTests {

    @Test
    func existsTrue_conKindCompleta_accountFoundLoTransporta() {
        #expect(CloudWelcomeSignInFlow.route(.exists(true, kind: .complete)) == .accountFound(kind: .complete))
    }

    @Test
    func existsTrue_conKindSoloGrupos_accountFoundLoTransporta() {
        #expect(CloudWelcomeSignInFlow.route(.exists(true, kind: .groupsOnly)) == .accountFound(kind: .groupsOnly))
    }

    /// El caso que sostiene la compatibilidad: un gateway anterior a g15_01 no manda `kind`, y eso
    /// NO puede convertirse en un error de ruteo — sería un callejón con «reintentar» en el sign-in
    /// de todos los clientes ya publicados. La cuenta se encuentra igual; qué se asume entonces lo
    /// decide `AccountKindLogic.resolve`, no este switch.
    @Test
    func existsTrue_sinKind_sigueSiendoAccountFound() {
        #expect(CloudWelcomeSignInFlow.route(.exists(true, kind: nil)) == .accountFound(kind: nil))
    }

    @Test
    func existsFalse_accountMissing() {
        #expect(CloudWelcomeSignInFlow.route(.exists(false, kind: nil)) == .accountMissing)
    }

    /// Una cuenta que no existe no tiene tipo: si el servidor mandara uno, se ignora. Sin este caso,
    /// un `kind` colado en un `exists:false` podría rutear a «cuenta encontrada».
    @Test
    func existsFalse_conKindDespistado_sigueSiendoAccountMissing() {
        #expect(CloudWelcomeSignInFlow.route(.exists(false, kind: .complete)) == .accountMissing)
    }

    @Test
    func sessionExpired_failsRetryable() {
        #expect(CloudWelcomeSignInFlow.route(
            .sessionExpired(detail: "401")
        ) == .failed(retryable: true))
    }

    @Test
    func transient_failsRetryable() {
        #expect(CloudWelcomeSignInFlow.route(
            .transient(detail: "network")
        ) == .failed(retryable: true))
    }
}

@Suite("Welcome sign-in nube — fase de pantalla por uiState")
struct CloudWelcomeSignInFlowPhaseTests {

    @Test
    func idle_isAdoptingAtZero() {
        // Fases consent/authenticating no-durables → el deriver reporta .idle.
        #expect(CloudWelcomeSignInFlow.phase(for: .idle) == .adopting(fraction: 0))
    }

    @Test
    func migrating_mapsFraction() {
        let step = MigrationUIStep(fraction: 0.45, phase: .claimingMigration)
        #expect(CloudWelcomeSignInFlow.phase(for: .migrating(step)) == .adopting(fraction: 0.45))
    }

    @Test
    func needsRelaunchToCloud_isRelaunch() {
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toCloud)) == .relaunch)
    }

    /// Decisión owner 2026-09-06: `.cloudActive` es una terminal de LISTA, no de relanzamiento.
    /// Llegar ahí significa que el store montado no tiene mirror que remontar (si lo tuviera, el
    /// deriver habría dado `.needsRelaunch(.toCloud)`, fijado por el test de arriba), así que pedir
    /// «cierra y reabre Yala» cobraba un relanzamiento que no hace falta.
    @Test
    func cloudActive_isReady_notRelaunch() {
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive) == .reentryReady)
    }

    /// `.reentryReady` y `.bornCloudReady` comparten pantalla pero NO salida, y por eso son fases
    /// distintas: quien re-entra llega con `hasCompletedOnboarding` ya marcado por `onAdoptStarted`
    /// (para que el seed no corra sobre una cuenta existente) y su siguiente pantalla es la app. Si
    /// alguien las colapsa, el adopt acabaría mandando al onboarding de 8 pasos a un usuario con
    /// datos — cuenta duplicada y categorías sembradas, subiendo por el motor que ya arrancó.
    @Test("El adopt jamás produce la terminal del ALTA")
    func adoptNeverProducesTheSignUpTerminal() {
        for uiState in [CloudMigrationUIState.cloudActive, .needsRelaunch(.toCloud)] {
            #expect(CloudWelcomeSignInFlow.phase(for: uiState) != .bornCloudReady)
        }
    }

    /// El par que se lee junto: son los dos desenlaces del MISMO adopt y lo que los separa es el
    /// mount. Escribirlos en un solo test es lo que impide que alguien "unifique" las dos terminales
    /// y devuelva a la re-entrada su «reinicia Yala».
    @Test("Las dos terminales del adopt se distinguen por el mount, no por el camino")
    func adoptTerminals_splitByMount() {
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toCloud)) == .relaunch)
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive) == .reentryReady)
    }

    @Test
    func waitingForLeader_isWaitingLeader() {
        #expect(CloudWelcomeSignInFlow.phase(for: .waitingForLeader) == .waitingLeader)
    }

    @Test
    func failed_isRetryableError() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration)) == .error(retryable: true))
    }

    @Test
    func reverseStates_degradeToNonRetryableError() {
        let step = MigrationUIStep(fraction: 0.5, phase: .reverseDrainAll)
        #expect(CloudWelcomeSignInFlow.phase(for: .reverting(step)) == .error(retryable: false))
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toICloud)) == .error(retryable: false))
    }
}

// MARK: - §3 del ticket `reentry-counts-as-fresh-install` · el claim aparcado por cuenta, no por red

/// Antes de esto, un 403 en el claim del adopt dejaba el journal en `claimingMigration` —fase
/// transicional perfectamente normal— así que el `uiState` seguía diciendo `.migrating` y la pantalla
/// se quedaba en «Conectando con tu cuenta…» para siempre, con el auto-resume gastando sus tres
/// intentos y ofreciendo después un botón de reintentar que no podía funcionar.
@Suite("Welcome sign-in nube — el claim bloqueado gana sobre el progreso")
struct CloudWelcomeSignInFlowClaimBlockerTests {

    private let midAdopt = CloudMigrationUIState.migrating(
        MigrationUIStep(fraction: 0.22, phase: .claimingMigration))

    @Test("403 a mitad del adopt → pantalla de cuenta bloqueada, no «Conectando…»")
    func accountUnavailable_beatsProgress() {
        #expect(CloudWelcomeSignInFlow.phase(for: midAdopt, claimBlocker: .accountUnavailable)
                == .accountBlocked)
    }

    @Test("Sin bloqueo, el mismo uiState sigue siendo progreso (control del test de arriba)")
    func noBlocker_staysAdopting() {
        #expect(CloudWelcomeSignInFlow.phase(for: midAdopt, claimBlocker: nil)
                == .adopting(fraction: 0.22))
    }

    @Test("401 sí es reintentable: volver a entrar rehace la sesión")
    func sessionExpired_isRetryable() {
        #expect(CloudWelcomeSignInFlow.phase(for: midAdopt, claimBlocker: .sessionExpired)
                == .error(retryable: true))
    }

    /// La red NO produce blocker (el runner lo deja en `nil` ante `transient`), así que la barra de
    /// progreso se queda donde estaba y el auto-resume hace su trabajo. Este test fija el contrato
    /// desde el lado de la pantalla: si algún día `transient` empezara a marcar blocker, aquí se ve.
    @Test("Un adopt esperando por red no se convierte en pantalla de fallo")
    func networkParked_staysAdopting() {
        #expect(CloudWelcomeSignInFlow.phase(for: .idle, claimBlocker: nil)
                == .adopting(fraction: 0))
    }

    @Test("Un bloqueo de un intento viejo NO tapa un adopt que ya terminó")
    func terminalsWin_overStaleBlocker() {
        #expect(CloudWelcomeSignInFlow.phase(for: .needsRelaunch(.toCloud),
                                             claimBlocker: .accountUnavailable) == .relaunch)
        // Lo que este caso fija es que el blocker NO gana sobre un terminal de éxito; cuál de los dos
        // terminales sea es cosa del mount (ver `adoptTerminals_splitByMount`).
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive,
                                             claimBlocker: .accountUnavailable) == .reentryReady)
    }

    @Test("El seguidor que espera a otro device también reporta el bloqueo (mismo POST, mismo 403)")
    func waitingForLeader_reportsBlocker() {
        #expect(CloudWelcomeSignInFlow.phase(for: .waitingForLeader,
                                             claimBlocker: .accountUnavailable) == .accountBlocked)
    }
}

// MARK: - H-2026-07-17-5 · detector de adopt aparcado

@Suite("Welcome adopt — auto-resume del drive aparcado (H-2026-07-17-5)")
struct WelcomeAdoptAutoResumeTests {

    private typealias SUT = WelcomeAdoptAutoResume

    /// Aplica N ticks idénticos y devuelve (estado final, fires acumulados).
    private func run(
        ticks: Int,
        isAdopting: Bool = true,
        isWorking: Bool = false,
        machineAdvanced: Bool = false,
        from state: SUT.State = .init()
    ) -> (state: SUT.State, fires: Int) {
        var current = state
        var fires = 0
        for _ in 0..<ticks {
            let (next, fire) = SUT.tick(
                isAdopting: isAdopting, isWorking: isWorking,
                machineAdvanced: machineAdvanced, state: current)
            current = next
            if fire { fires += 1 }
        }
        return (current, fires)
    }

    @Test
    func healthyDrive_neverFires_andHoldsIdleTicksAtZero() {
        // isWorking=true (drive en curso) N ticks → jamás fire; attempts se CONSERVA.
        let seeded = SUT.State(idleTicks: 2, attempts: 1, showManualRetry: false)
        let result = run(ticks: 10, isWorking: true, from: seeded)
        #expect(result.fires == 0)
        #expect(result.state.idleTicks == 0)
        #expect(result.state.attempts == 1)
    }

    @Test
    func nonAdoptingPhase_resetsIdleTicks_neverFires() {
        let seeded = SUT.State(idleTicks: 3, attempts: 0, showManualRetry: false)
        let result = run(ticks: 5, isAdopting: false, from: seeded)
        #expect(result.fires == 0)
        #expect(result.state.idleTicks == 0)
    }

    @Test
    func parked_firesAtThreshold_notBefore() {
        // Ticks 1…3: acumula sin fire. Tick 4 (== idleTicksBeforeResume): fire, attempts=1.
        let before = run(ticks: SUT.idleTicksBeforeResume - 1)
        #expect(before.fires == 0)
        #expect(before.state.idleTicks == SUT.idleTicksBeforeResume - 1)

        let (after, fired) = SUT.tick(
            isAdopting: true, isWorking: false, machineAdvanced: false, state: before.state)
        #expect(fired)
        #expect(after.attempts == 1)
        #expect(after.idleTicks == 0)
        #expect(!after.showManualRetry)
    }

    @Test
    func parkedForever_exhaustsAutos_thenSurfacesManualRetry_andNeverFiresAgain() {
        // 3 autos (maxAutoAttempts) → el 4º umbral muestra el botón SIN fire; después, nunca más.
        let ticksToExhaust = SUT.idleTicksBeforeResume * SUT.maxAutoAttempts
        let exhausted = run(ticks: ticksToExhaust)
        #expect(exhausted.fires == SUT.maxAutoAttempts)
        #expect(exhausted.state.attempts == SUT.maxAutoAttempts)
        #expect(!exhausted.state.showManualRetry)

        let surfaced = run(ticks: SUT.idleTicksBeforeResume, from: exhausted.state)
        #expect(surfaced.fires == 0)
        #expect(surfaced.state.showManualRetry)

        // Aparcada perpetua con el botón visible → jamás vuelve a fire.
        let perpetual = run(ticks: SUT.idleTicksBeforeResume * 5, from: surfaced.state)
        #expect(perpetual.fires == 0)
        #expect(perpetual.state.showManualRetry)
    }

    @Test
    func machineAdvanced_resetsAttempts_andHidesManualRetry() {
        let seeded = SUT.State(idleTicks: 2, attempts: SUT.maxAutoAttempts, showManualRetry: true)
        let (next, fired) = SUT.tick(
            isAdopting: true, isWorking: false, machineAdvanced: true, state: seeded)
        #expect(!fired)
        #expect(next.attempts == 0)
        #expect(!next.showManualRetry)
        // Con intentos frescos, un park posterior vuelve a auto-resumir.
        let reparked = run(ticks: SUT.idleTicksBeforeResume, from: next)
        #expect(reparked.fires == 1)
        #expect(reparked.state.attempts == 1)
    }

    @Test
    func advancedWhileWorking_resetsAttempts_butNoIdleAccumulation() {
        // Avance observado con el drive aún en curso: intentos frescos, racha ociosa en 0.
        let seeded = SUT.State(idleTicks: 3, attempts: 2, showManualRetry: false)
        let (next, fired) = SUT.tick(
            isAdopting: true, isWorking: true, machineAdvanced: true, state: seeded)
        #expect(!fired)
        #expect(next.attempts == 0)
        #expect(next.idleTicks == 0)
    }

    @Test
    func intermittentWorking_preservesAttempts_restartsIdleStreak() {
        // Park (fire 1) → un tick working (resume en vuelo, NO avance) → park de nuevo:
        // attempts se conserva y la racha ociosa arranca de cero.
        let first = run(ticks: SUT.idleTicksBeforeResume)
        #expect(first.fires == 1)
        let working = run(ticks: 1, isWorking: true, from: first.state)
        #expect(working.state.attempts == 1)
        #expect(working.state.idleTicks == 0)
        let second = run(ticks: SUT.idleTicksBeforeResume, from: working.state)
        #expect(second.fires == 1)
        #expect(second.state.attempts == 2)
    }
}

/// Ticket `born-cloud-signup-lands-on-existing-account-silently` (decisión de Jürgen del 2026-10-07). «Crear otra cuenta» con
/// un Apple ID que ya tenía una entra en ella —el claim contesta `existing_stable` y el alta sigue por la re-entrada—, y
/// hasta este ticket terminaba en `.reentryReady`: «¡Tu cuenta está lista!» después de «Creando tu cuenta…». Ahora la
/// terminal de ese camino dice «Ya tenías una cuenta, has entrado en ella»; la re-entrada normal no cambia.
@Suite("Welcome · el alta que entra en una cuenta que ya existía lo dice")
struct WelcomeSignUpEnteredExistingAccountTests {

    @Test("El alta que encontró la cuenta creada termina en su propia fase; la re-entrada, en la de siempre")
    func cloudActive_splitsByOrigin() {
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive, origin: .signUpFoundExistingAccount)
                == .signUpEnteredExistingAccount)
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive, origin: .reentry) == .reentryReady)
        // Sin origen es la re-entrada: los llamadores de antes (Almacenamiento no pasa por aquí) no cambian.
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive) == .reentryReady)
    }

    /// El origen solo elige el título de la terminal de «listo». El progreso, los fallos, la espera al líder y el
    /// relanzamiento son los mismos venga de donde venga el adopt.
    @Test("Fuera de `.cloudActive`, el origen no cambia nada")
    func otherStates_ignoreTheOrigin() {
        let step = MigrationUIStep(fraction: 0.4, phase: .claimingMigration)
        let states: [CloudMigrationUIState] = [
            .idle, .migrating(step), .reverting(step), .needsRelaunch(.toCloud), .needsRelaunch(.toICloud),
            .waitingForLeader, .failed(.migration), .failed(.reverse), .journalUnreadable,
        ]
        for state in states {
            #expect(CloudWelcomeSignInFlow.phase(for: state, origin: .signUpFoundExistingAccount)
                    == CloudWelcomeSignInFlow.phase(for: state, origin: .reentry), "\(state)")
            for blocker in [ClaimBlocker.accountUnavailable, .sessionExpired] {
                #expect(CloudWelcomeSignInFlow.phase(for: state, claimBlocker: blocker, origin: .signUpFoundExistingAccount)
                        == CloudWelcomeSignInFlow.phase(for: state, claimBlocker: blocker, origin: .reentry),
                        "\(state) · \(blocker)")
            }
        }
    }

    /// Un bloqueo viejo no tapa un final que ya ocurrió (`CloudWelcomeSignInFlowClaimBlockerTests`), tampoco en el alta.
    @Test func cloudActive_withAStaleBlocker_stillSaysItEnteredTheExistingAccount() {
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive, claimBlocker: .accountUnavailable,
                                             origin: .signUpFoundExistingAccount) == .signUpEnteredExistingAccount)
    }

    /// El alta no siembra encima de una cuenta viva: `existing_stable` sigue yendo a la re-entrada, y la terminal del alta
    /// de verdad (`.bornCloudReady`) no la produce nunca el adopt.
    @Test func theRoutingStaysTheSame() {
        #expect(BornCloudSignUpFlow.step(for: .routeReturningUser) == .continueAsReturningUser)
        for state in [CloudMigrationUIState.cloudActive, .needsRelaunch(.toCloud)] {
            #expect(CloudWelcomeSignInFlow.phase(for: state, origin: .signUpFoundExistingAccount) != .bornCloudReady)
        }
    }

    /// **El texto, en los 16 idiomas.** El de esta terminal no puede ser el de «¡Tu cuenta está lista!», y en español es
    /// la frase de Jürgen tal cual. Se lee del fichero de cada locale, porque la corrida solo ve uno.
    @Test func copy_inEveryLocale_isItsOwn() throws {
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let existing = try #require(table["welcome.bornCloud.readyExistingAccountTitle"], "\(locale)")
            let ready = try #require(table["welcome.bornCloud.readyTitle"], "\(locale)")
            #expect(!existing.isEmpty && !existing.contains("NEEDS_TRANSLATION"), "\(locale)")
            #expect(existing != ready, "\(locale): repite «\(ready)»")
            if locale.hasPrefix("es") {
                #expect(existing == "Ya tenías una cuenta, has entrado en ella", "\(locale)")
            }
        }
    }

    /// **El cableado de la pantalla**, que la lógica pura no ve: solo el alta que encontró la cuenta pasa el origen, el
    /// poll lo usa, y la terminal pinta el título nuevo con la salida de la re-entrada (`onFinishedToApp`: el flag de
    /// onboarding ya lo marcó `onAdoptStarted`, y el onboarding de 8 pasos sembraría encima de la cuenta).
    @Test func viewWiring() throws {
        let source = try String(contentsOf: Self.repoRoot.appendingPathComponent(
            "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"), encoding: .utf8)
        let branch = try #require(Self.slice(source, from: "case .continueAsReturningUser:", to: "case .show("))
        #expect(branch.contains("await runSignInFlow(origin: .signUpFoundExistingAccount)"))
        #expect(source.components(separatedBy: "origin: .signUpFoundExistingAccount").count == 2, "un solo llamador lo pasa")
        let flow = try #require(Self.slice(source, from: "private func runSignInFlow(origin: WelcomeAdoptOrigin) async {",
                                           to: "phase = .checking"))
        #expect(flow.contains("adoptOrigin = origin"))
        let poll = try #require(Self.slice(source, from: "private func pollAdoptProgress() async {", to: ") else {"))
        #expect(poll.contains("origin: adoptOrigin"))
        let screen = try #require(Self.slice(source, from: "private var signUpEnteredExistingAccountContent: some View {",
                                             to: "\n    }"))
        #expect(screen.contains("L10n.Welcome.BornCloud.readyExistingAccountTitle"))
        #expect(screen.contains("action: onFinishedToApp"))
        let reentry = try #require(Self.slice(source, from: "private var reentryReadyContent: some View {", to: "\n    }"))
        #expect(reentry.contains("title: L10n.Welcome.BornCloud.readyTitle"))
    }

    private static func slice(_ source: String, from start: String, to end: String) -> String? {
        guard let lower = source.range(of: start) else { return nil }
        guard let upper = source.range(of: end, range: lower.upperBound..<source.endIndex) else { return nil }
        return String(source[lower.lowerBound..<upper.upperBound])
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}
