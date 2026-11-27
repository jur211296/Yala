//
//  CompartidoTexto.swift
//  Yala
//
//  Los textos de la sección «Compartido» (`compartido.*` en `Compartido.strings`, los 16 idiomas), leídos con el idioma
//  de la app (variante → padre → main → la clave), como `L10n.DividirBoleta`.
//

import Foundation

extension L10n {
    enum Compartido {
        static let tabla = "Compartido"

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

        private static func s(_ key: String) -> String { string("compartido.\(key)") }

        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        /// «Grupos» (chip)
        static var chipGroups: String { s("chip.groups") }
        /// «Personas» (chip)
        static var chipPeople: String { s("chip.people") }
        /// «Añadir persona» (barra del chip Personas)
        static var addPerson: String { s("addPerson") }
        /// «En Viaje a Cusco · Piso compartido»
        static func inGroups(_ groups: [String]) -> String { f("people.inGroups", joinedGroups(groups)) }
        /// «A mano · Viaje a Cusco»
        static func settledSubtitle(groups: [String]) -> String { f("people.settledIn", joinedGroups(groups)) }
        /// «Ver liquidadas (3)»
        static func showSettled(_ count: Int) -> String { f("people.showSettled", count) }
        /// «Sin grupo»: lo que compartes con una persona fuera de un grupo.
        static var noGroup: String { s("people.noGroup") }
        /// «Ocultar liquidadas»
        static var hideSettled: String { s("people.hideSettled") }
        /// «Aún no compartes gastos con nadie»
        static var peopleEmptyTitle: String { s("people.emptyTitle") }
        /// «Cuando apuntes un gasto con alguien en un grupo, aquí verás…»
        static var peopleEmptyMessage: String { s("people.emptyMessage") }

        /// Los nombres de los grupos, separados por « · » como la línea de la tarjeta de grupo.
        static func joinedGroups(_ groups: [String]) -> String { groups.joined(separator: " · ") }
    }
}
