//
//  ChatTransactionDraftTests.swift
//  YalaTests
//
//  Tests para los modelos in-memory del chat Yala IA Registrar:
//  - ChatTransactionDraft (Codable, defaults, status transitions)
//  - ChatAttachment (encode/decode variant)
//  - QuickReply (Codable)
//  - ChatAssistantResponse (intent passthrough)
//  - QAPair / ChatMessage backward-compat (decode JSON sin `attachments`)
//

import Foundation
import Testing

@testable import Yala

struct ChatTransactionDraftTests {

    // MARK: - ChatTransactionDraft round-trip

    @Test func draft_roundTripCodable_preservesFields() throws {
        let draft = ChatTransactionDraft(
            amount: Decimal(50),
            currencyCode: "PEN",
            isExpense: true,
            note: "Mercado",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            needsUserInput: ["account"]
        )

        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(ChatTransactionDraft.self, from: data)

        #expect(decoded.id == draft.id)
        #expect(decoded.amount == draft.amount)
        #expect(decoded.currencyCode == "PEN")
        #expect(decoded.isExpense == true)
        #expect(decoded.note == "Mercado")
        #expect(decoded.date == draft.date)
        #expect(decoded.status == .pending)
        #expect(decoded.needsUserInput == ["account"])
        #expect(decoded.accountID == nil)
        #expect(decoded.subcategoryID == nil)
        #expect(decoded.tagIDs.isEmpty)
        #expect(decoded.savedTransactionID == nil)
    }

    @Test func draft_defaultStatus_isPending() {
        let draft = ChatTransactionDraft(
            amount: Decimal(10),
            currencyCode: "USD",
            isExpense: true,
            note: "x",
            date: Date.now
        )
        #expect(draft.status == .pending)
    }

    @Test func draft_statusTransitions_areMutable() {
        var draft = ChatTransactionDraft(
            amount: Decimal(10),
            currencyCode: "USD",
            isExpense: true,
            note: "x",
            date: Date.now
        )
        #expect(draft.status == .pending)

        draft.status = .saving
        #expect(draft.status == .saving)

        draft.status = .saved
        #expect(draft.status == .saved)
    }

    // MARK: - ChatAttachment variant encode/decode

    @Test func attachment_drafts_roundTrip() throws {
        let draft = ChatTransactionDraft(
            amount: Decimal(20), currencyCode: "PEN", isExpense: true,
            note: "n", date: Date(timeIntervalSince1970: 0)
        )
        let attachment = ChatAttachment.drafts([draft])

        let data = try JSONEncoder().encode(attachment)
        let decoded = try JSONDecoder().decode(ChatAttachment.self, from: data)

        if case .drafts(let decodedDrafts) = decoded {
            #expect(decodedDrafts.count == 1)
            #expect(decodedDrafts[0].amount == Decimal(20))
        } else {
            Issue.record("Expected .drafts variant")
        }
    }

    @Test func attachment_ambiguous_roundTrip() throws {
        let chip1 = QuickReply(label: "Registrar", triggerText: "gasté 50", forceIntent: .register)
        let chip2 = QuickReply(label: "Solo preguntar", triggerText: "gasté 50", forceIntent: .ask)
        let attachment = ChatAttachment.ambiguous(canned: "¿Quieres registrar?", choices: [chip1, chip2])

        let data = try JSONEncoder().encode(attachment)
        let decoded = try JSONDecoder().decode(ChatAttachment.self, from: data)

        if case .ambiguous(let canned, let choices) = decoded {
            #expect(canned == "¿Quieres registrar?")
            #expect(choices.count == 2)
            #expect(choices[0].forceIntent == .register)
            #expect(choices[1].forceIntent == .ask)
        } else {
            Issue.record("Expected .ambiguous variant")
        }
    }

    // MARK: - QAPair backward-compat (decode JSON sin attachments)

    @Test func qaPair_legacyJSON_withoutAttachments_decodesAttachmentsAsNil() throws {
        let legacyJSON = """
        {
            "question": "¿cuánto gasté?",
            "response": "Gastaste 100",
            "timestamp": 0
        }
        """.data(using: .utf8)!

        let pair = try JSONDecoder().decode(QAPair.self, from: legacyJSON)
        #expect(pair.question == "¿cuánto gasté?")
        #expect(pair.response == "Gastaste 100")
        #expect(pair.attachments == nil)
        #expect(pair.toolName == nil)
        #expect(pair.toolResultJSON == nil)
    }

    @Test func qaPair_withAttachments_roundTripPreservesAttachments() throws {
        let draft = ChatTransactionDraft(
            amount: Decimal(15), currencyCode: "EUR", isExpense: false,
            note: "salary", date: Date(timeIntervalSince1970: 1_000_000)
        )
        let pair = QAPair(
            question: "registra 15 ingreso",
            response: "Confirma el registro:",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            attachments: [.drafts([draft])]
        )

        let data = try JSONEncoder().encode(pair)
        let decoded = try JSONDecoder().decode(QAPair.self, from: data)

        #expect(decoded.attachments?.count == 1)
        if case .drafts(let drafts) = decoded.attachments?.first {
            #expect(drafts.count == 1)
            #expect(drafts[0].isExpense == false)
        } else {
            Issue.record("Expected .drafts attachment")
        }
    }

    // MARK: - ChatMessage backward-compat

    @Test func chatMessage_legacyJSON_withoutAttachments_decodes() throws {
        let legacyJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "role": "assistant",
            "text": "Hola",
            "timestamp": 0
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(ChatMessage.self, from: legacyJSON)
        #expect(message.role == .assistant)
        #expect(message.text == "Hola")
        #expect(message.attachments == nil)
    }

    // MARK: - ChatPersistedSession con attachments en allTurns

    @Test func persistedSession_roundTrip_withAttachmentsInTurns() throws {
        let draft = ChatTransactionDraft(
            amount: Decimal(5), currencyCode: "PEN", isExpense: true,
            note: "café", date: Date(timeIntervalSince1970: 0)
        )
        let pair = QAPair(
            question: "café 5",
            response: "Confirma",
            timestamp: Date(timeIntervalSince1970: 1),
            attachments: [.drafts([draft])]
        )
        let message = ChatMessage(
            role: .assistant,
            text: "Confirma",
            timestamp: Date(timeIntervalSince1970: 1),
            attachments: [.drafts([draft])]
        )
        let session = ChatPersistedSession(messages: [message], allTurns: [pair])

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(ChatPersistedSession.self, from: data)

        #expect(decoded.messages.count == 1)
        #expect(decoded.allTurns.count == 1)
        #expect(decoded.messages[0].attachments != nil)
        #expect(decoded.allTurns[0].attachments != nil)
    }

    // MARK: - QuickReply

    @Test func quickReply_roundTrip() throws {
        let chip = QuickReply(label: "Registrar", triggerText: "gasté 50", forceIntent: .register)
        let data = try JSONEncoder().encode(chip)
        let decoded = try JSONDecoder().decode(QuickReply.self, from: data)
        #expect(decoded.label == "Registrar")
        #expect(decoded.triggerText == "gasté 50")
        #expect(decoded.forceIntent == .register)
    }

    // MARK: - ChatAssistantResponse construction

    @Test func chatAssistantResponse_carriesIntent() {
        let r = ChatAssistantResponse(text: "ok", attachments: nil, intent: .ask)
        #expect(r.intent == .ask)
        #expect(r.attachments == nil)

        let r2 = ChatAssistantResponse(text: "?", attachments: nil, intent: .ambiguous)
        #expect(r2.intent == .ambiguous)
    }
}
