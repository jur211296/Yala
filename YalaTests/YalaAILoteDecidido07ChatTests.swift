//
//  YalaAILoteDecidido07ChatTests.swift
//  YalaTests
//
//  UX 2.2 · lote decidido 07 (Yala IA), lo del chat que necesita store:
//  - L14-7: «Nueva conversación» borra y «Deshacer» la devuelve, salvo que ya se haya empezado otra.
//  - L14-9: «Guardar los N» guarda los completos y solo esos, una vez, y la tarjeta enseña el importe con signo.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. Como `ChatDraftSignedAmountTests`, el
//  borrador entra por el blob de sesión del día, que es por donde lo lee la app al reabrir el chat; y `setContext`
//  toca `SessionState.shared`, así que la suite va `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Yala IA · nueva conversación y guardar los N", .serialized)
struct YalaAILoteDecidido07ChatTests {

    private struct Scenario {
        let vm: ChatAssistantViewModel
        let messageID: UUID
        let completeIDs: [UUID]
        let incompleteID: UUID
    }

    /// Un mensaje de Yala IA con dos registros completos y uno sin subcategoría, en la divisa preferida.
    private func makeScenario(context: ModelContext) throws -> Scenario {
        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Transporte", isIncome: false)
        let subcategory = makeTestSubcategory(context: context, name: "Taxi", category: category)
        try context.save()

        func draft(_ amount: Decimal, note: String, complete: Bool) -> ChatTransactionDraft {
            ChatTransactionDraft(
                amount: amount, currencyCode: preferred, isExpense: true, note: note, date: .now,
                accountID: account.persistentModelID,
                subcategoryID: complete ? subcategory.persistentModelID : nil
            )
        }
        let taxi = draft(45, note: "Taxi", complete: true)
        let bus = draft(3, note: "Bus", complete: true)
        let super_ = draft(120, note: "Súper", complete: false)
        let question = ChatMessage(role: .user, text: "Gasté 45 en taxi, 3 en bus y 120 en el súper", timestamp: .now)
        let message = ChatMessage(
            role: .assistant, text: "Confirma los registros:", timestamp: .now,
            attachments: [.drafts([taxi, bus, super_])]
        )
        let defaults = makeIsolatedDefaults()
        let blob = ChatPersistedSession(messages: [question, message], allTurns: [])
        defaults.set(try JSONEncoder().encode(blob), forKey: "chat_session_" + DayKeyFormatter.string(from: .now))

        let vm = ChatAssistantViewModel(defaults: defaults)
        vm.setContext(context, autoLoadSuggestions: false)
        return Scenario(vm: vm, messageID: message.id, completeIDs: [taxi.id, bus.id], incompleteID: super_.id)
    }

    private func drafts(_ vm: ChatAssistantViewModel, _ messageID: UUID) -> [ChatTransactionDraft] {
        let message = vm.messages.first { $0.id == messageID }
        return (message?.attachments ?? []).flatMap { attachment -> [ChatTransactionDraft] in
            if case .drafts(let drafts) = attachment { return drafts }
            return []
        }
    }

    // MARK: - L14-7

    @Test("Nueva conversación borra el hilo y Deshacer lo devuelve entero")
    func newConversation_thenUndo_restoresTheThread() throws {
        let context = try makeTestContext()
        let scenario = try makeScenario(context: context)
        let before = scenario.vm.messages.map(\.id)
        #expect(before.count == 2)

        let snapshot = try #require(scenario.vm.resetConversationContext())
        #expect(scenario.vm.messages.isEmpty)
        #expect(scenario.vm.turnCount == 0)

        #expect(scenario.vm.restoreConversation(snapshot))
        #expect(scenario.vm.messages.map(\.id) == before)
    }

    /// Deshacer solo actúa con el hilo vacío: un segundo toque, con la conversación ya devuelta, no la duplica.
    @Test("Deshacer dos veces no duplica la conversación")
    func undo_twice_doesNotDuplicate() throws {
        let context = try makeTestContext()
        let scenario = try makeScenario(context: context)
        let snapshot = try #require(scenario.vm.resetConversationContext())
        #expect(scenario.vm.restoreConversation(snapshot))
        // El hilo ya no está vacío: un segundo deshacer no puede añadir nada.
        #expect(!scenario.vm.restoreConversation(snapshot))
        #expect(scenario.vm.messages.count == 2)
    }

    @Test("Con el chat vacío no hay nada que deshacer")
    func newConversation_onAnEmptyChat_returnsNoSnapshot() throws {
        let context = try makeTestContext()
        let vm = ChatAssistantViewModel(defaults: makeIsolatedDefaults())
        vm.setContext(context, autoLoadSuggestions: false)
        #expect(vm.resetConversationContext() == nil)
    }

    // MARK: - L14-9

    @Test("Guardar los N cuenta solo los completos")
    func readyToSave_countsOnlyTheCompleteOnes() throws {
        let context = try makeTestContext()
        let scenario = try makeScenario(context: context)
        #expect(scenario.vm.draftsReadyToSave(messageID: scenario.messageID).map(\.id) == scenario.completeIDs)
    }

    @Test("Guardar los N guarda los completos, una vez, y deja el incompleto pendiente")
    func saveAll_savesEachCompleteDraftOnce() async throws {
        let context = try makeTestContext()
        let scenario = try makeScenario(context: context)

        await scenario.vm.saveAllReadyDrafts(messageID: scenario.messageID)
        // Un segundo toque no duplica: ya no queda ninguno listo.
        await scenario.vm.saveAllReadyDrafts(messageID: scenario.messageID)

        let saved = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(saved.count == 2, "errorMessage: \(scenario.vm.errorMessage ?? "ninguno")")
        #expect(Set(saved.map(\.amount)) == [-45, -3])

        let byID = Dictionary(uniqueKeysWithValues: drafts(scenario.vm, scenario.messageID).map { ($0.id, $0.status) })
        #expect(scenario.completeIDs.allSatisfy { byID[$0] == .saved })
        #expect(byID[scenario.incompleteID] == .pending)
        #expect(scenario.vm.draftsReadyToSave(messageID: scenario.messageID).isEmpty)
    }

    @Test("La tarjeta pide importe, cuenta y subcategoría, y el gasto lleva signo")
    func draft_readiness_andSignedAmount() throws {
        let context = try makeTestContext()
        let scenario = try makeScenario(context: context)
        let all = drafts(scenario.vm, scenario.messageID)
        let complete = try #require(all.first { $0.id == scenario.completeIDs[0] })
        let incomplete = try #require(all.first { $0.id == scenario.incompleteID })
        #expect(complete.isReadyToSave)
        #expect(!incomplete.isReadyToSave)

        var noAmount = complete
        noAmount.amount = nil
        #expect(!noAmount.isReadyToSave)
        #expect(noAmount.signedAmount == nil)
        var noAccount = complete
        noAccount.accountID = nil
        #expect(!noAccount.isReadyToSave)

        #expect(complete.signedAmount == -45)
        var income = complete
        income.isExpense = false
        #expect(income.signedAmount == 45)
    }
}
