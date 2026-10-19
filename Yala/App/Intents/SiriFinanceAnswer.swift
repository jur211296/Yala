//
//  SiriFinanceAnswer.swift
//  Yala
//
//  Qué contesta Siri a «¿cuánto gasté?» y «¿cuánto tengo?», decidido sin red y sin SwiftData sobre la foto de
//  `SiriFinanceSnapshot`. Lógica pura: la prueban `SiriFinanceAnswerTests` con relojes fijos.
//
//  Tres reglas que no se tocan sin reabrir la decisión del Paso 0 del encargo (D6):
//  - **No inventa**: si la foto es de OTRO período que el que se pregunta (cambió el mes y no se abrió Yala), no
//    contesta un número; pide abrir Yala.
//  - **Dice de cuándo es**: si la foto no es de hoy, la respuesta lo dice.
//  - **Solo gastos no tiene saldos**: «cuánto tengo» contesta lo gastado este mes, lo que enseña el Panel en ese modo.
//

import Foundation

/// Los períodos por los que se puede preguntar. El `rawValue` es el de `DetailPeriod`.
enum SiriSpendingPeriod: String, CaseIterable, Sendable {
    case thisWeek
    case thisMonth
    case lastMonth
    case thisYear

    var detailPeriod: DetailPeriod {
        switch self {
        case .thisWeek: return .thisWeek
        case .thisMonth: return .thisMonth
        case .lastMonth: return .lastMonth
        case .thisYear: return .thisYear
        }
    }
}

enum SiriFinanceAnswer: Equatable {
    /// No hay foto (Yala no se abrió nunca en este teléfono, o se cerró sesión).
    case noData
    /// Sesión solo grupos: no hay finanzas personales que contar.
    case groupsOnly
    /// La foto es de otro período: contestar sería dar el número de otro mes.
    case stale
    case spending(period: SiriSpendingPeriod, amount: Double, currencyCode: String, approximate: Bool, asOf: Date?)
    case totalBalance(amount: Double, currencyCode: String, approximate: Bool, asOf: Date?)
    case accountBalance(name: String, lines: [SiriFinanceSnapshot.Line], asOf: Date?)
    /// Modo solo gastos: no hay saldos, se dice lo gastado este mes.
    case expensesOnlySpending(amount: Double, currencyCode: String, approximate: Bool, asOf: Date?)
    case accountNotFound
}

enum SiriFinanceAnswerLogic {

    static func spending(
        snapshot: SiriFinanceSnapshot?,
        groupsOnly: Bool,
        period: SiriSpendingPeriod,
        now: Date,
        calendar: Calendar
    ) -> SiriFinanceAnswer {
        if groupsOnly { return .groupsOnly }
        guard let snapshot else { return .noData }
        guard let stored = currentPeriod(period, in: snapshot, now: now, calendar: calendar) else { return .stale }
        return .spending(
            period: period,
            amount: stored.expense,
            currencyCode: snapshot.preferredCurrencyCode,
            approximate: stored.expenseIsApproximate,
            asOf: asOf(snapshot, now: now, calendar: calendar)
        )
    }

    static func balance(
        snapshot: SiriFinanceSnapshot?,
        groupsOnly: Bool,
        expensesOnly: Bool,
        accountID: String?,
        now: Date,
        calendar: Calendar
    ) -> SiriFinanceAnswer {
        if groupsOnly { return .groupsOnly }
        guard let snapshot else { return .noData }
        let asOf = asOf(snapshot, now: now, calendar: calendar)
        if expensesOnly {
            guard let month = currentPeriod(.thisMonth, in: snapshot, now: now, calendar: calendar) else { return .stale }
            return .expensesOnlySpending(
                amount: month.expense,
                currencyCode: snapshot.preferredCurrencyCode,
                approximate: month.expenseIsApproximate,
                asOf: asOf
            )
        }
        if let accountID {
            guard let account = snapshot.account(id: accountID) else { return .accountNotFound }
            return .accountBalance(name: account.name, lines: account.lines, asOf: asOf)
        }
        return .totalBalance(
            amount: snapshot.totalBalance,
            currencyCode: snapshot.preferredCurrencyCode,
            approximate: snapshot.totalBalanceIsApproximate,
            asOf: asOf
        )
    }

    /// El período guardado, solo si es el MISMO que el de ahora: mismo inicio. El «mes pasado» de una foto de
    /// septiembre es agosto, y en octubre se pregunta por septiembre.
    static func currentPeriod(
        _ period: SiriSpendingPeriod,
        in snapshot: SiriFinanceSnapshot,
        now: Date,
        calendar: Calendar
    ) -> SiriFinanceSnapshot.Period? {
        guard let stored = snapshot.period(period.rawValue) else { return nil }
        let current = period.detailPeriod.dateInterval(now: now, calendar: calendar)
        return stored.start == current.start ? stored : nil
    }

    /// La fecha de la foto, si no es de hoy. Una foto «del futuro» (reloj cambiado) también se dice.
    static func asOf(_ snapshot: SiriFinanceSnapshot, now: Date, calendar: Calendar) -> Date? {
        calendar.isDate(snapshot.builtAt, inSameDayAs: now) ? nil : snapshot.builtAt
    }
}

// MARK: - Lo que se oye

/// El texto de cada respuesta, resuelto EN LA APP (`localize`), no por el sistema: una clave que resuelve Siri sale en
/// el idioma de desarrollo con un iPhone en es-PE (ticket `siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`).
enum SiriFinanceSpeech {

    static func text(
        for answer: SiriFinanceAnswer,
        localize: (String) -> String = { NSLocalizedString($0, comment: "") },
        currency: (Double, String) -> String = { YalaFormatterStatic.currency(value: $0, currencyCode: $1, forceFullPrecision: true) },
        date: (Date) -> String = { $0.formatted(date: .abbreviated, time: .shortened) },
        list: ([String]) -> String = { ListFormatter.localizedString(byJoining: $0) }
    ) -> String {
        func format(_ key: String, _ args: CVarArg...) -> String {
            String(format: localize(key), locale: Locale.current, arguments: args)
        }
        func tail(approximate: Bool, asOf: Date?) -> String {
            var parts: [String] = []
            if approximate { parts.append(localize("siri.query.approximate")) }
            if let asOf { parts.append(format("siri.query.asOf", date(asOf))) }
            return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
        }

        switch answer {
        case .noData:
            return localize("siri.query.noData")
        case .groupsOnly:
            return localize("siri.query.groupsOnly")
        case .stale:
            return localize("siri.query.stale")
        case .accountNotFound:
            return localize("siri.query.accountNotFound")
        case .spending(let period, let amount, let code, let approximate, let asOf):
            return format("siri.query.spending.\(period.rawValue)", currency(abs(amount), code))
                + tail(approximate: approximate, asOf: asOf)
        case .totalBalance(let amount, let code, let approximate, let asOf):
            return format("siri.query.balance.total", currency(amount, code)) + tail(approximate: approximate, asOf: asOf)
        case .accountBalance(let name, let lines, let asOf):
            let amounts = list(lines.map { currency($0.balance, $0.currencyCode) })
            return format("siri.query.balance.account", name, amounts) + tail(approximate: false, asOf: asOf)
        case .expensesOnlySpending(let amount, let code, let approximate, let asOf):
            return format("siri.query.balance.expensesOnly", currency(abs(amount), code))
                + tail(approximate: approximate, asOf: asOf)
        }
    }
}
