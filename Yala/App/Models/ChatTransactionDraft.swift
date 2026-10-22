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

    // MARK: - Divisa efectiva

    /// La divisa con la que el borrador se va a GUARDAR: la de la cuenta elegida, y solo mientras no
    /// hay cuenta, la que dictó el usuario.
    ///
    /// **`currencyCode` ya es este valor en un borrador vivo**, porque el ViewModel lo sincroniza al
    /// elegir cuenta (`updateDraft`) y lo congela al guardar (`saveDraft`). Este método es la
    /// autoridad de esa sincronización, no un segundo camino: quien tenga delante una `Account`
    /// resuelta debe llamarlo; quien solo tenga el borrador puede leer `currencyCode` directamente.
    /// Lo que NO debe hacer nadie es resolver la cuenta por su cuenta para deducir la divisa — se
    /// intentó en la tarjeta y volvió el bug, porque su `@Query` filtra `!isArchived` y `saveDraft`
    /// resuelve con `context.model(for:)`, que no filtra.
    ///
    /// De dónde viene el valor dictado: `parsed.currencyHint`, que el prompt del LLM pide
    /// explícitamente como `"USD" | "EUR" | "PEN" | null`. Sirve para ELEGIR cuenta —`DraftBuilder`
    /// llama a `findAccount(byCurrency:)`— pero no para estampar la transacción, porque ese match
    /// devuelve cuenta solo si hay **exactamente una** viva en esa divisa (`0 ó 2+ → nil`). Cuando
    /// devuelve `nil` el borrador nace sin cuenta, la tarjeta se la pide al usuario y el menú le
    /// ofrece todas las cuentas **sin filtrar por divisa** (filtra archivadas, no divisas). O sea que
    /// el desemparejamiento no era un caso de laboratorio: era la salida natural de que ese match
    /// fallara — por divisa sin cuenta, y también por tener DOS cuentas en la divisa dictada, donde
    /// las divisas ni siquiera difieren.
    ///
    /// Manda la cuenta, y no es una regla nueva: es la que **ya aplica el formulario a este mismo
    /// borrador** (`NewTransactionViewModel.prefill(fromChatDraft:)` hace
    /// `currencyCode = account.currencyCode` cuando el ID resuelve). La incoherencia estaba dentro de
    /// la propia tarjeta: pulsar «Editar» aplicaba esta regla y pulsar «Guardar» la contraria. Aguas
    /// abajo el resto del sistema ya la asumía — las otras rutas de creación estampan
    /// `account.currencyCode`, e `InboxDraft` (el borrador de Voz/Siri/Vision) ni siquiera tiene
    /// campo de divisa: usa el hint para elegir cuenta y lo descarta.
    ///
    /// Ojo al usarlo: el valor viaja a las CUATRO columnas del grupo de coherencia `money`. Quien
    /// estampe `currencyCode` con esto tiene que convertir desde esto mismo (`convertChecked(from:)`)
    /// o la fila queda diciendo una divisa y convertida desde otra. Y eso no lo cazan las columnas
    /// entre sí —quedan aritméticamente coherentes—, sino el reparador: `recalculatePreferredCurrency`
    /// reconvierte desde `currencyCode` en `date`, así que reescribiría otro número al pasar por ella.
    func effectiveCurrencyCode(account: Account?) -> String {
        account?.currencyCode ?? currencyCode
    }
}
