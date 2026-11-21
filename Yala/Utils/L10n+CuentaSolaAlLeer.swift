//
//  L10n+CuentaSolaAlLeer.swift
//  Yala
//
//  La cuenta se elige sola al leer una captura (parte 1, 2026-11-20): chip con estrella, línea de «por qué», selector con
//  «Coinciden con…», ayuda del número de cuenta y el paso de la tarjeta de Apple Pay. En su propia tabla
//  (`CuentaSolaAlLeer.strings`), leída con el idioma de la app como `OfertaProBeneficiosText`.
//

import Foundation

extension L10n {
    enum CuentaSolaAlLeer {
        static let table = "CuentaSolaAlLeer"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            let fullKey = "cuentaSola.\(key)"
            var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
            }
            return value == sentinel ? fullKey : value
        }

        private static func format(_ key: String, _ args: CVarArg...) -> String {
            String(format: string(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        enum Chip {
            /// «✦ Tarjeta de crédito»: la cuenta que se eligió sola.
            static func chosen(_ name: String) -> String { format("chip.chosen", name) }
            /// «Interbank Visa · sugerida»: la propone Yala IA.
            static func suggested(_ name: String) -> String { format("chip.suggested", name) }
            static var choose: String { string("chip.choose") }
            /// «Elige cuenta · 2 coinciden».
            static func chooseMatching(_ count: Int) -> String { format("chip.chooseMatching", count) }
        }

        enum Why {
            /// «Elegí Tarjeta de crédito porque la imagen lo dice. Toca la cuenta para cambiarla.»
            static func image(_ name: String) -> String { format("why.image", name) }
            /// «Elegí Zip Visa: termina en 4417, como su número de cuenta.»
            static func last4(_ name: String, _ digits: String) -> String { format("why.last4", name, digits) }
            /// «Lo sugiere Yala IA. Revisa que sea Interbank Visa antes de guardar.»
            static func suggested(_ name: String) -> String { format("why.suggested", name) }
        }

        enum Accessibility {
            static func chosen(_ name: String) -> String { format("a11y.chosen", name) }
            static func chosenLast4(_ name: String, _ digits: String) -> String { format("a11y.chosenLast4", name, digits) }
            static func suggested(_ name: String) -> String { format("a11y.suggested", name) }
            static func chooseMatching(_ count: Int) -> String { format("a11y.chooseMatching", count) }
        }

        enum Selector {
            /// «Coinciden con «Visa»».
            static func matches(_ words: String) -> String { format("selector.matches", words) }
            static var matchesNoWords: String { string("selector.matchesNoWords") }
            static var conflict: String { string("selector.conflict") }
            static var others: String { string("selector.others") }
            static var reasonImage: String { string("selector.reasonImage") }
            static var reasonAI: String { string("selector.reasonAI") }
        }

        enum Account {
            /// Ayuda bajo «Número de cuenta».
            static var numberHelp: String { string("account.numberHelp") }
        }

        enum ApplePay {
            static var cardStepTitle: String { string("applePay.cardStep.title") }
            static var cardStepDetail: String { string("applePay.cardStep.detail") }
            static var updateShortcut: String { string("applePay.updateShortcut") }
        }
    }
}
