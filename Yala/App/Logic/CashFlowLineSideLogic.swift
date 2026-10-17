//
//  CashFlowLineSideLogic.swift
//  Yala
//
//  Reglas del flujo de caja que dependen de si la línea es de ingreso o de gasto. Pasarse del plan es
//  mala noticia en un gasto y buena en un ingreso; y un pago programado solo se ofrece en su lado.
//

import Foundation

enum CashFlowLineSideLogic {

    /// La barra de avance del mes se pinta como alarma solo si un GASTO pasa del plan. Un ingreso por
    /// encima de lo estimado es buena noticia: antes salía en el mismo rosa que un gasto desbordado.
    static func progressIsAlarm(progress: Double, isIncome: Bool) -> Bool {
        progress > 1.0 && !isIncome
    }

    /// Si un pago programado pertenece al lado (ingresos o gastos) que se está agregando. Misma regla con
    /// la que el plan clasifica el pago al crear la línea (`transactionType == "income"`): antes la
    /// pestaña Ingresos de «Agregar línea» listaba también los gastos, y el elegido acababa en Gastos.
    static func scheduledPaymentMatchesSide(transactionType: String, isIncome: Bool) -> Bool {
        (transactionType == "income") == isIncome
    }
}
