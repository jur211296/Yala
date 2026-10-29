//
//  SpotlightIndexLogic.swift
//  Yala
//
//  Qué entra en el índice de Spotlight y qué hay que cambiar en él (opción C de `docs/siri-ios-27-2026-10.md`, decisión
//  de Jürgen del 2026-10-18). Lógica pura: la usa `SpotlightIndexService`, que es quien lee SwiftData y habla con
//  Core Spotlight.
//
//  Entra lo que la persona ve sin filtros: las tarjetas de cuenta del Panel (las de la foto de Siri, sin saldo) y los
//  movimientos que enseña Registros. Lo que Registros oculta (cuentas excluidas de las estadísticas, gastos de grupo con
//  el ajuste apagado, lo que espera su «Deshacer», los ingresos en «Solo gastos») tampoco se busca desde fuera.
//

import Foundation
import SwiftData

/// Un elemento del índice tal como lo decide la app.
nonisolated struct SpotlightEntry: Equatable, Sendable {
    enum Kind: String, Sendable {
        case account
        case transaction
    }

    let kind: Kind
    /// `account.<shortcutID>` o `transaction.<token del registro>` (`SpotlightRecordLink`): estable entre arranques
    /// mientras el almacén sea el mismo. Al cambiar de almacén (cierre de sesión, «Vaciar datos») el índice se vacía.
    let identifier: String
    let title: String
    let detail: String
    let keywords: [String]
    let date: Date?
    /// El `id` de la cuenta en Siri (`YalaAccountEntity`), solo en las cuentas.
    let accountID: String?
    /// Las divisas de la tarjeta, solo en las cuentas.
    let accountCurrencyCodes: [String]

    /// Cambia cuando cambia algo de lo que se enseña o se busca: decide si hay que volver a indexar.
    var fingerprint: String {
        [title, detail, keywords.joined(separator: "|"), date.map { String($0.timeIntervalSince1970) } ?? ""]
            .joined(separator: "\u{1F}")
    }
}

nonisolated enum SpotlightIndexLogic {

    static let accountPrefix = "account."
    static let transactionPrefix = "transaction."

    /// Un movimiento con lo que hace falta para decidir si entra y cómo se enseña.
    struct TransactionInput: Sendable {
        /// `SpotlightRecordLink.token(for:)` del registro. `syncID` no vale: solo lo tienen las filas del modo nube.
        let recordToken: String?
        let date: Date
        let amount: Double
        let currencyCode: String
        let note: String?
        let categoryName: String?
        let subcategoryName: String?
        let accountName: String?
        let tagNames: [String]
        /// `TransactionClassificationLogic.isIncome`: la categoría manda; sin categoría, el signo.
        let isIncome: Bool
        let isTransfer: Bool
        let isBalanceAdjustment: Bool
        let accountExcludedFromStatistics: Bool
        let isGroupBridged: Bool
        let isPendingDeletion: Bool
    }

    /// Lo que decide la sesión y no el movimiento.
    struct Context: Equatable, Sendable {
        /// La vista de solo grupos (`ShellModeLogic`): ahí no hay datos personales a la vista, y el índice se vacía.
        let isGroupsFocusedShell: Bool
        /// «Solo gastos»: la app oculta ingresos, transferencias y saldos.
        let isExpensesOnlyMode: Bool
        /// «Incluir los gastos de grupo en Registros» (`includeGroupTransactionsInFeed`, por defecto sí).
        let includeGroupTransactions: Bool
    }

    /// Los textos que pone la app, ya resueltos (traducción, moneda y fecha del teléfono).
    struct Presentation {
        let untitledTransaction: String
        let accountKind: String
        let formatAmount: (Double, String) -> String
        let formatDate: (Date) -> String
    }

    // MARK: - Qué entra

    /// Un movimiento entra si Registros lo enseña sin filtros. Transferencias y ajustes de saldo, no: una transferencia
    /// son dos filas iguales y un ajuste no es algo que se busque.
    static func isIndexable(_ tx: TransactionInput, context: Context) -> Bool {
        guard !context.isGroupsFocusedShell else { return false }
        guard tx.recordToken != nil else { return false }
        if tx.isTransfer || tx.isBalanceAdjustment { return false }
        if tx.isPendingDeletion { return false }
        if tx.accountExcludedFromStatistics { return false }
        if !context.includeGroupTransactions && tx.isGroupBridged { return false }
        if context.isExpensesOnlyMode && tx.isIncome { return false }
        return true
    }

    /// Lo que tiene que haber en el índice ahora mismo.
    static func entries(
        accounts: [SiriFinanceSnapshot.Account],
        transactions: [TransactionInput],
        context: Context,
        presentation: Presentation
    ) -> [SpotlightEntry] {
        guard !context.isGroupsFocusedShell else { return [] }
        var result: [SpotlightEntry] = []
        var seen = Set<String>()
        for account in accounts {
            let entry = accountEntry(account, presentation: presentation)
            if seen.insert(entry.identifier).inserted { result.append(entry) }
        }
        for tx in transactions where isIndexable(tx, context: context) {
            guard let entry = transactionEntry(tx, presentation: presentation) else { continue }
            if seen.insert(entry.identifier).inserted { result.append(entry) }
        }
        return result
    }

    /// «BCP» · «Cuenta · PEN · USD». Sin saldo: cambia a diario y en el índice se quedaría viejo.
    static func accountEntry(_ account: SiriFinanceSnapshot.Account, presentation: Presentation) -> SpotlightEntry {
        let currencies = account.lines.map(\.currencyCode)
        return SpotlightEntry(
            kind: .account,
            identifier: accountPrefix + account.id,
            title: account.name,
            detail: ([presentation.accountKind] + currencies).joined(separator: " · "),
            keywords: [presentation.accountKind] + currencies,
            date: nil,
            accountID: account.id,
            accountCurrencyCodes: currencies
        )
    }

    /// «Cine» · «S/ 25,00 · Ocio · BCP · 12 oct 2026». El título es la nota; sin nota, la subcategoría o la categoría.
    static func transactionEntry(_ tx: TransactionInput, presentation: Presentation) -> SpotlightEntry? {
        guard let token = tx.recordToken else { return nil }
        let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let classification = nonEmpty(tx.subcategoryName) ?? nonEmpty(tx.categoryName)
        let title = nonEmpty(note) ?? classification ?? presentation.untitledTransaction
        var parts = [presentation.formatAmount(abs(tx.amount), tx.currencyCode)]
        if let classification, classification != title { parts.append(classification) }
        if let account = nonEmpty(tx.accountName) { parts.append(account) }
        parts.append(presentation.formatDate(tx.date))
        let keywords = [tx.categoryName, tx.subcategoryName, tx.accountName].compactMap { nonEmpty($0) }
            + tx.tagNames.compactMap { nonEmpty($0) }
        return SpotlightEntry(
            kind: .transaction,
            identifier: transactionPrefix + token,
            title: title,
            detail: parts.joined(separator: " · "),
            keywords: keywords,
            date: tx.date,
            accountID: nil,
            accountCurrencyCodes: []
        )
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    // MARK: - Qué cambiar

    struct Plan: Equatable {
        /// Sin estado guardado no se sabe qué hay en el índice: se vacía antes de indexar.
        let deletesEverythingFirst: Bool
        let toIndex: [SpotlightEntry]
        let toDelete: [String]
        /// Lo que queda en el índice cuando el plan termina: identificador → huella.
        let resulting: [String: String]

        var isEmpty: Bool { !deletesEverythingFirst && toIndex.isEmpty && toDelete.isEmpty }
    }

    /// `indexed` es lo que la app dejó en el índice la última vez (identificador → huella), o `nil` si no lo sabe.
    static func plan(desired: [SpotlightEntry], indexed: [String: String]?) -> Plan {
        var resulting: [String: String] = [:]
        for entry in desired { resulting[entry.identifier] = entry.fingerprint }
        guard let indexed else {
            return Plan(deletesEverythingFirst: true, toIndex: desired, toDelete: [], resulting: resulting)
        }
        let toIndex = desired.filter { indexed[$0.identifier] != $0.fingerprint }
        let toDelete = indexed.keys.filter { resulting[$0] == nil }.sorted()
        return Plan(deletesEverythingFirst: false, toIndex: toIndex, toDelete: toDelete, resulting: resulting)
    }

    // MARK: - Tocar un resultado

    /// El enlace de la app que abre un resultado: la ficha de la cuenta o el registro.
    static func deepLink(forIdentifier identifier: String) -> String? {
        if identifier.hasPrefix(accountPrefix) {
            guard let id = UUID(uuidString: String(identifier.dropFirst(accountPrefix.count))) else { return nil }
            return AlertDeepLink.account.deepLink(for: id)
        }
        if identifier.hasPrefix(transactionPrefix) {
            let token = String(identifier.dropFirst(transactionPrefix.count))
            guard SpotlightRecordLink.isToken(token) else { return nil }
            return SpotlightRecordLink.prefix + token
        }
        return nil
    }
}

/// `records/<token>`: el enlace de un registro desde Spotlight. El token es el `PersistentIdentifier` del registro en
/// JSON y base64url (sin `+`, `/` ni `=`, para que viaje en la ruta de una URL).
nonisolated enum SpotlightRecordLink {
    static let prefix = "records/"

    /// Con las claves ordenadas: sin `.sortedKeys` el orden cambiaba de un proceso a otro (medido el 2026-10-28), el
    /// token de cada registro también, y cada arranque borraba y volvía a indexar todos los movimientos.
    static func token(for id: PersistentIdentifier) -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(id)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        } catch {
            #if DEBUG
            print("SpotlightRecordLink: Error: \(error)")
            #endif
            return nil
        }
    }

    static func identifier(fromToken token: String) -> PersistentIdentifier? {
        guard isToken(token) else { return nil }
        var base64 = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        do {
            return try JSONDecoder().decode(PersistentIdentifier.self, from: data)
        } catch {
            #if DEBUG
            print("SpotlightRecordLink: Error: \(error)")
            #endif
            return nil
        }
    }

    /// El token de `records/<token>`, o `nil` si el enlace no trae uno.
    static func token(fromDeepLink link: String) -> String? {
        guard link.hasPrefix(prefix) else { return nil }
        let token = String(link.dropFirst(prefix.count))
        return isToken(token) ? token : nil
    }

    static func isToken(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_"
        }
    }
}

/// El registro que un resultado de Spotlight pidió abrir, esperando a la ventana que drene Registros. Molde de
/// `AlertDeepLinkTarget`: el destino del router es el de siempre y el id espera aquí.
@MainActor
final class SpotlightRecordTarget {
    static let shared = SpotlightRecordTarget()

    private var pendingID: PersistentIdentifier?
    private var requestedAt: Date?

    func request(_ id: PersistentIdentifier, now: Date = .now) {
        pendingID = id
        requestedAt = now
    }

    /// Lo devuelve una sola vez, y nada si lleva más de `AlertDeepLinkTarget.maxAge` esperando.
    func consume(now: Date = .now) -> PersistentIdentifier? {
        defer {
            pendingID = nil
            requestedAt = nil
        }
        guard let id = pendingID, let requestedAt,
              now.timeIntervalSince(requestedAt) <= AlertDeepLinkTarget.maxAge else { return nil }
        return id
    }
}
