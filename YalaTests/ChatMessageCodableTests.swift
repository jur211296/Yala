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

    @Test func persistedSession_roundTrip_withTurns() throws {
        let messages = [
            ChatMessage(role: .user, text: "¿Mi presupuesto?", timestamp: Date.now),
            ChatMessage(role: .assistant, text: "Llevas 80% del presupuesto.", timestamp: Date.now)
        ]
        let turns = [
            QAPair(
                question: "¿Mi presupuesto?",
                toolName: "budget_status",
                toolResultJSON: "{\"used\": 0.8}",
                response: "Llevas 80% del presupuesto.",
                timestamp: Date.now
            ),
            QAPair(
                question: "¿Y restaurantes?",
                toolName: "spending_summary",
                toolResultJSON: "{\"total\": 320}",
                response: "Llevas S/ 320 en restaurantes.",
                timestamp: Date.now
            )
        ]
        let original = ChatPersistedSession(messages: messages, allTurns: turns)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.messages.count == 2)
        #expect(decoded.allTurns.count == 2)
        #expect(decoded.allTurns[0].toolName == "budget_status")
        #expect(decoded.allTurns[1].response == "Llevas S/ 320 en restaurantes.")
    }

    @Test func persistedSession_roundTrip_emptyTurns() throws {
        let messages = [ChatMessage(role: .user, text: "hi", timestamp: Date.now)]
        let original = ChatPersistedSession(messages: messages, allTurns: [])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.messages.count == 1)
        #expect(decoded.allTurns.isEmpty)
    }

    /// Migración: blobs antiguos con `previousQA: QAPair` se hidratan como `allTurns: [previousQA]`.
    @Test func persistedSession_legacyPreviousQA_migratesToAllTurns() throws {
        let legacyJSON = """
        {
          "messages": [
            {"id": "\(UUID().uuidString)", "role": "user", "text": "hola", "timestamp": \(Date.now.timeIntervalSinceReferenceDate)}
          ],
          "previousQA": {
            "question": "¿Cuánto gasté?",
            "toolName": "spending_summary",
            "toolResultJSON": null,
            "response": "Gastaste 100",
            "timestamp": \(Date.now.timeIntervalSinceReferenceDate)
          }
        }
        """

        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.allTurns.count == 1)
        #expect(decoded.allTurns[0].response == "Gastaste 100")
    }
}
