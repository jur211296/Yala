//
//  UsageModeTests.swift
//  YalaTests
//
//  «Cómo usas Yala» (card p0iu): la decisión pura de la vuelta, la vida de la marca de vista y el cableado de la pausa
//  de los avisos personales. El borrado de «Empezar de cero» va en `UsageModeFreshStartWipeTests` (necesita contexto).
//

import Foundation
import Testing

@testable import Yala

// MARK: - La decisión pura

struct UsageModeLogicTests {

    @Test func laPuertaDestacada_diceVolverSoloAQuienTuvoYalaCompleto() {
        #expect(UsageModeLogic.returnEntry(hasPrivateSession: true) == .comeBack)
        #expect(UsageModeLogic.returnEntry(hasPrivateSession: false) == .activate)
    }

    @Test func sinRegistros_noSePregunta_conUno_si() {
        #expect(UsageModeLogic.returnRoute(savedRecords: 0) == .direct)
        #expect(UsageModeLogic.returnRoute(savedRecords: 1) == .ask)
        #expect(UsageModeLogic.returnRoute(savedRecords: 248) == .ask)
    }

    /// Lo puenteado de un grupo vuelve solo tras el borrado, y un saldo inicial no es un registro.
    @Test func cuentaComoRegistroGuardado_soloLoPropio() {
        #expect(UsageModeLogic.countsAsSavedRecord(splitExpenseID: nil, splitSettlementID: nil, balanceAdjustmentType: nil))
        #expect(!UsageModeLogic.countsAsSavedRecord(splitExpenseID: "x", splitSettlementID: nil, balanceAdjustmentType: nil))
        #expect(!UsageModeLogic.countsAsSavedRecord(splitExpenseID: nil, splitSettlementID: "x", balanceAdjustmentType: nil))
        #expect(!UsageModeLogic.countsAsSavedRecord(splitExpenseID: nil, splitSettlementID: nil,
                                                    balanceAdjustmentType: "initialBalance"))
    }

    private func candidate(_ name: String, _ currency: String = "PEN", records: Int, archived: Bool = false,
                           system: Bool = false, line: Bool = false) -> UsageModeLogic.AccountCandidate {
        UsageModeLogic.AccountCandidate(name: name, currencyCode: currency, type: "checking", iconName: "creditcard",
                                        isArchived: archived, isSystemAccount: system, isLine: line,
                                        recordCount: records)
    }

    @Test func cuentaPrincipal_laDeMasRegistros_sinSistemaNiLineas() {
        let prefill = UsageModeLogic.primaryAccountPrefill([
            candidate("Grupos PEN", records: 90, system: true),
            candidate("Visa USD", "USD", records: 80, line: true),
            candidate("BCP", records: 40),
            candidate("Efectivo", "USD", records: 12),
        ], fallbackCurrency: "EUR")
        #expect(prefill.name == "BCP")
        #expect(prefill.currencyCode == "PEN")
    }

    @Test func cuentaPrincipal_prefiereNoArchivadas_yConEmpateElNombre() {
        let prefill = UsageModeLogic.primaryAccountPrefill([
            candidate("Vieja", records: 100, archived: true),
            candidate("Zeta", records: 5),
            candidate("Alfa", "USD", records: 5),
        ], fallbackCurrency: "EUR")
        #expect(prefill.name == "Alfa")
        #expect(prefill.currencyCode == "USD")
    }

    @Test func cuentaPrincipal_soloArchivadas_usaUnaArchivada() {
        let prefill = UsageModeLogic.primaryAccountPrefill([candidate("Vieja", "MXN", records: 3, archived: true)],
                                                           fallbackCurrency: "EUR")
        #expect(prefill.name == "Vieja")
        #expect(prefill.currencyCode == "MXN")
    }

    @Test func cuentaPrincipal_sinCuentas_usaLaDivisaPreferida() {
        let prefill = UsageModeLogic.primaryAccountPrefill([candidate("Grupos PEN", records: 9, system: true)],
                                                           fallbackCurrency: "EUR")
        #expect(prefill.name.isEmpty)
        #expect(prefill.currencyCode == "EUR")
    }
}

// MARK: - Los pagos que vencieron durante la pausa (encargo S11e)

struct UsageModePausedPaymentsLogicTests {

    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d)) ?? .distantPast
    }

    private func skips(isActive: Bool = true, isRecurring: Bool = true, hasPendingDraft: Bool = false,
                       due: Int, following: Int? = nil, pauseStart: Int?, today: Int = 27) -> Bool {
        UsageModeLogic.skipsOccurrencesMissedDuringPause(
            isActive: isActive, isRecurring: isRecurring, hasPendingDraft: hasPendingDraft,
            nextDueDay: day(due), followingDueDay: following.map(day), pauseStartDay: pauseStart.map(day),
            today: day(today))
    }

    @Test func venceDuranteLaPausa_seSalta() {
        #expect(skips(due: 20, pauseStart: 10))
        #expect(skips(due: 10, pauseStart: 10), "el día en que empezó la pausa ya cuenta")
        #expect(skips(due: 26, pauseStart: 10), "ayer también")
    }

    @Test func loDeHoy_loDeAntesDeLaPausa_yLoQueNoHaVencido_noSeTocan() {
        #expect(!skips(due: 27, pauseStart: 10), "hoy es el ciclo normal")
        #expect(!skips(due: 30, pauseStart: 10))
        #expect(!skips(due: 9, pauseStart: 10), "venció antes de la pausa")
    }

    @Test func sinFechaDeInicio_todoLoAnteriorAHoy() {
        #expect(skips(due: 1, pauseStart: nil))
        #expect(!skips(due: 27, pauseStart: nil))
    }

    @Test func pagoUnico_eInactivo_noSeTocan() {
        #expect(!skips(isRecurring: false, due: 20, pauseStart: 10))
        #expect(!skips(isActive: false, due: 20, pauseStart: 10))
    }

    /// Review adversarial de S11e: con un borrador pendiente, lo que decide es el vencimiento SIGUIENTE. Sin mirarlo, un
    /// borrador de antes de la pausa dejaba salir después, uno a uno, todo lo de la pausa.
    @Test func conBorradorPendiente_decideElVencimientoSiguiente() {
        #expect(skips(hasPendingDraft: true, due: 5, following: 12, pauseStart: 10), "lo que viene detrás es de la pausa")
        #expect(skips(hasPendingDraft: true, due: 15, following: 22, pauseStart: 10))
        #expect(!skips(hasPendingDraft: true, due: 15, following: 27, pauseStart: 10), "lo siguiente es hoy: ciclo normal")
        #expect(!skips(hasPendingDraft: true, due: 15, following: nil, pauseStart: 10), "la serie acaba en el pendiente")
        #expect(!skips(hasPendingDraft: true, due: 2, following: 9, pauseStart: 10), "lo siguiente también es de antes")
        #expect(!skips(hasPendingDraft: false, due: 5, following: 12, pauseStart: 10),
                "sin borrador, el de antes de la pausa sale primero por el camino normal")
    }
}

// MARK: - Apple Pay y Siri con Yala solo en grupos (encargo S11e)

struct GroupsOnlyIntentGateTests {

    @Test func laMismaDecisionQueLaShell() {
        #expect(GroupsOnlyIntentGate.verdict(hasPrivateSession: true, prefersGroupsOnlyView: false) == .allowed)
        #expect(GroupsOnlyIntentGate.verdict(hasPrivateSession: true, prefersGroupsOnlyView: true) == .blocked(.comeBack))
        #expect(GroupsOnlyIntentGate.verdict(hasPrivateSession: false, prefersGroupsOnlyView: false) == .blocked(.activate))
        #expect(GroupsOnlyIntentGate.verdict(hasPrivateSession: false, prefersGroupsOnlyView: true) == .blocked(.activate))
    }

    @Test func leeLasMarcas_yUnTelefonoNuevoSigueConSiri() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.gate")
        #expect(GroupsOnlyIntentGate.current(defaults) == .allowed, "sin marca escrita, la sesión privada se presume")
        PrivateSessionMark.set(true, defaults)
        GroupsOnlyViewMark.set(true, defaults)
        #expect(GroupsOnlyIntentGate.current(defaults) == .blocked(.comeBack))
        PrivateSessionMark.set(false, defaults)
        #expect(GroupsOnlyIntentGate.current(defaults) == .blocked(.activate))
    }

    /// Las cinco claves, con valor y sin la jerga de sesiones, en los dieciséis idiomas.
    @Test func losTextosExistenEnTodosLosIdiomas() throws {
        let keys = [GroupsOnlyIntentGate.messageKey(for: .activate), GroupsOnlyIntentGate.messageKey(for: .comeBack),
                    GroupsOnlyIntentGate.applePayTitleKey, GroupsOnlyIntentGate.applePayBodyKey(for: .activate),
                    GroupsOnlyIntentGate.applePayBodyKey(for: .comeBack)]
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent(locale).appendingPathComponent("Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale) no se lee")
            for key in keys {
                let value = try #require(table[key], "\(locale) no tiene \(key)")
                #expect(!value.isEmpty && !value.lowercased().contains("solo grupos"), "\(locale) · \(key): \(value)")
            }
        }
    }
}

// MARK: - La marca de vista vive encima de la sesión privada

@MainActor
struct GroupsOnlyViewMarkTests {

    @Test func seEnciendeYSeApaga_yLaPausaLaSigue() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.mark")
        #expect(!GroupsOnlyViewMark.isOn(defaults))
        #expect(!PersonalRemindersPause.isPaused(defaults))
        GroupsOnlyViewMark.set(true, defaults)
        #expect(GroupsOnlyViewMark.isOn(defaults))
        #expect(PersonalRemindersPause.isPaused(defaults))
        GroupsOnlyViewMark.set(false, defaults)
        #expect(!GroupsOnlyViewMark.isOn(defaults))
        #expect(!PersonalRemindersPause.isPaused(defaults))
    }

    /// Sin sesión privada no hay nada que ocultar: la marca muere con ella, y no deja en solo grupos a quien active
    /// Yala completo después.
    @Test func muereConLaSesionPrivada() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.dies")
        PrivateSessionMark.set(true, defaults)
        GroupsOnlyViewMark.set(true, defaults)
        PrivateSessionMark.set(true, defaults)
        #expect(GroupsOnlyViewMark.isOn(defaults), "reafirmar la sesión no puede apagar la vista")
        PrivateSessionMark.set(false, defaults)
        #expect(!GroupsOnlyViewMark.isOn(defaults))

        GroupsOnlyViewMark.set(true, defaults)
        PrivateSessionMark.clear(defaults)
        #expect(!GroupsOnlyViewMark.isOn(defaults))
    }

    /// «Vaciar datos» y el borrado del cierre de sesión barren la marca con las preferencias, y su fecha con ella.
    @Test func elBarridoDePreferenciasSeLaLleva() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.sweep")
        GroupsOnlyViewMark.set(true, defaults)
        DataWipeService.removeUserPreferenceKeys(from: defaults)
        #expect(!GroupsOnlyViewMark.isOn(defaults))
        #expect(defaults.object(forKey: GroupsOnlyViewMark.sinceUserDefaultsKey) == nil)
    }

    /// Encargo S11e: la marca apunta cuándo empezó la pausa. Reafirmarla no la mueve, y muere con ella por todos los
    /// caminos.
    @Test func apuntaElInicioDeLaPausa_unaVez_yMuereConLaMarca() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.since")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(GroupsOnlyViewMark.since(defaults) == nil)
        GroupsOnlyViewMark.set(true, defaults, now: start)
        GroupsOnlyViewMark.set(true, defaults, now: start.addingTimeInterval(86_400))
        #expect(GroupsOnlyViewMark.since(defaults) == start)
        GroupsOnlyViewMark.set(false, defaults)
        #expect(defaults.object(forKey: GroupsOnlyViewMark.sinceUserDefaultsKey) == nil)

        PrivateSessionMark.set(true, defaults)
        GroupsOnlyViewMark.set(true, defaults, now: start)
        PrivateSessionMark.set(false, defaults)
        #expect(defaults.object(forKey: GroupsOnlyViewMark.sinceUserDefaultsKey) == nil)

        // Una marca de un build sin fecha: la vuelta salta todo lo anterior a hoy.
        defaults.set(true, forKey: GroupsOnlyViewMark.userDefaultsKey)
        #expect(GroupsOnlyViewMark.since(defaults) == nil)
    }

    /// Del teléfono, no del Apple ID: no viaja por el canal de preferencias.
    @Test func noEsUnaPreferenciaSincronizada() {
        #expect(!PrefSyncKey.allCases.map(\.rawValue).contains(GroupsOnlyViewMark.userDefaultsKey))
    }
}

// MARK: - El cableado (source-scan)

@Suite("Cómo usas Yala · cableado de la pausa y de la vuelta")
struct UsageModeWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Las líneas de código de una función, de su firma a la primera que contenga `until`.
    private static func lines(of signature: String, in source: String, take count: Int) throws -> [String] {
        let all = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
        let start = try #require(all.firstIndex { $0.contains(signature) }, "no encontré «\(signature)»")
        return Array(all[(start + 1)..<min(all.count, start + 1 + count)])
    }

    /// Cada productor de avisos personales mira la pausa ANTES de hacer nada: si el guard baja, la primera línea deja
    /// de serlo y el caso cae.
    @Test(arguments: [
        ("Yala/Services/ReportNotificationService.swift", "func sendDueReports(context: ModelContext) async {"),
        ("Yala/Services/ScheduledPaymentNotificationService.swift", "func checkAllPaymentNotifications() async {"),
        ("Yala/Services/ScheduledPaymentNotificationService.swift", "func checkAndNotifyCreditCardPayments() async {"),
        ("Yala/Services/BudgetAlertService.swift", "func checkBudgetsAndNotify() async {"),
        ("Yala/App/Services/ScheduledPaymentDraftService.swift",
         "static func processDuePayments(context: ModelContext) -> Int {"),
    ])
    func cadaProductorPersonalMiraLaPausaPrimero(file: String, signature: String) throws {
        let body = try Self.lines(of: signature, in: try Self.source(file), take: 1)
        #expect(body.first?.hasPrefix("guard !PersonalRemindersPause.isPaused() else { return") == true,
                "\(file): \(signature) no empieza por la pausa: \(body)")
    }

    /// Los recordatorios repetitivos: la pausa va DETRÁS de la salida de los dinámicos (los de grupos) y retira lo
    /// agendado. Y los resúmenes de pagos se retiran sin agendar ninguno.
    @Test func recordatoriosYResumenes_respetanLaPausa() throws {
        let src = try Self.source("Yala/Services/NotificationService.swift")
        let schedule = try Self.lines(of: "func scheduleNotification(for item: NotificationItem) async {", in: src,
                                      take: 14)
        let dynamic = try #require(schedule.firstIndex { $0.hasPrefix("if item.notificationType.requiresDynamicContent") })
        let pause = try #require(schedule.firstIndex { $0 == "if PersonalRemindersPause.isPaused() {" })
        #expect(dynamic < pause, "la pausa iría antes de la salida de los avisos de grupos")
        #expect(schedule[pause + 1] == "await cancelNotification(for: item)")
        #expect(src.contains("if PersonalRemindersPause.isPaused() { effectivePlans = [] }"))
    }

    /// Los avisos de grupos NO leen la pausa: siguen igual (lienzo, ida).
    @Test func losAvisosDeGruposNoSePausan() throws {
        for file in ["Yala/Services/Groups/GroupNotificationService.swift",
                     "Yala/Services/Groups/GroupSettlementReminderService.swift",
                     "Yala/Services/Groups/GroupBudgetAlertService.swift"] {
            let src = try Self.source(file)
            #expect(!src.contains("PersonalRemindersPause"), "\(file) se pausaría en solo grupos")
        }
    }

    /// El intent de activar es la vuelta cuando hay sesión privada y «Solo grupos» elegido.
    @Test func elIntentDeActivar_esLaVueltaConSesionPrivada() throws {
        let body = try Self.lines(of: "case .presentFullModeActivation:", in: try Self.source("Yala/App/ContentView.swift"),
                                  take: 6)
        #expect(body == [
            "if SessionState.shared.isGroupsOnlyByChoice {",
            "beginReturnToFull()",
            "} else if SessionState.shared.isGroupsFocusedShell {",
            "SessionState.shared.returnToFullSummary = nil",
            "showFullModeActivation = true",
            "}",
        ])
    }

    /// Encargo S11e: la vuelta salta lo que venció en la pausa ANTES de levantarla (un kill entre las dos no deja que el
    /// arranque siguiente lo saque todo), y con la fecha que apuntó la marca.
    @Test func laVueltaSaltaLoVencido_antesDeLevantarLaPausa_yTrasSacarLoDeAntes() throws {
        let src = try Self.source("Yala/App/Services/UsageModeService.swift")
        let skipLine = "ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause(context: context, pausedSince: pause.since)"
        let body = try Self.lines(of: "static func returnToFull(context: ModelContext) async {", in: src, take: 6)
        #expect(Array(body[1...4]) == [
            "let pause = GroupsOnlyViewMark.isOn() ? PausedPayments(since: GroupsOnlyViewMark.since()) : nil",
            "if let pause {",
            skipLine,
            "}",
        ], "sin marca no se salta nada, y con ella se salta antes de levantarla")
        #expect(body[5] == "sessionState.prefersGroupsOnlyView = false")
        let resume = try Self.lines(of: "private static func resumePersonalReminders(context: ModelContext, pause: PausedPayments?) async {",
                                    in: src, take: 4)
        #expect(resume == [
            "ScheduledPaymentDraftService.processDuePayments(context: context)",
            "if let pause {",
            skipLine,
            "}",
        ])
    }

    /// Apple Pay y «anotar con Siri» miran la puerta ANTES de encolar nada; Siri, antes de Pro y de pedir el texto.
    @Test func applePayYSiri_miranLaPuertaPrimero() throws {
        let src = try Self.source("Yala/App/Intents/QuickExpenseIntent.swift")
        let applePay = try Self.lines(of: "struct ApplePayTransactionIntent: AppIntent {", in: src, take: 400)
        let applePayPerform = try #require(applePay.firstIndex { $0 == "func perform() async throws -> some IntentResult {" })
        #expect(applePay[applePayPerform + 1] == "if case .blocked(let entry) = GroupsOnlyIntentGate.current() {")
        let gateEnd = try #require(applePay[applePayPerform...].firstIndex { $0 == "return .result()" })
        #expect(applePay[applePayPerform..<gateEnd].contains("deepLink: GroupsOnlyIntentGate.activationDeepLink"))
        #expect(!applePay[applePayPerform..<gateEnd].contains { $0.contains("ApplePayPendingStore.append") })

        let siri = try Self.lines(of: "func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {",
                                  in: src, take: 3)
        #expect(siri == [
            "if case .blocked(let entry) = GroupsOnlyIntentGate.current() {",
            "return .result(dialog: await openFullModeActivation(entry), view: EmptyView())",
            "}",
        ])
    }

    /// Las dos preguntas de Siri dicen el aviso antes de leer la foto de las finanzas.
    @Test func lasPreguntasDeSiri_miranLaPuertaPrimero() throws {
        let src = try Self.source("Yala/App/Intents/SiriQueryIntents.swift")
        for intent in ["struct SpendingQueryIntent: AppIntent {", "struct BalanceQueryIntent: AppIntent {"] {
            let body = try Self.lines(of: intent, in: src, take: 30)
            let perform = try #require(body.firstIndex { $0 == "func perform() async throws -> some IntentResult & ProvidesDialog {" })
            #expect(Array(body[(perform + 1)...(perform + 3)]) == [
                "if case .blocked(let entry) = GroupsOnlyIntentGate.current() {",
                "return .result(dialog: IntentSpeech.resolved(GroupsOnlyIntentGate.message(for: entry)))",
                "}",
            ], "\(intent)")
        }
    }

    /// El toque del aviso de Apple Pay abre la vuelta (o la activación), antes de buscar un destino de pestaña.
    @Test func elToqueDelAvisoDeApplePay_abreLaVuelta() throws {
        let body = try Self.lines(of: "static func routeTap(deepLink destination: String, targetSessionID: String?) {",
                                  in: try Self.source("Yala/Services/NotificationService.swift"), take: 8)
        #expect(body.first == "if destination == GroupsOnlyIntentGate.activationDeepLink {")
        let submit = try #require(body.firstIndex { $0 == "RouterEntryGate.shared.submit(.presentFullModeActivation)" })
        #expect(body[submit + 1] == "return")
        #expect(GroupsOnlyIntentGate.activationDeepLink == "activate-full")
    }

    /// La ida pone la marca ANTES de retirar lo pendiente: con ella puesta, ningún productor vuelve a agendar.
    @Test func laIdaMarcaAntesDeRetirarLoPendiente() throws {
        let body = try Self.lines(of: "static func enterGroupsOnly() async {",
                                  in: try Self.source("Yala/App/Services/UsageModeService.swift"), take: 7)
        let mark = try #require(body.firstIndex { $0 == "sessionState.prefersGroupsOnlyView = true" })
        let cancel = try #require(body.firstIndex { $0 == "await NotificationService.shared.cancelPendingPersonalNotifications()" })
        #expect(mark < cancel)
    }
}
