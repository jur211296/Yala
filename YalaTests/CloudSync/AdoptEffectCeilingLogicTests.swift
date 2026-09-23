//
//  AdoptEffectCeilingLogicTests.swift
//  YalaTests
//
//  Ticket `adopt-effect-retries-forever-with-no-ceiling`. El EFECTO del adopt —el reconcile de huérfanas que corre tras un
//  claim que ya contestó `existing_stable`— se reintentaba para siempre cuando no podía terminar, con Almacenamiento
//  pintado como si nunca hubiera empezado. Decisiones de Jürgen del 2026-09-23: 15 min acumulados con la base local que no
//  se deja leer, 72 h con cualquier causa, la tarjeta de progreso con «Cancelar» mientras espera, y dos textos propios.
//
//  Aquí va la lógica pura y el cableado de la pantalla. El comportamiento del runner (relojes, salida, cancelación) está en
//  `MigrationRunnerTests` §16; el ejecutor que separa la avería local de la red, en `MigrationWorkExecutorTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Efecto del adopt: techo, texto y salida · lógica pura")
@MainActor
struct AdoptEffectCeilingLogicTests {

    private let supportEmail = "soporte@example.test"

    private func message(_ exit: AdoptClaimExit?) -> String {
        StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: nil, forwardStepExit: nil, adoptClaimExit: exit, cutoverBlocker: nil,
            supportEmail: supportEmail)
    }

    // MARK: - Los textos (decisión de Jürgen: texto por motivo)

    /// Cada salida del efecto con su frase, comparando TEXTOS.
    @Test func eachEffectExit_hasTheDecidedText() {
        #expect(message(.effectLocalFailure) == L10n.Storage.Failed.adoptEffectLocalFailure)
        #expect(message(.effectStalled) == L10n.Storage.Failed.adoptEffectStalled)
    }

    /// Las tres frases nuevas son suyas y están traducidas: ninguna repite una del claim del adopt ni de «Migrar», y ninguna
    /// da el correo (ningún motivo del efecto habla de la cuenta).
    @Test func theThreeNewTexts_areTheirOwn_andTranslated() {
        let texts = [L10n.Storage.Failed.adoptEffectLocalFailure, L10n.Storage.Failed.adoptEffectStalled,
                     L10n.Storage.Confirm.cancelAdoptEffectBody]
        let others = [L10n.Storage.Failed.adoptStalled, L10n.Storage.Failed.adoptSessionExpired,
                      L10n.Storage.Failed.adoptAccountUnavailable(supportEmail), L10n.Storage.Confirm.cancelAdoptBody,
                      L10n.Storage.Confirm.cancelMigrationBody, L10n.Storage.Failed.stepStalled,
                      L10n.Storage.Failed.snapshotLocalFailure, L10n.Storage.Failed.migration]
        #expect(Set(texts).count == texts.count)
        for text in texts {
            #expect(!text.hasPrefix("storage."), "clave sin traducir: \(text)")
            #expect(!others.contains(text), "\(text)")
            #expect(!text.contains(supportEmail))
        }
    }

    /// **Ninguna de las tres afirma el estado de la nube, en ningún idioma.** El reconcile puede haber subido algo de este
    /// teléfono antes de fallar, así que la frase del claim del adopt —«este dispositivo no cambió nada de lo que tienes en
    /// la nube»— aquí sería falsa. Se lee del fichero de cada locale, porque la corrida solo ve uno.
    @Test func theNewTexts_inEveryLocale_claimNeitherTheCloudNorTheLocalData() throws {
        let keys = ["storage.failed.adoptEffectLocalFailure", "storage.failed.adoptEffectStalled",
                    "storage.confirm.cancelAdoptEffectBody"]
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let untouched = try #require(table["storage.confirm.cancelAdoptBody"], "\(locale)")
                .components(separatedBy: CharacterSet(charactersIn: ".。")).first ?? ""
            // Y la de «Migrar» que promete los datos en el teléfono, cortada en su primera cláusula: en un teléfono recién
            // instalado es falsa (la cazó la review; la regla es la del claim del adopt).
            let localData = try #require(table["storage.confirm.cancelMigrationBody"], "\(locale)")
                .components(separatedBy: CharacterSet(charactersIn: ".。,，、;；")).first ?? ""
            #expect(!untouched.isEmpty && !localData.isEmpty, "\(locale): control del corte de la frase")
            for key in keys {
                let value = try #require(table[key], "\(locale) · \(key)")
                #expect(!value.isEmpty && !value.contains("NEEDS_TRANSLATION"), "\(locale) · \(key)")
                #expect(!value.contains(untouched), "\(locale) · \(key) repite «\(untouched)»")
                #expect(!value.contains(localData), "\(locale) · \(key) repite «\(localData)»")
            }
        }
    }

    // MARK: - WIRE

    /// La marca va al journal y el paso al canario: no se renombran.
    @Test func rawValues_areWire() {
        #expect(AdoptClaimExit.effectStalled.rawValue == "effectStalled")
        #expect(AdoptClaimExit.effectLocalFailure.rawValue == "effectLocalFailure")
        #expect(AdoptEffectBlocker.localFailure.rawValue == "localFailure")
        #expect(MigrationRunner.adoptEffectStep == "adopt")
        #expect(MetricsService.forwardStepWaitingDetail(
            step: MigrationRunner.adoptEffectStep, stalledSeconds: 900, causeStalledSeconds: 900, blocker: "localFailure")
            == "adopt|15m_1h|15m_1h|stop_localFailure")
    }

    // MARK: - Alcance

    /// El efecto se está reintentando solo con las TRES cosas: `notStarted`, el efecto en el journal y el modo aún en iCloud.
    @Test func adoptEffectScope_isNotStartedWithThePending_beforeTheCloudMode() {
        #expect(AdoptEffectScope.isPending(.notStarted, adoptEffectJournaled: true, persistedCloudMode: false))
        #expect(!AdoptEffectScope.isPending(.notStarted, adoptEffectJournaled: false, persistedCloudMode: false),
                "`notStarted` a secas es el teléfono que nunca empezó")
        #expect(!AdoptEffectScope.isPending(.notStarted, adoptEffectJournaled: true, persistedCloudMode: true),
                "con `.cloud` ya escrito el adopt hizo lo irreversible")
        for phase in [MigrationPhase.claimingMigration, .failedRollback, .done, .waitingForLeader] {
            #expect(!AdoptEffectScope.isPending(phase, adoptEffectJournaled: true, persistedCloudMode: false), "\(phase)")
        }
    }

    /// «Cancelar» sale donde salía, y además con el efecto pendiente.
    @Test func cancelScope_addsTheAdoptEffect() {
        #expect(ForwardCancelScope.offersCancel(.notStarted, adoptEffectPending: true))
        #expect(!ForwardCancelScope.offersCancel(.notStarted, adoptEffectPending: false))
        #expect(ForwardCancelScope.offersCancel(.uploadingSnapshot, adoptEffectPending: false), "lo de antes no se pierde")
        #expect(!ForwardCancelScope.offersCancel(.verifying, adoptEffectPending: false))
    }

    // MARK: - La pantalla

    private func derive(_ mode: StorageMode, _ phase: MigrationPhase, adoptEffect: Bool) -> CloudMigrationUIState {
        CloudMigrationUIStateDeriver.derive(
            storageMode: mode, phase: phase, mirrorOffArmed: false, mountedDecision: .iCloudMirror,
            adoptEffectJournaled: adoptEffect)
    }

    /// Mientras se reintenta, progreso —con la fase journaleada— y no `.idle`: la persona ve que algo está pasando, y la
    /// tarjeta le da «Retomar» y «Cancelar». Con `.cloud` ya escrito sigue siendo el adoptado.
    @Test func deriver_paintsTheRetryingAdoptAsProgress() {
        #expect(derive(.icloud, .notStarted, adoptEffect: true)
                == .migrating(MigrationUIStep(fraction: CloudMigrationUIStateDeriver.adoptEffectFraction, phase: .notStarted)))
        #expect(derive(.icloud, .notStarted, adoptEffect: false) == .idle, "control: sin el pendiente, idle")
        #expect(derive(.cloud, .notStarted, adoptEffect: true) == .cloudActive)
        #expect(derive(.icloud, .failedRollback, adoptEffect: true) == .failed(.migration), "el flag no toca otras fases")
        #expect(CloudMigrationUIStateDeriver.adoptEffectFraction > CloudMigrationUIStateDeriver.fraction(for: .claimingMigration))
    }

    /// El Welcome lo lee como el adopt en curso, con su fracción: antes salía `.adopting(0)` por el `.idle`.
    @Test func welcome_readsTheRetryingAdoptAsAdopting() {
        let state = derive(.icloud, .notStarted, adoptEffect: true)
        #expect(CloudWelcomeSignInFlow.phase(for: state)
                == .adopting(fraction: CloudMigrationUIStateDeriver.adoptEffectFraction))
    }

    /// La lectura del journal lleva el pendiente: una fila con `.adoptBackendAccount` lo marca, y sin fila no.
    @Test func journalRead_carriesTheAdoptEffect() {
        let state = MigrationState()
        state.setPhase(.notStarted)
        state.setPendingEffects([.adoptBackendAccount])
        guard case .read(let snapshot) = MigrationJournalRead.read(fetch: { state }) else {
            Issue.record("control: la fila se leyó")
            return
        }
        #expect(snapshot.adoptEffectJournaled)
        let otra = MigrationState()
        otra.setPendingEffects([.rollback])
        guard case .read(let sinAdopt) = MigrationJournalRead.read(fetch: { otra }) else {
            Issue.record("control: la fila se leyó")
            return
        }
        #expect(!sinAdopt.adoptEffectJournaled)
        #expect(!MigrationJournalSnapshot.empty.adoptEffectJournaled)
    }

    // MARK: - Cableado (source-scan)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo de un `func`, de su llave de apertura a la de cierre, en líneas de código sin comentarios.
    private static func lines(of marker: String, in path: String) throws -> [String] {
        let src = try source(path)
        let start = try #require(src.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(src[start.upperBound...])
        guard let open = chars.firstIndex(of: "{") else { return [] }
        var depth = 0
        var end = open
        for i in open..<chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { end = i; break } }
        }
        return String(chars[open...end]).split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    /// Con el efecto del adopt pendiente, Almacenamiento conserva la sección de Grupos: puede durar 72 h, y es la única
    /// puerta para soltar esa cuenta (hallazgo de la review).
    @Test func progressCard_keepsTheGroupsSection_whileTheAdoptEffectRetries() throws {
        let src = try Self.source("Yala/App/Views/Settings/StorageSettingsView.swift")
        let code = src.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.isEmpty }
        let at = try #require(code.firstIndex(of: "case .migrating(let step):"))
        #expect(Array(code[at...(at + 4)]) == [
            "case .migrating(let step):",
            "progressCard(controller, step: step, reverse: false)",
            "if controller.isAdoptEffectPending {",
            "GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)",
            "}",
        ])
    }

    /// El `catch` del efecto que falla y el save que lo retira, enteros: el «sí» apuntado se honra antes de intentarlo, la
    /// observación va SOLO con el adopt, antes de la parada retomable, y el reloj se va en el MISMO save que retira el
    /// efecto.
    @Test func drain_observesTheAdoptFailure_andClearsTheClockOnSuccess() throws {
        let body = try Self.lines(of: "private func drainPendingEffects(isResume: Bool) async throws",
                                  in: "Yala/Services/CloudSync/MigrationRunner.swift")
        let tail = Array(body.suffix(13))
        #expect(tail == [
            "if effect == .adoptBackendAccount, migrationCancelRequested, try await journalMigrationCancel() { return }",
            "do {",
            "try await executor.execute(effect)",
            "} catch {",
            "CloudSyncBreadcrumb.migrationEffectFailed(effect: effect.rawValue, reason: \"\\(error)\")",
            "if effect == .adoptBackendAccount, try await observeAdoptEffectFailure(error) { return }",
            "throw Stop.effectFailed",
            "}",
            "removeFirstPending(state)",
            "if effect == .adoptBackendAccount { state.clearAdoptEffectStallCeiling() }",
            "try context.save()",
            "}",
            "}",
        ], "\(tail)")
    }
}
