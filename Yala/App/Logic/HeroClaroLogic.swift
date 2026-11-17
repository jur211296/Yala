//
//  HeroClaroLogic.swift
//  Yala
//
//  El hero «claro» fuera del Panel (encargo del 2026-11-16, decisión de Jürgen: «el hero del Panel es el estándar»).
//  Estadísticas, Registros y el Flujo de caja llevan el mismo patrón que el Panel: rótulo en palabras de persona, un «?»
//  que explica la cifra, la cifra pegada al rótulo y el detalle en chico.
//
//  Lógica pura: qué explicación toca a cada cifra, cuándo sale el «?» y los números del ejemplo de cada hoja. Los textos
//  se resuelven en la vista (`HeroInfoContent`), como el rótulo de `StatsHeroCaption`.
//

import Foundation

nonisolated enum HeroClaroLogic {

    /// La explicación que abre el «?» de una cifra.
    enum Topic: Equatable, CaseIterable {
        /// «Te queda» / «Te quedó»: ingresos − gastos del período.
        case net
        /// «Gastos de …»: lo gastado en el período.
        case expense
        /// «Ingresos de …»: lo que entró en el período.
        case income
        /// Distribución con los dos chips y un filtro: ingresos y gastos sumados, sin restar.
        case total
        /// Distribución en saldo: lo que hay en las cuentas («Tu saldo hoy» / «Tenías al cierre»).
        case accountsBalance
        /// Flujo de caja, mes en curso: «Al 30 de noviembre tendrías».
        case cashFlowMonthEnd
        /// Flujo de caja, otro mes: lo que entra menos lo que sale de ese mes según el plan.
        case cashFlowMonth
    }

    /// La explicación de la cifra de Estadísticas o de Registros: la misma magnitud que dice su rótulo
    /// (`StatsHeroCaption`), así que nunca puede explicar otra cosa que la que enseña.
    static func topic(for caption: StatsHeroCaption) -> Topic {
        switch caption {
        case .netPeriod: return .net
        case .expensePeriod: return .expense
        case .incomePeriod: return .income
        case .totalPeriod: return .total
        case .accountsBalance: return .accountsBalance
        }
    }

    /// La del mes del Flujo de caja: «Al 30 tendrías» solo en el mes en curso y con cuentas que sumen (la misma condición
    /// que elige su rótulo, `CashFlowMonthSummaryLogic.heroLabel`).
    static func cashFlowTopic(isCurrentMonth: Bool, hasMonthEnd: Bool) -> Topic {
        isCurrentMonth && hasMonthEnd ? .cashFlowMonthEnd : .cashFlowMonth
    }

    /// El «?» sale, como en el Panel, solo con «Mostrar ayudas» encendido y con una cifra a la que explicar.
    static func showsHelp(showHints: Bool, showsFigure: Bool) -> Bool {
        showHints && showsFigure
    }

    // MARK: - El ejemplo de cada hoja

    /// Una fila del ejemplo: qué es y cuánto. `isResult` es la fila de la cifra (en negrita).
    struct ExampleRow: Equatable {
        enum Label: Equatable {
            case income, expense, net, netShortfall, total, balanceToday, leftToComeIn, leftToGoOut, monthEnd
            case savings, card, refund, salary, sale
        }
        let label: Label
        let value: Double
        let isResult: Bool
    }

    /// Los números del ejemplo, en la moneda principal de la persona. Cuadran por construcción: el resultado es la
    /// cuenta de las filas de encima (lo fija `HeroClaroLogicTests`).
    static func example(for topic: Topic) -> [ExampleRow] {
        switch topic {
        case .net:
            return [
                .init(label: .income, value: 3_000, isResult: false),
                .init(label: .expense, value: 2_200, isResult: false),
                .init(label: .net, value: 3_000 - 2_200, isResult: true),
            ]
        case .expense:
            return [
                .init(label: .expense, value: 1_800, isResult: false),
                .init(label: .refund, value: -200, isResult: false),
                .init(label: .expense, value: 1_800 - 200, isResult: true),
            ]
        case .income:
            return [
                .init(label: .salary, value: 2_500, isResult: false),
                .init(label: .sale, value: 500, isResult: false),
                .init(label: .income, value: 2_500 + 500, isResult: true),
            ]
        case .total:
            return [
                .init(label: .income, value: 400, isResult: false),
                .init(label: .expense, value: 1_100, isResult: false),
                .init(label: .total, value: 400 + 1_100, isResult: true),
            ]
        case .accountsBalance:
            return [
                .init(label: .savings, value: 1_000, isResult: false),
                .init(label: .card, value: -300, isResult: false),
                .init(label: .balanceToday, value: 1_000 - 300, isResult: true),
            ]
        case .cashFlowMonthEnd:
            return [
                .init(label: .balanceToday, value: 1_000, isResult: false),
                .init(label: .leftToComeIn, value: 2_500, isResult: false),
                .init(label: .leftToGoOut, value: 1_800, isResult: false),
                .init(label: .monthEnd, value: 1_000 + 2_500 - 1_800, isResult: true),
            ]
        case .cashFlowMonth:
            return [
                .init(label: .income, value: 3_000, isResult: false),
                .init(label: .expense, value: 3_400, isResult: false),
                .init(label: .netShortfall, value: abs(3_000 - 3_400), isResult: true),
            ]
        }
    }
}
