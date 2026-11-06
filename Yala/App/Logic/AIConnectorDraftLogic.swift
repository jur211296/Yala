//
//  AIConnectorDraftLogic.swift
//  Yala
//
//  Tu IA registra en Yala (2.3): de lo que Claude, ChatGPT o Grok apuntó por el conector (`apuntar_movimiento`) a lo que
//  lleva el borrador de la Bandeja. Pura: sin `ModelContext`, para que los tests la recorran entera.
//
//  - El importe llega positivo y el signo lo pone el tipo: gasto negativo, ingreso positivo.
//  - La fecha, como el correo del banco: el día que dijo la IA a mediodía; una fecha de más de un día en el futuro o
//    ilegible cae a la de llegada (`BankEmailDraftLogic.date`).
//  - La cuenta y la subcategoría ya las resolvió el conector contra las de la persona: se buscan por su `shortcutID`
//    (el `sync_id` de la nube). Si no están (borradas, o aún sin bajar), por el nombre que trae, y solo si encaja una.
//    Una cuenta en otra divisa que la del importe no se pone, y una subcategoría del otro lado (ingreso para un gasto)
//    tampoco (`DraftBuilder.matchesNature`): la Bandeja las pide. Sin cuenta nombrada, la única en esa divisa; con una
//    nombrada que ya no está, ninguna.
//

import Foundation

enum AIConnectorDraftLogic {

    struct DraftFields: Equatable {
        let note: String
        let amount: Double
        let isExpense: Bool
        let date: Date
        let currencyCode: String?
        let accountID: UUID?
        let accountName: String?
        let subcategoryID: UUID?
        let subcategoryName: String?
        /// La línea de evidencia del borrador: qué IA lo apuntó («Claude»). `nil` si no se sabe.
        let evidence: String?
    }

    static func fields(from dto: ConnectorDraftDTO, calendar: Calendar = .current) -> DraftFields {
        let magnitude = abs(dto.amount)
        let isExpense = dto.kind != "income"
        let trimmed: (String?) -> String? = { value in
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        return DraftFields(
            note: trimmed(dto.note) ?? "",
            amount: isExpense ? -magnitude : magnitude,
            isExpense: isExpense,
            date: BankEmailDraftLogic.date(from: dto.date, receivedAtMs: dto.receivedAtMs, calendar: calendar),
            currencyCode: dto.currency.map { $0.uppercased() }.flatMap { $0.count == 3 ? $0 : nil },
            accountID: dto.accountID.flatMap(UUID.init(uuidString:)),
            accountName: trimmed(dto.accountName),
            subcategoryID: dto.subcategoryID.flatMap(UUID.init(uuidString:)),
            subcategoryName: trimmed(dto.subcategoryName),
            evidence: trimmed(dto.client)
        )
    }

    /// La cuenta del borrador entre las de la persona, o `nil` (la Bandeja la pide).
    @MainActor
    static func account(for fields: DraftFields, in accounts: [Account]) -> Account? {
        let live = accounts.filter { !$0.isArchived && !$0.isSystemAccount }
        let currencyFits: (Account) -> Bool = { account in
            guard let code = fields.currencyCode else { return true }
            return account.currencyCode.uppercased() == code
        }
        if let id = fields.accountID, let byID = live.first(where: { $0.shortcutID == id }) {
            return currencyFits(byID) ? byID : nil
        }
        // La regla por divisa solo cuando la IA no nombró ninguna cuenta. Si nombró una y ya no está (archivada, borrada),
        // poner otra sería elegir por la persona: la Bandeja la pide.
        guard let name = fields.accountName.map(fold), !name.isEmpty else {
            guard fields.accountID == nil else { return nil }
            return fields.currencyCode.flatMap { DraftBuilder.findAccount(byCurrency: $0, in: live) }
        }
        let byName = live.filter { fold($0.name) == name }
        guard byName.count == 1, let only = byName.first else { return nil }
        return currencyFits(only) ? only : nil
    }

    /// La subcategoría del borrador entre las visibles de la persona, del lado del tipo, o `nil`.
    @MainActor
    static func subcategory(for fields: DraftFields, in subcategories: [Subcategory]) -> Subcategory? {
        let candidates = subcategories.filter { $0.isVisible && DraftBuilder.matchesNature($0, isExpense: fields.isExpense) }
        if let id = fields.subcategoryID, let byID = candidates.first(where: { $0.shortcutID == id }) {
            return byID
        }
        guard let name = fields.subcategoryName.map(fold), !name.isEmpty else { return nil }
        let byName = candidates.filter { fold($0.name) == name }
        return byName.count == 1 ? byName.first : nil
    }

    /// Lo que se mira de un borrador `.aiConnector` que ya está en el almacén.
    struct Existing: Equatable {
        let createdAt: Date
        let amount: Double?
        let note: String

        init(createdAt: Date, amount: Double?, note: String) {
            self.createdAt = createdAt
            self.amount = amount
            self.note = note
        }

        @MainActor
        init(_ draft: InboxDraft) {
            self.init(createdAt: draft.createdAt, amount: draft.amount, note: draft.note)
        }
    }

    /// ¿Este movimiento de la cola ya es un borrador del almacén (lo creó otro aparato y llegó por el sync)? Mismo
    /// instante de llegada (al milisegundo, que es lo que guarda el gateway), mismo importe y misma nota.
    static func alreadyMaterialized(receivedAt: Date, fields: DraftFields, among existing: [Existing]) -> Bool {
        existing.contains { draft in
            abs(draft.createdAt.timeIntervalSince(receivedAt)) < 0.001
                && draft.amount == fields.amount
                && draft.note == fields.note
        }
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
    }
}

/// Los ids de borradores del conector que esta app ya creó, para no duplicar si el `ack` no llegó al gateway. Guarda los
/// últimos 200; uno más viejo ya lo habrá borrado el gateway (30 días) o el `ack` siguiente. Molde de
/// `BankEmailCreatedIDsStore`, con su propia clave: las dos colas son distintas.
enum AIConnectorCreatedIDsStore {
    static let key = "aiConnector.createdDraftIDs"
    static let limit = 200

    static func contains(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(id)
    }

    static func add(_ ids: [String], defaults: UserDefaults = .standard) {
        var current = defaults.stringArray(forKey: key) ?? []
        for id in ids where !current.contains(id) { current.append(id) }
        if current.count > limit { current.removeFirst(current.count - limit) }
        defaults.set(current, forKey: key)
    }
}
