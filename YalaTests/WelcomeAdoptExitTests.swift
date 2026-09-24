//
//  WelcomeAdoptExitTests.swift
//  YalaTests
//
//  Ticket `welcome-adopt-effect-failure-has-no-reason-and-no-cancel` (decisión de Jürgen del 2026-09-23): si entrar en tu
//  cuenta falla desde la bienvenida, la pantalla dice el motivo con los textos de Almacenamiento, y mientras el adopt corre
//  hay «Cancelar la activación», con el mismo camino que allí.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bienvenida · el motivo del fallo del adopt y su salida")
struct WelcomeAdoptExitTests {

    /// Las cinco salidas que se explican. `.cancelled` no está: quien cancela no ve un fallo.
    static let explainedExits: [AdoptClaimExit] = [
        .stalled, .sessionExpired, .accountUnavailable, .effectStalled, .effectLocalFailure,
    ]

    // MARK: - El mapeo de motivos

    /// El corazón del ticket: el fallo LOCAL del efecto y su techo largo ya no dicen «Revisa tu conexión».
    @Test func effectExits_mapToTheirOwnPhase() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), adoptClaimExit: .effectLocalFailure)
                == .adoptExit(.effectLocalFailure))
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), adoptClaimExit: .effectStalled)
                == .adoptExit(.effectStalled))
    }

    /// Las tres del claim, por la misma puerta: «mismos textos por motivo que Almacenamiento».
    @Test(arguments: explainedExits)
    func everyExplainedExit_isItsOwnPhase(_ exit: AdoptClaimExit) {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), adoptClaimExit: exit) == .adoptExit(exit))
    }

    /// Sin marca, o con la de una cancelación, el fallo sigue siendo el de siempre.
    @Test func noExitOrCancelled_staysTheGenericError() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration)) == .error(retryable: true))
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), adoptClaimExit: .cancelled)
                == .error(retryable: true))
    }

    /// Solo la tarjeta de la IDA lee la marca, como en Almacenamiento (`guard kind == .migration`).
    @Test func reverseFailure_ignoresTheExit() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.reverse), adoptClaimExit: .effectLocalFailure)
                == .error(retryable: true))
    }

    /// La marca solo cuenta en el fallo: con la máquina en marcha o terminada, se pinta lo de siempre.
    @Test func exitOutsideAFailure_changesNothing() {
        let step = MigrationUIStep(fraction: 0.6, phase: .notStarted)
        #expect(CloudWelcomeSignInFlow.phase(for: .migrating(step), adoptClaimExit: .effectStalled)
                == .adopting(fraction: 0.6))
        #expect(CloudWelcomeSignInFlow.phase(for: .cloudActive, adoptClaimExit: .effectStalled) == .reentryReady)
        #expect(CloudWelcomeSignInFlow.phase(for: .idle, adoptClaimExit: .effectStalled) == .adopting(fraction: 0))
    }

    /// `claimBlocker` sigue ganando: la pantalla del 403 no cambia.
    @Test func claimBlocker_stillWins() {
        #expect(CloudWelcomeSignInFlow.phase(
            for: .failed(.migration), claimBlocker: .accountUnavailable, adoptClaimExit: .effectLocalFailure)
                == .accountBlocked)
        #expect(CloudWelcomeSignInFlow.phase(
            for: .failed(.migration), claimBlocker: .sessionExpired, adoptClaimExit: .effectStalled)
                == .error(retryable: true))
    }

    // MARK: - Los textos son los de Almacenamiento

    /// Compara TEXTOS: lo que la persona lee es la frase, y la de la bienvenida tiene que ser la de la tarjeta de fallo. Hoy
    /// `message()` llama a la misma función, así que esto fija que SIGA llamándola: un texto propio en una de las dos cae.
    /// Qué texto es cada motivo lo fija `effectTexts_areTheirKeys`.
    @Test(arguments: explainedExits)
    func welcomeText_isTheStorageText(_ exit: AdoptClaimExit) throws {
        let welcome = try #require(StorageFailureCopyLogic.adoptExitMessage(exit, supportEmail: "a@b.c"))
        let storage = StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: nil, adoptClaimExit: exit, cutoverBlocker: nil, supportEmail: "a@b.c")
        #expect(welcome == storage)
        #expect(welcome != L10n.Welcome.Cloud.errorBody, "volvió el «Revisa tu conexión»")
    }

    /// Las dos del efecto, contra su clave: si alguien las cruzara, el test anterior seguiría verde.
    @Test func effectTexts_areTheirKeys() {
        #expect(StorageFailureCopyLogic.adoptExitMessage(.effectLocalFailure) == L10n.Storage.Failed.adoptEffectLocalFailure)
        #expect(StorageFailureCopyLogic.adoptExitMessage(.effectStalled) == L10n.Storage.Failed.adoptEffectStalled)
        #expect(StorageFailureCopyLogic.adoptExitMessage(.stalled) == L10n.Storage.Failed.adoptStalled)
        #expect(StorageFailureCopyLogic.adoptExitMessage(.sessionExpired) == L10n.Storage.Failed.adoptSessionExpired)
        #expect(StorageFailureCopyLogic.adoptExitMessage(.accountUnavailable, supportEmail: "a@b.c")
                == L10n.Storage.Failed.adoptAccountUnavailable("a@b.c"))
        #expect(StorageFailureCopyLogic.adoptExitMessage(.cancelled) == nil)
    }

    /// El cuerpo del diálogo de cancelar, por fase, compartido por las dos pantallas.
    @Test func cancelBody_perPhase() {
        #expect(StorageFailureCopyLogic.cancelMigrationBody(isAdoptClaim: true, isAdoptEffectPending: false)
                == L10n.Storage.Confirm.cancelAdoptBody)
        #expect(StorageFailureCopyLogic.cancelMigrationBody(isAdoptClaim: false, isAdoptEffectPending: true)
                == L10n.Storage.Confirm.cancelAdoptEffectBody)
        #expect(StorageFailureCopyLogic.cancelMigrationBody(isAdoptClaim: false, isAdoptEffectPending: false)
                == L10n.Storage.Confirm.cancelMigrationBody)
        // Las dos a la vez no ocurren (el efecto es `notStarted`, el claim no), pero si ocurrieran manda el claim.
        #expect(StorageFailureCopyLogic.cancelMigrationBody(isAdoptClaim: true, isAdoptEffectPending: true)
                == L10n.Storage.Confirm.cancelAdoptBody)
    }

    // MARK: - La salida durante el adopt

    @Test func cancel_isOfferedOnlyOnTheBar_andOnlyWhenTheMachineOffersIt() {
        #expect(WelcomeAdoptCancel.offersCancel(screenPhase: .adopting(fraction: 0.6), canCancelMigration: true))
        #expect(!WelcomeAdoptCancel.offersCancel(screenPhase: .adopting(fraction: 0.6), canCancelMigration: false))
        for other: CloudWelcomeSignInPhase in [.waitingLeader, .error(retryable: true), .adoptExit(.effectStalled),
                                               .relaunch, .reentryReady, .checking] {
            #expect(!WelcomeAdoptCancel.offersCancel(screenPhase: other, canCancelMigration: true), "\(other)")
        }
    }

    private static func after(
        _ phase: MigrationPhase, effect: Bool = false, exit: AdoptClaimExit? = .cancelled, unreadable: Bool = false
    ) -> WelcomeAdoptCancel.AfterCancel {
        WelcomeAdoptCancel.afterCancel(
            journaledPhase: phase, adoptEffectJournaled: effect, adoptClaimExit: exit, journalUnreadable: unreadable)
    }

    /// Solo con la huella entera: `notStarted`, sin el pendiente del efecto y con la marca de la cancelación.
    @Test func afterCancel_leavesOnlyWithTheFootprint() {
        #expect(Self.after(.notStarted) == .back)
    }

    /// El EFECTO pendiente ya es `notStarted` ANTES de cancelar: sin este término, una cancelación que no aterrizó
    /// (la pre-espera del import venció) sacaba a la persona con el efecto vivo, y el re-kick lo retomaba a su espalda.
    @Test func afterCancel_effectStillPending_staysPut() {
        #expect(Self.after(.notStarted, effect: true) == .keepPolling)
    }

    /// Un adopt que terminó bien también deja `notStarted`, sin la marca: salir tiraba la cuenta ya adoptada.
    @Test func afterCancel_withoutTheCancelMark_staysPut() {
        #expect(Self.after(.notStarted, exit: nil) == .keepPolling)
        for other: AdoptClaimExit in [.stalled, .sessionExpired, .accountUnavailable, .effectStalled, .effectLocalFailure] {
            #expect(Self.after(.notStarted, exit: other) == .keepPolling, "\(other)")
        }
    }

    @Test func afterCancel_unreadableOrOtherPhase_staysPut() {
        #expect(Self.after(.notStarted, unreadable: true) == .keepPolling)
        #expect(Self.after(.claimingMigration) == .keepPolling)
        #expect(Self.after(.done) == .keepPolling)
    }

    // MARK: - La pantalla, cableada

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static let view = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"

    /// Solo código: los docblocks nombran los mismos símbolos.
    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String) throws -> String {
        let src = try source(view)
        let start = try #require(src.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(src[start.upperBound...])
        guard let open = chars.firstIndex(of: "{") else { return "" }
        var depth = 0
        var end = open
        for i in open..<chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { end = i; break } }
        }
        return String(chars[open...end])
    }

    /// Espacios colapsados: lo que se fija es la secuencia de tokens, no la indentación.
    private static func flat(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
    }

    /// El poll le pasa la marca al mapeo. Sin esto, el mapeo puro está bien y la pantalla sigue diciendo «conexión».
    @Test func poll_passesTheExit() throws {
        let poll = try Self.flat(Self.body(of: "private func pollAdoptProgress()"))
        #expect(poll.contains(Self.flat("""
            guard let next = CloudWelcomeSignInFlow.phase(
                for: controller.uiState,
                claimBlocker: controller.claimBlocker,
                adoptClaimExit: controller.adoptClaimExit) else {
            """)))
        // Terminal: el poll para, como en `.error`.
        #expect(poll.contains("case .relaunch, .error, .adoptExit: return"))
    }

    /// La fase pinta el texto de Almacenamiento y ofrece la flecha.
    @Test func adoptExitScreen_isWired() throws {
        let src = try Self.source(Self.view)
        #expect(src.contains("body: StorageFailureCopyLogic.adoptExitMessage(exit) ?? L10n.Welcome.Cloud.errorBody)"))
        let back = try Self.body(of: "private var canGoBack: Bool")
        #expect(back.contains(
            "case .intro, .notFound, .blockedForeignData, .error, .adoptExit, .providerMismatch, .accountBlocked: true"))
    }

    /// La barra ofrece el botón con el predicado de Almacenamiento, y su diálogo cancela por el mismo camino.
    @Test func cancelButton_isWired() throws {
        let adopting = try Self.flat(Self.body(of: "private func adoptingContent(fraction: Double)"))
        #expect(adopting.contains(Self.flat("""
            if offersAdoptCancel, let controller = CloudMigrationController.shared {
                cancelAdoptButton(controller)
            }
            """)))
        let offers = try Self.flat(Self.body(of: "private var offersAdoptCancel: Bool"))
        #expect(offers == Self.flat("""
            {
                guard !cancelRequested, let controller = CloudMigrationController.shared else { return false }
                return WelcomeAdoptCancel.offersCancel(screenPhase: phase, canCancelMigration: controller.canCancelMigration)
            }
            """))
        let button = try Self.flat(Self.body(of: "private func cancelAdoptButton("))
        // El botón entero: una sentencia añadida al toque (un `cancelAdopt()` directo que se salta el diálogo) cae aquí.
        #expect(button == Self.flat("""
            {
                Button(L10n.Storage.Progress.cancelMigration) {
                    confirmCancelAdopt = true
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(controller.isWorking ? 0.4 : 0.8))
                .disabled(controller.isWorking)
                .accessibilityIdentifier("welcome_cloud_adopt_cancel")
            }
            """))
        // El diálogo cuelga del `body`, que no sale del árbol: su `.onChange` corre de verdad.
        let src = try Self.flat(Self.source(Self.view))
        for needle in ["isPresented: $confirmCancelAdopt, titleVisibility: .visible) {",
                       "Button(L10n.Storage.Confirm.cancelMigrationConfirm) { cancelRequested = true launchFlow { await cancelAdopt() } }",
                       "Button(L10n.Storage.Confirm.cancelMigrationKeep, role: .cancel) {}",
                       "isAdoptClaim: controller.isAdoptClaim, isAdoptEffectPending: controller.isAdoptEffectPending))",
                       ".onChange(of: offersAdoptCancel) { _, offers in if !offers { confirmCancelAdopt = false } }"] {
            #expect(src.contains(needle), "\(needle)")
        }
    }

    /// El poll mira la cancelación pedida ANTES del mapeo, en cada vuelta; «Retomar» no re-reclama con ella pedida; y el
    /// flag se repone al empezar cada adopt.
    @Test func cancelLanded_isWatchedByThePoll() throws {
        let poll = try Self.flat(Self.body(of: "private func pollAdoptProgress()"))
        let check = try #require(poll.range(of: "controller.refresh() if cancelLanded(controller) { onBack() return }"))
        let mapping = try #require(poll.range(of: "guard let next = CloudWelcomeSignInFlow.phase("))
        #expect(check.lowerBound < mapping.lowerBound)
        let landed = try Self.flat(Self.body(of: "private func cancelLanded(_ controller: CloudMigrationController) -> Bool"))
        #expect(landed == Self.flat("""
            {
                cancelRequested && WelcomeAdoptCancel.afterCancel(
                    journaledPhase: controller.journaledPhase, adoptEffectJournaled: controller.adoptEffectJournaled,
                    adoptClaimExit: controller.adoptClaimExit, journalUnreadable: controller.isJournalUnreadable) == .back
            }
            """))
        let retry = try Self.flat(Self.body(of: "private func retryAdoptResume() async"))
        #expect(retry.contains("if case .idle = controller.uiState, !cancelRequested {"))
        let src = try Self.flat(Self.source(Self.view))
        #expect(src.contains(
            "lastObservedPhase = nil cancelRequested = false await CloudMigrationController.shared?.startAdoptWithExistingSession()"))
    }

    /// El cuerpo ENTERO: una sentencia antepuesta (un `onBack()` antes de cancelar, un `return`) pasaría un `contains`.
    @Test func cancelAdopt_cancelsThenPolls() throws {
        let cancel = try Self.body(of: "private func cancelAdopt() async")
        #expect(cancel == """
            {
                    guard let controller = CloudMigrationController.shared else { return }
                    await controller.cancelMigration()
                    guard !Task.isCancelled else { return }
                    await pollAdoptProgress()
                }
            """)
    }
}
