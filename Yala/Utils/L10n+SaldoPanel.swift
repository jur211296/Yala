//
//  L10n+SaldoPanel.swift
//  Yala
//
//  Panel: el saldo en grande, «Tu dinero hoy» en chico y el «?» que explica los dos (2026-11-16). En su propio fichero,
//  como los lotes de 2.2 y 2.3. La cifra grande sigue usando `L10n.Panel.Hero.haveToday` («Tu saldo hoy»), que comparten
//  Estadísticas y el flujo de caja.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func saldoPanelString(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum SaldoPanel {
        /// La línea chica del hero: lo que hay en las cuentas que cuentan como dinero para usar.
        static var moneyToday: String { saldoPanelString("panel.saldo.moneyToday") }
        /// VoiceOver del «?» junto al saldo.
        static var infoButton: String { saldoPanelString("panel.saldo.infoButton") }

        enum Info {
            static var title: String { saldoPanelString("panel.saldo.info.title") }
            static var balanceBody: String { saldoPanelString("panel.saldo.info.balanceBody") }
            static var moneyBody: String { saldoPanelString("panel.saldo.info.moneyBody") }
            static var exampleTitle: String { saldoPanelString("panel.saldo.info.exampleTitle") }
            static var exampleSavings: String { saldoPanelString("panel.saldo.info.exampleSavings") }
            static var exampleCard: String { saldoPanelString("panel.saldo.info.exampleCard") }
            static var exampleNote: String { saldoPanelString("panel.saldo.info.exampleNote") }
            static var chooseAccounts: String { saldoPanelString("panel.saldo.info.chooseAccounts") }
            static var chooseHint: String { saldoPanelString("panel.saldo.info.chooseHint") }
        }

        /// La pantalla con un interruptor por cuenta.
        static var accountsTitle: String { saldoPanelString("panel.saldo.accounts.title") }
        /// El interruptor de cada cuenta, el mismo en el formulario de la cuenta y en la lista.
        static var countsToggle: String { saldoPanelString("panel.saldo.countsToggle") }
        static var countsHint: String { saldoPanelString("panel.saldo.countsHint") }
    }
}
