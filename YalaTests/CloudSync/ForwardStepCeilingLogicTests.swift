//
//  ForwardStepCeilingLogicTests.swift
//  YalaTests / CloudSync
//
//  Lo PURO del techo de los tres pasos de la ida sin cifra que baje —claim (22 %), identidad (35 %) y `cutover(.pending)`
//  (80 %)— (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`): qué texto ve la persona por cada motivo, el WIRE
//  de los motivos y del canario, en qué fases se ofrece «Cancelar», y el cableado de la pantalla. El recorrido del runner
//  vive en `MigrationRunnerTests` §15; las aristas, en `MigrationStateMachineTests`; el reparto del no del servidor, en
//  `MigrationWorkExecutorTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Activación de la nube: techo de los tres pasos · lógica pura")
@MainActor
struct ForwardStepCeilingLogicTests {

    private let supportEmail = "soporte@example.test"

    private func message(
        _ exit: ForwardStepExitReason?, snapshot: SnapshotExitReason? = nil, _ blocker: ICloudChannelVerdict? = nil
    ) -> String {
        StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: snapshot, forwardStepExit: exit, cutoverBlocker: blocker,
            supportEmail: supportEmail)
    }

    private static let allReasons: [ForwardStepExitReason] = [
        .stalled, .sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure, .lineageUnproven,
    ]

    // MARK: - El texto de la tarjeta de fallo (decisión de Jürgen: texto POR MOTIVO)

    /// Cada motivo con su frase, comparando TEXTOS. Las dos que se reusan de la subida son exactamente las de la subida; las
    /// tres propias existen porque las de la subida hablan de subir los datos y al 22 % no se ha subido nada.
    @Test func eachForwardStepExitReason_hasTheDecidedText() {
        #expect(message(.stalled) == L10n.Storage.Failed.stepStalled)
        #expect(message(.sessionExpired) == L10n.Storage.Failed.stepSessionExpired)
        #expect(message(.otherDevice) == L10n.Storage.Failed.stepOtherDevice)
        #expect(message(.accountUnavailable) == L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail))
        #expect(message(.refused) == L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail),
                "el servidor dijo que no: es la frase de la cuenta, con su correo")
        #expect(message(.localFailure) == L10n.Storage.Failed.snapshotLocalFailure)
        #expect(message(.lineageUnproven) == L10n.Storage.Failed.stepLineageUnproven,
                "el relevo sin linaje (ticket `migration-takeover-uploads-without-a-lineage-check`)")
        #expect(message(.leaderRowsNotArrived) == L10n.Storage.Failed.stepLeaderRowsNotArrived,
                "el relevo del mismo iCloud sin las filas del líder: su frase, no la de «no coinciden»")
    }

    /// Las tres frases nuevas son distintas entre sí, de las de la subida que NO se reusan y del genérico. Y ninguna sale
    /// como clave cruda: comparar L10n con L10n no lo vería (lo cazó la review de la subida).
    @Test func theThreeNewTexts_areTheirOwn_andTranslated() {
        let new = [L10n.Storage.Failed.stepStalled, L10n.Storage.Failed.stepSessionExpired,
                   L10n.Storage.Failed.stepOtherDevice]
        #expect(Set(new).count == 3)
        for text in new {
            #expect(!text.hasPrefix("storage."), "clave sin traducir en el idioma de la corrida: \(text)")
            #expect(!text.isEmpty)
            #expect(text != L10n.Storage.Failed.snapshotStalled && text != L10n.Storage.Failed.snapshotSessionExpired,
                    "la de la subida dice «mientras subíamos tus datos», que al 22 % es falso")
            #expect(text != L10n.Storage.Failed.migration, "ninguno cae al genérico: esa fue la decisión")
        }
        #expect(Set(Self.allReasons.map { message($0) }).count == 6,
                "siete motivos, seis frases: `refused` y `accountUnavailable` comparten la de la cuenta a propósito")
    }

    /// Solo lo que dijo el servidor sobre la cuenta da el correo de soporte. «Otro dispositivo tomó el relevo» no es un
    /// problema que resolver con soporte.
    @Test func onlyTheAccountAnswers_giveTheSupportEmail() {
        for exit in [ForwardStepExitReason.accountUnavailable, .refused] {
            #expect(message(exit).contains(supportEmail), "\(exit)")
        }
        for exit in [ForwardStepExitReason.stalled, .sessionExpired, .otherDevice, .localFailure, .lineageUnproven] {
            #expect(!message(exit).contains(supportEmail), "\(exit)")
        }
    }

    /// El motivo de los tres pasos manda sobre el veredicto del canal iCloud (es el único escrito por ESTE fallo) y cede ante
    /// el de la subida, que va antes y conserva su comportamiento de #212.
    @Test func precedence_snapshotThenStepThenICloudVerdict() {
        #expect(message(.otherDevice, .quotaExceeded) == L10n.Storage.Failed.stepOtherDevice)
        #expect(message(.otherDevice, snapshot: .localFailure) == L10n.Storage.Failed.snapshotLocalFailure)
        #expect(message(nil, .quotaExceeded) == L10n.Storage.Failed.migrationICloudFull, "sin motivo, lo de siempre")
        #expect(message(nil) == L10n.Storage.Failed.migration)
        #expect(StorageFailureCopyLogic.message(kind: .reverse, snapshotExit: nil, forwardStepExit: .otherDevice,
                                                cutoverBlocker: nil) == L10n.Storage.Failed.reverse,
                "la vuelta no lee el motivo de la ida")
    }

    // MARK: - WIRE

    /// Los `rawValue` viajan en el journal, en la clave del reloj de causa y en el canario: letra a letra.
    @Test func rawValues_areWire() {
        #expect([ForwardStepPhase.claim, .identity, .cutoverPending, .waitingForLeader].map(\.rawValue)
            == ["claim", "identity", "cutoverPending", "waitingForLeader"])
        #expect([ForwardStepBlocker.sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure,
                 .lineageUnproven].map(\.rawValue)
            == ["sessionExpired", "accountUnavailable", "refused", "otherDevice", "localFailure", "lineageUnproven"])
        #expect(Self.allReasons.map(\.rawValue)
            == ["stalled", "sessionExpired", "accountUnavailable", "refused", "otherDevice", "localFailure",
                "lineageUnproven"])
        for blocker in [ForwardStepBlocker.sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure,
                        .lineageUnproven] {
            #expect(ForwardStepExitReason(blocker).rawValue == blocker.rawValue, "\(blocker)")
        }
    }

    /// Los tres pasos y la espera del seguidor (ticket `adopt-follower-waits-for-the-leader-with-no-ceiling`), y solo esos:
    /// la subida tiene su techo y el cutover confirmado no puede hacer rollback.
    @Test func forwardStepPhase_coversTheThreeStepsAndTheFollower() {
        #expect(ForwardStepPhase(phase: .claimingMigration) == .claim)
        #expect(ForwardStepPhase(phase: .assigningIdentity) == .identity)
        #expect(ForwardStepPhase(phase: .cutover(.pending)) == .cutoverPending)
        #expect(ForwardStepPhase(phase: .waitingForLeader) == .waitingForLeader)
        for phase in MigrationStateMachineTests.allPhases
        where ![MigrationPhase.claimingMigration, .assigningIdentity, .cutover(.pending), .waitingForLeader]
            .contains(phase) {
            #expect(ForwardStepPhase(phase: phase) == nil, "\(phase)")
        }
    }

    /// «Cancelar la activación» se ofrece en las cuatro fases en las que el teléfono sigue intacto y la fase puede
    /// quedarse parada, y en ninguna otra. En positivo: una fase nueva no lo gana por omisión. **El claim, con las dos
    /// intenciones** desde `adopt-claim-stays-parked-with-no-ceiling`: la salida del adopt ya lleva a volver a entrar. **Y la
    /// espera del seguidor** desde `adopt-follower-waits-for-the-leader-with-no-ceiling`: sin ella, un «sí» dado con el claim
    /// en vuelo se perdía si el claim contestaba `claiming_in_progress`.
    @Test func cancelScope_isTheSnapshotTheThreeStepsAndTheFollower() {
        let offering: [MigrationPhase] = [.claimingMigration, .assigningIdentity, .uploadingSnapshot, .cutover(.pending),
                                          .waitingForLeader]
        for phase in MigrationStateMachineTests.allPhases {
            #expect(ForwardCancelScope.offersCancel(phase) == offering.contains(phase), "\(phase)")
        }
    }

    // MARK: - El claim de un ADOPT (ticket `adopt-claim-stays-parked-with-no-ceiling`)

    /// Solo el claim y la espera del seguidor, y solo con la intención de adoptar (una fila sin intención se lee así en el
    /// runner y el controller). El seguidor entra desde `adopt-follower-waits-for-the-leader-with-no-ceiling`: sale igual y
    /// deja la misma marca.
    @Test func adoptClaimScope_isTheClaimOrTheFollowerWithTheAdoptIntent() {
        for phase in MigrationStateMachineTests.allPhases {
            #expect(AdoptClaimScope.isAdoptClaim(phase, claimIntent: .adoptIfExisting)
                    == (phase == .claimingMigration || phase == .waitingForLeader), "\(phase)")
            #expect(!AdoptClaimScope.isAdoptClaim(phase, claimIntent: .migrateOnly), "\(phase) · migrar")
        }
    }

    /// El aviso del 22 %: los dos motivos definitivos que vio el último claim, solo en el claim de un adopt. Los motivos que
    /// el claim no produce no se avisan con una frase que no es suya.
    @Test func adoptClaimNotice_isTheObservedDefinitiveCause_onlyInTheAdoptClaim() {
        let pairs: [(ForwardStepBlocker, AdoptClaimNotice)] = [(.sessionExpired, .sessionExpired),
                                                               (.accountUnavailable, .accountUnavailable)]
        for (cause, notice) in pairs {
            #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .adoptIfExisting, observedCause: cause)
                    == notice)
            #expect(AdoptClaimScope.notice(phase: .waitingForLeader, claimIntent: .adoptIfExisting, observedCause: cause)
                    == notice, "la espera del seguidor avisa igual")
            #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .migrateOnly, observedCause: cause)
                    == nil, "«Migrar» no está en el ticket")
            #expect(AdoptClaimScope.notice(phase: .assigningIdentity, claimIntent: .adoptIfExisting, observedCause: cause)
                    == nil, "fuera del claim no")
        }
        for cause in [ForwardStepBlocker.refused, .otherDevice, .localFailure] {
            #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .adoptIfExisting, observedCause: cause)
                    == nil, "\(cause)")
        }
        #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .adoptIfExisting, observedCause: nil)
                == nil, "la red no se avisa: se cura sola")
    }

    /// **La marca abre la tarjeta de adopt solo para SU cuenta** (hallazgo de la lente de consumidores): la tarjeta no pasa
    /// por la puerta de «Migrar», y con la sesión de otra cuenta —la de Grupos— adoptaba esa otra y le subía lo local.
    @Test func adoptReentry_isOfferedOnlyForTheAttemptAccount_orWithoutSession() {
        func offers(_ exit: AdoptClaimExit?, attempt: String?, session: Bool, hash: String?) -> Bool {
            AdoptClaimScope.offersReentry(exit: exit, attemptAccountHash: attempt, hasSession: session,
                                          sessionAccountHash: hash)
        }
        #expect(!offers(nil, attempt: "a", session: true, hash: "a"), "sin marca, lo de siempre")
        #expect(offers(.cancelled, attempt: "a", session: false, hash: nil), "sin sesión: la salida de la sesión borrada")
        #expect(offers(.stalled, attempt: "a", session: true, hash: "a"), "con la sesión de esa cuenta")
        #expect(!offers(.stalled, attempt: "a", session: true, hash: "b"), "con la de OTRA cuenta, no")
        #expect(!offers(.stalled, attempt: nil, session: true, hash: "b"), "sin saber de quién era el intento, no")
        #expect(!offers(.stalled, attempt: "a", session: true, hash: nil), "con sesión y sin cuenta legible, no")
    }

    /// Tras firmar desde esa tarjeta, otra cuenta no se adopta. Sin marca, o sin saber la cuenta del intento, es la tarjeta de
    /// siempre y no bloquea.
    @Test func adoptReentry_blocksAnotherAccountAfterSigningIn() {
        #expect(AdoptClaimScope.blocksReentry(exit: .sessionExpired, attemptAccountHash: "a", sessionAccountHash: "b"))
        #expect(AdoptClaimScope.blocksReentry(exit: .sessionExpired, attemptAccountHash: "a", sessionAccountHash: nil))
        #expect(!AdoptClaimScope.blocksReentry(exit: .sessionExpired, attemptAccountHash: "a", sessionAccountHash: "a"))
        #expect(!AdoptClaimScope.blocksReentry(exit: nil, attemptAccountHash: "a", sessionAccountHash: "b"))
        #expect(!AdoptClaimScope.blocksReentry(exit: .cancelled, attemptAccountHash: nil, sessionAccountHash: "b"))
    }

    /// WIRE de la marca, y de qué motivo del techo sale cada una. Los tres que el claim no produce caen al techo largo,
    /// que no acusa a nadie.
    @Test func adoptClaimExit_rawValuesAreWire_andMapFromTheCeiling() {
        #expect([AdoptClaimExit.stalled, .sessionExpired, .accountUnavailable, .cancelled].map(\.rawValue)
            == ["stalled", "sessionExpired", "accountUnavailable", "cancelled"])
        // Las dos del EFECTO (ticket `adopt-effect-retries-forever-with-no-ceiling`) no salen nunca del claim.
        for reason in [ForwardStepExitReason.stalled, .sessionExpired, .accountUnavailable, .refused, .otherDevice,
                       .localFailure, .lineageUnproven] {
            #expect(![AdoptClaimExit.effectStalled, .effectLocalFailure, .effectLineageUnproven]
                .contains(AdoptClaimExit(reason)), "\(reason)")
        }
        #expect(AdoptClaimExit(.stalled) == .stalled)
        #expect(AdoptClaimExit(.sessionExpired) == .sessionExpired)
        #expect(AdoptClaimExit(.accountUnavailable) == .accountUnavailable)
        for reason in [ForwardStepExitReason.refused, .otherDevice, .localFailure, .lineageUnproven] {
            #expect(AdoptClaimExit(reason) == .stalled, "\(reason)")
        }
    }

    private func adoptMessage(_ exit: AdoptClaimExit?, step: ForwardStepExitReason? = nil) -> String {
        StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: nil, forwardStepExit: step, adoptClaimExit: exit, cutoverBlocker: nil,
            supportEmail: supportEmail)
    }

    /// Cada salida del adopt con su frase, comparando TEXTOS, y por DELANTE del motivo del paso, que la misma salida
    /// también journalea. `cancelled` no tiene tarjeta: cae a lo de siempre.
    @Test func adoptClaimExit_hasItsOwnTexts_beforeTheStepReason() {
        #expect(adoptMessage(.stalled, step: .stalled) == L10n.Storage.Failed.adoptStalled)
        #expect(adoptMessage(.sessionExpired, step: .sessionExpired) == L10n.Storage.Failed.adoptSessionExpired)
        #expect(adoptMessage(.accountUnavailable, step: .accountUnavailable)
                == L10n.Storage.Failed.adoptAccountUnavailable(supportEmail))
        #expect(adoptMessage(.cancelled) == L10n.Storage.Failed.migration)
        #expect(adoptMessage(.cancelled, step: .stalled) == L10n.Storage.Failed.stepStalled)
        #expect(StorageFailureCopyLogic.message(kind: .reverse, snapshotExit: nil, adoptClaimExit: .stalled,
                                                cutoverBlocker: nil) == L10n.Storage.Failed.reverse)
    }

    /// Las frases nuevas son suyas, están traducidas, y **ninguna habla de los datos del dispositivo**: en un teléfono recién
    /// instalado no los hay. Solo la de la cuenta da el correo.
    @Test func adoptTexts_areTheirOwn_translated_andDoNotPromiseLocalData() {
        let texts = [L10n.Storage.Failed.adoptStalled, L10n.Storage.Failed.adoptSessionExpired,
                     L10n.Storage.Failed.adoptAccountUnavailable(supportEmail), L10n.Storage.Confirm.cancelAdoptBody,
                     L10n.Storage.Progress.adoptSessionExpired,
                     L10n.Storage.Progress.adoptAccountUnavailable(supportEmail), L10n.Storage.Errors.adoptOtherAccount]
        #expect(Set(texts).count == texts.count)
        let forwardTexts = [L10n.Storage.Failed.stepStalled, L10n.Storage.Failed.stepSessionExpired,
                            L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail),
                            L10n.Storage.Confirm.cancelMigrationBody, L10n.Storage.Failed.migration]
        for text in texts {
            #expect(!text.hasPrefix("storage."), "clave sin traducir: \(text)")
            #expect(!forwardTexts.contains(text), "reusar la frase de «Migrar» diría que los datos siguen aquí")
        }
        #expect(texts[2].contains(supportEmail) && texts[5].contains(supportEmail))
        for text in [texts[0], texts[1], texts[3], texts[4], texts[6]] { #expect(!text.contains(supportEmail)) }
    }

    /// Ninguna de las seis frases del adopt, en NINGÚN idioma, promete datos en este dispositivo: se leen del fichero de
    /// cada locale, porque la corrida solo ve uno. La prueba es que ninguna repite la frase de «Migrar» que lo promete.
    @Test func adoptTexts_inEveryLocale_doNotReuseTheLocalDataSentence() throws {
        let keys = ["storage.failed.adoptStalled", "storage.failed.adoptSessionExpired",
                    "storage.failed.adoptAccountUnavailable", "storage.confirm.cancelAdoptBody",
                    "storage.progress.adoptSessionExpired", "storage.progress.adoptAccountUnavailable",
                    "storage.errors.adoptOtherAccount"]
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let localData = try #require(table["storage.confirm.cancelMigrationBody"], "\(locale)")
                .components(separatedBy: CharacterSet(charactersIn: ".。")).first ?? ""
            for key in keys {
                let value = try #require(table[key], "\(locale) · \(key)")
                #expect(!value.isEmpty && !value.contains("NEEDS_TRANSLATION"), "\(locale) · \(key)")
                #expect(!value.contains(localData), "\(locale) · \(key) repite «\(localData)»")
            }
        }
    }


    /// **Los textos de la espera del seguidor, en los 16 idiomas** (ticket `adopt-follower-waits-for-the-leader-with-no-ceiling`,
    /// decisión de Jürgen): propios, traducidos, y ninguno repite el del 22 %, que se leía como parar el otro teléfono.
    @Test func followerTexts_inEveryLocale_areTheirOwn() throws {
        let pairs: [(String, String)] = [
            ("storage.waiting.stopWaiting", "storage.progress.cancelMigration"),
            ("storage.confirm.stopWaitingTitle", "storage.confirm.cancelMigrationTitle"),
            ("storage.confirm.stopWaitingBody", "storage.confirm.cancelAdoptBody"),
            ("storage.confirm.stopWaitingConfirm", "storage.confirm.cancelMigrationConfirm"),
            ("storage.confirm.stopWaitingKeep", "storage.confirm.cancelMigrationKeep"),
            ("storage.progress.followerSessionExpired", "storage.progress.adoptSessionExpired"),
        ]
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            for (key, twentyTwo) in pairs {
                let value = try #require(table[key], "\(locale) · \(key)")
                #expect(!value.isEmpty && !value.contains("NEEDS_TRANSLATION"), "\(locale) · \(key)")
                #expect(value != table[twentyTwo], "\(locale) · \(key) repite el texto del 22 %")
            }
        }
        #expect(!L10n.Storage.stopWaiting.hasPrefix("storage."), "clave sin traducir en la corrida")
        #expect(!L10n.Storage.Progress.followerSessionExpired.hasPrefix("storage."))
    }

    /// El detalle del canario: el paso delante y los dos tramos detrás, con la forma de la subida.
    @Test func waitingCanaryDetail_hasTheStepAndBothClocks() {
        #expect(MetricsService.forwardStepWaitingDetail(
            step: "claim", stalledSeconds: 10, causeStalledSeconds: 0, blocker: nil) == "claim|lt_15m|-|waiting")
        #expect(MetricsService.forwardStepWaitingDetail(
            step: "cutoverPending", stalledSeconds: 259_200, causeStalledSeconds: 900, blocker: "otherDevice")
            == "cutoverPending|gte_72h|15m_1h|stop_otherDevice")
        #expect(MetricsCanary.cloudForwardStepWaiting.rawValue == "cloudForwardStepWaiting")
        #expect(MetricsCanary.cloudForwardStepAborted.rawValue == "cloudForwardStepAborted")
    }

    // MARK: - El cableado de la pantalla (source-scan)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo de un `func`, de su llave de apertura a la de cierre, sin líneas de comentario.
    private static func body(of marker: String, in path: String) throws -> String {
        let src = try source(path)
        let start = try #require(src.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(src[start.upperBound...])
        guard let open = chars.firstIndex(of: "{") else { return "" }
        var depth = 0
        var end = open
        for i in open..<chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { end = i; break } }
        }
        return String(chars[open...end]).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// La tarjeta de fallo recibe el motivo de los tres pasos, y el controller lo lee del journal y lo vuelve a `nil` en las
    /// dos ramas sin fila legible. Sin la primera, la pantalla diría el genérico; sin la segunda, un motivo viejo.
    @Test func failureCard_readsTheStepReasonFromTheJournal() throws {
        let failure = try Self.body(of: "private func failureMessage(",
                                    in: "Yala/App/Views/Settings/StorageSettingsView.swift")
        #expect(failure.contains("forwardStepExit: controller.forwardStepExitReason"))
        let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"
        let src = try Self.source(controller)
        // Desde `an-unreadable-migration-journal-reads-as-never-started` la lectura es una función pura
        // (`MigrationJournalRead.read`) y el controller solo aplica su snapshot: sin fila, el motivo es `nil`
        // (`MigrationJournalSnapshot.empty`); con el fetch fallido NO se toca, y eso lo mide `MigrationJournalUnreadableTests`.
        #expect(src.contains(
            "forwardStepExitReason: state.forwardStepExitReasonRaw.flatMap(ForwardStepExitReason.init(rawValue:))"))
        let apply = try Self.body(of: "private func readJournal() -> MigrationJournalRead", in: controller)
        #expect(apply.contains("forwardStepExitReason = snapshot.forwardStepExitReason"))
        // La intención del claim, del journal y con el mismo default que el runner: sin ella, el botón saldría en el claim
        // de un adopt.
        #expect(src.contains(
            "claimIntent: state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting"))
        #expect(apply.contains("journaledClaimIntent = snapshot.claimIntent"))
        // El claim de un adopt: la marca de su salida y el reloj de causa del aviso, del journal (ticket
        // `adopt-claim-stays-parked-with-no-ceiling`). Sin ellos, «Reintentar» llevaría a «Migrar» y el aviso no saldría.
        #expect(src.contains("adoptClaimExit: state.adoptClaimExitRaw.flatMap(AdoptClaimExit.init(rawValue:))"))
        #expect(src.contains("adoptClaimAccountHash: state.adoptClaimAccountHash"))
        #expect(apply.contains("adoptClaimExit = snapshot.adoptClaimExit"))
        #expect(apply.contains("adoptClaimAccountHash = snapshot.adoptClaimAccountHash"))
        #expect(failure.contains("adoptClaimExit: controller.adoptClaimExit"))
        #expect(MigrationJournalSnapshot.empty.adoptClaimExit == nil)
        #expect(MigrationJournalSnapshot.empty.forwardStepExitReason == nil)
        #expect(MigrationJournalSnapshot.empty.claimIntent == .adoptIfExisting)
    }

    /// La pantalla del adopt, cableada (ticket `adopt-claim-stays-parked-with-no-ceiling`): la tarjeta de `.idle` ofrece
    /// «Activar la nube en este dispositivo» tras la salida de un adopt; el diálogo de cancelar cambia de cuerpo en su claim;
    /// y la tarjeta de progreso avisa del motivo definitivo. Cada término, fijado entero: sin el primero «Reintentar» lleva
    /// a «Migrar», que la puerta para; sin el segundo el diálogo dice que los datos siguen en el teléfono.
    @Test func adoptScreen_isWired() throws {
        let view = "Yala/App/Views/Settings/StorageSettingsView.swift"
        let migrate = try Self.body(of: "private func migrateCard(", in: view)
        #expect(migrate.contains(
            "let isAdopt = controller.offersAdoptReentry || controller.markerDecision() == .secondaryDeviceCloudLogin"))
        let cancel = try Self.body(of: "private func cancelMigrationButton(", in: view)
        // Desde `adopt-effect-retries-forever-with-no-ceiling` con un tercer cuerpo para el efecto del adopt. Desde
        // `welcome-adopt-effect-failure-has-no-reason-and-no-cancel` lo elige una función que comparte con la bienvenida;
        // sus tres ramas las fija `WelcomeAdoptExitTests.cancelBody_perPhase`.
        #expect(cancel.contains("""
            Text(StorageFailureCopyLogic.cancelMigrationBody(
                            isAdoptClaim: controller.isAdoptClaim, isAdoptEffectPending: controller.isAdoptEffectPending))
            """))
        let card = try Self.body(of: "private func progressCard(", in: view)
        #expect(card.contains("} else if let notice = controller.adoptClaimNotice {"))
        #expect(card.contains("Text(adoptClaimNoticeText(notice))"))
        // La espera del seguidor lleva el mismo aviso y la misma salida con sus palabras (ticket
        // `adopt-follower-waits-for-the-leader-with-no-ceiling`), y la tarjeta recibe el controller.
        let waiting = try Self.body(of: "private func waitingCard(", in: view)
        #expect(waiting.contains("if let notice = controller.adoptClaimNotice {\n                Text(followerNoticeText(notice))"))
        #expect(waiting.contains("if controller.canStopWaitingForLeader {\n                stopWaitingButton(controller)"))
        #expect(!waiting.contains("cancelMigrationButton"), "«Cancelar la activación» se leía como parar el otro teléfono")
        #expect(try Self.source(view).contains("case .waitingForLeader:\n            waitingCard(controller)"))
        let stop = try Self.body(of: "private func stopWaitingButton(", in: view)
        for needle in ["YalaSecondaryButton(L10n.Storage.stopWaiting,", "confirmStopWaiting = true",
                       "isPresented: $confirmStopWaiting", "Button(L10n.Storage.Confirm.stopWaitingConfirm) {",
                       "Task { await controller.cancelMigration() }",
                       "Button(L10n.Storage.Confirm.stopWaitingKeep, role: .cancel) {}",
                       "Text(L10n.Storage.Confirm.stopWaitingBody)"] {
            #expect(stop.contains(needle), "\(needle)")
        }
        let followerNotice = try Self.body(of: "private func followerNoticeText(", in: view)
        #expect(followerNotice.contains("case .sessionExpired:     return L10n.Storage.Progress.followerSessionExpired"))
        #expect(try Self.source(view).contains("""
            .onChange(of: controller?.canStopWaitingForLeader) { _, waiting in
                        if waiting != true { confirmStopWaiting = false }
            """))
        let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"
        let reentry = try Self.body(of: "var offersAdoptReentry: Bool", in: controller)
        #expect(reentry.contains("exit: adoptClaimExit, attemptAccountHash: adoptClaimAccountHash,"))
        #expect(reentry.contains("hasSession: CloudAuthService.shared.hasSession,"))
        #expect(reentry.contains("sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) })"))
        // Tras firmar, la tarjeta de adopt no entra en OTRA cuenta: la comprobación va antes de fijar la intención y del
        // claim, y para sin escribir nada.
        let toClaim = try Self.body(of: "private func continueToClaim(", in: controller)
        #expect(toClaim.contains("""
            if AdoptClaimScope.blocksReentry(
                            exit: adoptClaimExit, attemptAccountHash: adoptClaimAccountHash,
                            sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) }) {
                            _ = await closeSessionIfOpened(openedSession)
                            await r.submit(.signInFailed)
            """))
        let blockAt = try #require(toClaim.range(of: "AdoptClaimScope.blocksReentry("))
        let intentAt = try #require(toClaim.range(of: "r.setForwardClaimIntent(.adoptIfExisting)"))
        #expect(blockAt.lowerBound < intentAt.lowerBound)
        let refresh = try Self.body(of: "func refresh()", in: controller)
        #expect(refresh.contains("claimDefinitiveCause = _runner?.lastClaimDefinitiveCause"))
        let isAdopt = try Self.body(of: "var isAdoptClaim: Bool", in: controller)
        #expect(isAdopt.contains(
            "!isJournalUnreadable && AdoptClaimScope.isAdoptClaim(journaledPhase, claimIntent: journaledClaimIntent)"))
        let stopWaiting = try Self.body(of: "var canStopWaitingForLeader: Bool", in: controller)
        #expect(stopWaiting.contains("canCancelMigration && journaledPhase == .waitingForLeader"))
        let notice = try Self.body(of: "var adoptClaimNotice: AdoptClaimNotice?", in: controller)
        #expect(notice.contains("guard !isJournalUnreadable else { return nil }"))
        #expect(notice.contains(
            "phase: journaledPhase, claimIntent: journaledClaimIntent, observedCause: claimDefinitiveCause"))
    }

    // MARK: - El relevo sin linaje (ticket `migration-takeover-uploads-without-a-lineage-check`)

    /// Su frase es suya —no la del adopt con el mismo nombre, que habla de un marcador y de esperar a iCloud— y en ningún
    /// idioma promete «tus datos» en el teléfono: la bienvenida la enseña a un teléfono que puede estar recién instalado. Se
    /// lee del fichero de cada locale, porque la corrida solo ve uno.
    @Test func lineageText_isItsOwn_inEveryLocale() throws {
        let text = L10n.Storage.Failed.stepLineageUnproven
        #expect(!text.hasPrefix("storage."))
        #expect(text != L10n.Storage.Failed.adoptEffectLineageUnproven)
        #expect(text != L10n.Storage.Failed.stepOtherDevice)
        #expect(StorageFailureCopyLogic.forwardLineageMessage == text, "una sola frase para las dos pantallas")

        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let value = try #require(table["storage.failed.stepLineageUnproven"], "\(locale)")
            #expect(!value.isEmpty && !value.contains("NEEDS_TRANSLATION"), "\(locale)")
            // La frase de «Migrar» que promete los datos en el teléfono, cortada en su primera cláusula (el molde del adopt).
            let localData = try #require(table["storage.confirm.cancelMigrationBody"], "\(locale)")
                .components(separatedBy: CharacterSet(charactersIn: ".。,，、;；")).first ?? ""
            #expect(!localData.isEmpty, "\(locale): control del corte")
            #expect(!value.contains(localData), "\(locale) repite «\(localData)»")
            #expect(value != table["storage.failed.adoptEffectLineageUnproven"], "\(locale)")
        }
    }

    /// Ticket `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`. El relevo del MISMO iCloud al
    /// que le faltan las filas del líder tiene su frase: la de `lineageUnproven` dice que los datos «no coinciden» y pide
    /// revisar la cuenta, y aquí es la cuenta buena y coinciden. Hereda las prohibiciones de su vecina —no promete «tus datos»
    /// en el teléfono— y es distinta de ella y de la del adopt en cada idioma.
    @Test func leaderRowsText_isItsOwn_inEveryLocale() throws {
        let text = L10n.Storage.Failed.stepLeaderRowsNotArrived
        #expect(!text.hasPrefix("storage."))
        #expect(text != L10n.Storage.Failed.stepLineageUnproven)
        #expect(StorageFailureCopyLogic.forwardLineageMessage(for: .leaderRowsNotArrived) == text)
        #expect(StorageFailureCopyLogic.forwardLineageMessage(for: .lineageUnproven)
                == L10n.Storage.Failed.stepLineageUnproven, "control: el otro motivo conserva su frase")

        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let value = try #require(table["storage.failed.stepLeaderRowsNotArrived"], "\(locale)")
            #expect(!value.isEmpty && !value.contains("NEEDS_TRANSLATION"), "\(locale)")
            let localData = try #require(table["storage.confirm.cancelMigrationBody"], "\(locale)")
                .components(separatedBy: CharacterSet(charactersIn: ".。,，、;；")).first ?? ""
            #expect(!localData.isEmpty, "\(locale): control del corte")
            #expect(!value.contains(localData), "\(locale) repite «\(localData)»")
            #expect(value != table["storage.failed.stepLineageUnproven"], "\(locale)")
            #expect(value != table["storage.failed.adoptEffectLineageUnproven"], "\(locale)")
        }
    }

    /// El claim no produce el linaje: el aviso del 22 % calla con él, como con los otros motivos que no son suyos.
    @Test func lineageUnproven_isNotAClaimNotice() {
        #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .adoptIfExisting,
                                       observedCause: .lineageUnproven) == nil)
        #expect(AdoptClaimScope.notice(phase: .claimingMigration, claimIntent: .adoptIfExisting,
                                       observedCause: .leaderRowsNotArrived) == nil)
    }

    /// La bienvenida: el adopt que recibió el relevo y salió por linaje tiene su fase —ni `.adoptExit`, que es del claim o
    /// del efecto, ni el «Revisa tu conexión» de `.error`—. La marca de un adopt manda antes, y la vuelta no lo lee.
    @Test func welcome_lineageExit_isItsOwnPhase() {
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), forwardStepExit: .lineageUnproven)
                == .lineageExit(.lineageUnproven))
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), forwardStepExit: .leaderRowsNotArrived)
                == .lineageExit(.leaderRowsNotArrived), "misma pantalla y salidas, con su frase")
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), forwardStepExit: .localFailure)
                == .error(retryable: true), "los demás motivos del paso siguen como estaban")
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.migration), adoptClaimExit: .stalled,
                                             forwardStepExit: .lineageUnproven) == .adoptExit(.stalled))
        #expect(CloudWelcomeSignInFlow.phase(for: .failed(.reverse), forwardStepExit: .lineageUnproven)
                == .error(retryable: true))
        #expect(CloudWelcomeSignInFlow.phase(for: .idle, forwardStepExit: .lineageUnproven) == .adopting(fraction: 0))
    }
}
