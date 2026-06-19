//
//  ChatAssistantModels.swift
//  Yala
//
//  DTOs, enums and param structs for the Ask Yala chat assistant.
//

import Foundation
import SwiftData

// MARK: - Chat Error

enum ChatAssistantError: Error, LocalizedError {
    case noAPIKey
    case notProUser
    case noAIConsent
    case offline
    case rateLimited
    case dailyLimitReached
    case questionTooLong
    case emptyQuestion
    case toolExecutionFailed(String)
    case parseFailed
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .notProUser: return "Pro subscription required"
        case .noAIConsent: return "AI consent not accepted"
        case .offline: return "No internet connection"
        case .rateLimited: return "Please wait a few seconds"
        case .dailyLimitReached: return "Daily question limit reached"
        case .questionTooLong: return "Question too long"
        case .emptyQuestion: return "Question is empty"
        case .toolExecutionFailed(let reason): return "Tool execution failed: \(reason)"
        case .parseFailed: return "Failed to parse response"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .timeout: return "Request timed out"
        }
    }
}

// MARK: - QA Pair (1-turn memory)

nonisolated struct QAPair: Codable {
    let question: String
    let toolName: String?
    let toolResultJSON: String?
    let response: String
    let timestamp: Date
    /// ID del `ChatMessage` (assistant) que materializa esta respuesta. Usado por
    /// el VM para localizar el QAPair correcto cuando se mutan attachments (multi-tx
    /// con cards stacked → matching por texto puede colisionar). Opcional para
    /// backward-compat con blobs persistidos pre-feature.
    let messageID: UUID?
    /// Drafts/quick-replies adjuntos a la respuesta del assistant. `nil` para turnos sin attachments
    /// (el flow `ask` no genera ninguno). Var para que el VM mute el estado de los drafts
    /// (`pending → saving → saved`) sin reconstruir el QAPair entero.
    var attachments: [ChatAttachment]?

    var isExpired: Bool {
        Date.now.timeIntervalSince(timestamp) > 300
    }

    enum CodingKeys: String, CodingKey {
        case question, toolName, toolResultJSON, response, timestamp, attachments, messageID
    }

    init(
        question: String,
        toolName: String? = nil,
        toolResultJSON: String? = nil,
        response: String,
        timestamp: Date,
        messageID: UUID? = nil,
        attachments: [ChatAttachment]? = nil
    ) {
        self.question = question
        self.toolName = toolName
        self.toolResultJSON = toolResultJSON
        self.response = response
        self.timestamp = timestamp
        self.messageID = messageID
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.question = try c.decode(String.self, forKey: .question)
        self.toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
        self.toolResultJSON = try c.decodeIfPresent(String.self, forKey: .toolResultJSON)
        self.response = try c.decode(String.self, forKey: .response)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.messageID = try c.decodeIfPresent(UUID.self, forKey: .messageID)
        self.attachments = try c.decodeIfPresent([ChatAttachment].self, forKey: .attachments)
    }
}

// MARK: - Chat Date Range

enum ChatDateRange: String, Codable {
    case today
    case yesterday
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case thisYear = "this_year"
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case custom

    func toDateInterval(dateFrom: String? = nil, dateTo: String? = nil) -> DateInterval {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)

        switch self {
        case .today:
            return DateInterval(start: startOfToday, end: now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return DateInterval(start: yesterday, end: startOfToday)
        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return DateInterval(start: weekStart, end: now)
        case .lastWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? startOfToday
            return DateInterval(start: prevWeekStart, end: weekStart)
        case .thisMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return DateInterval(start: monthStart, end: now)
        case .lastMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? startOfToday
            return DateInterval(start: prevMonthStart, end: monthStart)
        case .thisYear:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
            return DateInterval(start: yearStart, end: now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: now)
        case .custom:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let start = dateFrom.flatMap { formatter.date(from: $0) } ?? startOfToday
            let end = dateTo.flatMap { formatter.date(from: $0) } ?? now
            return DateInterval(start: start, end: end)
        }
    }
}

// MARK: - Chat Message

nonisolated struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date
    /// Drafts/quick-replies adjuntos al mensaje del assistant. `nil` para mensajes del user
    /// y para respuestas plain del flow `ask`. Var: el VM muta el status de los drafts in-place.
    var attachments: [ChatAttachment]?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        timestamp: Date,
        attachments: [ChatAttachment]? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.attachments = attachments
    }

    enum MessageRole: String, Codable {
        case user
        case assistant
    }

    enum CodingKeys: String, CodingKey {
        case id, role, text, timestamp, attachments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.role = try c.decode(MessageRole.self, forKey: .role)
        self.text = try c.decode(String.self, forKey: .text)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.attachments = try c.decodeIfPresent([ChatAttachment].self, forKey: .attachments)
    }
}

// MARK: - Chat Suggestion

nonisolated struct ChatSuggestion: Identifiable, Codable {
    let id: UUID
    let text: String
    let icon: String
    let type: SuggestionType

    init(id: UUID = UUID(), text: String, icon: String, type: SuggestionType) {
        self.id = id
        self.text = text
        self.icon = icon
        self.type = type
    }

    enum SuggestionType: String, Codable {
        case topMerchant
        case biggestCategory
        case activeBudget
        case comparison
        case general
    }
}

// MARK: - Persisted Session (day-calendar storage blob)

/// Blob JSON guardado en `UserDefaults` con clave `chat_session_<YYYY-MM-DD>`.
/// Persiste mensajes + todos los turnos del día (allTurns) para que el LLM reciba
/// contexto multi-turno completo en cada nueva pregunta.
nonisolated struct ChatPersistedSession: Codable {
    let messages: [ChatMessage]
    let allTurns: [QAPair]

    init(messages: [ChatMessage], allTurns: [QAPair]) {
        self.messages = messages
        self.allTurns = allTurns
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case allTurns
        case previousQA
    }

    /// Decoder con migración: blobs antiguos guardaban `previousQA: QAPair?` (1-turn).
    /// Se hidratan como `allTurns: [previousQA]` para no perder contexto.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.messages = try c.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []

        if let turns = try c.decodeIfPresent([QAPair].self, forKey: .allTurns) {
            self.allTurns = turns
        } else if let legacy = try c.decodeIfPresent(QAPair.self, forKey: .previousQA) {
            self.allTurns = [legacy]
        } else {
            self.allTurns = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(messages, forKey: .messages)
        try c.encode(allTurns, forKey: .allTurns)
    }
}

// MARK: - Chat Intent (classifier output)

enum ChatIntent: String, Codable {
    case ask
    case register
    case ambiguous
}

// MARK: - Quick Reply (ambiguous chips)

nonisolated struct QuickReply: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String
    /// Texto reenviado como nuevo `sendQuestion(...)` cuando el user pulsa el chip.
    let triggerText: String
    /// Intent forzado al reenviar — bypassa el classifier para evitar reclasificar
    /// el mismo texto retórico como ambiguous otra vez.
    let forceIntent: ChatIntent

    init(id: UUID = UUID(), label: String, triggerText: String, forceIntent: ChatIntent) {
        self.id = id
        self.label = label
        self.triggerText = triggerText
        self.forceIntent = forceIntent
    }
}

// MARK: - Chat Attachment

/// Variant adjunto a un `ChatMessage` o `QAPair` cuando la respuesta del assistant
/// requiere UI interactiva (cards de drafts, chips de aclaración).
enum ChatAttachment: Codable, Equatable {
    case drafts([ChatTransactionDraft])
    case ambiguous(canned: String, choices: [QuickReply])

    enum CodingKeys: String, CodingKey {
        case kind, drafts, canned, choices
    }

    enum Kind: String, Codable {
        case drafts
        case ambiguous
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .drafts(let drafts):
            try c.encode(Kind.drafts, forKey: .kind)
            try c.encode(drafts, forKey: .drafts)
        case .ambiguous(let canned, let choices):
            try c.encode(Kind.ambiguous, forKey: .kind)
            try c.encode(canned, forKey: .canned)
            try c.encode(choices, forKey: .choices)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .drafts:
            let drafts = try c.decode([ChatTransactionDraft].self, forKey: .drafts)
            self = .drafts(drafts)
        case .ambiguous:
            let canned = try c.decode(String.self, forKey: .canned)
            let choices = try c.decode([QuickReply].self, forKey: .choices)
            self = .ambiguous(canned: canned, choices: choices)
        }
    }
}

// MARK: - Chat Assistant Response

/// Output del pipeline `ChatAssistantService.processQuestion`. Reemplaza la tupla
/// `(text, toolName)` previa al pivot Yala IA → context-rich + draft cards.
struct ChatAssistantResponse {
    let text: String
    let attachments: [ChatAttachment]?
    /// Intent que terminó usándose (puede provenir del classifier o de `forceIntent`).
    /// Usado por el VM para telemetría y por flujos que necesiten saber qué path corrió.
    let intent: ChatIntent

    init(text: String, attachments: [ChatAttachment]? = nil, intent: ChatIntent) {
        self.text = text
        self.attachments = attachments
        self.intent = intent
    }
}

// MARK: - Chat Draft Prefill

/// Payload del `RouterIntent.presentNewTransactionFromChatDraft` — abre `NewTransactionView`
/// pre-llenado con los datos del draft del chat. Si NTV persiste la transacción,
/// usa `originMessageID + originDraftID` para marcar el card del chat como `.saved`.
/// Si el user CANCELA NTV, el card queda `.pending` (no se notifica).
struct ChatDraftPrefill: Equatable {
    /// Tracking del card de origen para callback post-save desde NTV.
    let originMessageID: UUID
    let originDraftID: UUID

    let accountID: PersistentIdentifier?
    let subcategoryID: PersistentIdentifier?
    let amount: Decimal?
    let currencyCode: String
    let note: String
    let date: Date
    let isExpense: Bool
    let tagIDs: [PersistentIdentifier]
}
