//
//  ChatMessageCodableTests.swift
//  YalaTests
//
//  Round-trip Codable tests for ChatMessage, ChatSuggestion, QAPair y ChatPersistedSession.
//  Soporta persistencia día-calendario del chat assistant.
//

import Testing
import Foundation
@testable import Yala

struct ChatMessageCodableTests {

    // MARK: - ChatMessage

    @Test func encodeDecode_userMessage_roundTrip() throws {
        let original = ChatMessage(role: .user, text: "¿Cuánto gasté?", timestamp: Date.now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.role == .user)
        #expect(decoded.text == original.text)
    }

    @Test func encodeDecode_assistantMessage_roundTrip() throws {
        let original = ChatMessage(role: .assistant, text: "Gastaste **PEN 120**.", timestamp: Date.now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded.role == .assistant)
        #expect(decoded.text == original.text)
    }

    @Test func encodeDecode_preservesId() throws {
        let id = UUID()
        let original = ChatMessage(id: id, role: .user, text: "test", timestamp: Date.now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(decoded.id == id)
    }

    @Test func encodeDecode_preservesTimestampMillisecond() throws {
        let timestamp = Date(timeIntervalSince1970: 1_745_587_200.123)
        let original = ChatMessage(role: .user, text: "ts", timestamp: timestamp)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        #expect(abs(decoded.timestamp.timeIntervalSince1970 - timestamp.timeIntervalSince1970) < 0.01)
    }

    @Test func decodeArray_decodesAllMessages() throws {
        let array = [
            ChatMessage(role: .user, text: "uno", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "dos", timestamp: Date.now),
            ChatMessage(role: .user, text: "tres", timestamp: Date.now)
        ]
        let data = try JSONEncoder().encode(array)
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].text == "uno")
        #expect(decoded[1].role == .assistant)
        #expect(decoded[2].text == "tres")
    }

    // MARK: - ChatPersistedSession

    @Test func persistedSession_roundTrip_withPreviousQA() throws {
        let messages = [
            ChatMessage(role: .user, text: "¿Mi presupuesto?", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "Llevas 80% del presupuesto.", timestamp: Date.now)
        ]
        let qa = QAPair(
            question: "¿Mi presupuesto?",
            toolName: "budget_status",
            toolResultJSON: "{\"used\": 0.8}",
            response: "Llevas 80% del presupuesto.",
            timestamp: Date.now
        )
        let original = ChatPersistedSession(messages: messages, previousQA: qa)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.messages.count == 2)
        #expect(decoded.messages[0].text == "¿Mi presupuesto?")
        #expect(decoded.previousQA?.toolName == "budget_status")
        #expect(decoded.previousQA?.toolResultJSON == "{\"used\": 0.8}")
    }

    @Test func persistedSession_roundTrip_nilPreviousQA() throws {
        let messages = [ChatMessage(role: .user, text: "hi", timestamp: Date.now)]
        let original = ChatPersistedSession(messages: messages, previousQA: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.messages.count == 1)
        #expect(decoded.previousQA == nil)
    }
}
