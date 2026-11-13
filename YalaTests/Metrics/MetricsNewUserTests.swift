//
//  MetricsNewUserTests.swift
//  YalaTests
//
//  Telemetría del usuario nuevo después del alta (card 4b7h, 2026-11-13): el reinicio del alta, el primer registro,
//  presupuesto, pago y segunda cuenta, y Primeros pasos. Cada evento sale UNA VEZ POR INSTALACIÓN; los `primeros.*` solo
//  en una instalación que cerró el alta con esta versión, y lo borrado como «Era de prueba» no cuenta.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

/// Red que nunca entrega (500): el vaciado corta con `.retry` y lo encolado se queda en la cola para leerlo.
private final class FailingSession: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(), response)
    }
}

/// Los 15 eventos de la card, en el orden del catálogo.
private let newUserEvents: [MetricsUseFeature] = [
    .altaReabrirPide, .altaReabrirVuelve,
    .primerosRegistro, .primerosPresupuesto, .primerosPago, .primerosCuenta2,
    .primerosPasosVe, .primerosPasosCuenta, .primerosPasosRegistrar, .primerosPasosPresupuesto, .primerosPasosPagos,
    .primerosPasosGrupo, .primerosPasosDinero, .primerosPasosInicio, .primerosPasosCompleta,
]

@MainActor
@Suite("Usuario nuevo · catálogo y decisiones puras")
struct MetricsNewUserLogicTests {

    @Test func losQuinceSonDeUnaVezPorInstalacion_yLosDeAntesNo() {
        for feature in newUserEvents {
            #expect(feature.isOncePerInstall, "\(feature.rawValue)")
            #expect(feature.requiresNewUser == feature.rawValue.hasPrefix("primeros."), "\(feature.rawValue)")
        }
        let others = MetricsUseFeature.allCases.filter { !newUserEvents.contains($0) }
        #expect(others.allSatisfy { !$0.isOncePerInstall }, "los de siempre siguen siendo uno al día")
        #expect(others.contains(.altaTermina) && others.contains(.registrarMovimiento))
    }

    @Test func unaVez_yLosPrimerosSoloConAltaNueva() {
        #expect(MetricsOnceLogic.shouldEmit(.altaReabrirPide, emitted: [], isNewUser: false))
        #expect(!MetricsOnceLogic.shouldEmit(.altaReabrirPide, emitted: ["alta.reabrir.pide"], isNewUser: true))
        #expect(!MetricsOnceLogic.shouldEmit(.primerosRegistro, emitted: [], isNewUser: false), "quien actualiza no tiene «primero»")
        #expect(MetricsOnceLogic.shouldEmit(.primerosRegistro, emitted: ["primeros.pago"], isNewUser: true))
        #expect(!MetricsOnceLogic.shouldEmit(.primerosRegistro, emitted: ["primeros.registro"], isNewUser: true))
    }

    @Test func reabrir_soloLoDelAlta() {
        let signUp: Set<WelcomeMirrorRelaunchLogic.Destination> = [.privateOnboarding, .restoreICloud]
        for destination in WelcomeMirrorRelaunchLogic.Destination.allCases {
            let isSignUp = signUp.contains(destination)
            #expect(MetricsUseFeature.relaunchAsked(destination: destination) == (isSignUp ? .altaReabrirPide : nil), "\(destination)")
            #expect(MetricsUseFeature.relaunchReturned(destination: destination) == (isSignUp ? .altaReabrirVuelve : nil), "\(destination)")
        }
        #expect(MetricsUseFeature.relaunchAsked(destination: nil) == nil)
    }

    @Test func cadaPasoDelMazo_tieneSuSlug_yLasPracticasNo() {
        let slugs = SetupStepID.deck.compactMap(NewUserMilestoneLogic.deckStepDone)
        #expect(slugs.count == SetupStepID.deck.count)
        #expect(Set(slugs).count == slugs.count, "uno distinto por paso")
        #expect(NewUserMilestoneLogic.deckStepDone(.tryVoiceInput) == nil)
        #expect(NewUserMilestoneLogic.deckStepDone(.tryImageInput) == nil)
    }

    @Test func hitos_porPaso() {
        #expect(NewUserMilestoneLogic.milestone(for: .firstExpense) == .primerosRegistro)
        #expect(NewUserMilestoneLogic.milestone(for: .firstBudget) == .primerosPresupuesto)
        #expect(NewUserMilestoneLogic.milestone(for: .scheduledPayment) == .primerosPago)
        #expect(NewUserMilestoneLogic.milestone(for: .tryVoiceInput) == nil, "la práctica de voz crea un borrador")
        #expect(NewUserMilestoneLogic.milestone(for: .firstAccount) == nil)
    }

    @Test func alArrancar_elRegistroEsperaAlTutorial_peroNoPorSiempre() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let ceiling = NewUserMilestoneLogic.recordTutorialWaitCeiling
        func emits(_ m: MetricsUseFeature, running: Bool, waited: TimeInterval?) -> Bool {
            NewUserMilestoneLogic.emitsAtLaunch(
                m, recordTutorialRunning: running, waitingSince: waited.map { _ in start },
                now: start.addingTimeInterval(waited ?? 0))
        }
        #expect(!emits(.primerosRegistro, running: true, waited: ceiling - 1), "su hoja final aún puede preguntar")
        #expect(emits(.primerosRegistro, running: true, waited: ceiling), "tutorial abandonado: sale")
        #expect(emits(.primerosRegistro, running: true, waited: nil), "sin fecha, vencido")
        #expect(emits(.primerosRegistro, running: false, waited: 0))
        #expect(emits(.primerosPresupuesto, running: true, waited: 0), "el tutorial solo retiene el registro")
    }

    @Test func segundaCuenta_desdeDos() {
        #expect(!NewUserMilestoneLogic.reachesSecondAccount(billableAccounts: 1))
        #expect(NewUserMilestoneLogic.reachesSecondAccount(billableAccounts: 2))
        #expect(NewUserMilestoneLogic.reachesSecondAccount(billableAccounts: 3))
    }
}

@MainActor
@Suite("Usuario nuevo · una vez por instalación, y lo de prueba no cuenta", .serialized)
struct MetricsNewUserServiceTests {

    private func withStartedService(newUser: Bool = true, _ body: (UserDefaults) throws -> Void) rethrows {
        let defaults = makeIsolatedDefaults()
        MetricsService._testReset()
        MetricsService.start(client: MetricsClient(baseURL: URL(fileURLWithPath: "/"), urlSession: FailingSession()), defaults: defaults)
        defer { MetricsService._testReset() }
        if newUser { MetricsService.localRegistrationCompleted(mode: "initial") }
        try body(defaults)
    }

    private func count(_ feature: MetricsUseFeature, in defaults: UserDefaults) -> Int {
        MetricsSpool.pending(defaults).filter { $0 == .use(feature) }.count
    }

    @Test(arguments: newUserEvents)
    func cadaEvento_saleUnaVez_yNoSeRepite(_ feature: MetricsUseFeature) {
        withStartedService { defaults in
            #expect(count(feature, in: defaults) == 0)
            MetricsService.used(feature)
            MetricsService.used(feature)
            MetricsService.used(feature, now: Date.now.addingTimeInterval(3 * 86_400))
            #expect(count(feature, in: defaults) == 1, "una vez por instalación, también otro día")
        }
    }

    @Test func sinAltaNueva_losPrimerosNoSalen_yElReinicioSi() {
        withStartedService(newUser: false) { defaults in
            MetricsService.used(.primerosRegistro)
            MetricsService.used(.primerosPasosVe)
            MetricsService.used(.altaReabrirPide)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            #expect(count(.primerosPasosVe, in: defaults) == 0)
            #expect(count(.altaReabrirPide, in: defaults) == 1)
        }
    }

    @Test func activarYalaCompleto_noEsUnAltaNueva() {
        withStartedService(newUser: false) { defaults in
            MetricsService.localRegistrationCompleted(mode: "fullActivation")
            MetricsService.used(.primerosRegistro)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            MetricsService.localRegistrationCompleted(mode: "groupInvite")
            MetricsService.used(.primerosRegistro)
            #expect(count(.primerosRegistro, in: defaults) == 1)
        }
    }

    @Test func conElPasoYaHecho_saleEnElActo() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstBudget, stepAlreadyCompleted: true)
            #expect(count(.primerosPresupuesto, in: defaults) == 1)
        }
    }

    @Test func sinPregunta_saleAlCerrarElPaso() {
        withStartedService { defaults in
            NewUserMetrics.created(.scheduledPayment, stepAlreadyCompleted: false)
            #expect(count(.primerosPago, in: defaults) == 0, "espera a saber si viene «¿Era de prueba?»")
            NewUserMetrics.stepCompleted(.scheduledPayment, practicePending: false)
            #expect(count(.primerosPago, in: defaults) == 1)
            #expect(count(.primerosPasosPagos, in: defaults) == 1)
        }
    }

    @Test func guardarloComoReal_emiteAlContestar() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.stepCompleted(.firstExpense, practicePending: true)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            #expect(count(.primerosPasosRegistrar, in: defaults) == 1, "el paso sí está hecho")
            NewUserMetrics.practiceAnswered(step: .firstExpense, kept: true)
            #expect(count(.primerosRegistro, in: defaults) == 1)
        }
    }

    @Test func borrarloComoPrueba_noEmite_yElSiguienteSi() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.stepCompleted(.firstExpense, practicePending: true)
            NewUserMetrics.practiceAnswered(step: .firstExpense, kept: false)
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: false)
            #expect(count(.primerosRegistro, in: defaults) == 0, "ni al contestar ni al arrancar")
            // El paso ya está hecho: el siguiente registro sale en el acto.
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: true)
            #expect(count(.primerosRegistro, in: defaults) == 1)
        }
    }

    @Test func laPreguntaDeOtroPaso_noTocaElRegistro() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.practiceAnswered(step: .tryVoiceInput, kept: true)
            NewUserMetrics.practiceAnswered(step: .firstBudget, kept: true)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            #expect(count(.primerosPresupuesto, in: defaults) == 0, "no esperaba nada")
        }
    }

    @Test func tutorial_sinRegistroQueSeQuede_noEmite() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.recordTutorialFinished(keptARecord: false)
            NewUserMetrics.stepCompleted(.firstExpense, practicePending: false)
            #expect(count(.primerosRegistro, in: defaults) == 0)
        }
    }

    @Test func tutorial_conRegistroQueSeQueda_emiteAlCerrarElPaso() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.recordTutorialFinished(keptARecord: true)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            NewUserMetrics.stepCompleted(.firstExpense, practicePending: false)
            #expect(count(.primerosRegistro, in: defaults) == 1)
        }
    }

    @Test func alArrancar_saleLoQueEsperaba_salvoElRegistroConTutorial() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstBudget, stepAlreadyCompleted: false)
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: true)
            #expect(count(.primerosPresupuesto, in: defaults) == 1)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: false)
            #expect(count(.primerosRegistro, in: defaults) == 1)
            #expect(defaults.object(forKey: MetricsService.waitingMilestonesKey) == nil, "no queda nada esperando")
        }
    }

    /// Cerrar el tutorial con la X tras probar una manera lo deja en marcha: a las 24 h el registro sale igual.
    @Test func tutorialAbandonado_elRegistroSaleAlDiaSiguiente() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: true, now: .now.addingTimeInterval(3600))
            #expect(count(.primerosRegistro, in: defaults) == 0)
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: true, now: .now.addingTimeInterval(25 * 3600))
            #expect(count(.primerosRegistro, in: defaults) == 1, "el plazo cuenta desde el primero, no desde el último")
        }
    }

    @Test func reentrada_retiraLaMarcaYLoQueEsperaba() {
        withStartedService { defaults in
            NewUserMetrics.created(.firstBudget, stepAlreadyCompleted: false)
            NewUserMetrics.reentered()
            NewUserMetrics.releaseWaitingAtLaunch(recordTutorialRunning: false)
            MetricsService.used(.primerosRegistro)
            #expect(count(.primerosPresupuesto, in: defaults) == 0)
            #expect(count(.primerosRegistro, in: defaults) == 0)
            #expect(!defaults.bool(forKey: MetricsService.newUserKey))
        }
    }

    @Test func sinAltaNueva_nadaEspera() {
        withStartedService(newUser: false) { defaults in
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            #expect(defaults.object(forKey: MetricsService.waitingMilestonesKey) == nil)
        }
    }

    @Test func segundaCuenta_alCrearLaSegundaPropia() throws {
        try withStartedService { defaults in
            let context = try makeTestContext()
            context.insert(Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#22C55E", iconName: "banknote", type: "cash"))
            try context.save()
            NewUserMetrics.accountCreated(in: context)
            #expect(count(.primerosCuenta2, in: defaults) == 0, "con una no")
            context.insert(Account(name: "BCP", currencyCode: "PEN", colorHex: "#F97316", iconName: "creditcard", type: "debit"))
            try context.save()
            NewUserMetrics.accountCreated(in: context)
            NewUserMetrics.accountCreated(in: context)
            #expect(count(.primerosCuenta2, in: defaults) == 1)
        }
    }

    @Test func resetLocalState_olvidaLoDeUnaVez() {
        withStartedService { defaults in
            MetricsService.used(.primerosPasosVe)
            NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: false)
            MetricsService.resetLocalState(defaults)
            #expect(defaults.stringArray(forKey: MetricsService.onceEmittedKey) == nil)
            #expect(!defaults.bool(forKey: MetricsService.newUserKey))
            #expect(defaults.object(forKey: MetricsService.waitingMilestonesKey) == nil)
        }
    }

    @Test func sinServicio_enTests_noEscribeNada() {
        MetricsService._testReset()
        let before = MetricsSpool.pending(.standard).count
        MetricsService.used(.altaReabrirPide)
        NewUserMetrics.created(.firstExpense, stepAlreadyCompleted: true)
        #expect(MetricsSpool.pending(.standard).count == before, "en tests jamás toca .standard")
    }
}

@Suite("Usuario nuevo · la cola no pierde lo que sale una sola vez")
struct MetricsNewUserSpoolTests {

    /// Un `primeros.*` desalojado no vuelve nunca: con la cola llena caen antes los canarios y los `use` diarios.
    @Test func colaLlena_loDeUnaVezEsLoUltimoEnCaer() {
        let defaults = makeIsolatedDefaults()
        MetricsSpool.enqueue(.use(.primerosRegistro), defaults: defaults)
        MetricsSpool.enqueue(.use(.panel), defaults: defaults)
        for i in 0..<(MetricsSpool.capacity + 5) {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        let pending = MetricsSpool.pending(defaults)
        #expect(pending.count == MetricsSpool.capacity)
        #expect(pending.first == .use(.primerosRegistro), "el de una vez se queda")
        #expect(!pending.contains(.use(.panel)), "el diario cae el primero")
        #expect(!pending.contains { $0.n == "c0" }, "después, los canarios más viejos")
    }
}

/// Cada evento tiene quien lo emita en producción: un enganche borrado deja la serie del panel en cero sin un rojo.
@Suite("Usuario nuevo · cableado (source-scan)")
struct MetricsNewUserWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Solo código: un comentario que nombre el enganche no lo sostiene.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test(arguments: [
        ("Yala/App/ViewModels/NewTransactionViewModel.swift", "if !isTransfer { NewUserMetrics.created(.firstExpense) }"),
        ("Yala/Services/DraftService.swift", "if createsAnOwnRecord { NewUserMetrics.created(.firstExpense) }"),
        ("Yala/App/Views/Inbox/InboxDraftEditSheet.swift", "if createsAnOwnRecord { NewUserMetrics.created(.firstExpense) }"),
        ("Yala/App/ViewModels/ChatAssistantViewModel.swift", "NewUserMetrics.created(.firstExpense)"),
        ("Yala/App/ViewModels/BudgetEditorViewModel.swift", "if newBudgetUUID != nil { NewUserMetrics.created(.firstBudget) }"),
        ("Yala/App/ViewModels/ScheduledPaymentEditorViewModel.swift", "if createdNew { NewUserMetrics.created(.scheduledPayment) }"),
        ("Yala/App/ViewModels/Accounts/AccountFormViewModel.swift", "if created?.isBillableUserAccount == true { NewUserMetrics.accountCreated(in: context) }"),
        ("Yala/App/Services/FirstAccountCreator.swift", "NewUserMetrics.accountCreated(in: context)"),
        ("Yala/App/Models/SetupChecklistManager.swift", "NewUserMetrics.stepCompleted(step, practicePending: practiceItem != nil)"),
        ("Yala/App/Models/SetupChecklistManager.swift", "MetricsService.used(.primerosPasosCompleta)"),
        ("Yala/App/Views/Shared/PracticeCleanupPrompt.swift", "NewUserMetrics.practiceAnswered(step: item?.stepID, kept: !delete)"),
        ("Yala/App/Views/Panel/PanelSheetsModifier.swift", "NewUserMetrics.practiceAnswered(step: sheets.practiceCleanupItem?.stepID, kept: true)"),
        ("Yala/App/Views/Panel/PanelSheetsModifier.swift", "NewUserMetrics.practiceAnswered(step: sheets.practiceCleanupItem?.stepID, kept: false)"),
        ("Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift", "NewUserMetrics.recordTutorialFinished(keptARecord: hasAnyUserRecord())"),
        ("Yala/App/Views/Panel/PanelView.swift", ".onAppear { MetricsService.used(.primerosPasosVe) }"),
        ("Yala/App/AppBootstrapper.swift", "NewUserMetrics.releaseWaitingAtLaunch("),
        ("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift", "MetricsUseFeature.relaunchAsked("),
        ("Yala/App/ContentView.swift", "MetricsUseFeature.relaunchReturned(destination: pending)"),
        ("Yala/App/ContentView.swift", "if kind == .reentry { NewUserMetrics.reentered() }"),
    ])
    func elEngancheSigueAhi(_ path: String, _ hook: String) throws {
        #expect(Self.codeOnly(try Self.source(path)).contains(hook), "falta en \(path): \(hook)")
    }

    /// El lote solo cuenta los personales que aprobó él mismo: el hito va dentro de `genericApprovedCount > 0`.
    @Test func elLoteCuentaSoloLoPersonal() throws {
        let code = Self.codeOnly(try Self.source("Yala/Services/DraftService.swift"))
        let guardRange = try #require(code.range(of: "if genericApprovedCount > 0 {"))
        let rest = code[guardRange.upperBound...]
        let hook = try #require(rest.range(of: "NewUserMetrics.created(.firstExpense)"))
        let close = try #require(rest.range(of: "WidgetDataCache.updateCache(context: context)"))
        #expect(hook.lowerBound < close.lowerBound)
    }

    /// La respuesta al tutorial va ANTES de cerrar el paso: después, el paso ya habría emitido el registro que esperaba.
    @Test func elTutorialDescartaAntesDeCerrarElPaso() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift"))
        let discard = try #require(code.range(of: "NewUserMetrics.recordTutorialFinished("))
        let finish = try #require(code.range(of: "RecordTutorialSession.shared.finish()"))
        #expect(discard.lowerBound < finish.lowerBound)
    }

    /// La vuelta solo cuenta en las ramas que siguen el alta, no donde se vuelve a pedir reabrir.
    @Test func laVueltaNoSeCuentaAlVolverAPedirReabrir() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/ContentView.swift"))
        let consume = try #require(code.range(of: "if let pending = WelcomePendingDestinationStore.consume() {"))
        let after = code[consume.upperBound...]
        let reAsk = try #require(after.range(of: "welcomeFlowInitialStep = .mirrorRelaunch"))
        let firstNote = try #require(after.range(of: "noteReturned()"))
        #expect(reAsk.lowerBound < firstNote.lowerBound, "la rama que vuelve a pedir reabrir no anota la vuelta")
        #expect(after.components(separatedBy: "noteReturned()").count - 1 == 2, "onboarding privado y restaurar")
    }
}
