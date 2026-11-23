//
//  ComerciosEnComunTexto.swift
//  Yala
//
//  Los textos de «Comercios en común» (`comerciosComun.*` en `ComerciosEnComun.strings`, los 16 idiomas), leídos con
//  el idioma de la app (variante → padre → main → la clave), como `L10n.BandejaChipGrupo`. Y el aviso de una vez.
//

import Foundation

extension L10n {
    enum ComerciosEnComun {
        static let tabla = "ComerciosEnComun"

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

        private static func s(_ key: String) -> String { string("comerciosComun.\(key)") }

        /// «Así suele categorizarse %@ en Yala.»: la línea de «Esto leí» cuando la categoría viene de la lista común.
        static func linea(_ comercio: String) -> String { String(format: s("linea.texto"), comercio) }
        /// «Cambiar»: abre el selector de categoría.
        static var lineaCambiar: String { s("linea.cambiar") }

        /// El aviso de una vez, antes del primer envío.
        static var avisoMensaje: String { s("aviso.mensaje") }
        static var avisoNoAportar: String { s("aviso.noAportar") }

        /// Perfil y su pantalla.
        static var titulo: String { s("titulo") }
        static var aportar: String { s("ajustes.aportar") }
        static var aportarPie: String { s("ajustes.aportarPie") }
        static var queSeEnviaTitulo: String { s("ajustes.queSeEnvia.titulo") }
        static var queSeEnviaNombre: String { s("ajustes.queSeEnvia.nombre") }
        static var queSeEnviaTipo: String { s("ajustes.queSeEnvia.tipo") }
        static var queSeEnviaNunca: String { s("ajustes.queSeEnvia.nunca") }
        static var comoFuncionaTitulo: String { s("ajustes.comoFunciona.titulo") }
        static var comoFuncionaSemana: String { s("ajustes.comoFunciona.semana") }
        static var comoFuncionaVarios: String { s("ajustes.comoFunciona.varios") }
        static var comoFuncionaLocal: String { s("ajustes.comoFunciona.local") }
        static var comoFuncionaManda: String { s("ajustes.comoFunciona.manda") }
    }
}

/// El aviso de una vez: el aviso flotante de siempre (sobrevive a las hojas), con «No aportar».
enum ComerciosEnComunAviso {
    @MainActor
    static func show(onNoAportar: @escaping @MainActor () -> Void) {
        DraftDiscardUndoNotice.show(
            message: L10n.ComerciosEnComun.avisoMensaje,
            systemImage: "person.3.fill",
            undoTitle: L10n.ComerciosEnComun.avisoNoAportar,
            noticeIdentifier: "comercios_comun_aviso",
            undoIdentifier: "comercios_comun_no_aportar",
            onUndo: onNoAportar
        )
    }
}
