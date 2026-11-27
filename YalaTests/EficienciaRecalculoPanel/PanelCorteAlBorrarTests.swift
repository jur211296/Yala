//
//  PanelCorteAlBorrarTests.swift
//  YalaTests
//
//  Lote 4 de eficiencia (26-nov-2026): con el cálculo del Panel cediendo el hilo dentro de sus etapas, otra tarea puede
//  borrar un movimiento entre dos tramos (un «Deshacer» que vence, una página de la nube). Leer un `@Model` borrado
//  aborta en el iPhone, así que el cálculo se corta y una recarga lo rehace con lo de ahora. Un guardado sin borrados no
//  corta: con una importación en marcha el Panel no terminaría nunca.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Recálculo del Panel · un borrado a mitad corta y recarga", .serialized)
@MainActor
struct PanelCorteAlBorrarTests {

    @MainActor private final class Mando {
        var calls = 0
        var armed = false
        var action: (() -> Void)?
    }

    private let session = SessionState()

    private func makePanel(foreground: @escaping @MainActor () -> Bool) throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let account = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(account)
        for i in 0..<40 {
            context.insert(TransactionItem(
                date: aMomentAgoToday(), amount: -Double(i + 1), currencyCode: "PEN",
                account: account, amountInPreferredCurrency: -Double(i + 1), preferredCurrencyCode: "PEN"
            ))
        }
        try context.save()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = foreground
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    private func wait(_ viewModel: PanelViewModel, completedReaching target: Int) async throws {
        for _ in 0..<150 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func settle(_ viewModel: PanelViewModel) async throws {
        let before = viewModel.debugCalculationRuns
        viewModel.reloadAndRecalculate()
        try await wait(viewModel, completedReaching: before + 1)
        try #require(viewModel.debugCalculationRuns == before + 1)
        try await Task.sleep(for: .milliseconds(250))
    }

    @Test("Un movimiento borrado y guardado entre dos etapas corta el cálculo y una recarga lo rehace sin él")
    func deletionMidCalculation_cutsAndReloads() async throws {
        let mando = Mando()
        let (viewModel, context) = try makePanel(foreground: {
            mando.calls += 1
            if mando.armed, mando.calls == 2 { mando.action?() }
            return true
        })
        try await settle(viewModel)
        let victim = try #require(viewModel.transactions.first)
        mando.action = {
            context.delete(victim)
            do { try context.save() } catch { Issue.record("no guardó: \(error)") }
        }
        mando.calls = 0
        mando.armed = true
        let started = viewModel.debugCalculationsStarted
        let completed = viewModel.debugCalculationRuns

        viewModel.recalculateData()
        try await wait(viewModel, completedReaching: completed + 1)

        #expect(viewModel.debugCalculationRuns == completed + 1, "la recarga terminó")
        #expect(viewModel.debugCalculationsStarted >= started + 2, "el cálculo con el borrado dentro se cortó y se rehízo")
        #expect(!viewModel.transactions.contains { $0.isDeleted || $0.modelContext == nil })
        #expect(viewModel.transactions.count == 39)
    }

    @Test("Un guardado sin borrados a mitad del cálculo no lo corta")
    func saveWithoutDeletion_doesNotCut() async throws {
        let mando = Mando()
        let (viewModel, context) = try makePanel(foreground: {
            mando.calls += 1
            if mando.armed, mando.calls == 2 { mando.action?() }
            return true
        })
        try await settle(viewModel)
        mando.action = {
            context.insert(Yala.Category(name: "Nueva", colorHex: "#000", isIncome: false))
            do { try context.save() } catch { Issue.record("no guardó: \(error)") }
        }
        mando.calls = 0
        mando.armed = true
        let started = viewModel.debugCalculationsStarted
        let completed = viewModel.debugCalculationRuns

        viewModel.recalculateData()
        try await wait(viewModel, completedReaching: completed + 1)

        #expect(viewModel.debugCalculationRuns == completed + 1)
        #expect(viewModel.debugCalculationsStarted == started + 1, "un guardado sin borrados cortó el cálculo")
    }
}
