//
//  ImportAccountResolver.swift
//  Yala
//
//  A qué cuenta va cada fila de un archivo con columna `account` (H7 de la auditoría del import 2.2, card 34qe).
//
//  Hasta el 2026-10-29 todo iba a una cuenta, o a una por moneda: las 7 cuentas del archivo de Jürgen entraban fundidas
//  en 3, con los saldos de cada una mal. Ahora cada fila va a la cuenta que nombra, y la que no existe se propone crear.
//
//  Sin `@Model`: se construye con los valores de las cuentas y decide; quien importa crea las cuentas nuevas.
//

import Foundation

/// Lo que el resolvedor necesita de una cuenta.
struct ImportAccountCandidate: Equatable {
    let id: UUID
    let name: String
    let currencyCode: String
    let isArchived: Bool
    let isSystem: Bool
    let parentID: UUID?
}

struct ImportAccountResolver {

    /// A dónde va la fila.
    enum Outcome: Equatable {
        case existing(UUID)
        /// Una cuenta que no existe y se crea; `key` la identifica entre filas.
        case new(key: String)
    }

    /// Por qué la fila no tiene cuenta.
    enum Failure: Error, Equatable {
        /// La columna existe y la celda está vacía.
        case empty
        /// La cuenta está archivada o es la de Grupos: no se importa a ella.
        case unavailable(name: String)
        /// Dos cuentas activas con ese nombre y esa moneda.
        case ambiguous(name: String)
        /// Hay una cuenta con ese nombre, pero en otra moneda y sin línea de la moneda de la fila.
        case currencyMismatch(name: String, accountCurrency: String)
    }

    /// Una cuenta que el import va a crear: el nombre como lo escribió su primera fila y la moneda de esa fila.
    struct NewAccount: Equatable {
        let key: String
        let name: String
        let currencyCode: String
    }

    private let importable: [ImportAccountCandidate]
    private let unavailableKeys: Set<String>
    /// Los miembros de la tarjeta de cada cuenta que es parte de una (la principal y sus líneas).
    private let cardMembers: [UUID: [UUID]]
    private let byID: [UUID: ImportAccountCandidate]

    /// Las cuentas nuevas, en el orden en que aparecen en el archivo.
    private(set) var newAccounts: [NewAccount] = []

    /// - Parameter accounts: TODAS las cuentas del usuario, archivadas y de sistema incluidas: hacen falta para no
    ///   crear una cuenta con el nombre de una archivada y para leer las tarjetas.
    init(accounts: [ImportAccountCandidate]) {
        var byID: [UUID: ImportAccountCandidate] = [:]
        for account in accounts where byID[account.id] == nil { byID[account.id] = account }
        self.byID = byID
        importable = accounts.filter { !$0.isArchived && !$0.isSystem }
        unavailableKeys = Set(accounts.filter { $0.isArchived || $0.isSystem }.map { Self.key($0.name) })

        let roles = AccountLineLogic.resolve(accounts.map {
            AccountLineNode(id: $0.id, parentID: $0.parentID, currencyCode: $0.currencyCode,
                            isArchived: $0.isArchived, isSystem: $0.isSystem)
        })
        var members: [UUID: [UUID]] = [:]
        for (id, role) in roles {
            if case .principal(let lineIDs) = role {
                let card = [id] + lineIDs
                for member in card { members[member] = card }
            }
        }
        cardMembers = members
    }

    /// La clave de un nombre: sin mayúsculas ni tildes y con los espacios de dentro reducidos a uno («Crédito BCP» y
    /// «credito  bcp» son la misma cuenta).
    static func key(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Resuelve una fila. Una cuenta nueva queda apuntada la primera vez que aparece, con la moneda de esa fila.
    mutating func resolve(name rawName: String?, currency: String) -> Result<Outcome, Failure> {
        let name = (rawName ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return .failure(.empty) }
        let key = Self.key(name)
        let currency = normalizeCurrencyCode(currency)

        let candidates = importable.filter { Self.key($0.name) == key }
        if !candidates.isEmpty {
            let sameCurrency = candidates.filter { normalizeCurrencyCode($0.currencyCode) == currency }
            if sameCurrency.count == 1, let only = sameCurrency.first { return .success(.existing(only.id)) }
            if sameCurrency.count > 1 {
                let exact = sameCurrency.filter { $0.name == name }
                if exact.count == 1, let only = exact.first { return .success(.existing(only.id)) }
                return .failure(.ambiguous(name: name))
            }
            // En otra moneda: si es parte de una tarjeta con líneas, la línea de la moneda de la fila.
            let viaCard = Set(candidates.flatMap { cardMembers[$0.id] ?? [] }).compactMap { byID[$0] }
                .filter { !$0.isArchived && !$0.isSystem && normalizeCurrencyCode($0.currencyCode) == currency }
            if viaCard.count == 1, let line = viaCard.first { return .success(.existing(line.id)) }
            if viaCard.count > 1 { return .failure(.ambiguous(name: name)) }
            let accountCurrency = candidates.map { normalizeCurrencyCode($0.currencyCode) }.sorted().joined(separator: ", ")
            return .failure(.currencyMismatch(name: name, accountCurrency: accountCurrency))
        }

        if unavailableKeys.contains(key) { return .failure(.unavailable(name: name)) }

        if let existing = newAccounts.first(where: { $0.key == key }) {
            guard existing.currencyCode == currency else {
                return .failure(.currencyMismatch(name: existing.name, accountCurrency: existing.currencyCode))
            }
            return .success(.new(key: key))
        }
        newAccounts.append(NewAccount(key: key, name: name, currencyCode: currency))
        return .success(.new(key: key))
    }
}
