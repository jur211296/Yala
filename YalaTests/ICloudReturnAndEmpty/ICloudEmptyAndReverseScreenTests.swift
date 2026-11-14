//
//  ICloudEmptyAndReverseScreenTests.swift
//  YalaTests / ICloudReturnAndEmpty
//
//  Dos bugs del recorrido de la bienvenida del 13-nov en el iPhone 14:
//   - E03 (card `icloud-recien-vaciado-yala-dice-ya-tiene`): tras «Vaciar datos», «Entrar con mi iCloud» decía «Ya tienes
//     datos en tu iCloud — 62 categorías» (solo las de serie que la app vuelve a sembrar) y la restauración avisaba de una
//     «copia de antes de pasar a tu cuenta de Yala» que ya no lo era. Jürgen: «no debe considerar cosas que no son para
//     iCloud vacío».
//   - E07 (card `volver-a-tu-icloud-se-queda-en-traer-tus`): «Traer tus datos de tu cuenta de Yala» sin cifra durante minutos
//     y «Cancelar» apagado. La cifra y el botón se fijan aquí; el drenaje por tandas, en `ReverseDrainBatchesTests`.
//

import Foundation
import Testing

@testable import Yala

private func corpus(transactions: Int = 0, accounts: Int = 0, categories: Int = 0, budgets: Int = 0,
                    truncated: Bool = false) -> ICloudPersonalCorpus {
    ICloudPersonalCorpus(transactions: transactions, accounts: accounts, categories: categories,
                         budgets: budgets, oldestTransactionDate: nil, truncated: truncated)
}

// MARK: - La puerta del Welcome

@Suite("iCloud recién vaciado · la puerta lo trata como vacío")
struct ICloudJustEmptiedGateTests {
    private typealias Gate = WelcomePrivateICloudGateLogic

    /// El caso del recorrido: 62 categorías de serie y nada más. Va directo, como un iCloud sin nada (E03b).
    @Test("solo categorías o presupuestos: sigue sin «Ya tienes datos»",
          arguments: [corpus(categories: 62), corpus(budgets: 3), corpus(categories: 62, budgets: 3)])
    func seedOnlyICloud_proceeds(_ c: ICloudPersonalCorpus) {
        #expect(c.hasAnyData, "control: el predicado del corpus (que lee el aviso tardío) sigue contándolas")
        #expect(Gate.decide(skipValidation: false, outcome: .measured(c), deviceData: .none) == .proceed)
    }

    @Test("movimientos, cuentas o el tope: avisa",
          arguments: [corpus(transactions: 1), corpus(accounts: 1), corpus(categories: 62, truncated: true),
                      corpus(transactions: 2, categories: 62)])
    func userDataICloud_asks(_ c: ICloudPersonalCorpus) {
        #expect(Gate.decide(skipValidation: false, outcome: .measured(c), deviceData: .none) == .foundData(c))
    }

    /// Lo que el teléfono tiene sigue mandando: con iCloud de serie y datos aquí, se avisa de los del teléfono.
    @Test("iCloud solo con categorías y el teléfono con datos: avisa de los del teléfono")
    func seedOnlyICloud_withDeviceData_asksAboutTheDevice() {
        #expect(Gate.decide(skipValidation: false, outcome: .measured(corpus(categories: 62)), deviceData: .present)
                == .foundDeviceData(iCloudUnverified: false))
    }
}

// MARK: - La nota de «copia de antes»

@Suite("Restaurar · la nota de copia antigua solo cuando corresponde")
struct RestorePreCloudNoteTests {
    @Test("faro puesto y la copia con movimientos o cuentas: sale",
          arguments: [(5, 0), (0, 2), (5, 2)])
    func linkedWithUserData_shows(_ counts: (Int, Int)) {
        #expect(WelcomeRestoreView.showsPreCloudNote(beaconLinked: true, transactions: counts.0, accounts: counts.1))
    }

    @Test("faro puesto y la copia sin movimientos ni cuentas (solo categorías de serie): no sale")
    func linkedWithSeedOnly_hides() {
        #expect(!WelcomeRestoreView.showsPreCloudNote(beaconLinked: true, transactions: 0, accounts: 0))
    }

    @Test("sin faro: no sale")
    func notLinked_hides() {
        #expect(!WelcomeRestoreView.showsPreCloudNote(beaconLinked: false, transactions: 9, accounts: 3))
    }
}

// MARK: - La cifra de «Traer tus datos»

@Suite("Volver a tu iCloud · «Traer tus datos» lleva su cifra")
struct ReverseBringStepCountTests {
    private typealias Logic = CloudProgressStepsLogic

    @Test("en el drenaje, el primer paso enseña «X de Y» con su barra")
    func drainShowsTheCount() {
        let steps = Logic.reverseSteps(
            phase: .reverseDrainAll, waitingForICloud: false, wipingDeleted: nil, startingReverse: false,
            pending: nil, firstPending: nil, bring: .init(done: 150, total: 600))
        #expect(steps.first?.kind == .bring)
        #expect(steps.first?.state == .active)
        #expect(steps.first?.count == .uploaded(done: 150, total: 600, fraction: 0.25))
    }

    @Test("fuera del drenaje la cifra no se arrastra", arguments: [MigrationPhase.reverseVerify, .reverseFreezeBackend])
    func otherPhasesHaveNoCount(_ phase: MigrationPhase) {
        let steps = Logic.reverseSteps(
            phase: phase, waitingForICloud: false, wipingDeleted: nil, startingReverse: false,
            pending: nil, firstPending: nil, bring: .init(done: 150, total: 600))
        #expect(steps.first?.count == nil)
    }

    @Test("sin cifra todavía (antes de la primera tanda): el paso sale sin número")
    func noProgressYet() {
        let steps = Logic.reverseSteps(
            phase: .reverseDrainAll, waitingForICloud: false, wipingDeleted: nil, startingReverse: false,
            pending: nil, firstPending: nil)
        #expect(steps.first?.count == nil)
    }
}

// MARK: - El cableado de «Cancelar» y de la cifra (source-scan)

@Suite("Volver a tu iCloud · «Cancelar» no espera al drenaje (source-scan)")
struct ReverseCancelWhileDrainingWiringTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/ICloudReturnAndEmpty/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo de un `func` sin líneas de comentario.
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
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"
    private static let runner = "Yala/Services/CloudSync/MigrationRunner.swift"
    private static let view = "Yala/App/Views/Settings/StorageSettingsView.swift"

    /// Hasta el 13-nov el botón colgaba de `isWorking`, que sigue en `true` durante todo el drenaje.
    @Test func cancelButton_isNotDisabledByTheWorkInFlight() throws {
        let button = try Self.body(of: "private func cancelReverseButton(_ controller: CloudMigrationController) -> some View {",
                                   in: Self.view)
        #expect(button.contains("isDisabled: controller.isCancellingReverse"))
        #expect(!button.contains("isWorking"), "el trabajo en vuelo no apaga «Cancelar»")
    }

    /// El «sí» llega al RUNNER antes de que el controller se ponga a esperar: es lo que el drenaje mira entre tandas.
    @Test func cancelReverse_reachesTheRunnerBeforeWaiting() throws {
        let cancel = try Self.body(of: "func cancelReverse() async {", in: Self.controller)
        let request = try #require(cancel.range(of: "_runner?.requestReverseCancel()"))
        let spin = try #require(cancel.range(of: "while isWorking {"))
        #expect(request.lowerBound < spin.lowerBound)
    }

    /// Firmar para continuar no puede dejar un «sí» viejo en el runner: cortaría la vuelta que la persona rescata.
    @Test func signInToResume_withdrawsTheRunnerCancel() throws {
        let resume = try Self.body(of: "func signInToResumeReverse() async {", in: Self.controller)
        let withdraw = try #require(resume.range(of: "_runner?.withdrawReverseCancel()"))
        let resumeCall = try #require(resume.range(of: "await resume()"))
        #expect(withdraw.lowerBound < resumeCall.lowerBound)
    }

    /// El runner pasa el «sí» al drenaje y no cuenta un corte por cancelar como atasco de la etapa.
    @Test func runnerDrain_passesTheCancelAndSkipsTheStallOnCancel() throws {
        let text = try Self.source(Self.runner)
        let drain = try #require(text.range(of: "case .reverseDrainAll:\n                // Por tandas"))
        let tail = String(text[drain.lowerBound...].prefix(2500))
        #expect(tail.contains("continueWhile: { [weak self] in !(self?.reverseCancelRequested ?? true) }"))
        #expect(tail.contains("if reverseCancelRequested, drainOutcome != .completed { return }"))
        let early = try #require(tail.range(of: "if reverseCancelRequested, drainOutcome != .completed { return }"))
        let stall = try #require(tail.range(of: "observeReversePreMountStall(.drain"))
        #expect(early.lowerBound < stall.lowerBound, "sale antes de observar el techo")
    }

    /// La cifra que pinta la pantalla es la del runner, solo en la fase del drenaje.
    @Test func controller_feedsTheBringCountOnlyWhileDraining() throws {
        let text = try Self.source(Self.controller)
        #expect(text.contains("reverseDrainProgress = _runner?.reverseDrainProgress"))
        #expect(text.contains("bring: journaledPhase == .reverseDrainAll ? reverseDrainProgress : nil"))
    }
}
