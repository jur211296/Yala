//
//  L10n+CorreosBancoGuia.swift
//  Yala
//
//  La guía de «Correo del banco» para quien nunca configuró un reenvío (pedido de Jürgen del 2026-11-23): cada paso dice
//  dónde entrar, qué tocar y qué se va a ver. Y el «Volver a este paso» de `YalaStepGuide`. En su propia tabla
//  (`CorreosBancoGuia.strings`), leída con el idioma de la app como `L10n.CuentaSolaAlLeer`.
//

import Foundation

extension L10n {
    enum CorreosBancoGuia {
        static let table = "CorreosBancoGuia"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            let fullKey = "correosGuia.\(key)"
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

        /// Las claves de la tabla, para la paridad entre idiomas.
        static let keys = [
            "guideLine", "findBank", "copy.title", "copy.detail",
            "gmail.add.title", "gmail.add.detail", "gmail.confirm.title", "gmail.confirm.waiting", "gmail.confirm.code",
            "gmail.filter.title", "gmail.filter.detail",
            "rule.title", "outlook.rule.detail", "icloud.rule.detail",
            "wait.title", "wait.detail", "stepGuide.reopen", "stepGuide.reopenHint",
        ]

        static var guideLine: String { string("guideLine") }
        /// Cómo encontrar la dirección del banco: va delante de los pasos del filtro o la regla.
        static var findBank: String { string("findBank") }
        static var copyTitle: String { string("copy.title") }
        static var copyDetail: String { string("copy.detail") }

        enum Gmail {
            static var addTitle: String { string("gmail.add.title") }
            static var addDetail: String { string("gmail.add.detail") }
            static var confirmTitle: String { string("gmail.confirm.title") }
            static var confirmWaiting: String { string("gmail.confirm.waiting") }
            static func confirmCode(_ code: String) -> String { format("gmail.confirm.code", code) }
            static var filterTitle: String { string("gmail.filter.title") }
            static var filterDetail: String { string("gmail.filter.detail") }
        }

        static var ruleTitle: String { string("rule.title") }
        static var outlookRuleDetail: String { string("outlook.rule.detail") }
        static var icloudRuleDetail: String { string("icloud.rule.detail") }
        static var waitTitle: String { string("wait.title") }
        static var waitDetail: String { string("wait.detail") }

        /// «Volver a este paso», en cada paso ya hecho de una guía por pasos.
        static var reopen: String { string("stepGuide.reopen") }
        static var reopenHint: String { string("stepGuide.reopenHint") }
    }
}
