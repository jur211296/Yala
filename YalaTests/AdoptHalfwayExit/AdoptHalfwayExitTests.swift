//
//  AdoptHalfwayExitTests.swift
//  YalaTests / AdoptHalfwayExit
//
//  Lote del 13-nov (ticket `adopt-halfway-always-has-an-exit`): entrar con la cuenta a medias siempre tiene salida.
//   · gd78 — cerrar Yala en pleno «Conectando con tu cuenta» montaba el espejo de iCloud al reabrir (medido en el iPhone
//     14: import del iCloud privado, export a iCloud, «Cancelar la activación» apagado).
//   · 285z — un paso a medias de otro intento dejaba la entrada con Google en «Ahora mismo no podemos preparar este
//     dispositivo» para siempre (opción A de Jürgen: se deshace y se entra limpio).
//   · jxbp — la barra pasaba de 0 % a 60 % fijo y de ahí a «lista».
//
//  El arranque se simula con las mismas funciones puras que `SwiftDataConfiguration.personalConfiguration`, en su orden; el
//  cableado de producción se fija por source-scan, sin comentarios.
//

import Foundation
import Testing

@testable import Yala

@Suite("Entrada a medias · el arranque sigue neutro y retoma o deshace", .serialized)
@MainActor
struct AdoptHalfwayExitTests {

    private typealias Mount = SwiftDataConfiguration.PersonalStoreDecision

    /// Un arranque como el de producción: neutro de la instalación nueva, la marca del traspaso y la decisión de montaje.
    private static func launch(storeFileExists: Bool, _ defaults: UserDefaults) -> Mount {
        let fresh = SwiftDataConfiguration.isFreshInstallForNeutralMount(
            personalStoreFileExists: storeFileExists,
            persistedMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults),
            hasShownWelcomeChooser: defaults.bool(forKey: "hasShownWelcomeChooser"))
        StorageModePersistence.settleFreshInstallNeutralMount(
            freshInstall: fresh,
            hasCompletedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding"),
            defaults)
        WelcomeAdoptInFlight.settle(persistedMode: StorageModePersistence.read(defaults),
                                    mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults), defaults)
        return SwiftDataConfiguration.personalStoreDecision(
            storageMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults),
            iCloudAvailable: true,
            freshInstall: fresh,
            neutralDurable: SwiftDataConfiguration.shouldMountNeutralDurable(defaults))
    }

    /// Lo que hace la bienvenida hasta `onAdoptStarted`: «Entrar con Google» marca el chooser, y empezar el traspaso marca
    /// el onboarding y retira el neutro. `armsInFlight: false` es el código de antes del arreglo.
    private static func startAdoptFromWelcome(_ defaults: UserDefaults, armsInFlight: Bool) {
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        let snapshot = WelcomeAdoptBackOut.Snapshot.capture(
            hasCompletedOnboarding: false, hasPrivateSession: false, defaults)
        if armsInFlight {
            WelcomeAdoptInFlight.arm(snapshot: snapshot, provider: .google, defaults)
        }
        defaults.set(true, forKey: "hasCompletedOnboarding")
        StorageModePersistence.retireNeutralMountOnChoice(defaults)
    }

    // MARK: - gd78 · el montaje del arranque

    @Test("MUTACIÓN gd78: cerrar Yala a mitad del traspaso y reabrir sigue montando NEUTRO, sin espejo")
    func killMidAdopt_relaunchKeepsTheNeutralMount() {
        let defaults = makeIsolatedDefaults(prefix: "adopt.halfway.kill")
        #expect(Self.launch(storeFileExists: false, defaults) == .neutralNoMirror, "instalación nueva")
        Self.startAdoptFromWelcome(defaults, armsInFlight: true)
        #expect(Self.launch(storeFileExists: true, defaults) == .neutralNoMirror,
                "con el bug montaba el espejo de iCloud y exportaba lo bajado de la cuenta")
        #expect(Self.launch(storeFileExists: true, defaults) == .neutralNoMirror, "y al tercer arranque también")
    }

    @Test("Control gd78: sin la marca, el mismo recorrido monta el espejo (el bug medido en el iPhone 14)")
    func control_withoutTheMark_theRelaunchMirrors() {
        let defaults = makeIsolatedDefaults(prefix: "adopt.halfway.control")
        _ = Self.launch(storeFileExists: false, defaults)
        Self.startAdoptFromWelcome(defaults, armsInFlight: false)
        #expect(Self.launch(storeFileExists: true, defaults) == .iCloudMirror)
    }

    @Test("El par escrito retira la marca: el arranque monta en modo nube y la marca no sobrevive")
    func pairWritten_settlesTheMark() {
        let defaults = makeIsolatedDefaults(prefix: "adopt.halfway.landed")
        _ = Self.launch(storeFileExists: false, defaults)
        Self.startAdoptFromWelcome(defaults, armsInFlight: true)
        StorageModePersistence.writeCloudArmed(defaults: defaults)
        #expect(Self.launch(storeFileExists: true, defaults) == .cloudMirrorOff)
        #expect(!WelcomeAdoptInFlight.isArmed(defaults), "una marca superviviente decidiría el montaje tras volver a iCloud")
    }

    @Test("Confinada a iCloud sin armar: en la ventana del cutover (`.cloud` sin armar) no monta neutro")
    func mark_isInertOutsideTheVirginPair() {
        #expect(WelcomeAdoptInFlight.holdsNeutralMount(armed: true, persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!WelcomeAdoptInFlight.holdsNeutralMount(armed: true, persistedMode: .cloud, mirrorOffArmed: false))
        #expect(!WelcomeAdoptInFlight.holdsNeutralMount(armed: true, persistedMode: .icloud, mirrorOffArmed: true))
        #expect(!WelcomeAdoptInFlight.holdsNeutralMount(armed: false, persistedMode: .icloud, mirrorOffArmed: false))
    }

    @Test("La foto que se guarda es la del PRIMER intento, y el borrado se la lleva entera")
    func snapshot_isTheFirstOne_andTheWipeClearsIt() {
        let defaults = makeIsolatedDefaults(prefix: "adopt.halfway.snapshot")
        let first = WelcomeAdoptBackOut.Snapshot(hasCompletedOnboarding: false, hasPrivateSession: false,
                                                 neutralMountArmed: true, freshInstallOwnsNeutralMount: true)
        WelcomeAdoptInFlight.arm(snapshot: first, provider: .google, defaults)
        let retry = WelcomeAdoptBackOut.Snapshot(hasCompletedOnboarding: true, hasPrivateSession: true,
                                                 neutralMountArmed: false, freshInstallOwnsNeutralMount: false)
        WelcomeAdoptInFlight.arm(snapshot: retry, provider: .apple, defaults)
        #expect(WelcomeAdoptInFlight.snapshot(defaults) == first)
        #expect(WelcomeAdoptInFlight.provider(defaults) == .google)
        WelcomeAdoptInFlight.clear(defaults)
        #expect(WelcomeAdoptInFlight.snapshot(defaults) == nil)
        for key in WelcomeAdoptInFlight.allKeys { #expect(defaults.object(forKey: key) == nil, "\(key)") }
    }

    // MARK: - gd78 · qué hace el arranque con la marca

    @Test("Retoma todo lo que no sea una salida sin rastro; deshace solo una salida que no dejó nada")
    func relaunchRoute_table() {
        typealias R = WelcomeAdoptInFlight
        // Cierre antes del claim: la persona ya dijo «Cargar mis datos y entrar», se vuelve a pedir.
        #expect(R.relaunchRoute(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: nil, hasLocalData: false) == .resume)
        #expect(R.relaunchRoute(journaledPhase: .notStarted, adoptEffectJournaled: true, journalUnreadable: false,
                                adoptClaimExit: nil, hasLocalData: false) == .resume)
        #expect(R.relaunchRoute(journaledPhase: .claimingMigration, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: nil, hasLocalData: false) == .resume)
        #expect(R.relaunchRoute(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: true,
                                adoptClaimExit: nil, hasLocalData: false) == .release,
                "con el journal ilegible la pantalla no tenía salida: la app, como antes")
        // Salidas.
        #expect(R.relaunchRoute(journaledPhase: .failedRollback, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: nil, hasLocalData: false) == .backOut)
        #expect(R.relaunchRoute(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: .stalled, hasLocalData: true) == .backOut, "el claim no sube ni baja nada")
        #expect(R.relaunchRoute(journaledPhase: .failedRollback, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: .effectLocalFailure, hasLocalData: true) == .release,
                "MUTACIÓN review: con datos locales tras una salida no se retoma (volvía a reclamar la cuenta sola)")
        #expect(R.relaunchRoute(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: false,
                                adoptClaimExit: .cancelled, hasLocalData: true) == .release)
    }

    // MARK: - 285z · cancelar el paso a medias desde la puerta

    @Test("MUTACIÓN 285z: la puerta ofrece cancelar solo lo cancelable y con el par sin escribir")
    func staleCancel_offersOnlyWhatIsSafe() {
        typealias C = WelcomeStaleMigrationCancel
        #expect(C.offers(canCancelMigration: true, journalUnreadable: false, persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!C.offers(canCancelMigration: false, journalUnreadable: false, persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!C.offers(canCancelMigration: true, journalUnreadable: true, persistedMode: .icloud, mirrorOffArmed: false))
        #expect(!C.offers(canCancelMigration: true, journalUnreadable: false, persistedMode: .cloud, mirrorOffArmed: true),
                "con el par escrito el paso ya hizo lo irreversible")
        #expect(!C.offers(canCancelMigration: true, journalUnreadable: false, persistedMode: .icloud, mirrorOffArmed: true))
    }

    @Test("La cancelación aterrizó cuando el journal ya no tiene nada en vuelo")
    func staleCancel_landed() {
        typealias C = WelcomeStaleMigrationCancel
        #expect(C.landed(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: false))
        #expect(C.landed(journaledPhase: .failedRollback, adoptEffectJournaled: false, journalUnreadable: false))
        #expect(!C.landed(journaledPhase: .notStarted, adoptEffectJournaled: true, journalUnreadable: false))
        #expect(!C.landed(journaledPhase: .claimingMigration, adoptEffectJournaled: false, journalUnreadable: false))
        #expect(!C.landed(journaledPhase: .notStarted, adoptEffectJournaled: false, journalUnreadable: true))
    }

    // MARK: - jxbp · la barra

    @Test("MUTACIÓN jxbp: el efecto del adopt avanza por pasos reales, de 25 % a 95 %, y la lectura con su cifra")
    func adoptProgress_advancesWithRealWork() {
        let stages = AdoptEffectProgress.Stage.allCases.map { AdoptEffectProgress(stage: $0, rowsRead: 0, rowsExpected: 100) }
        let fractions = stages.map(\.fraction)
        #expect(fractions == fractions.sorted(), "los pasos van en orden")
        #expect(Set(fractions).count == fractions.count, "cada paso mueve la barra")
        #expect(fractions.first == AdoptEffectProgress.startFraction)
        #expect((fractions.last ?? 1) < 1, "«lista» la pone el terminal, no el efecto")
        var reading = AdoptEffectProgress(stage: .readingAccount, rowsRead: 0, rowsExpected: 5_000)
        let atStart = reading.fraction
        reading.rowsRead = 2_500
        let half = reading.fraction
        reading.rowsRead = 9_000
        #expect(atStart < half && half < reading.fraction)
        #expect(reading.fraction == AdoptEffectProgress.readingEnd, "más filas que el Merkle (borradas) no se pasa del tramo")
        #expect(AdoptEffectProgress(stage: .readingAccount, rowsRead: 300, rowsExpected: nil).fraction
                == AdoptEffectProgress.readingStart, "sin cifra del Merkle la lectura no inventa avance")
    }

    @Test("La pantalla toma el paso real del runner, y sin él no salta al 60 %")
    func derive_usesTheRealStep() {
        let mid = AdoptEffectProgress(stage: .readingAccount, rowsRead: 50, rowsExpected: 100)
        let state = CloudMigrationUIStateDeriver.derive(
            storageMode: .icloud, phase: .notStarted, mirrorOffArmed: false, mountedDecision: .neutralNoMirror,
            adoptEffectJournaled: true, adoptProgress: mid)
        #expect(state == .migrating(MigrationUIStep(fraction: mid.fraction, phase: .notStarted)))
        let unknown = CloudMigrationUIStateDeriver.derive(
            storageMode: .icloud, phase: .notStarted, mirrorOffArmed: false, mountedDecision: .neutralNoMirror,
            adoptEffectJournaled: true)
        #expect(unknown == .migrating(MigrationUIStep(fraction: AdoptEffectProgress.startFraction, phase: .notStarted)))
        #expect(CloudMigrationUIStateDeriver.adoptEffectFraction > CloudMigrationUIStateDeriver.fraction(for: .claimingMigration))
    }

    @Test("La barra no retrocede cuando un reintento vuelve al primer paso")
    func displayed_neverGoesBack() {
        #expect(AdoptEffectProgress.displayed(previous: nil, next: 0.25) == 0.25)
        #expect(AdoptEffectProgress.displayed(previous: 0.8, next: 0.25) == 0.8)
        #expect(AdoptEffectProgress.displayed(previous: 0.3, next: 0.5) == 0.5)
        #expect(AdoptEffectProgress.expectedRows(merkleCounts: [5_438, 13, -1, 138]) == 5_589)
    }
}

// MARK: - Cableado de producción

@Suite("Entrada a medias · cableado (source-scan)")
struct AdoptHalfwayExitWiringTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Sin las líneas de comentario: documentar el arreglo no puede contar como el arreglo.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("MUTACIÓN gd78: `onAdoptStarted` arma la marca ANTES de marcar el onboarding y retirar el neutro")
    func onAdoptStarted_armsBeforeMarking() throws {
        let view = try Self.code("Yala/App/ContentView.swift")
        let start = try #require(view.range(of: "onAdoptStarted: {"))
        let arm = try #require(view.range(of: "WelcomeAdoptInFlight.arm(snapshot:", range: start.upperBound..<view.endIndex))
        let onboarding = try #require(view.range(of: "hasCompletedOnboarding = true", range: start.upperBound..<view.endIndex))
        let retire = try #require(view.range(of: "StorageModePersistence.retireNeutralMountOnChoice()",
                                             range: start.upperBound..<view.endIndex))
        #expect(arm.lowerBound < onboarding.lowerBound)
        #expect(arm.lowerBound < retire.lowerBound)
    }

    @Test("MUTACIÓN gd78: el adaptador del montaje suma la marca, y el montaje asienta la marca antes de decidir")
    func mountAdapter_includesTheMark() throws {
        let config = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        let adapterStart = try #require(config.range(
            of: "static func shouldMountNeutralDurable(_ defaults: UserDefaults = .standard) -> Bool {"))
        let adapterEnd = try #require(config.range(of: "\n    }", range: adapterStart.upperBound..<config.endIndex))
        let adapter = String(config[adapterStart.upperBound..<adapterEnd.lowerBound])
        #expect(adapter.contains("WelcomeAdoptInFlight.holdsNeutralMount("))
        let settle = try #require(config.range(of: "WelcomeAdoptInFlight.settle("))
        let decide = try #require(config.range(of: "neutralDurable: shouldMountNeutralDurable())"))
        #expect(settle.lowerBound < decide.lowerBound)
    }

    @Test("El arranque con la marca vuelve a la pantalla de conexión ANTES de aterrizar en la app")
    func boot_resumesBeforeLandingInTheApp() throws {
        let view = try Self.code("Yala/App/ContentView.swift")
        let check = try #require(view.range(of: "private func checkInitialSyncState() async {"))
        let resume = try #require(view.range(of: "if resumeWelcomeAdoptAfterRelaunch() {",
                                             range: check.upperBound..<view.endIndex))
        let returning = try #require(view.range(of: "runReturningUserPostChecks()", range: check.upperBound..<view.endIndex))
        #expect(resume.lowerBound < returning.lowerBound)
        #expect(view.contains("resumesAdopt: welcomeCloudResumesAdopt,"))
    }

    @Test("La salida hacia atrás usa la foto durable cuando el cierre se llevó la del `@State`")
    func backOut_readsTheDurableSnapshot() throws {
        let view = try Self.code("Yala/App/ContentView.swift")
        #expect(view.contains("guard let snapshot = adoptStartSnapshot ?? WelcomeAdoptInFlight.snapshot() else { return }"))
    }

    @Test("El borrado se lleva la marca entera")
    func wipe_clearsTheMark() throws {
        let wipe = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("for key in WelcomeAdoptInFlight.allKeys { defaults.removeObject(forKey: key) }"))
    }

    @Test("MUTACIÓN jxbp: la pantalla conduce y refresca a la vez en las dos entradas del adopt")
    func welcome_drivesWhilePolling() throws {
        let view = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(!view.contains("sessionOpenedByThisAttempt: sessionOpenedHere)\n                await pollAdoptProgress()"),
                "el poll esperaba al drive: la barra se quedaba en 0 % todo el traspaso")
        #expect(view.components(separatedBy: "await driveWhilePolling {").count - 1 == 3)
        // Review: el drive en su propia tarea (cancelar no lo corta) y el sondeo no se va a un fallo con el drive en vuelo.
        #expect(view.contains("let driving = Task { @MainActor in"))
        #expect(view.contains("if controller.isWorking, CloudWelcomeSignInFlow.isFailureTerminal(next) {"))
    }

    @Test("El aviso «iCloud disponible» calla mientras la marca sostiene el neutro")
    func iCloudMismatch_staysQuietWhileHeld() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("guard !WelcomeAdoptInFlight.holdsNeutralMount() else { return }"))
    }

    @Test("MUTACIÓN 285z: el aviso del paso a medias de la puerta ofrece cancelarlo")
    func gate_offersTheStaleCancel() throws {
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(gate.contains("if WelcomeStaleMigrationCancel.offers(controller: CloudMigrationController.shared) {"))
        #expect(gate.contains("phase = .cancellingStaleMigration(intento: intento)"))
        #expect(gate.contains("await cancelStaleMigration()"))
    }
}

@Suite("Entrada a medias · «Cancelar la activación» con el efecto en vuelo")
struct AdoptHalfwayCancelEnabledTests {

    @Test("MUTACIÓN gd78: con el efecto del adopt en vuelo el botón se toca; con otra pasada del runner, no")
    func cancel_isReachableDuringTheAdoptEffect() {
        #expect(MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: false, cancelling: false,
                                                       adoptEffectPending: true))
        #expect(!MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: false, cancelling: false,
                                                        adoptEffectPending: false), "control: una subida en vuelo sigue igual")
        #expect(!MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: false, cancelling: true,
                                                        adoptEffectPending: true), "un segundo toque no corta el primero")
    }
}

@Suite("Entrada a medias · lo que cazó la review")
@MainActor
struct AdoptHalfwayReviewTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Los finales de fallo que el sondeo ignora con el drive en vuelo, y solo esos")
    func failureTerminals() {
        #expect(CloudWelcomeSignInFlow.isFailureTerminal(.error(retryable: true)))
        #expect(CloudWelcomeSignInFlow.isFailureTerminal(.accountBlocked))
        #expect(CloudWelcomeSignInFlow.isFailureTerminal(.adoptExit(.effectStalled)))
        #expect(!CloudWelcomeSignInFlow.isFailureTerminal(.reentryReady))
        #expect(!CloudWelcomeSignInFlow.isFailureTerminal(.relaunch))
        #expect(!CloudWelcomeSignInFlow.isFailureTerminal(.adopting(fraction: 0.5)))
    }

    @Test("MUTACIÓN review: la puerta retira la marca solo si la cancelación aterrizó")
    func gate_clearsTheMarkOnlyWhenLanded() throws {
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(gate.contains("if landed { WelcomeAdoptInFlight.clear() }"))
        #expect(gate.contains("Task { @MainActor in await controller.cancelMigration() }"))
    }

    @Test("MUTACIÓN review: «Continuar a la app» solo retira la marca con el par escrito, y una salida la retira siempre")
    func contentView_lifecycle() throws {
        let view = try Self.code("Yala/App/ContentView.swift")
        let finished = try #require(view.range(of: "onFinishedToApp: {"))
        let end = try #require(view.range(of: "onBornCloudCompleted: {", range: finished.upperBound..<view.endIndex))
        let tail = String(view[finished.upperBound..<end.lowerBound])
        #expect(tail.contains("WelcomeAdoptInFlight.settle(persistedMode: StorageModePersistence.read(),"))
        #expect(!tail.contains("WelcomeAdoptInFlight.clear()"))
        #expect(view.contains("if adoptStartSnapshot == nil, let durable = WelcomeAdoptInFlight.snapshot() {"))
        let restore = try #require(view.range(of: "private func restoreStateIfAdoptLeftNoTrace() {"))
        let body = String(view[restore.upperBound...].prefix(1500))
        let landed = try #require(body.range(of: "if WelcomeStaleMigrationCancel.landed("))
        let leftNoTrace = try #require(body.range(of: "guard WelcomeAdoptBackOut.leftNoTrace("))
        #expect(landed.lowerBound < leftNoTrace.lowerBound, "la salida se reconoce antes de decidir si se deshace")
    }

    @Test("La lectura de la cuenta cuenta solo filas vivas, como el Merkle")
    func reading_countsLiveRows() throws {
        let exec = try Self.code("Yala/Services/CloudSync/MigrationWorkExecutor.swift")
        #expect(exec.contains("onPage?(page.deltas.lazy.filter { $0.op != .tombstone }.count)"))
        #expect(exec.contains("defer { adoptEffectProgress = nil }"))
    }
}
