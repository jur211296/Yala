//
//  ConectaTuIAText.swift
//  Yala
//
//  Los textos de «Conecta tu IA» (`conectaTuIA.*` en `ConectaTuIA.strings`, los 16 idiomas), leídos con el idioma de la
//  app (variante → padre → main → la clave), como `L10n.ComerciosEnComun`.
//

import Foundation

extension L10n {
    enum ConectaTuIA {
        static let tabla = "ConectaTuIA"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            return value == sentinel ? key : value
        }

        private static func s(_ key: String) -> String { string("conectaTuIA.\(key)") }

        private static func format(_ key: String, _ arg: String) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arg)
        }

        // Ajustes
        static var title: String { s("title") }
        static var rowSubtitle: String { s("row.subtitle") }
        static var headerTitle: String { s("header.title") }
        static var headerMessage: String { s("header.message") }

        // Cómo conectarla
        static var stepsHeader: String { s("steps.header") }
        static var copy: String { s("copy") }
        static var copied: String { s("copied") }
        static var copyHint: String { s("copyHint") }
        static var chatGPTNote: String { s("chatgpt.note") }

        /// Los tres pasos de una IA. El segundo termina en la dirección del conector, que la vista pinta debajo.
        static func steps(_ provider: ConectaTuIALogic.Provider) -> [String] {
            let prefix: String = switch provider {
            case .claude: "claude"
            case .chatgpt: "chatgpt"
            case .grok: "grok"
            }
            return (1...3).map { s("\(prefix).step\($0)") }
        }

        // Qué puede hacer
        static var canHeader: String { s("can.header") }
        static var canRead: String { s("can.read") }
        static var canDraft: String { s("can.draft") }
        static var canNever: String { s("can.never") }
        static var canFooter: String { s("can.footer") }

        // Sin la cuenta de Yala
        static var accountTitle: String { s("account.title") }
        static var accountMessage: String { s("account.message") }
        static var accountButton: String { s("account.button") }
        static var accountWhere: String { s("account.where") }

        // Conectadas
        static var connectedHeader: String { s("connected.header") }
        static var connectedEmpty: String { s("connected.empty") }
        static var connectedFooter: String { s("connected.footer") }
        static func connectedSince(_ date: String) -> String { format("connected.since", date) }
        static var connectedLocal: String { s("connected.local") }
        static func lastDraft(_ relative: String) -> String { format("connected.lastDraft", relative) }
        static var loadFailed: String { s("connected.loadFailed") }

        // Desconectar
        static var disconnect: String { s("disconnect") }
        static func disconnectConfirmTitle(_ name: String) -> String { format("disconnect.confirmTitle", name) }
        static var disconnectConfirmBody: String { s("disconnect.confirmBody") }
        static var disconnectFailed: String { s("disconnect.failed") }

        // Bandeja
        static var inboxTitle: String { s("inbox.title") }
        static var inboxMessage: String { s("inbox.message") }
        static var inboxButton: String { s("inbox.button") }
        static var filterFromAI: String { s("filter.fromAI") }

        // Paso 7 de Primeros pasos
        static var paso7Name: String { s("paso7.name") }
        static var paso7StoryTitle: String { s("paso7.storyTitle") }
        static var paso7StoryMessage: String { s("paso7.storyMessage") }
        static var paso7MethodTitle: String { s("paso7.methodTitle") }
        static var paso7MethodSubtitle: String { s("paso7.methodSubtitle") }
        /// Lo que la persona le dice a su IA en la ilustración: «Apunta 25 de almuerzo».
        static var paso7Example: String { s("paso7.example") }

        /// «Conectada el 23 nov · claude.ai · último borrador hace 2 h». Lo que no se sabe, no sale.
        static func detailLine(_ connection: AIConnection, lastDraftAt: Foundation.Date?, now: Foundation.Date = .now) -> String {
            let locale = LanguageManager.resolved.locale
            let since = Foundation.Date(timeIntervalSince1970: connection.conectadaEl)
                .formatted(.dateTime.day().month(.abbreviated).locale(locale))
            var parts = [connectedSince(since)]
            if connection.local {
                parts.append(connectedLocal)
            } else if let host = connection.vuelta, !host.isEmpty {
                parts.append(host)
            }
            if let lastDraftAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.locale = locale
                formatter.unitsStyle = .full
                parts.append(lastDraft(formatter.localizedString(for: min(lastDraftAt, now), relativeTo: now)))
            }
            return parts.joined(separator: " · ")
        }
    }
}
