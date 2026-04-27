//
//  ChatTransactionDraft.swift
//  Yala
//
//  In-memory draft proposed by Yala IA chat for user confirmation.
//  Not persisted in SwiftData — vive dentro de un QAPair/ChatMessage del chat
//  (sesión del día) hasta que el user pulsa Save y se crea el TransactionItem real.
//

import Foundation
import SwiftData

struct ChatTransactionDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal?
    var currencyCode: String
    var isExpense: Bool
    var note: String
    var date: Date
    var accountID: PersistentIdentifier?
    var subcategoryID: PersistentIdentifier?
    var tagIDs: [PersistentIdentifier]
    var status: Status
    var savedTransactionID: PersistentIdentifier?
    /// Campos críticos sin valor inferido: `["account", "subcategory", "amount"]`.
    var needsUserInput: [String]

    enum Status: String, Codable {
        case pending
        case saving
        case saved
        case failed
        case discarded
    }

    init(
        id: UUID = UUID(),
        amount: Decimal?,
        currencyCode: String,
        isExpense: Bool,
        note: String,
        date: Date,
        accountID: PersistentIdentifier? = nil,
        subcategoryID: PersistentIdentifier? = nil,
        tagIDs: [PersistentIdentifier] = [],
        status: Status = .pending,
        savedTransactionID: PersistentIdentifier? = nil,
        needsUserInput: [String] = []
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.isExpense = isExpense
        self.note = note
        self.date = date
        self.accountID = accountID
        self.subcategoryID = subcategoryID
        self.tagIDs = tagIDs
        self.status = status
        self.savedTransactionID = savedTransactionID
        self.needsUserInput = needsUserInput
    }

    // Custom Codable con `decodeIfPresent` para tagIDs y savedTransactionID — blobs
    // persistidos antes de que esos campos existieran decodan a default vacío en vez
    // de fallar y romper la sesión del día.
    enum CodingKeys: String, CodingKey {
        case id, amount, currencyCode, isExpense, note, date
        case accountID, subcategoryID, tagIDs, status, savedTransactionID, needsUserInput
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.amount = try c.decodeIfPresent(Decimal.self, forKey: .amount)
        self.currencyCode = try c.decode(String.self, forKey: .currencyCode)
        self.isExpense = try c.decode(Bool.self, forKey: .isExpense)
        self.note = try c.decode(String.self, forKey: .note)
        self.date = try c.decode(Date.self, forKey: .date)
        self.accountID = try c.decodeIfPresent(PersistentIdentifier.self, forKey: .accountID)
        self.subcategoryID = try c.decodeIfPresent(PersistentIdentifier.self, forKey: .subcategoryID)
        self.tagIDs = try c.decodeIfPresent([PersistentIdentifier].self, forKey: .tagIDs) ?? []
        self.status = try c.decode(Status.self, forKey: .status)
        self.savedTransactionID = try c.decodeIfPresent(PersistentIdentifier.self, forKey: .savedTransactionID)
        self.needsUserInput = try c.decodeIfPresent([String].self, forKey: .needsUserInput) ?? []
    }
}
