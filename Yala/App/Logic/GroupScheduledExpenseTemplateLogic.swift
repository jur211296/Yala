//
//  GroupScheduledExpenseTemplateLogic.swift
//  Yala
//
//  Construye el `GroupExpensePrefillTemplate` con el que la Bandeja abre el formulario de grupo al
//  aprobar un borrador `.groupScheduledExpense`. Vivía dentro de `InboxView.loadGroupScheduledContext`;
//  sale de ahí para poder probarlo de punta a punta (borrador → formulario → gasto → puente).
//

import Foundation

enum GroupScheduledExpenseTemplateLogic {
    /// La plantilla del gasto de grupo que materializa un pago planificado de grupo.
    ///
    /// - Parameters:
    ///   - payment: el pago planificado. Es la fuente del reparto (SSOT): el borrador no lo snapshotea.
    ///   - draftDate: la fecha DEL BORRADOR (`effectiveDate`), no `payment.nextDueDate`: el pago recurrente
    ///     puede haber avanzado ya su próxima fecha, y tomarla de ahí fecharía el gasto en el vencimiento
    ///     SIGUIENTE. El borrador es la ocurrencia concreta que la persona ve.
    static func buildTemplate(payment: ScheduledPayment, draftDate: Date) -> GroupExpensePrefillTemplate {
        GroupExpensePrefillTemplate(
            totalAmount: payment.splitTotalAmount ?? abs(payment.amount),
            currencyCode: payment.currencyCode,
            splitType: SplitType(rawValue: payment.splitType ?? "equal") ?? .equal,
            participantIDs: payment.resolvedParticipantIDs(),
            values: payment.resolvedSplitValues(),
            description: payment.name,
            accountPrefill: payment.account,
            date: draftDate,
            // La que la persona eligió al planificarlo: el editor la ofrece como prefill del gasto.
            subcategory: payment.subcategory
        )
    }
}
