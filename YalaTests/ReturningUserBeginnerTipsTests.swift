//
//  ReturningUserBeginnerTipsTests.swift
//  YalaTests
//
//  Card «Quien entra por "Ya tengo una cuenta" vuelve a ver todos los tips de principiante», decisión de Jürgen del
//  2026-10-22: si llega con datos, no los ve; si llega vacío, sí.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tips de principiante · quien vuelve con datos no los ve", .serialized)
struct ReturningUserBeginnerTipsTests {

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "ReturningUserBeginnerTipsTests.\(UUID().uuidString)"))
    }

    private let entrada = Date(timeIntervalSince1970: 1_800_000_000)

    private func movimiento(creadoEl fecha: Date, en context: ModelContext) {
        let tx = TransactionItem(date: fecha, amount: -10, currencyCode: "PEN", note: "", category: nil, account: nil,
                                 tags: [], amountInPreferredCurrency: -10)
        tx.createdAt = fecha
        context.insert(tx)
    }

    // MARK: - La regla

    @Test("Sin entrada pendiente no hay nada que decidir")
    func nothingPending() {
        #expect(ReturningUserBeginnerTips.decide(pendingSince: nil, broughtData: true, now: entrada) == .nothingPending)
    }

    @Test("Con datos traídos, los tips se dan por vistos")
    func broughtData() {
        #expect(ReturningUserBeginnerTips.decide(pendingSince: entrada, broughtData: true, now: entrada) == .markSeen)
    }

    @Test("Sin datos todavía, se espera; pasado el plazo, ve los tips como alguien nuevo")
    func waitsThenGivesUp() {
        let casiSiete = entrada.addingTimeInterval(ReturningUserBeginnerTips.patience - 1)
        let pasado = entrada.addingTimeInterval(ReturningUserBeginnerTips.patience + 1)
        #expect(ReturningUserBeginnerTips.decide(pendingSince: entrada, broughtData: false, now: casiSiete) == .keepWaiting)
        #expect(ReturningUserBeginnerTips.decide(pendingSince: entrada, broughtData: false, now: pasado) == .giveUp)
    }

    // MARK: - Contra el store

    @Test("Llegó un movimiento de antes de la entrada: todas las marcas de «visto» y la entrada resuelta")
    func settleMarksEverySeenKey() throws {
        let context = try makeTestContext()
        let defaults = try isolatedDefaults()
        ReturningUserBeginnerTips.armOnReentry(now: entrada, defaults: defaults)
        movimiento(creadoEl: entrada.addingTimeInterval(-86_400 * 90), en: context)
        try context.save()

        var checklistDismissed = 0
        let decision = ReturningUserBeginnerTips.settleIfPending(
            context: context, now: entrada, defaults: defaults, dismissSetupChecklist: { checklistDismissed += 1 })

        #expect(decision == .markSeen)
        // Card ds09: «Primeros pasos» se retira con los tips, una vez.
        #expect(checklistDismissed == 1)
        for key in ReturningUserBeginnerTips.seenKeys {
            #expect(defaults.bool(forKey: key), "\(key) no quedó como visto")
        }
        #expect(defaults.object(forKey: ReturningUserBeginnerTips.pendingKey) == nil)
        #expect(defaults.bool(forKey: "guide.panel.dismissed"))
        #expect(defaults.bool(forKey: "hasSeenSettingsTour"))
    }

    @Test("Llegó vacío y la persona apunta su primer gasto: los tips siguen")
    func ownFirstExpenseDoesNotCount() throws {
        let context = try makeTestContext()
        let defaults = try isolatedDefaults()
        ReturningUserBeginnerTips.armOnReentry(now: entrada, defaults: defaults)
        movimiento(creadoEl: entrada.addingTimeInterval(60), en: context)
        try context.save()

        var checklistDismissed = 0
        let decision = ReturningUserBeginnerTips.settleIfPending(
            context: context, now: entrada.addingTimeInterval(120), defaults: defaults,
            dismissSetupChecklist: { checklistDismissed += 1 })

        #expect(decision == .keepWaiting)
        #expect(checklistDismissed == 0)
        #expect(!defaults.bool(forKey: "guide.panel.dismissed"))
        #expect(defaults.object(forKey: ReturningUserBeginnerTips.pendingKey) != nil)
    }

    @Test("Sin entrada pendiente, nada se toca aunque haya datos (quien empieza de cero ve sus tips)")
    func freshInstallKeepsTheTips() throws {
        let context = try makeTestContext()
        let defaults = try isolatedDefaults()
        movimiento(creadoEl: entrada.addingTimeInterval(-86_400), en: context)
        try context.save()

        var checklistDismissed = 0
        #expect(ReturningUserBeginnerTips.settleIfPending(
            context: context, now: entrada, defaults: defaults,
            dismissSetupChecklist: { checklistDismissed += 1 }) == .nothingPending)
        #expect(checklistDismissed == 0)
        #expect(!defaults.bool(forKey: "guide.panel.dismissed"))
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("La entrada por «Ya tengo una cuenta» la apunta y quien enseña tips pregunta antes")
    func wiring() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        let inicio = try #require(content.range(of: "fileprivate func completeOnboardingAsRestoreSkip() {"))
        #expect(content[inicio.upperBound...].prefix(400).contains("ReturningUserBeginnerTips.armOnReentry()"))

        #expect(try Self.code("Yala/App/AppBootstrapper.swift")
            .contains("ReturningUserBeginnerTips.settleIfPending(context: context)"))
        #expect(try Self.code("Yala/App/Views/Shared/ContextualGuideBanner.swift")
            .contains("ReturningUserBeginnerTips.settleIfPending(context: modelContext)"))
        #expect(try Self.code("Yala/App/Views/Profile/ProfileView.swift")
            .contains("ReturningUserBeginnerTips.settleIfPending(context: modelContext)"))

        // El borrado reinicia las mismas guías que esta regla marca, y suelta la entrada pendiente.
        let wipe = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("for guideID in ReturningUserBeginnerTips.guideIDs"))
        #expect(wipe.contains("defaults.removeObject(forKey: ReturningUserBeginnerTips.pendingKey)"))
    }
}
