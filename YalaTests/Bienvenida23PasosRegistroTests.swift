//
//  Bienvenida23PasosRegistroTests.swift
//  YalaTests
//
//  Lote 03 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): la prueba de cortesía y el estado del tutorial del paso 2 (Y23-09). En su propio fichero porque pide
//  `makeTestContext()` (una suite por fichero, `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Y23-09 · la prueba de cortesía y el estado del tutorial

@MainActor
@Suite("Bienvenida 2.3 · paso 2, prueba de cortesía (Y23-09)", .serialized)
struct RecordTutorialSessionTests {
    typealias Method = RecordTutorialLogic.Method

    private func session() throws -> RecordTutorialSession {
        RecordTutorialSession(defaults: try #require(testDefaults(suiteName: "RecordTutorial.\(UUID().uuidString)")))
    }

    private func fakeID(_ context: ModelContext) throws -> PersistentIdentifier {
        let item = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -25, currencyCode: "PEN")
        context.insert(item)
        try context.save()
        return item.persistentModelID
    }

    /// Las cuatro maneras en orden; hecha u omitida no se vuelve a ofrecer.
    @Test func methods_inOrder_eachOnce() throws {
        let context = try makeTestContext()
        let session = try session()
        #expect(session.nextMethod == .manual)
        session.recordSaved(.manual, id: try fakeID(context))
        #expect(session.nextMethod == .voice)
        session.skip(.voice)
        #expect(session.nextMethod == .photo)
        // Una prueba hecha no se reabre como pendiente ni cambia de estado.
        session.skip(.manual)
        #expect(session.state(of: .manual) == .done)
        session.recordSaved(.photo, id: try fakeID(context), isDraft: true)
        session.recordSaved(.ai, id: try fakeID(context))
        #expect(session.nextMethod == nil)
        #expect(session.records.count == 3)
        #expect(RecordTutorialLogic.betweenHeadline(recordCount: session.records.count) == .records(3))
    }

    /// Lo hecho se guarda: si iOS cierra Yala a mitad, se sigue donde iba.
    @Test func survivesARelaunch() throws {
        let context = try makeTestContext()
        let defaults = try #require(testDefaults(suiteName: "RecordTutorial.\(UUID().uuidString)"))
        let first = RecordTutorialSession(defaults: defaults)
        let id = try fakeID(context)
        first.recordSaved(.manual, id: id)
        first.skip(.voice)
        let again = RecordTutorialSession(defaults: defaults)
        #expect(again.state(of: .manual) == .done)
        #expect(again.state(of: .voice) == .skipped)
        #expect(again.records.map(\.persistentID) == [id])
        #expect(again.hasStarted)
    }

    /// Los borradores de más de una frase con varios gastos entran en la hoja sin cambiar el estado de la manera.
    @Test func extraDrafts_joinTheCleanupWithoutResolvingTheMethod() throws {
        let context = try makeTestContext()
        let session = try session()
        let extra = try fakeID(context)
        session.addExtraDrafts(.voice, ids: [extra, extra])
        #expect(session.records.count == 1)
        #expect(session.records.first?.isDraft == true)
        #expect(session.state(of: .voice) == .pending)
    }

    /// «Omitir este paso»: lo que falte queda omitido.
    @Test func skipAll_resolvesWhatIsLeft() throws {
        let session = try session()
        session.skipAll()
        #expect(session.nextMethod == nil)
        #expect(Method.allCases.allSatisfy { session.state(of: $0) == .skipped })
    }

    /// Con cuenta Free, Yala IA funciona dentro de la prueba y al cerrarla vuelve el candado.
    @Test func chatTrial_opensOnceAndLocksAgain() {
        let gate = FeatureGateService.shared
        guard !gate.isProUser else { return }
        #expect(!gate.canAccess(.chatAssistant))
        gate.enableSetupTrial(for: .chatAssistant)
        #expect(gate.canAccess(.chatAssistant))
        gate.disableSetupTrial(for: .chatAssistant)
        #expect(!gate.canAccess(.chatAssistant))
    }

    /// Mientras dura el tutorial, guardar un registro no da por hecho el paso 2 (lo cierra el tutorial al terminar), y
    /// al terminar con algo anotado queda hecho; sin nada, omitido.
    @Test func whileRunning_step2IsHeld_thenFinishResolvesIt() {
        let manager = SetupChecklistManager.shared
        manager.resetAll()
        manager.onAllStepsCompleted = {}
        defer { manager.resetAll() }

        manager.beginRecordTutorial()
        manager.markCompleted(.firstExpense)
        manager.markCompleted(.tryVoiceInput)
        manager.markSkipped(.firstExpense)
        #expect(!manager.isResolved(.firstExpense))
        #expect(!manager.isResolved(.tryVoiceInput))
        // Los demás pasos no se retienen.
        manager.markCompleted(.firstAccount)
        #expect(manager.isResolved(.firstAccount))

        manager.finishRecordTutorial(savedAnyRecord: true)
        #expect(!manager.isRecordTutorialRunning)
        #expect(manager.stepCompleted[.firstExpense] == true)

        // Cerrar sin haber probado ninguna manera no deja el paso retenido: un registro por otro camino lo cierra.
        manager.resetAll()
        manager.beginRecordTutorial()
        manager.cancelRecordTutorial()
        manager.markCompleted(.firstExpense)
        #expect(manager.stepCompleted[.firstExpense] == true)

        manager.resetAll()
        manager.beginRecordTutorial()
        manager.finishRecordTutorial(savedAnyRecord: false)
        #expect(manager.stepSkipped[.firstExpense] == true)
        #expect(manager.stepCompleted[.firstExpense] != true)
    }
}
