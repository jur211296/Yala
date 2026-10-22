//
//  BalanceCalculatorInputLogic.swift
//  Yala
//
//  El formato de los campos de la calculadora del saldo (`BalanceCalculatorSheet`), en un solo sitio.
//
//  Los campos de la calculadora guardan el número «crudo»: dígitos, un punto como decimal y nada más
//  (`filterCalcInput` convierte la coma en punto y descarta todo lo demás). Hasta el 2026-10-22 el onboarding
//  prefijaba el campo al reabrir la calculadora con `AmountInputHelper.formatWithGrouping`, que lleva separador
//  de miles: «1,800.00» en es-PE o «1.800,00» en es-ES. El parseo de la calculadora no entiende ese separador y
//  leía 0, así que «Usar este saldo» dejaba la cuenta en cero (ticket
//  `reopened-balance-calculator-reads-a-grouped-amount-as-zero`). Quien escribe en el campo y quien lo lee usan
//  ahora estas dos funciones, y las dos hablan el mismo formato.
//

import Foundation

nonisolated enum BalanceCalculatorInputLogic {

    /// Lo que la calculadora entiende al leer un campo: el número con punto decimal. Una coma se lee como decimal
    /// (es lo que deja `filterCalcInput` al teclear «12,5»). Texto vacío o ilegible es 0.
    static func parse(_ text: String) -> Double {
        Double(text.replacing(",", with: ".")) ?? 0
    }

    /// El texto con el que se prefija un campo: sin separador de miles, con punto decimal y sin decimales si el
    /// monto es entero. Es el mismo formato que dejaría la persona al teclearlo, así que editarlo después sigue
    /// funcionando. Siempre positivo: el signo lo pone la calculadora.
    static func prefillText(for amount: Double) -> String {
        let value = abs(amount)
        let cents = (value * 100).rounded()
        if cents.truncatingRemainder(dividingBy: 100) == 0 {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), cents / 100)
        }
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), cents / 100)
    }
}
