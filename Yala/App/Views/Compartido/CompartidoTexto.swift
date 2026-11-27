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

        // MARK: Lote 2 · detalle de persona

        enum Detail {
            private static func s(_ key: String) -> String { Compartido.string("compartido.detail.\(key)") }

            private static func f(_ key: String, _ args: CVarArg...) -> String {
                String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
            }

            /// «Todos los grupos»
            static var filterAll: String { s("filter.all") }
            /// «Filtrar por grupo» (VoiceOver de la cápsula)
            static var filterLabel: String { s("filter.label") }
            /// «Con Beto te deben» / «Con Beto debes» / «Con Beto estás a mano»
            static func heroWith(_ name: String, owed: Bool, settled: Bool) -> String {
                settled ? f("hero.with.settled", name) : f(owed ? "hero.with.owed" : "hero.with.owe", name)
            }
            /// «En Viaje a Cusco te deben» / «… debes» / «… estás a mano»
            static func heroIn(_ group: String, owed: Bool, settled: Bool) -> String {
                settled ? f("hero.in.settled", group) : f(owed ? "hero.in.owed" : "hero.in.owe", group)
            }
            /// «Tú no le debes nada.»
            static var youOweNothing: String { s("hero.youOweNothing") }
            /// «No te debe nada.»
            static var theyOweNothing: String { s("hero.theyOweNothing") }
            /// «Y tú le debes S/ 20.00.»
            static func alsoYouOwe(_ amounts: String) -> String { f("hero.alsoYouOwe", amounts) }
            /// «Y te debe S/ 20.00.»
            static func alsoTheyOwe(_ amounts: String) -> String { f("hero.alsoTheyOwe", amounts) }
            /// «Solo este grupo.»
            static var onlyThisGroup: String { s("hero.onlyThisGroup") }
            /// «Solo lo que no está en un grupo.»
            static var onlyNoGroup: String { s("hero.onlyNoGroup") }
            /// «Saldar todo»
            static var settleAll: String { s("settle.all") }
            /// «Se apunta un pago por cada grupo y moneda.»
            static var settleAllNote: String { s("settle.allNote") }
            /// «Para confirmar un pago o ver los pagos de un grupo, elígelo arriba.»
            static var pickGroupHint: String { s("settle.pickGroupHint") }
            /// «Saldar todo con Beto»
            static func settleSheetTitle(_ name: String) -> String { f("settle.sheetTitle", name) }
            /// «Se apuntarán 3 pagos, uno por grupo y moneda…»
            static func settleSheetMessage(_ count: Int) -> String { f("settle.sheetMessage", count) }
            /// «Beto te paga S/ 110.00»
            static func rowTheyPay(_ name: String, _ amount: String) -> String { f("settle.rowTheyPay", name, amount) }
            /// «Le pagas S/ 30.00 a Beto»
            static func rowYouPay(_ name: String, _ amount: String) -> String { f("settle.rowYouPay", name, amount) }
            /// «Apuntar 3 pagos»
            static func settleConfirm(_ count: Int) -> String { f("settle.confirm", count) }
            /// «Apuntaste 3 pagos con Beto. Quedan a mano.»
            static func settleSaved(_ count: Int, _ name: String) -> String { f("settle.savedNotice", count, name) }
            /// «No se pudieron apuntar todos los pagos. Revisa cada grupo.»
            static var settleFailed: String { s("settle.failed") }
            /// «Total gastado juntos»
            static var statsTotalTogether: String { s("stats.totalTogether") }
            /// «Por grupo»
            static var statsByGroup: String { s("stats.byGroup") }
            /// «te debe S/ 110.00»
            static func statsTheyOwe(_ amounts: String) -> String { f("stats.theyOwe", amounts) }
            /// «le debes S/ 30.00»
            static func statsYouOwe(_ amounts: String) -> String { f("stats.youOwe", amounts) }
            /// «Abre lo que compartes con esta persona» (pista de VoiceOver de la tarjeta)
            static var openHint: String { s("openHint") }
        }

        // MARK: Lote 3 · invitar a una persona y entrar sin grupo

        /// «¿Con quién?» (el selector de Nuevo gasto, Voz, Foto e Yala IA)
        static var whoTitle: String { s("who.title") }
        /// «Persona» (debajo del nombre de una persona en «¿Con quién?»)
        static var personSubtitle: String { s("who.personSubtitle") }
        /// «Escribir un nombre»
        static var writeName: String { s("who.writeName") }
        /// «Nombre»
        static var namePlaceholder: String { s("who.namePlaceholder") }
        /// «Añadir»
        static var addAction: String { s("who.add") }
        /// «No hace falta que tenga Yala: le puedes mandar la invitación después.»
        static var newPersonHint: String { s("who.hint") }
        /// «Escribe su nombre. Podrás apuntar gastos con esta persona…» (hoja de «Añadir persona»)
        static var addPersonMessage: String { s("addPerson.message") }
        /// «Aún no tienes grupos»
        static var emptyGroupsTitle: String { s("empty.groups.title") }
        /// «Para viajes, la casa o la oficina: todos ven los gastos al día.»
        static var emptyGroupsMessage: String { s("empty.groups.message") }
        /// «Crear grupo»
        static var emptyGroupsAction: String { s("empty.groups.action") }
        /// «Apunta un gasto con alguien»
        static var emptyPeopleTitle: String { s("empty.people.title") }
        /// «Un almuerzo a medias o un taxi…»
        static var emptyPeopleMessage: String { s("empty.people.message") }
        /// «Nuevo gasto»
        static var emptyPeopleAction: String { s("empty.people.action") }
        /// «Marta ya está en Compartido»
        static func addedTitle(_ name: String) -> String { f("added.title", name) }
        /// «Invita a Marta para que vea lo que te debe y apunte gastos contigo…»
        static func addedMessage(_ name: String) -> String { f("added.message", name) }
        /// «Jürgen te invita a Yala para llevar juntos los gastos que comparten…» (texto que viaja con el enlace)
        static func shareMessage(inviter: String) -> String { f("share.message", inviter) }
        /// «Te invitan a Yala para llevar juntos los gastos que comparten…»
        static var shareMessageNoInviter: String { s("share.messageNoInviter") }
        /// «Jürgen te invita a Yala» (tarjeta de quien abre el enlace)
        static func inviteCardTitle(_ inviter: String) -> String { f("invite.cardTitle", inviter) }
        /// «Te invitan a Yala»
        static var inviteCardTitleNoName: String { s("invite.cardTitleNoName") }
        /// «Para seguir juntos los gastos que comparten»
        static var inviteCardSubtitle: String { s("invite.cardSubtitle") }
        /// «Te están invitando a unirte a Yala para seguir tus gastos compartidos aquí.»
        static var inviteMessage: String { s("invite.message") }
        /// «Unirme a Yala»
        static var inviteJoin: String { s("invite.join") }
        /// «Ya estás conectado con Jürgen»
        static func readyTitle(_ inviter: String) -> String { f("invite.readyTitle", inviter) }
        /// «Ya estás en Yala»
        static var readyTitleNoName: String { s("invite.readyTitleNoName") }
        /// «Lo que apunten juntos lo ven los dos, al día.»
        static var readyMessage: String { s("invite.readyMessage") }
        /// «Apúntalo con una persona» (hoja de «Grupo» del + sin grupos)
        static var neededWithPerson: String { s("needed.withPerson") }
        /// «Escribe con quién y Yala lleva la cuenta. Para un viaje o la casa, crea un grupo.»
        static var neededMessage: String { s("needed.message") }

        /// Los nombres de los grupos, separados por « · » como la línea de la tarjeta de grupo.
        static func joinedGroups(_ groups: [String]) -> String { groups.joined(separator: " · ") }
    }
}
