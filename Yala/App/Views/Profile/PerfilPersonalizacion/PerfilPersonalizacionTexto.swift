//
//  PerfilPersonalizacionTexto.swift
//  Yala
//
//  Los textos de la personalización del perfil (`perfil.*` en `PerfilPersonalizacion.strings`, los 16 idiomas), leídos
//  con el idioma de la app (variante → padre → main → la clave), como `L10n.AsistentePagoPlanificado`. Los nombres de las
//  plantillas del fondo son los del editor de tarjetas (`L10n.DisenoTarjeta.template`).
//

import Foundation

extension L10n {
    enum PerfilPersonalizacion {
        static let tabla = "PerfilPersonalizacion"

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

        private static func s(_ key: String) -> String { string("perfil.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        // Tarjeta
        static var cardLabel: String { s("card.label") }
        static var avatarMenu: String { s("avatar.menu") }

        // Avatar
        static var avatarSection: String { s("section.avatar") }
        static var kindPicker: String { s("kind.picker") }
        static var kindSymbol: String { s("kind.symbol") }
        static var kindEmoji: String { s("kind.emoji") }
        static var kindInitials: String { s("kind.initials") }
        static var kindPhoto: String { s("kind.photo") }
        static func symbolNumbered(_ index: Int) -> String { f("symbol.numbered", index) }
        static var initialsDetail: String { s("initials.detail") }
        static var initialsNeedName: String { s("initials.needName") }
        static var photoChoose: String { s("photo.choose") }
        static var photoChange: String { s("photo.change") }
        static var photoRemove: String { s("photo.remove") }
        static var photoDetail: String { s("photo.detail") }

        // Color
        static var colorSection: String { s("section.color") }
        static var colorTheme: String { s("color.theme") }
        static func colorNumbered(_ index: Int) -> String { f("color.numbered", index) }
        static var colorCustom: String { s("color.custom") }

        // Fondo
        static var cardSection: String { s("section.card") }

        // Volver
        static var reset: String { s("reset") }

        /// El nombre del tipo de avatar, para el selector.
        static func kind(_ kind: ProfileAvatarKind) -> String {
            switch kind {
            case .symbol: return kindSymbol
            case .emoji: return kindEmoji
            case .initials: return kindInitials
            }
        }
    }
}
