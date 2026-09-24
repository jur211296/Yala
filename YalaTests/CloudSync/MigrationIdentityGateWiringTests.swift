//
//  MigrationIdentityGateWiringTests.swift
//  YalaTests / CloudSync
//
//  Cableado de la puerta de identidad de «Migrar a la nube» (ticket
//  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). Va por source-scan, como
//  `ReverseUploadControllerWiringTests`: el controller tiene `init` privado y vive como singleton sobre el `mainContext`, la
//  comprobación pregunta a la red con la sesión de `CloudAuthService.shared`, y la hoja es SwiftUI. Lo que DECIDE cada pieza
//  tiene tests de comportamiento (`StorageMigrationIdentityGateLogicTests`, `MigrationRunnerTests` sección 10c,
//  `MigrationWorkExecutorTests`, `MigrationStateJournalTests`); estos fijan que el controller, el runner y la vista lo usan
//  donde toca y en el orden que importa.
//
//  **Los cuerpos van ENTEROS y normalizados, y lo decidió la review**: con `contains` y órdenes sueltos, una lente midió
//  mutantes que sobrevivían —la traducción de «no se pudo preguntar» a «cuenta nueva», un `signOut` dentro de `announce`,
//  «Entendido» quemando el one-shot de «Usar otra cuenta»—. Cambiar cualquiera de estas funciones obliga a mirar esto.
//

import Foundation
import Testing

@testable import Yala

@Suite("«Migrar a la nube»: cableado de la puerta de identidad (source-scan)")
struct MigrationIdentityGateWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static let controllerPath = "Yala/Services/CloudSync/CloudMigrationController.swift"
    private static let runnerPath = "Yala/Services/CloudSync/MigrationRunner.swift"
    private static let viewPath = "Yala/App/Views/Settings/StorageSettingsView.swift"
    private static let blockViewPath = "Yala/App/Views/Settings/StorageMigrationBlockedView.swift"
    private static let debugPanelPath = "Yala/App/Views/Settings/CloudSyncDebugView.swift"

    /// El cuerpo de lo que abre `marker` (su primera `{` ya incluida en el marcador), hasta la llave que lo cierra. Ninguno
    /// de los cuerpos escaneados lleva llaves dentro de comentarios o literales (medido por la review).
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

    /// Líneas de código sin espacios, sin vacías y sin comentarios, completos o al final de la línea. Ninguno de los cuerpos
    /// escaneados tiene `//` dentro de un literal.
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

    /// Los dos caminos de `startMigration` —sesión viva y recién firmada— pasan por la puerta, y ninguno llega al claim por
    /// su cuenta. Solo el recién firmado abre la sesión.
    @Test func startMigration_bothPathsGoThroughTheGate() throws {
        let start = try Self.body(
            of: "func startMigration(consentPath: ConsentPath, signIn plan: SignInPlan) async {", in: Self.controllerPath)
        #expect(Self.occurrences(of: "submit(.signInSucceeded)", in: start) == 0,
                "nadie llega al claim sin pasar por `continueToClaim`")
        let live = try #require(start.range(
            of: "await continueToClaim(r, consentPath: consentPath, sessionOpenedByThisAttempt: false)"))
        let signIn = try #require(start.range(of: "try await CloudAuthService.shared.signIn(with: provider)"))
        let fresh = try #require(start.range(
            of: "await continueToClaim(r, consentPath: consentPath, sessionOpenedByThisAttempt: true)"))
        #expect(live.lowerBound < signIn.lowerBound, "la sesión viva no firma")
        #expect(signIn.lowerBound < fresh.lowerBound, "la sesión que se cierra al parar es la que acaba de abrirse")
        #expect(Self.occurrences(of: "continueToClaim(", in: start) == 2)
    }

    /// El orden es el bug: la comprobación ANTES del claim, con el runner en `authenticating` (no durable); al parar, la
    /// sesión del intento se cierra ANTES de devolver el runner al inicio, que espera quiescencia; al seguir, la intención
    /// de migrar puesta ANTES del `submit`, y un `submit` que no llega al claim también es una parada. El adopt, desde
    /// `adopt-claim-stays-parked-with-no-ceiling`, no entra en OTRA cuenta que la del adopt que salió (la tarjeta que abre
    /// esa marca no pasa por la puerta): para como la puerta, cerrando la sesión que abrió y sin claim.
    @Test func continueToClaim_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: "sessionOpenedByThisAttempt openedSession: Bool\n    ) async {", in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "guard consentPath == .migration else {",
            "migrationAttempt = nil",
            "if AdoptClaimScope.blocksReentry(",
            "exit: adoptClaimExit, attemptAccountHash: adoptClaimAccountHash,",
            "sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) }) {",
            "_ = await closeSessionIfOpened(openedSession)",
            "await r.submit(.signInFailed)",
            "lastError = L10n.Storage.Errors.adoptOtherAccount",
            "CloudSyncBreadcrumb.migrationIdentityBlocked(reason: \"adopt_other_account\", stage: \"gate\")",
            "MetricsService.cloudMigrationExistingAccountBlocked(reason: \"adopt_other_account\", stage: \"gate\")",
            "return",
            "}",
            "r.setForwardClaimIntent(.adoptIfExisting)",
            // Ticket `adopt-exit-keeps-the-session-it-opened`: de quién es la sesión, ANTES de conducir (un kill en la
            // primera pasada la perdía), y retirada si la llamada no llegó al claim.
            "recordAdoptSessionOwnership(sessionOpenedByThisAttempt: openedSession)",
            "await r.submit(.signInSucceeded)",
            "withdrawAdoptSessionOwnershipIfNotStarted()",
            "return",
            "}",
            // Y «Migrar» no hereda la marca de un adopt anterior.
            "AdoptSessionOwnership.record(nil)",
            "let (check, discovery) = await checkMigrationIdentity(sessionOpenedByThisAttempt: openedSession)",
            "guard check == .proceed else {",
            "let rejectedProvider = await closeSessionIfOpened(openedSession)",
            "await r.submit(.signInFailed)",
            "announce(check, offersAnotherAccount: openedSession, rejectedProvider: rejectedProvider)",
            "return",
            "}",
            "migrationAttempt = MigrationAttempt(sessionOpenedByThisAttempt: openedSession, checkedDiscovery: discovery)",
            "r.setForwardClaimIntent(.migrateOnly)",
            "let refusalBefore = r.lastForwardClaimRefusal",
            "await r.submit(.signInSucceeded)",
            "await announceForwardClaimRefusal(since: refusalBefore)",
            "refresh()",
            "guard migrationAttempt != nil,",
            "[.notStarted, .consent, .authenticating].contains(journaledPhase) else { return }",
            "migrationAttempt = nil",
            "_ = await closeSessionIfOpened(openedSession)",
            "lastError = L10n.Storage.Errors.generic",
        ])
    }

    /// Adelantar la comprobación al toque no cierra ninguna sesión —la de antes es la de sus grupos— ni toca el runner, y
    /// solo para en un bloqueo: si no pudo preguntar, sigue al consentimiento y decide `continueToClaim`.
    @Test func preflight_onlyStopsOnABlock_andNeverSignsOut() throws {
        let body = try Self.body(of: "func preflightMigrationIdentity() async -> Bool {", in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "guard !isWorking else { return false }",
            "isWorking = true",
            "isCheckingMigrationIdentity = true",
            "defer {",
            "isWorking = false",
            "isCheckingMigrationIdentity = false",
            "}",
            "lastError = nil",
            "let (check, _) = await checkMigrationIdentity(sessionOpenedByThisAttempt: false)",
            "guard case .blocked = check else { return true }",
            "announce(check, offersAnotherAccount: false, rejectedProvider: nil)",
            "return false",
        ])
    }

    /// La traducción de lo que contestó el backend, entera: un `.unavailable` que se leyera como cuenta nueva dejaría
    /// migrar a la cuenta de grupos de otra persona, y perder `discovery = found` cambiaba el aviso de «volvió a iCloud».
    /// El seam va primero y solo en DEBUG, y el eje se pasa sin leer `PrivateSessionMark`.
    ///
    /// **Y la marca del claim sin respuesta viaja aparte del sello** (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`): la lógica pura la trata distinto —no se salta la red de
    /// «Empezar desde cero»—, así que fundirla aquí con un `||` en `claimedForMigrationHere` le quitaría esa diferencia.
    ///
    /// **El sello de «Empezar desde cero» y el origen de la sesión viajan tal cual** (ticket
    /// `fresh-start-keeps-a-groups-session-that-migrate-promotes`): con la key equivocada, o con el parámetro fijado a
    /// `true`, la sesión que dejó la persona anterior volvía a promoverse con las finanzas de la nueva.
    @Test func checkMigrationIdentity_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: """
            sessionOpenedByThisAttempt: Bool
                ) async -> (StorageMigrationIdentityGateLogic.Check, CloudIdentityRoutingLogic.Discovery?) {
            """,
            in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "#if DEBUG",
            "if let fingida = UITestHooks.fakeMigrationIdentityCheck { return (fingida, nil) }",
            "#endif",
            "let answer: StorageMigrationIdentityGateLogic.Answer",
            "var discovery: CloudIdentityRoutingLogic.Discovery?",
            "var userID: String?",
            "switch await CloudIdentityDiscovery().discover(gate: .settingsMigrateToCloud) {",
            "case let .discovered(found, id):",
            "answer = .discovered(found)",
            "discovery = found",
            "userID = id",
            "case .unavailable:",
            "answer = .unavailable",
            "}",
            "let claimedForMigrationHere = userID.map {",
            "CloudClaimActionStore.shared.action(forUserID: $0) == .proceedMigration",
            "} ?? false",
            "let hasUnansweredMigrationClaim = userID.map {",
            "CloudClaimActionStore.shared.hasMigrationClaimAttempt(forUserID: $0)",
            "} ?? false",
            "let check = StorageMigrationIdentityGateLogic.check(",
            "answer: answer,",
            "deviceState: .privateSession,",
            "isAssociatedGroupsAccount: GroupsAccountAssociation.shared.isAssociated(sub: userID),",
            "claimedForMigrationHere: claimedForMigrationHere,",
            "hasUnansweredMigrationClaim: hasUnansweredMigrationClaim,",
            "sessionOpenedByThisAttempt: sessionOpenedByThisAttempt,",
            "deviceSealedForFreshStart: UserDefaults.standard.bool(",
            "forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart))",
            "return (check, discovery)",
        ])

        // Las dos llamadas son las de `continueToClaim` y el adelanto al toque, que fijan sus cuerpos enteros: ninguna otra
        // entrada pregunta sin decir de dónde viene la sesión.
        let code = Self.lines(try Self.source(Self.controllerPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: "checkMigrationIdentity(sessionOpenedByThisAttempt:", in: code) == 2)

        // Un solo lector del seam en todo `Yala/`.
        let enumerator = try #require(FileManager.default.enumerator(
            at: Self.repoRoot.appendingPathComponent("Yala"), includingPropertiesForKeys: nil))
        var readers = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let code = Self.lines(try String(contentsOf: url, encoding: .utf8)).joined(separator: "\n")
            readers += Self.occurrences(of: "UITestHooks.fakeMigrationIdentityCheck", in: code)
        }
        #expect(readers == 1, "solo `checkMigrationIdentity` finge la respuesta: \(readers) lectores")
    }

    /// Solo se cierra la sesión que abrió el intento, y el método se lee ANTES de cerrarla: después ya no existe.
    @Test func closeSessionIfOpened_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: "private func closeSessionIfOpened(_ opened: Bool) async -> CloudSignInProvider? {", in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "guard opened else { return nil }",
            "let provider = CloudAuthService.shared.storedProvider().flatMap(CloudSignInProvider.init(rawValue:))",
            "await CloudAuthService.shared.signOut()",
            "return provider",
        ])
        let code = Self.lines(try Self.source(Self.controllerPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: "CloudAuthService.shared.signOut()", in: code) == 1,
                "ningún otro camino de la puerta cierra sesiones")
    }

    /// Un claim devuelto al inicio se avisa una vez por rechazo NUEVO —nuevo para esta llamada y para el controller: un
    /// `resume` que empezó antes del toque lo veía nuevo respecto a su foto—, con la sesión cerrada si la abrió el intento y
    /// el motivo de lo que dijeron la comprobación y el claim.
    @Test func forwardClaimRefusal_wholeBodyIsPinned() throws {
        let body = try Self.body(
            of: "private func announceForwardClaimRefusal(since before: ForwardClaimRefusal?) async {",
            in: Self.controllerPath)
        #expect(Self.lines(body) == [
            "guard let refusal = _runner?.lastForwardClaimRefusal, refusal != before,",
            "refusal.sequence > lastAnnouncedForwardRefusalSequence else { return }",
            "lastAnnouncedForwardRefusalSequence = refusal.sequence",
            "let attempt = migrationAttempt",
            "migrationAttempt = nil",
            "let openedSession = attempt?.sessionOpenedByThisAttempt ?? false",
            "let rejectedProvider = await closeSessionIfOpened(openedSession)",
            "publishBlock(",
            "StorageMigrationIdentityGateLogic.blockForClaimRefusal(",
            "checkedDiscovery: attempt?.checkedDiscovery, claimState: refusal.claimState),",
            "offersAnotherAccount: openedSession,",
            "rejectedProvider: rejectedProvider,",
            "stage: \"claim\")",
        ])
    }

    /// El aviso de la comprobación y la publicación, enteros: «No pudimos comprobar tu cuenta» no puede salir mudo, nadie
    /// cierra sesiones aquí, y el correo y el método viajan al aviso.
    @Test func announceAndPublish_wholeBodiesArePinned() throws {
        let announce = try Self.body(of: """
            rejectedProvider: CloudSignInProvider?
                ) {
                    switch check {
            """, in: Self.controllerPath)
        #expect(Self.lines(announce) == [
            "case .proceed:",
            "return",
            "case .blocked(let reason):",
            "publishBlock(reason, offersAnotherAccount: offersAnotherAccount, rejectedProvider: rejectedProvider,",
            "stage: \"gate\")",
            "case .couldNotCheck:",
            "lastError = L10n.Storage.Errors.identityCheck",
            "CloudSyncBreadcrumb.migrationIdentityBlocked(reason: \"unchecked\", stage: \"gate\")",
            "MetricsService.cloudMigrationExistingAccountBlocked(reason: \"unchecked\", stage: \"gate\")",
        ])

        let publish = try Self.body(of: """
            stage: String
                ) {
            """, in: Self.controllerPath)
        #expect(Self.lines(publish) == [
            "migrationIdentityBlock = MigrationIdentityBlock(",
            "reason: reason,",
            "offersAnotherAccount: offersAnotherAccount,",
            "associatedEmail: reason == .anotherGroupsAccountAssociated",
            "? GroupsAccountAssociation.shared.read()?.email : nil,",
            "rejectedProvider: rejectedProvider)",
            "CloudSyncBreadcrumb.migrationIdentityBlocked(reason: reason.slug, stage: stage)",
            "MetricsService.cloudMigrationExistingAccountBlocked(reason: reason.slug, stage: stage)",
        ])
    }

    /// Cada entrada que lleva al claim de la ida fija la intención antes: `continueToClaim` (migrar y adopt de Ajustes), el
    /// adopt del Welcome y el panel DEBUG. Una entrada nueva que se olvide journalearía la de la anterior.
    @Test func everyClaimEntrySetsTheIntent() throws {
        let code = Self.lines(try Self.source(Self.controllerPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: "submit(.signInSucceeded)", in: code) == 3)
        #expect(Self.occurrences(of: "setForwardClaimIntent(", in: code) == 3)

        let adopt = try Self.body(of: "func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {", in: Self.controllerPath)
        let intent = try #require(adopt.range(of: "r.setForwardClaimIntent(.adoptIfExisting)"))
        let started = try #require(adopt.range(of: "await r.startMigration(dryRun: false)"))
        let signedIn = try #require(adopt.range(of: "await r.submit(.signInSucceeded)"))
        #expect(intent.lowerBound < started.lowerBound)
        #expect(started.lowerBound < signedIn.lowerBound)

        let panel = try Self.body(of: "func acceptConsentAndSignIn() async {", in: Self.debugPanelPath)
        let panelIntent = try #require(panel.range(of: "r.setForwardClaimIntent(.adoptIfExisting)"))
        let panelSignedIn = try #require(panel.range(of: "await r.submit(.signInSucceeded)"))
        #expect(panelIntent.lowerBound < panelSignedIn.lowerBound)
    }

    /// «Retomar» y el re-kick también avisan: un claim aparcado por la red puede contestar `existing_stable` al retomar.
    @Test func resume_announcesARefusal() throws {
        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {", in: Self.controllerPath)
        let snapshot = try #require(resume.range(of: "let forwardRefusalBefore = runner.lastForwardClaimRefusal"))
        let resumed = try #require(resume.range(of: "await runner.resume()"))
        let announce = try #require(resume.range(of: "await announceForwardClaimRefusal(since: forwardRefusalBefore)"))
        #expect(snapshot.lowerBound < resumed.lowerBound, "la foto va antes de llamar al runner")
        #expect(resumed.lowerBound < announce.lowerBound)
    }

    // MARK: - Runner

    /// La intención que decide es la JOURNALEADA, y se escribe con la transición a `claimingMigration`. El sello se deshace
    /// ANTES de journalear la vuelta al inicio, y la rama va antes de entregar el claim a la máquina.
    @Test func driveClaim_readsTheJournal_andRefusesInOrder() throws {
        let body = try Self.body(of: "private func driveClaim() async throws -> Bool {", in: Self.runnerPath)
        let reads = try #require(body.range(
            of: "let intent = state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting"))
        // Con la marca del claim sin respuesta solo en «Migrar» (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`):
        // la intención que la decide es también la journaleada.
        let claims = try #require(body.range(
            of: "switch await executor.performClaim(marksMigrationAttempt: intent == .migrateOnly) {"))
        let refuses = try #require(body.range(of: "if intent.refuses(claimState) {"))
        let discard = try #require(body.range(of: "executor.discardLastClaimStamp()"))
        let refused = try #require(body.range(of: "try await handle(.claimRefusedExistingAccount)"))
        let recorded = try #require(body.range(of: "lastForwardClaimRefusal = ForwardClaimRefusal("))
        let delivered = try #require(body.range(of: "try await handle(.claimResult(claimState, sameDeviceReclaim: false))"))
        #expect(reads.lowerBound < claims.lowerBound)
        #expect(claims.lowerBound < refuses.lowerBound)
        #expect(refuses.lowerBound < discard.lowerBound)
        #expect(discard.lowerBound < refused.lowerBound)
        #expect(refused.lowerBound < recorded.lowerBound, "se anota tras journalear: sin fase nueva no hay aviso")
        #expect(recorded.lowerBound < delivered.lowerBound, "el rechazo sale antes de entregar el claim a la máquina")
        #expect(!Self.lines(body).contains { $0.contains("forwardClaimIntent.refuses") },
                "`driveClaim` no decide con la intención de memoria")

        let runner = Self.lines(try Self.source(Self.runnerPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: ".claimRefusedExistingAccount", in: runner) == 1, "un solo productor de la arista")
        #expect(runner.contains("""
            if event == .signInSucceeded, next == .claimingMigration {
            state.forwardClaimIntentRaw = forwardClaimIntent.rawValue
            }
            """), "la intención se journalea en el save de la transición al claim")
    }

    // MARK: - Vista

    /// El toque adelanta la comprobación solo en «Migrar» con sesión viva; el adopt y el camino sin sesión van al
    /// consentimiento como siempre.
    @Test func migrateButton_preflightOnlyForMigrationWithALiveSession() throws {
        let view = try Self.source(Self.viewPath)
        let start = try #require(view.range(of: "consentPath = isAdopt ? .adopt : .migration"))
        let end = try #require(view.range(of: ".accessibilityIdentifier(\"storage_migrate_button\")"))
        let action = String(view[start.lowerBound..<end.lowerBound])
        #expect(Self.lines(action) == [
            "consentPath = isAdopt ? .adopt : .migration",
            "guard !isAdopt, case .reuseLiveSession = decision else {",
            "showConsent = true",
            "return",
            "}",
            "Task {",
            "guard await controller.preflightMigrationIdentity() else { return }",
            "showConsent = true",
            "}",
            "}",
        ])
        #expect(view.contains("isLoading: controller.isCheckingMigrationIdentity"))
    }

    /// La hoja: «Usar otra cuenta» y solo él quema el one-shot; el aviso se suelta del controller cuando la hoja MONTA; la
    /// pantalla lo copia sin soltarlo; y el `onDismiss` es el único que abre la elección de Apple/Google, y solo sin sesión
    /// viva: con una que apareció mientras el aviso esperaba, la elección se cerraba sola y migraba con ella.
    @Test func blockSheet_wholeWiringIsPinned() throws {
        let sheet = try Self.body(
            of: ".sheet(item: $presentedMigrationBlock, onDismiss: onMigrationBlockDismissed) { block in",
            in: Self.viewPath)
        #expect(Self.lines(sheet) == [
            "StorageMigrationBlockedView(",
            "block: block,",
            "onUseAnotherAccount: {",
            "migrationBlockUseAnotherAccount = true",
            "presentedMigrationBlock = nil",
            "},",
            "onClose: { presentedMigrationBlock = nil })",
            ".onAppear {",
            "if controller?.migrationIdentityBlock?.id == block.id { controller?.migrationIdentityBlock = nil }",
            "}",
        ])

        let consume = try Self.body(
            of: ".onChange(of: controller?.migrationIdentityBlock?.id, initial: true) { _, id in", in: Self.viewPath)
        #expect(Self.lines(consume) == [
            "guard id != nil, let block = controller?.migrationIdentityBlock else { return }",
            "presentedMigrationBlock = block",
        ])

        let dismissed = try Self.body(of: "private func onMigrationBlockDismissed() {", in: Self.viewPath)
        #expect(Self.lines(dismissed) == [
            "guard migrationBlockUseAnotherAccount else { return }",
            "migrationBlockUseAnotherAccount = false",
            "guard !abortIfCloudEntryClosed() else { return }",
            "guard case .askProvider = signInDecision() else { return }",
            "consentPath = .migration",
            "showSignInChooser = true",
        ])

        let code = Self.lines(try Self.source(Self.viewPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: "migrationBlockUseAnotherAccount = true", in: code) == 1)
        #expect(Self.occurrences(of: "controller?.migrationIdentityBlock = nil", in: code) == 1,
                "solo la hoja montada suelta el aviso")
    }

    /// Cada botón de la hoja con SU acción y SU id, y la nota de Apple fuera del `if` de los botones.
    @Test func blockView_buttonsArePinned() throws {
        let body = try Self.body(of: "VStack(spacing: DS.Spacing.md) {", in: Self.blockViewPath)
        #expect(Self.lines(body) == [
            "if block.showsAppleSameAccountNote {",
            "Text(L10n.Storage.MigrateBlock.appleSameAccountNote)",
            ".font(DS.Typography.caption)",
            ".foregroundStyle(.secondary)",
            ".multilineTextAlignment(.center)",
            ".accessibilityIdentifier(\"storage_migrate_block_apple_note\")",
            "}",
            "if block.offersAnotherAccount {",
            "YalaPrimaryButton(L10n.Storage.MigrateBlock.useAnotherAccount,",
            "icon: \"person.crop.circle.badge.plus\") {",
            "onUseAnotherAccount()",
            "}",
            ".accessibilityIdentifier(\"storage_migrate_block_use_another\")",
            "YalaSecondaryButton(L10n.Common.understood) {",
            "onClose()",
            "}",
            ".accessibilityIdentifier(\"storage_migrate_block_close\")",
            "} else {",
            "YalaPrimaryButton(L10n.Common.understood) {",
            "onClose()",
            "}",
            ".accessibilityIdentifier(\"storage_migrate_block_close\")",
            "}",
        ])
    }

    // MARK: - Seams

    /// **La paridad del nombre de los dos seams.** Con un typo a un lado, la puerta preguntaría de verdad o el aviso no se
    /// publicaría, y los XCUITest caerían culpando a la hoja.
    @Test func seams_argNameParity() throws {
        let launcher = try Self.source("YalaUITests/Support/XCUIApplication+Yala.swift")
        let hooks = try Self.source("Yala/App/UITestHooks.swift")
        for arg in ["-uitest-fake-migration-identity", "-uitest-pending-migration-block"] {
            #expect(launcher.contains("args.append(\"\(arg)\")"), "el lanzador del XCUITest no pasa `\(arg)`")
            #expect(hooks.contains("parseValue(after: \"\(arg)\""), "`UITestHooks` no lee `\(arg)`")
        }
        for value in ["personalData", "proceed", "personalDataApple"] {
            #expect(hooks.contains("case \"\(value)\":"), "`UITestHooks` no entiende el valor `\(value)`")
        }
        let controller = Self.lines(try Self.source(Self.controllerPath)).joined(separator: "\n")
        #expect(Self.occurrences(of: "UITestHooks.pendingMigrationBlock", in: controller) == 1,
                "el aviso fingido solo se publica al crear el controller")
    }
}
