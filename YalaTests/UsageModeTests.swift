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

    /// «Vaciar datos» y el borrado del cierre de sesión barren la marca con las preferencias.
    @Test func elBarridoDePreferenciasSeLaLleva() {
        let defaults = makeIsolatedDefaults(prefix: "test.usagemode.sweep")
        GroupsOnlyViewMark.set(true, defaults)
        DataWipeService.removeUserPreferenceKeys(from: defaults)
        #expect(!GroupsOnlyViewMark.isOn(defaults))
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

    /// La ida pone la marca ANTES de retirar lo pendiente: con ella puesta, ningún productor vuelve a agendar.
    @Test func laIdaMarcaAntesDeRetirarLoPendiente() throws {
        let body = try Self.lines(of: "static func enterGroupsOnly() async {",
                                  in: try Self.source("Yala/App/Services/UsageModeService.swift"), take: 7)
        let mark = try #require(body.firstIndex { $0 == "sessionState.prefersGroupsOnlyView = true" })
        let cancel = try #require(body.firstIndex { $0 == "await NotificationService.shared.cancelPendingPersonalNotifications()" })
        #expect(mark < cancel)
    }
}
