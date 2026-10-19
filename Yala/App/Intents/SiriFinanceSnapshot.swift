//
//  SiriFinanceSnapshot.swift
//  Yala
//
//  Lo que Siri puede contestar sin abrir la app: cuánto gastaste en un período y cuánto tienes, en total o en una
//  cuenta. Card «Integrar Yala con el nuevo Siri con IA de iOS 27» (2.2), opción B de `docs/siri-ios-27-2026-10.md`.
//
//  Una foto PROPIA en el App Group (`storageKey`), no el snapshot de los widgets:
//  - el intent no abre SwiftData (un 2º `ModelContainer` sobre el store de la app vació la UI hasta un arranque en frío,
//    `siri-intent-dual-container`), así que lee algo ya calculado;
//  - el `WidgetDataSnapshot` está duplicado en dos targets y se decodifica entero: un campo nuevo mal declarado apaga
//    todos los widgets (regla del App Group en `swiftdata-cloudkit.md`). Una clave aparte no puede romperlo;
//  - el id de cuenta del snapshot de widgets es el `hashValue` de un `PersistentIdentifier`, que cambia entre
//    procesos: una entidad de Siri necesita el `shortcutID`, que no cambia.
//
//  La escribe `WidgetDataCache.updateCache` con los MISMOS números que los widgets y la borra `clearCache`, así que
//  vive y muere con ellos (cierre de sesión, borrados).
//

import Foundation

nonisolated struct SiriFinanceSnapshot: Codable, Equatable, Sendable {

    static let storageKey = "siri_finance_snapshot"
    static let currentVersion = 1

    let version: Int
    let builtAt: Date
    let preferredCurrencyCode: String
    let totalBalance: Double
    let totalBalanceIsApproximate: Bool
    let periods: [Period]
    let accounts: [Account]

    /// Un período tal como lo calculó la app al escribir la foto. `start` es lo que prueba que la foto habla del
    /// período por el que se pregunta: el «este mes» de una foto de septiembre no es el de octubre.
    struct Period: Codable, Equatable, Sendable {
        let key: String
        let start: Date
        let end: Date
        let expense: Double
        let expenseIsApproximate: Bool
    }

    /// Una tarjeta del Panel: la cuenta principal y, si tiene, sus líneas en otras divisas.
    struct Account: Codable, Equatable, Sendable {
        /// `shortcutID` de la cuenta principal.
        let id: String
        let name: String
        /// La principal primero, después sus líneas por divisa.
        let lines: [Line]
    }

    struct Line: Codable, Equatable, Sendable {
        let currencyCode: String
        /// Saldo en la divisa de la línea, con signo (una tarjeta de crédito con deuda es negativa).
        let balance: Double
    }

    func period(_ key: String) -> Period? { periods.first { $0.key == key } }
    func account(id: String) -> Account? { accounts.first { $0.id == id } }
}

// MARK: - Construcción

/// Lo que la foto necesita de una cuenta. Sin `@Model`: se construye en el sitio que lee SwiftData.
nonisolated struct SiriAccountInput: Equatable, Sendable {
    let node: AccountLineNode
    let name: String
    let excludedFromStatistics: Bool
    let nativeBalance: Double
}

/// En el main actor: `DetailPeriod` y `WidgetDataSnapshot` lo están (aislamiento por defecto del target).
enum SiriFinanceSnapshotBuilder {

    /// Los períodos por los que Siri puede preguntar (`SiriSpendingPeriod`). Tienen que estar entre los que
    /// `WidgetDataCache` precalcula.
    static let periodKeys: [DetailPeriod] = [.thisWeek, .thisMonth, .lastMonth, .thisYear]

    /// - Parameters:
    ///   - widget: el snapshot de los widgets recién calculado; de ahí salen los totales, así Siri y los widgets dicen
    ///     lo mismo.
    ///   - accounts: TODAS las cuentas (archivadas incluidas): una principal archivada tiene que estar para que su
    ///     línea se lea suelta (`AccountCardLogic.cards`).
    static func make(
        widget: WidgetDataSnapshot,
        accounts: [SiriAccountInput],
        now: Date,
        calendar: Calendar
    ) -> SiriFinanceSnapshot {
        let summaries = widget.periodSummaries
        let periods: [SiriFinanceSnapshot.Period] = periodKeys.compactMap { period in
            guard let summary = summaries[period.rawValue] else { return nil }
            let interval = period.dateInterval(now: now, calendar: calendar)
            return SiriFinanceSnapshot.Period(
                key: period.rawValue,
                start: interval.start,
                end: interval.end,
                expense: summary.totalExpense,
                expenseIsApproximate: summary.expenseIsApproximate ?? false
            )
        }

        return SiriFinanceSnapshot(
            version: SiriFinanceSnapshot.currentVersion,
            builtAt: now,
            preferredCurrencyCode: widget.preferredCurrencyCode,
            totalBalance: widget.totalBalance,
            totalBalanceIsApproximate: widget.allTimeSummary.periodBalanceIsApproximate ?? false,
            periods: periods,
            accounts: cards(from: accounts)
        )
    }

    /// Las cuentas que enseña el Panel, agrupadas en tarjetas: ni archivadas, ni excluidas de las estadísticas, ni las
    /// de sistema de Grupos. Qué es línea de qué lo decide SOLO `AccountLineLogic.resolve`.
    static func cards(from accounts: [SiriAccountInput]) -> [SiriFinanceSnapshot.Account] {
        let roles = AccountLineLogic.resolve(accounts.map(\.node))
        let shown = accounts.filter { !$0.node.isArchived && !$0.node.isSystem && !$0.excludedFromStatistics }
        let cards = AccountCardLogic.cards(shown, roles: roles, id: { $0.node.id }, currencyCode: { $0.node.currencyCode })
        return cards.map { card in
            SiriFinanceSnapshot.Account(
                id: card.head.node.id.uuidString,
                name: card.head.name,
                lines: card.members.map { SiriFinanceSnapshot.Line(currencyCode: $0.node.currencyCode, balance: $0.nativeBalance) }
            )
        }
    }
}

// MARK: - Almacén

nonisolated enum SiriFinanceSnapshotStore {

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    static func write(_ snapshot: SiriFinanceSnapshot, to defaults: UserDefaults?) {
        guard let defaults else { return }
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: SiriFinanceSnapshot.storageKey)
        } catch {
            #if DEBUG
            print("SiriFinanceSnapshotStore: Error: \(error)")
            #endif
        }
    }

    /// `nil` si no hay foto o no se deja leer: el intent contesta «abre Yala una vez», nunca un cero.
    static func read(from defaults: UserDefaults?) -> SiriFinanceSnapshot? {
        guard let data = defaults?.data(forKey: SiriFinanceSnapshot.storageKey) else { return nil }
        do {
            let snapshot = try JSONDecoder().decode(SiriFinanceSnapshot.self, from: data)
            return snapshot.version == SiriFinanceSnapshot.currentVersion ? snapshot : nil
        } catch {
            #if DEBUG
            print("SiriFinanceSnapshotStore: Error: \(error)")
            #endif
            return nil
        }
    }

    static func clear(in defaults: UserDefaults?) {
        defaults?.removeObject(forKey: SiriFinanceSnapshot.storageKey)
    }
}
