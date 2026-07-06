//
//  DraftServiceHandleConvertTests.swift
//  YalaTests
//
//  Cubre `DraftService.handleDraftConvertedToGroupExpense` (commit 8d1c9211): tras convertir
//  un borrador PERSONAL en un `SplitExpense` de grupo (el form ya lo creó vía el bridge Caso A),
//  este método cierra el ciclo BORRANDO el `InboxDraft` original de la bandeja — sin crear una
//  `TransactionItem` personal (el gasto ya vive en el grupo).
//
//  Usa `makeTestContext()` (store in-memory reusado por archivo) → la suite DEBE ser
//  `@Suite(.serialized)`. El método toca `DraftService.shared` (singleton) y
//  `SessionState.shared` (increment de dataVersion), otra razón para serializar.
//
//  NOTA — la elegibilidad del botón ("Convertir a gasto compartido") vive en
//  `DraftConversionEligibilityLogic` y YA está cubierta por `DraftConversionEligibilityLogicTests`
//  (allowlist de sources, isExpense/hasAmount/hasEligibleGroups/status). NO se duplica aquí.
//
//  NOTA — el método captura errores internamente (`do/catch`, retorna Void) y no expone su
//  resultado, así que se verifica por efecto observable (draft ausente del store tras la llamada).
//  Los efectos colaterales sobre singletons de sólo-lectura externa (`WidgetDataCache`,
//  `TelemetryService`, `GroupTransactionBridge.isReady`) no son observables desde el test y
//  quedan fuera de aserción.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("DraftService.handleDraftConvertedToGroupExpense", .serialized)
struct DraftServiceHandleConvertTests {

    /// El draft convertido se ELIMINA del store (desaparece de la bandeja).
    @Test func convert_deletesDraftFromInbox() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, amount: 50.0, note: "Cena")
        try context.save()

        // Precondición: existe exactamente 1 draft.
        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).count == 1)

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).isEmpty)
    }

    /// Solo se borra el draft convertido; los demás drafts de la bandeja sobreviven.
    @Test func convert_leavesOtherDraftsUntouched() throws {
        let context = try makeTestContext()
        let target = makeTestInboxDraft(context: context, amount: 80.0, note: "A convertir")
        let survivor = makeTestInboxDraft(context: context, amount: 30.0, note: "Sigue en bandeja")
        try context.save()

        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).count == 2)

        DraftService.shared.handleDraftConvertedToGroupExpense(target, context: context)

        let remaining = try context.fetch(FetchDescriptor<InboxDraft>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.note == "Sigue en bandeja")
        #expect(remaining.first?.persistentModelID == survivor.persistentModelID)
    }

    /// El borrado se PERSISTE (save): un fetch nuevo tras la llamada no lo trae.
    @Test func convert_persistsDeletion() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, amount: 120.0, note: "Persistido")
        try context.save()
        let deletedID = draft.persistentModelID

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.persistentModelID == deletedID }
        )
        #expect(try context.fetch(descriptor).isEmpty)
    }

    /// NO crea una `TransactionItem` personal (el gasto ya vive en el grupo — solo se borra el draft).
    @Test func convert_doesNotCreatePersonalTransaction() throws {
        let context = try makeTestContext()
        let draft = makeTestInboxDraft(context: context, amount: 45.0, note: "Sin TX personal")
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)
    }

    /// Funciona con drafts de cualquier source convertible (ej. Apple Pay): el efecto es el mismo,
    /// borrar de la bandeja. El source no altera el path (solo se lee para telemetría).
    @Test func convert_applePaySource_deletesDraft() throws {
        let context = try makeTestContext()
        let draft = InboxDraft(amount: 200.0, sourceType: .applePay)
        context.insert(draft)
        try context.save()

        DraftService.shared.handleDraftConvertedToGroupExpense(draft, context: context)

        #expect(try context.fetch(FetchDescriptor<InboxDraft>()).isEmpty)
    }
}
