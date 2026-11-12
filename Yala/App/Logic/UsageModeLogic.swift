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

    // MARK: - Los pagos programados que vencieron durante la pausa

    /// ¿Se saltan, al volver, los vencimientos de este pago que cayeron durante «Solo grupos»? (decisión de Jürgen del
    /// 2026-10-27, encargo S11e: al volver no aparecen de golpe; cada pago sigue en su próxima fecha, los de grupo y los
    /// personales.) `true` ⇒ la próxima fecha pasa al primer vencimiento desde hoy, sin borrador.
    ///
    /// Se mira el primer vencimiento que aún no salió a la Bandeja: la próxima fecha, o la siguiente si ya hay un
    /// borrador pendiente (ese borrador cubre la próxima fecha, y aprobarlo o descartarlo con la fecha ya por delante no
    /// la vuelve a avanzar: `ScheduledDraftOccurrenceLogic.approvalAdvancesPointer`). Sin mirar la siguiente, un
    /// borrador de antes de la pausa dejaba salir después, uno a uno, todo lo de la pausa (review adversarial de S11e).
    ///
    /// - Un pago de una vez no tiene próxima fecha: saltarlo lo apagaría sin que nadie lo viera. Sale al volver.
    /// - Si ese primer vencimiento es anterior a la pausa, no venció durante ella: sigue el camino normal (la vuelta
    ///   saca su borrador y vuelve a preguntar con él pendiente). `pauseStartDay == nil` (marca de un build sin la
    ///   fecha): todo lo anterior a hoy.
    /// - El de hoy es el ciclo normal.
    static func skipsOccurrencesMissedDuringPause(isActive: Bool, isRecurring: Bool, hasPendingDraft: Bool,
                                                  nextDueDay: Date, followingDueDay: Date?, pauseStartDay: Date?,
                                                  today: Date) -> Bool {
        guard isActive, isRecurring, nextDueDay < today else { return false }
        guard let firstNotShown = hasPendingDraft ? followingDueDay : nextDueDay, firstNotShown < today else {
            return false
        }
        if let pauseStartDay, firstNotShown < pauseStartDay { return false }
        return true
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
