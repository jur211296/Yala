//
//  AdoptSessionOwnershipTests.swift
//  YalaTests / CloudSync
//
//  La sesión que abrió un adopt se cierra cuando el adopt sale (ticket `adopt-exit-keeps-the-session-it-opened`, decisión A
//  de Jürgen del 2026-09-23). La decisión es pura (`AdoptSessionOwnership`) y se prueba con su tabla; el cableado —el
//  controller tiene `init` privado y firma con `CloudAuthService.shared`, la bienvenida es SwiftUI— va por source-scan con
//  los cuerpos ENTEROS, como `MigrationIdentityGateWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("La sesión que abrió un adopt: cuándo se cierra")
struct AdoptSessionOwnershipLogicTests {

    private static let cuenta = "hash-de-la-cuenta-A"
    private static let otra = "hash-de-la-cuenta-B"

    private static func decide(
        owned: String? = cuenta, session: String? = cuenta, phase: MigrationPhase,
        effectPending: Bool = false, cloud: Bool = false
    ) -> AdoptSessionOwnership.Decision {
        AdoptSessionOwnership.decide(
            ownedAccountHash: owned, sessionAccountHash: session, phase: phase,
            adoptEffectPending: effectPending, persistedCloudMode: cloud)
    }

    // MARK: - Salidas: se cierra

    /// El control positivo de todo el suite: el techo de cualquier paso deja `failedRollback`, y con la sesión de ESA cuenta
    /// se cierra. Sin él, los `keep` de abajo pasarían con un `decide` que no cerrara nunca.
    @Test func ceilingExit_closesTheSessionItOpened() {
        #expect(Self.decide(phase: .failedRollback) == .closeSession)
    }

    /// «Cancelar» (claim, efecto, pasos del líder) y «Dejar de esperar» dejan `notStarted` sin el efecto pendiente.
    @Test func cancelExit_closesTheSessionItOpened() {
        #expect(Self.decide(phase: .notStarted) == .closeSession)
    }

    // MARK: - En vuelo: no se toca

    /// `notStarted` con el efecto pendiente es el adopt esperando su reconcile, no una salida.
    @Test func effectPending_isInFlight() {
        #expect(Self.decide(phase: .notStarted, effectPending: true) == .keep)
    }

    @Test(arguments: [
        MigrationPhase.claimingMigration, .waitingForLeader, .assigningIdentity, .uploadingSnapshot, .verifying,
        .cutover(.pending),
    ])
    func stepsInFlight_keep(_ phase: MigrationPhase) {
        #expect(Self.decide(phase: phase) == .keep)
    }

    // MARK: - Sin marca: el trato de siempre

    /// Sin marca la sesión no la abrió un adopt —la de Grupos con «Activar la nube en este dispositivo», la que trae la puerta
    /// de Grupos a la bienvenida, o un adopt de un build anterior—, y no se cierra aunque el adopt salga.
    @Test(arguments: [MigrationPhase.failedRollback, .notStarted])
    func withoutMark_neverCloses(_ phase: MigrationPhase) {
        #expect(Self.decide(owned: nil, phase: phase) == .keep)
    }

    // MARK: - La marca se olvida

    /// El adopt que llegó a la nube: la sesión es ya la de la cuenta. Con `notStarted` sin pendientes —el estado del adopt
    /// terminado— cerrarla dejaría a la persona fuera de su nube recién activada.
    @Test func adoptThatReachedTheCloud_forgetsWithoutClosing() {
        #expect(Self.decide(phase: .notStarted, cloud: true) == .forget)
        #expect(Self.decide(phase: .done, cloud: true) == .forget)
        #expect(Self.decide(phase: .notStarted, effectPending: true, cloud: true) == .forget)
    }

    /// La persona entró después con OTRA cuenta (por Grupos): esa sesión no la abrió el adopt.
    @Test func otherSessionLive_forgetsWithoutClosing() {
        #expect(Self.decide(session: Self.otra, phase: .failedRollback) == .forget)
        #expect(Self.decide(session: Self.otra, phase: .notStarted) == .forget)
    }

    /// Sin sesión legible no se decide: un `currentUserID` que aún no se lee (el llavero protegido en un prewarm) no es «otra
    /// sesión», y olvidar la marca ahí dejaba abierta la sesión que describía (lo cazó la review). La borra el siguiente
    /// sign-in.
    @Test func noSessionReadable_keeps() {
        #expect(Self.decide(session: nil, phase: .failedRollback) == .keep)
        #expect(Self.decide(session: nil, phase: .notStarted) == .keep)
    }

    // MARK: - Qué se apunta al empezar

    /// El intento que abrió su sesión apunta su cuenta, pisando la que hubiera.
    @Test func openedSession_recordsItsAccount() {
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: true, sessionAccountHash: Self.cuenta, current: nil) == Self.cuenta)
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: true, sessionAccountHash: Self.cuenta, current: Self.otra) == Self.cuenta)
    }

    /// Un intento con una sesión que no abrió conserva la marca solo si ya describe esa sesión: un «Retomar» de la
    /// bienvenida tras relanzar, sobre la sesión que firmó un intento anterior (lo cazó la review: la borraba).
    @Test func notOpened_keepsOnlyTheMarkOfTheLiveSession() {
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: false, sessionAccountHash: Self.cuenta, current: Self.cuenta) == Self.cuenta)
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: false, sessionAccountHash: Self.cuenta, current: Self.otra) == nil)
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: false, sessionAccountHash: Self.cuenta, current: nil) == nil)
    }

    /// Sin sesión no hay cuenta que apuntar.
    @Test func noSession_recordsNothing() {
        #expect(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: true, sessionAccountHash: nil, current: Self.cuenta) == nil)
    }

    // MARK: - Cuándo se retira tras conducir

    /// La llamada volvió sin entrar en el claim: la marca se retira, o su `authenticating` normalizado se leería salida.
    @Test(arguments: [MigrationPhase.notStarted, .dryRun, .consent, .authenticating])
    func stoppedBeforeTheClaim_withdraws(_ phase: MigrationPhase) {
        #expect(AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: phase, adoptEffectPending: false, persistedCloudMode: false))
    }

    @Test(arguments: [MigrationPhase.claimingMigration, .waitingForLeader, .assigningIdentity, .uploadingSnapshot,
                      .failedRollback])
    func inTheClaimOrAfter_keeps(_ phase: MigrationPhase) {
        #expect(!AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: phase, adoptEffectPending: false, persistedCloudMode: false))
    }

    /// `existing_stable` con el reconcile aparcado: `notStarted` con el efecto pendiente ya pasó por el claim.
    @Test func effectPendingAfterTheClaim_keeps() {
        #expect(!AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: .notStarted, adoptEffectPending: true, persistedCloudMode: false))
    }

    /// El adopt que terminó dentro de la misma llamada: la olvida `decide`, no esto.
    @Test func adoptThatAlreadyReachedTheCloud_keeps() {
        #expect(!AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: .notStarted, adoptEffectPending: false, persistedCloudMode: true))
    }

    // MARK: - El registrador

    @Test func ownsLiveSession_onlyWithTheMarkOfThatSession() throws {
        let d = try #require(UserDefaults(suiteName: "AdoptSessionOwnershipLogicTests.\(UUID().uuidString)"))
        #expect(!AdoptSessionOwnership.ownsLiveSession(sessionAccountHash: Self.cuenta, d))
        AdoptSessionOwnership.record(Self.cuenta, d)
        #expect(AdoptSessionOwnership.ownsLiveSession(sessionAccountHash: Self.cuenta, d))
        #expect(!AdoptSessionOwnership.ownsLiveSession(sessionAccountHash: Self.otra, d))
        #expect(!AdoptSessionOwnership.ownsLiveSession(sessionAccountHash: nil, d))
    }

    // MARK: - El recorrido entero

    /// Un adopt de la bienvenida que firmó, espera su reconcile tras relanzar y se cancela días después: la marca apuntada al
    /// empezar es la que cierra, sin nada en memoria.
    @Test func welcomeAdopt_cancelledAfterARelaunch_closes() {
        let owned = AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: true, sessionAccountHash: Self.cuenta, current: nil)
        #expect(!AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: .notStarted, adoptEffectPending: true, persistedCloudMode: false))
        #expect(Self.decide(owned: owned, phase: .notStarted, effectPending: true) == .keep)
        #expect(Self.decide(owned: owned, phase: .notStarted, effectPending: false) == .closeSession)
    }
}

@Suite("La marca de la sesión del adopt: su tienda", .serialized)
struct AdoptSessionOwnershipStoreTests {

    private static func defaults() throws -> UserDefaults {
        let name = "AdoptSessionOwnershipStoreTests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test func record_thenRead() throws {
        let d = try Self.defaults()
        #expect(AdoptSessionOwnership.read(d) == nil)
        AdoptSessionOwnership.record("abc", d)
        #expect(AdoptSessionOwnership.read(d) == "abc")
    }

    /// Un intento que no abrió la sesión BORRA la de otro: `nil` no es «no toques».
    @Test func recordNil_removesThePreviousMark() throws {
        let d = try Self.defaults()
        AdoptSessionOwnership.record("abc", d)
        AdoptSessionOwnership.record(nil, d)
        #expect(d.object(forKey: AdoptSessionOwnership.userDefaultsKey) == nil)
    }

    /// Un hash vacío no es una cuenta: no deja una key que alguien lea como marca.
    @Test func recordEmpty_removes() throws {
        let d = try Self.defaults()
        AdoptSessionOwnership.record("abc", d)
        AdoptSessionOwnership.record("", d)
        #expect(d.object(forKey: AdoptSessionOwnership.userDefaultsKey) == nil)
    }

    @Test func key_livesWithTheMigrationState() {
        #expect(AdoptSessionOwnership.userDefaultsKey == "cloudSync.adoptSessionAccountHash")
    }
}

@Suite("La sesión que abrió un adopt: cableado (source-scan)")
struct AdoptSessionOwnershipWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static let controllerPath = "Yala/Services/CloudSync/CloudMigrationController.swift"
    private static let welcomePath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El cuerpo de lo que abre `marker` (su primera `{` ya incluida), hasta la llave que lo cierra.
    private static func body(of marker: String, in path: String) throws -> String {
        let text = try source(path)
        let start = try #require(text.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// Líneas de código sin espacios, sin vacías y sin comentarios.
    private static func lines(_ body: String) -> [String] {
        body.split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    // MARK: - Controller

    /// Solo `.closeSession` firma fuera, y la marca se consume en los dos desenlaces que terminan.
    @Test func closeSessionOfExitedAdopt_wholeBodyIsPinned() throws {
        let body = try Self.body(of: "private func closeSessionOfExitedAdopt() async {", in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "guard !isJournalUnreadable else { return }",
            "let owned = AdoptSessionOwnership.read()",
            "switch AdoptSessionOwnership.decide(",
            "ownedAccountHash: owned,",
            "sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) },",
            "phase: journaledPhase, adoptEffectPending: isAdoptEffectPending,",
            "persistedCloudMode: StorageModePersistence.read() == .cloud) {",
            "case .keep:",
            "return",
            "case .forget:",
            "AdoptSessionOwnership.record(nil)",
            "case .closeSession:",
            "AdoptSessionOwnership.record(nil)",
            "CloudSyncBreadcrumb.adoptExitClosedSession()",
            // El único `signOut` del controller sigue siendo el de `closeSessionIfOpened` (lo cuenta
            // `MigrationIdentityGateWiringTests.closeSessionIfOpened_wholeBodyIsPinned`).
            "_ = await closeSessionIfOpened(true)",
            "}",
        ])
    }

    /// Qué se apunta lo decide la lógica pura, con la sesión viva y la marca que hubiera.
    @Test func recordAdoptSessionOwnership_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: "private func recordAdoptSessionOwnership(sessionOpenedByThisAttempt openedSession: Bool) {",
            in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "AdoptSessionOwnership.record(AdoptSessionOwnership.markToRecord(",
            "sessionOpenedByThisAttempt: openedSession,",
            "sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) },",
            "current: AdoptSessionOwnership.read()))",
        ])
    }

    /// Se retira tras un `refresh()` —la fase de DESPUÉS del `submit`— y solo si la llamada no entró en el claim.
    /// Devuelve si paró antes del claim, que es lo que lee el adopt de Ajustes para cerrar la sesión: con el journal
    /// ilegible, `false` (no decide), y solo `true` en el camino que retira la marca.
    @Test func withdrawAdoptSessionOwnershipIfNotStarted_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: "private func withdrawAdoptSessionOwnershipIfNotStarted() -> Bool {", in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "refresh()",
            "guard !isJournalUnreadable, AdoptSessionOwnership.stoppedBeforeTheClaim(",
            "phase: journaledPhase, adoptEffectPending: isAdoptEffectPending,",
            "persistedCloudMode: StorageModePersistence.read() == .cloud) else { return false }",
            "AdoptSessionOwnership.record(nil)",
            "return true",
        ])
    }

    /// Ticket `settings-adopt-stalled-before-the-claim-keeps-the-session`: la parada antes del claim cierra la sesión SOLO en
    /// Ajustes. La bienvenida descarta lo que devuelve la retirada y no cierra nada ni avisa: su «Retomar» reusa la sesión.
    @Test func welcomeAdopt_keepsTheSessionWhenItStopsBeforeTheClaim() throws {
        let adopt = Self.lines(try Self.body(
            of: "func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {", in: Self.controllerPath))
        let submit = try #require(adopt.firstIndex(of: "await r.submit(.signInSucceeded)"))
        #expect(adopt[submit + 1] == "withdrawAdoptSessionOwnershipIfNotStarted()")
        #expect(!adopt.contains { $0.contains("closeSessionIfOpened") })
        #expect(!adopt.contains { $0.contains("signOut") })
        #expect(!adopt.contains { $0.contains("settingsAdoptStoppedBeforeTheClaim") })
        let code = try Self.source(Self.controllerPath)
        #expect(Self.occurrences(of: "StorageFailureCopyLogic.settingsAdoptStoppedBeforeTheClaim(", in: code) == 1,
                "solo el adopt de Ajustes avisa de esta parada")
    }

    /// El adopt de la bienvenida la apunta ANTES de conducir —un kill en la primera pasada la perdía (lo cazaron las dos
    /// lentes)— y la retira DESPUÉS del `submit`. El de Ajustes lo fija el cuerpo entero de `continueToClaim`
    /// (`MigrationIdentityGateWiringTests`).
    @Test func welcomeAdopt_recordsBeforeDrivingAndWithdrawsAfter() throws {
        let adopt = Self.lines(try Self.body(
            of: "func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {", in: Self.controllerPath))
        let record = try #require(adopt.firstIndex(
            of: "recordAdoptSessionOwnership(sessionOpenedByThisAttempt: sessionOpenedByThisAttempt)"))
        let start = try #require(adopt.firstIndex(of: "await r.startMigration(dryRun: false)"))
        let submit = try #require(adopt.firstIndex(of: "await r.submit(.signInSucceeded)"))
        #expect(record < start)
        #expect(adopt[submit + 1] == "withdrawAdoptSessionOwnershipIfNotStarted()")
        let code = try Self.source(Self.controllerPath)
        #expect(Self.occurrences(of: "recordAdoptSessionOwnership(sessionOpenedByThisAttempt:", in: code) == 2,
                "las dos entradas del adopt (la definición lleva la etiqueta interna y no casa)")
        #expect(Self.occurrences(of: "withdrawAdoptSessionOwnershipIfNotStarted()", in: code) == 3)
    }

    /// Cada llamada que conduce el runner mira después si el adopt salió; `resumeIfNeeded` lo mira ANTES de decidir, porque
    /// es el arranque y el re-kick.
    @Test func everyRunnerDrive_checksForAnExitedAdopt() throws {
        let code = try Self.source(Self.controllerPath)
        #expect(Self.occurrences(of: "await closeSessionOfExitedAdopt()", in: code) == 4)

        let poll = Self.lines(try Self.body(of: "func pollLeader(clearingError: Bool = true) async {", in: Self.controllerPath))
        #expect(Array(poll.suffix(4)) == [
            "await runner.pollLeader()", "refresh()", "await closeSessionOfExitedAdopt()", "startRuntimeIfStable()",
        ])

        let cancel = Self.lines(try Self.body(of: "func cancelMigration() async {", in: Self.controllerPath))
        #expect(cancel.last == "await closeSessionOfExitedAdopt()")
        let cancelled = try #require(cancel.firstIndex(of: "await runner.cancelMigration()"))
        #expect(cancel.firstIndex(of: "await closeSessionOfExitedAdopt()").map { $0 > cancelled } == true)

        let ifNeeded = Self.lines(try Self.body(
            of: "func resumeIfNeeded(clearingError: Bool = true) async {", in: Self.controllerPath))
        let check = try #require(ifNeeded.firstIndex(of: "await closeSessionOfExitedAdopt()"))
        let decide = try #require(ifNeeded.firstIndex(
            of: "switch MigrationBootDecision.decide(phase: phase, hasPendingEffects: hasPending) {"))
        let phaseSet = try #require(ifNeeded.firstIndex(of: "journaledPhase = phase"))
        #expect(phaseSet < check, "decide con la fase recién leída")
        #expect(check < decide)
        // `resume` lo fija el cuerpo entero en `ReverseUploadControllerWiringTests`.
    }

    // MARK: - Bienvenida

    /// La pantalla sabe si firmó ella: solo tras un `signIn` que no lanzó.
    @Test func welcome_marksTheSessionItSignedIn() throws {
        let ensure = Self.lines(try Self.body(of: "private func ensureSignedIn() async -> Bool {", in: Self.welcomePath))
        let signIn = try #require(ensure.firstIndex(of: "try await CloudAuthService.shared.signIn(with: provider)"))
        #expect(ensure[signIn + 1] == "sessionOpenedHere = true")
        #expect(ensure[signIn + 2] == "return true")
        let code = try Self.source(Self.welcomePath)
        #expect(Self.occurrences(of: "sessionOpenedHere = true", in: code) == 1)
        #expect(code.contains("@State private var sessionOpenedHere = false"))
    }

    /// Sin sesión, el «Retomar» de la bienvenida vuelve a firmar en vez de reclamar sin ella: la salida del adopt puede
    /// haberla cerrado (lo cazaron las dos lentes).
    @Test func welcomeRetry_signsInAgainWithoutASession() throws {
        let retry = Self.lines(try Self.body(of: "private func retryAdoptResume() async {", in: Self.welcomePath))
        let idle = try #require(retry.firstIndex(of: "if case .idle = controller.uiState, !cancelRequested {"))
        #expect(Array(retry[(idle + 1)...(idle + 5)]) == [
            "guard CloudAuthService.shared.hasSession else {",
            "await runFlowAfterConsent()",
            "return",
            "}",
            "await controller.startAdoptWithExistingSession(sessionOpenedByThisAttempt: sessionOpenedHere)",
        ])
    }

    // MARK: - Sesión y registrador

    /// La marca describe UNA sesión: la borran los dos sitios donde nace una (Apple, Google) y el cierre, también sin
    /// backend (antes del `guard let client`). Sin eso, una sesión de Grupos firmada después con la misma cuenta la
    /// heredaba (lo cazó la lente de consumidores).
    @Test func authService_clearsTheMarkOnEverySignInAndSignOut() throws {
        let path = "Yala/Services/CloudSync/CloudAuthService.swift"
        let code = Self.lines(try Self.source(path))
        #expect(code.filter { $0 == "AdoptSessionOwnership.record(nil)" }.count == 3)
        for (i, line) in code.enumerated() where line == "CloudSyncBreadcrumb.authSignedIn()" {
            #expect(code[i + 1] == "AdoptSessionOwnership.record(nil)", "tras el sign-in de la línea \(i)")
        }
        // Desde el 2026-09-26 `signOut()` devuelve si la sesión se fue, y su `guard` sin cliente devuelve ese testigo
        // (`detach-does-not-verify-the-cloud-session-actually-closed`). Lo que se fija aquí no cambia: la marca, antes.
        let signOut = Self.lines(try Self.body(of: "func signOut() async -> Bool {", in: path))
        let clear = try #require(signOut.firstIndex(of: "AdoptSessionOwnership.record(nil)"))
        let guardClient = try #require(signOut.firstIndex(of: "guard let client else { return storedSessionIsGone }"))
        #expect(clear < guardClient)
    }

    /// El registrador de Grupos del arranque no asocia la sesión de un adopt. Su comportamiento lo fija
    /// `GroupsAssociationRegistrarTests.noRegistraLaSesionDeUnAdopt`; esto, que el guard va antes de escribir.
    @Test func registrar_skipsTheAdoptSession() throws {
        let body = Self.lines(try Self.body(
            of: "static func syncFromLiveSessionIfNeeded(", in: "Yala/Services/CloudSync/GroupsAccountAssociation.swift"))
        let skip = try #require(body.firstIndex(
            of: "guard !AdoptSessionOwnership.ownsLiveSession(sessionAccountHash: CloudBeacon.hash(sub), defaults) else { return }"))
        let write = try #require(body.firstIndex(of: "store.associate("))
        #expect(skip < write)
    }

    /// Las dos llamadas —el adopt y su «Retomar»— pasan quién firmó, y no un literal.
    @Test func welcome_passesWhoOpenedTheSession() throws {
        let code = Self.lines(try Self.source(Self.welcomePath)).joined(separator: " ")
        #expect(Self.occurrences(of: "startAdoptWithExistingSession(", in: code) == 2)
        #expect(Self.occurrences(of: "sessionOpenedByThisAttempt: sessionOpenedHere)", in: code) == 2)
    }
}
