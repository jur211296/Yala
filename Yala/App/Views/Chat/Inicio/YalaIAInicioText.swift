//
//  YalaIAInicioText.swift
//  Yala
//
//  Los textos del inicio de Yala IA, en su tabla propia (`YalaIAInicio.strings`, encargo del 17-nov). Se leen con la
//  misma cadena que `ls()` de `L10n.swift`: el idioma elegido dentro de Yala, su variante y su idioma padre. Con
//  `String(localized:table:)` a secas la tabla saldría en el idioma del teléfono aunque la persona eligiera otro en
//  Ajustes.
//

import Foundation

enum YalaIAInicioText {

    static let table = "YalaIAInicio"

    /// La clave en la tabla, con la cadena de idiomas de la app (variante → padre → main → la clave).
    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "yalaIAInicio.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    // MARK: - Apunta un gasto

    /// «Anotaré un gasto»
    static var logUserMessage: String { string("log.userMessage") }
    /// «¡Perfecto! Puedes hacerlo de estas maneras…»
    static var logReply: String { string("log.reply") }
    /// Los tres ejemplos: uno solo, varios a la vez y con fecha y cuenta.
    static var logExamples: [String] { [string("log.example1"), string("log.example2"), string("log.example3")] }

    // MARK: - Pregunta por tus finanzas

    /// «Preguntaré por mis finanzas»
    static var askUserMessage: String { string("ask.userMessage") }
    /// «¡Buena idea! Pregúntame con tus palabras…»
    static var askReply: String { string("ask.reply") }

    // MARK: - Crea conversando

    /// «Quiero crear algo»
    static var createUserMessage: String { string("create.userMessage") }
    /// «Lo armamos juntos, paso a paso…»
    static var createReply: String { string("create.reply") }
    static var createAccount: String { string("create.account") }
    static var createAccountMessage: String { string("create.accountMessage") }
    static var createCategory: String { string("create.category") }
    static var createCategoryMessage: String { string("create.categoryMessage") }
    static var createFavorite: String { string("create.favorite") }
    static var createFavoriteMessage: String { string("create.favoriteMessage") }
    static var createGroup: String { string("create.group") }
    static var createGroupMessage: String { string("create.groupMessage") }
}
