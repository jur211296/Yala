//
//  AccountCurrencyPlanLogic.swift
//  Yala
//
//  Qué más cuelga de una cuenta cuando cambia su divisa, además del historial.
//  Ticket `account-currency-change-leaves-scheduled-and-favorites-stale`.
//

import Foundation

/// Las decisiones puras del cambio de divisa sobre lo que NO es historial: pagos programados,
/// favoritos y borradores pendientes de la Bandeja.
///
/// **El problema que cierra:** los tres guardan un importe y toman la divisa de la cuenta al
/// materializarse (el borrador del pago programado, la precarga del favorito, la aprobación del
/// borrador). Tras cambiar la cuenta de soles a dólares, el alquiler de 3.500 nacía cada mes como
/// 3.500 dólares.
///
/// **La política, decidida por Jürgen (opción 2A del 2026-10-07, confirmada el 2026-10-08):**
/// antes de cambiar la divisa Yala avisa y enseña qué se convierte; los pagos programados y los
/// favoritos pasan a la tasa de HOY; el historial sigue convirtiéndose a la tasa de SU fecha. Los
/// borradores pendientes van con el historial, a la tasa de su fecha (Jürgen, 2026-10-08).
enum AccountCurrencyPlanLogic {

    // MARK: - Qué entra

    /// Un pago programado se convierte con la cuenta solo si es personal.
    ///
    /// Los de grupo (`groupZoneID != nil`) llevan el importe en la divisa del GRUPO y lo manda el
    /// grupo: el editor solo deja elegir cuentas de esa divisa y el borrador se aprueba en el
    /// formulario de grupo. Convertirlo cambiaría un gasto compartido desde la pantalla de cuentas.
    static func convertsScheduledPayment(isGroupPayment: Bool) -> Bool {
        !isGroupPayment
    }

    /// La forma de un borrador que importa para decidir si se convierte.
    struct DraftShape: Equatable, Sendable {
        let isPending: Bool
        let sourceType: DraftSourceType
        let hasGroupPointer: Bool
        let hasAmount: Bool
    }

    /// Un borrador pendiente se convierte salvo que su importe lo mande un grupo.
    ///
    /// `isFromGroup` no basta: `.groupScheduledExpense` no está ahí (se puede saltar como un pago
    /// planificado) y su importe sigue siendo de la divisa del grupo. Y un puntero de grupo suelto
    /// (`splitExpenseID`, `splitSettlementID`, `splitGroupZoneID`) dice lo mismo aunque el tipo diga
    /// otra cosa. Los aprobados y rechazados son historia del Inbox: guardan su propia divisa
    /// (`cachedCurrencyCode`) y no se tocan.
    static func convertsDraft(_ draft: DraftShape) -> Bool {
        guard draft.isPending, draft.hasAmount else { return false }
        if draft.sourceType.isFromGroup || draft.sourceType == .groupScheduledExpense { return false }
        return !draft.hasGroupPointer
    }

    // MARK: - Redondeo

    /// Los decimales con los que se escribe un importe en esta divisa (ISO 4217: JPY 0, USD 2).
    ///
    /// Sale de `NumberFormatter`, que lee los datos de ICU, en vez de una tabla propia: una lista a
    /// mano se queda corta con la divisa número 55.
    static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizeCurrencyCode(currencyCode)
        return max(0, formatter.maximumFractionDigits)
    }

    /// Redondea a los decimales de la divisa. Solo para programados y favoritos: son números que la
    /// persona tecleó y vuelve a ver, y «930,2346 $» en un pago programado no lo escribiría nadie.
    static func rounded(_ amount: Decimal, to currencyCode: String) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, fractionDigits(for: currencyCode), .plain)
        return result
    }
}
