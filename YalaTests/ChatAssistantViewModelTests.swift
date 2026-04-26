//
//  ChatAssistantViewModelTests.swift
//  YalaTests
//
//  Tests for ChatAssistantViewModel: state, limits, suggestions, error handling.
//

import Testing
import Foundation
import SwiftData
@testable import Yala

struct ChatAssistantViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_isEmpty() {
        let vm = ChatAssistantViewModel()
        #expect(vm.messages.isEmpty)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
        #expect(vm.inputText.isEmpty)
    }

    // MARK: - Daily Limit

    @MainActor @Test func questionsRemaining_usesServiceLimit() {
        let vm = ChatAssistantViewModel()
        #expect(vm.questionsRemaining <= ChatAssistantService.dailyLimit)
        #expect(vm.questionsRemaining >= 0)
    }

    @MainActor @Test func canAskMore_trueWhenUnderLimit() {
        let vm = ChatAssistantViewModel()
        // Fresh state — counter should be under limit
        #expect(vm.canAskMore)
    }

    @MainActor @Test func showQuestionCounter_falseWhenFresh() {
        let vm = ChatAssistantViewModel()
        // Fresh state — counter should not show (< 25)
        #expect(!vm.showQuestionCounter)
    }

    // MARK: - Input Validation

    @MainActor @Test func sendQuestion_emptyText_doesNotAddMessage() async {
        let vm = ChatAssistantViewModel()
        await vm.sendQuestion("")
        #expect(vm.messages.isEmpty)
    }

    @MainActor @Test func sendQuestion_whitespaceOnly_doesNotAddMessage() async {
        let vm = ChatAssistantViewModel()
        await vm.sendQuestion("   \n  ")
        #expect(vm.messages.isEmpty)
    }

    // MARK: - Reset

    @MainActor @Test func reset_clearsAllState() {
        let vm = ChatAssistantViewModel()
        vm.inputText = "some text"

        vm.reset()

        #expect(vm.messages.isEmpty)
        #expect(vm.inputText.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(!vm.isLoading)
    }

    // MARK: - Persistence (day-calendar UserDefaults)

    /// Helper para limpiar todas las keys `chat_session_*` antes/después de cada test.
    @MainActor private func clearChatSessionKeys() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("chat_session_") {
            defaults.removeObject(forKey: key)
        }
    }

    @MainActor @Test func persistedSession_rehydratesAcrossInstances() throws {
        clearChatSessionKeys()
        defer { clearChatSessionKeys() }

        let context = try makeTestContext()

        // Construir y persistir manualmente un ChatPersistedSession del día actual
        let messages = [
            ChatMessage(role: .user, text: "test pregunta", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "test respuesta", timestamp: Date.now)
        ]
        let blob = ChatPersistedSession(messages: messages, allTurns: [])
        let data = try JSONEncoder().encode(blob)
        let key = "chat_session_" + DayKeyFormatter.string(from: Date.now)
        UserDefaults.standard.set(data, forKey: key)

        // Nueva instancia del VM debe rehidratar la sesión
        let vm = ChatAssistantViewModel()
        vm.setContext(context)

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].text == "test pregunta")
        #expect(vm.messages[1].role == .assistant)
    }

    @MainActor @Test func reconstructTurns_pairsConsecutiveUserAssistant() {
        let messages = [
            ChatMessage(role: .user, text: "P1", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "R1", timestamp: Date.now),
            ChatMessage(role: .user, text: "P2", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "R2", timestamp: Date.now)
        ]
        let turns = ChatAssistantViewModel.reconstructTurns(from: messages)
        #expect(turns.count == 2)
        #expect(turns[0].question == "P1")
        #expect(turns[0].response == "R1")
        #expect(turns[1].question == "P2")
        #expect(turns[1].response == "R2")
    }

    @MainActor @Test func reconstructTurns_dropsOrphanLastUser() {
        // User pregunta y nunca llega respuesta — el último user queda huérfano y se descarta.
        let messages = [
            ChatMessage(role: .user, text: "P1", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "R1", timestamp: Date.now),
            ChatMessage(role: .user, text: "P2_orphan", timestamp: Date.now)
        ]
        let turns = ChatAssistantViewModel.reconstructTurns(from: messages)
        #expect(turns.count == 1)
        #expect(turns[0].question == "P1")
    }

    @MainActor @Test func clearPersistedSession_removesUserDefaultsKey() throws {
        clearChatSessionKeys()
        defer { clearChatSessionKeys() }

        let key = "chat_session_" + DayKeyFormatter.string(from: Date.now)

        // Sembrar data y verificar que existe
        UserDefaults.standard.set(Data([0x01]), forKey: key)
        #expect(UserDefaults.standard.data(forKey: key) != nil)

        let vm = ChatAssistantViewModel()
        vm.clearPersistedSession()

        #expect(UserDefaults.standard.data(forKey: key) == nil)
    }

    // MARK: - Suggestions

    // Deshabilitado en Fase 1: el test crashea con signal trap solo en suite mode (state pollution
    // acumulado de tests previos). Aislado pasa. Fase 2 reescribe `loadSuggestions` a `async` y este
    // test cambia de forma; se reactiva entonces.
    @MainActor @Test(.disabled("Reescritura pendiente para loadSuggestions async en Fase 2 — crash en suite mode"))
    func loadSuggestions_returnsBetween1And10() throws {
        clearChatSessionKeys()
        defer { clearChatSessionKeys() }

        let vm = ChatAssistantViewModel()
        let context = try makeTestContext()

        // Insert some transactions for suggestions
        let cat = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        context.insert(cat)
        let tx = TransactionItem(date: Date.now, amount: -50, currencyCode: "USD", note: "Starbucks", category: cat, amountInPreferredCurrency: -50)
        tx.preferredCurrencyCode = "USD"
        context.insert(tx)
        try context.save()

        vm.setContext(context)
        // Tras Fase 2 el VM puede guardar hasta 10 sugerencias (cap a 3 vive en la View).
        #expect(vm.suggestions.count <= 10)
        #expect(vm.suggestions.count >= 1)
    }

    // MARK: - ChatMessage Model

    @Test func chatMessage_userRole_isCorrect() {
        let msg = ChatMessage(role: .user, text: "Hello", timestamp: Date.now)
        #expect(msg.role == .user)
        #expect(msg.text == "Hello")
    }

    @Test func chatMessage_assistantRole_isCorrect() {
        let msg = ChatMessage(role: .assistant, text: "Response", timestamp: Date.now)
        #expect(msg.role == .assistant)
    }

    // MARK: - QAPair Model

    @Test func qaPair_expiresAfter5Minutes() {
        let old = QAPair(
            question: "test",
            toolName: nil,
            toolResultJSON: nil,
            response: "answer",
            timestamp: Date.now.addingTimeInterval(-301) // 5 min + 1 sec ago
        )
        #expect(old.isExpired)
    }

    @Test func qaPair_notExpiredWithin5Minutes() {
        let recent = QAPair(
            question: "test",
            toolName: nil,
            toolResultJSON: nil,
            response: "answer",
            timestamp: Date.now.addingTimeInterval(-60) // 1 min ago
        )
        #expect(!recent.isExpired)
    }

    // MARK: - ChatDateRange

    @Test func chatDateRange_thisMonth_returnsValidInterval() {
        let interval = ChatDateRange.thisMonth.toDateInterval()
        #expect(interval.start < interval.end)
        #expect(interval.start <= Date.now)
    }

    @Test func chatDateRange_custom_parsesISODates() {
        let interval = ChatDateRange.custom.toDateInterval(dateFrom: "2026-01-01", dateTo: "2026-01-31")
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = .gmt
        #expect(utcCalendar.component(.month, from: interval.start) == 1)
        #expect(utcCalendar.component(.year, from: interval.start) == 2026)
    }

    @Test func chatDateRange_yesterday_isOneDayBefore() {
        let interval = ChatDateRange.yesterday.toDateInterval()
        let duration = interval.duration
        // Yesterday should be approximately 24 hours (86400 seconds)
        #expect(abs(duration - 86400) < 1)
    }
}
