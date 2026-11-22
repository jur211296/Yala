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

// MARK: - Parte 2: reglas de captura (2026-11-21)

extension L10n.CuentaSolaAlLeer {
    private static func fmt(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: LanguageManager.resolved.locale, arguments: args)
    }

    enum Rule {
        /// «Elegí Zip Visa por tu regla «zip».»
        static func why(_ name: String, _ rule: String) -> String { fmt("why.rule", name, rule) }
        static func accessibility(_ name: String, _ rule: String) -> String { fmt("a11y.chosenRule", name, rule) }
        /// «Dos reglas apuntan a cuentas distintas».
        static var conflict: String { string("selector.rulesConflict") }
        /// «Tu regla «zip»», el motivo de una fila del selector.
        static func reason(_ rule: String) -> String { fmt("selector.reasonRule", rule) }
    }

    enum Remember {
        /// «¿Siempre que diga «Zip»?»
        static func offer(_ words: String) -> String { fmt("remember.offer", words) }
        static var action: String { string("remember.action") }
        static var dismiss: String { string("remember.dismiss") }
        /// «Listo. Cuando diga «Zip», irá a Zip Visa.»
        static func done(_ words: String, _ account: String) -> String { fmt("remember.done", words, account) }
    }

    enum Rules {
        static var section: String { string("rules.section") }
        static var add: String { string("rules.add") }
        static var footer: String { string("rules.footer") }

        /// La fila de una regla en Editar cuenta.
        static func row(_ rule: AccountCaptureRule) -> String {
            switch rule.kind {
            case .applePayCard: return fmt("rules.row.applePay", rule.value)
            case .merchant: return fmt("rules.row.merchant", rule.value)
            case .text:
                return rule.mode == .together && CuentaSolaAlLeerReglas.palabras(rule.value).count >= 2
                    ? fmt("rules.row.textTogether", rule.value) : fmt("rules.row.text", rule.value)
            }
        }
    }

    enum Editor {
        static var newTitle: String { string("editor.newTitle") }
        static var editTitle: String { string("editor.editTitle") }
        static var when: String { string("editor.when") }
        static func kind(_ kind: AccountCaptureRule.Kind) -> String {
            switch kind {
            case .applePayCard: return string("editor.kind.applePay")
            case .text: return string("editor.kind.text")
            case .merchant: return string("editor.kind.merchant")
            }
        }
        static func placeholder(_ kind: AccountCaptureRule.Kind) -> String {
            switch kind {
            case .applePayCard: return string("editor.placeholder.applePay")
            case .text: return string("editor.placeholder.text")
            case .merchant: return string("editor.placeholder.merchant")
            }
        }
        static var words: String { string("editor.words") }
        static func mode(_ mode: AccountCaptureRule.Mode) -> String {
            mode == .together ? string("editor.mode.together") : string("editor.mode.allWords")
        }
        static var goesTo: String { string("editor.goesTo") }
        static var preview: String { string("editor.preview") }
        static func previewText(_ kind: AccountCaptureRule.Kind, value: String, account: String) -> String {
            switch kind {
            case .applePayCard: return fmt("editor.preview.applePay", value, account)
            case .text: return fmt("editor.preview.text", value, account)
            case .merchant: return fmt("editor.preview.merchant", value, account)
            }
        }
        static var previewEmpty: String { string("editor.preview.empty") }
        static var applePayHint: String { string("editor.applePayHint") }
        static var save: String { string("editor.save") }
        static var delete: String { string("editor.delete") }
    }

    enum Duplicate {
        static var title: String { string("duplicate.title") }
        /// «Ya tienes esta regla para Interbank Visa. ¿La paso a Zip Visa?»
        static func message(from: String, to: String) -> String { fmt("duplicate.message", from, to) }
        static var move: String { string("duplicate.move") }
    }

    enum Consent {
        static var notNow: String { string("consent.notNow") }
    }
}
