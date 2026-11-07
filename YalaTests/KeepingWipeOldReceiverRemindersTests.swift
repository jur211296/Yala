//
//  KeepingWipeOldReceiverRemindersTests.swift
//  YalaTests
//
//  Ticket `old-receivers-of-a-keeping-wipe-delete-the-origin-reminders`. «Vaciar datos» que se queda en el Panel conserva
//  los recordatorios, pero un dispositivo del mismo iCloud con la 2.1 procesa la señal con su corte viejo: se lleva todo
//  recordatorio creado hasta la señal, y el borrado viaja por el espejo al origen. El origen los vuelve a crear con fecha
//  posterior a la señal; aquí se prueba que el corte de la 2.1 ya no tiene nada que llevarse.
//
//  El corte de la 2.1 es el mismo `rowsToWipe(cut:)` de hoy en su parte de recordatorios (`takesDated`, sin
//  `keepsReminders`): la 2.1 borra `rows.notifications` tal cual.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("«Vaciar datos» que conserva la cuenta · los recordatorios frente a un receptor de la 2.1", .serialized)
struct KeepingWipeOldReceiverRemindersTests {

    private let signaledAt = Date(timeIntervalSince1970: 1_800_000_000)
    private var before: Date { signaledAt.addingTimeInterval(-3_600) }

    private func seedReminders(_ context: ModelContext) throws -> [NotificationItem] {
        let custom = NotificationItem(name: "Pagar la luz", text: "Vence hoy", hour: 9, minute: 30, type: .custom,
                                      isActive: false, iconName: "bolt.fill", colorHex: "#FF0000", sortOrder: 3)
        custom.weekdaysRaw = "2,4"
        custom.lastNotifiedDate = before
        custom.createdAt = before
        let report = NotificationItem(name: "Informe", text: "Tu semana", hour: 20, minute: 0, type: .weeklyReport,
                                      sortOrder: 1)
        report.configurationData = Data([1, 2, 3])
        report.createdAt = before
        context.insert(custom)
        context.insert(report)
        try context.save()
        return [custom, report]
    }

    /// Lo que se llevaría hoy el borrado de un receptor de la 2.1, con la marca del parque (entra por `skipOnboarding`).
    private func oldReceiverTakes(_ context: ModelContext) throws -> [NotificationItem] {
        let cut = try #require(RemoteWipeCutLogic.cut(signaledAt: signaledAt, fleetStartedOver: true))
        return try #require(DataWipeService.rowsToWipe(in: context, cut: cut).notifications)
    }

    @Test("control: sin re-crearlos, el corte de la 2.1 se lleva los recordatorios que el origen conserva")
    func withoutRecreating_theOldCutTakesThem() throws {
        let context = try makeTestContext()
        _ = try seedReminders(context)
        #expect(try oldReceiverTakes(context).count == 2)
    }

    @Test("re-creados tras la señal, el corte de la 2.1 no se lleva ninguno, y salen iguales")
    func recreated_surviveTheOldCut_andKeepEverything() throws {
        let context = try makeTestContext()
        let originals = try seedReminders(context)
        let originalIDs = Set(originals.map(\.id))

        try DataWipeService.recreateKeptRemindersAfterSignal(in: context, signaledAt: signaledAt,
                                                             now: signaledAt.addingTimeInterval(-5))

        let kept = try context.fetch(FetchDescriptor<NotificationItem>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(kept.count == 2)
        #expect(try oldReceiverTakes(context).isEmpty,
                "el receptor de la 2.1 se sigue llevando recordatorios que el origen prometió conservar")
        // Con un reloj por detrás de la señal, la copia nace igual DESPUÉS de ella (estrictamente).
        #expect(kept.allSatisfy { $0.createdAt > signaledAt })
        #expect(Set(kept.map(\.id)).isDisjoint(with: originalIDs),
                "una copia con el id de la original: el espejo la leería como la misma fila y el borrado de la 2.1 la alcanza")

        let report = try #require(kept.first)
        #expect(report.name == "Informe" && report.text == "Tu semana" && report.hour == 20 && report.minute == 0)
        #expect(report.typeRaw == NotificationType.weeklyReport.rawValue && report.configurationData == Data([1, 2, 3]))
        let custom = try #require(kept.last)
        #expect(custom.name == "Pagar la luz" && custom.text == "Vence hoy" && custom.hour == 9 && custom.minute == 30)
        #expect(custom.isActive == false && custom.iconName == "bolt.fill" && custom.colorHex == "#FF0000")
        #expect(custom.sortOrder == 3 && custom.weekdaysRaw == "2,4" && custom.lastNotifiedDate == before)
    }

    @Test("sin recordatorios no hace nada")
    func noReminders_noop() throws {
        let context = try makeTestContext()
        try DataWipeService.recreateKeptRemindersAfterSignal(in: context, signaledAt: signaledAt)
        #expect(try context.fetchCount(FetchDescriptor<NotificationItem>()) == 0)
    }
}

/// El cableado: solo el origen que AVISA al parque conservando la cuenta los re-crea.
@Suite("«Vaciar datos» que conserva la cuenta · cableado de la re-creación (source-scan)")
struct KeepingWipeOldReceiverRemindersWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    @Test("MUTACIÓN: dentro de `keepsReminders`, y solo con aviso al parque que conserva la cuenta")
    func recreationIsGatedOnTheKeepingBroadcast() throws {
        let fuente = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(fuente.contains("if keepsReminders { NotificationService.shared.cancelAllNotifications() "
                                + "if broadcastSignal && signalKeepsSetup { try recreateKeptRemindersAfterSignal("
                                + "in: context, signaledAt: signalTimestamp ?? .now) } }"),
                "la re-creación ya no va dentro de `keepsReminders` con su condición: o un receptor reescribe filas que viajan, o el origen deja de protegerlas")
        // Una sola llamada en producción: el receptor no puede re-crear (sus escrituras viajarían al origen).
        #expect(fuente.components(separatedBy: "recreateKeptRemindersAfterSignal(in:").count - 1 == 1)
    }
}
