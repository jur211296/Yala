//
//  UsageModeLogic.swift
//  Yala
//
//  Decisiones puras de «Cómo usas Yala» (card p0iu, decisiones de Jürgen del 2026-10-26): qué ofrece Ajustes, por dónde
//  vuelve la persona a Yala completo y con qué cuenta empieza de cero. Sin SwiftData ni singletons: lo que decide se
//  prueba con valores.
//

import Foundation

nonisolated enum UsageModeLogic {

    // MARK: - El botón destacado de Ajustes y de Más

    /// Qué dice la puerta destacada de la shell reducida.
    enum ReturnEntry: Equatable {
        /// Nunca tuvo Yala completo en este teléfono: «Activar Yala completo».
        case activate
        /// Eligió «Solo grupos» sobre Yala completo: «Volver a Yala completo · Tus cuentas y registros te esperan».
        case comeBack
    }

    static func returnEntry(hasPrivateSession: Bool) -> ReturnEntry {
        hasPrivateSession ? .comeBack : .activate
    }

    // MARK: - Qué pasa al volver

    /// «Sin registros» = cero registros propios (decisión 3 de Jürgen): sin pregunta, directo al Panel.
    enum ReturnRoute: Equatable {
        case direct
        case ask
    }

    static func returnRoute(savedRecords: Int) -> ReturnRoute {
        savedRecords > 0 ? .ask : .direct
    }

    /// Lo que cuenta la hoja de la vuelta y la segunda confirmación de «Empezar de cero».
    struct SavedSummary: Equatable {
        var records: Int
        var accounts: Int
        var budgets: Int
        var firstDate: Date?
        var lastDate: Date?
    }

    /// Un registro que cuenta como «guardado»: los que vienen de un grupo vuelven solos tras un borrado (convergencia) y
    /// un saldo inicial no es un registro. Contarlos haría preguntar a quien no tiene nada que perder.
    static func countsAsSavedRecord(splitExpenseID: String?, splitSettlementID: String?,
                                    balanceAdjustmentType: String?) -> Bool {
        splitExpenseID == nil && splitSettlementID == nil && balanceAdjustmentType == nil
    }

    // MARK: - La cuenta principal de «Empezar de cero»

    struct AccountCandidate: Equatable {
        var name: String
        var currencyCode: String
        var type: String
        var iconName: String
        var isArchived: Bool
        var isSystemAccount: Bool
        var isLine: Bool
        var recordCount: Int
    }

    struct AccountPrefill: Equatable {
        var name: String
        var currencyCode: String
        var type: String
        var iconName: String
    }

    /// La cuenta con más registros entre las que la persona creó (ni las de Grupos ni las líneas de una tarjeta). Mejor
    /// una no archivada; a igualdad, la primera por nombre, para que sea estable. Sin ninguna, la divisa preferida y un
    /// nombre vacío que la vista rellena con el del tipo.
    static func primaryAccountPrefill(_ candidates: [AccountCandidate], fallbackCurrency: String) -> AccountPrefill {
        let own = candidates.filter { !$0.isSystemAccount && !$0.isLine }
        let pool = own.contains { !$0.isArchived } ? own.filter { !$0.isArchived } : own
        let best = pool.sorted {
            if $0.recordCount != $1.recordCount { return $0.recordCount > $1.recordCount }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.first
        guard let best else {
            return AccountPrefill(name: "", currencyCode: fallbackCurrency, type: "checking", iconName: "creditcard")
        }
        return AccountPrefill(name: best.name, currencyCode: best.currencyCode, type: best.type, iconName: best.iconName)
    }
}
