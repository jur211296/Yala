//
//  AsistenteFavoritoTexto.swift
//  Yala
//
//  Los textos propios del asistente de «Nuevo favorito» (`asistenteFavorito.*` en `AsistenteFavorito.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `AsistenteCreacionTexto`. Los del
//  contenedor («Usar formulario», «Paso 2 de 6», descartar) son los compartidos.
//

import Foundation

extension L10n {
    enum AsistenteFavorito {
        static let tabla = "AsistenteFavorito"

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

        private static func s(_ key: String) -> String { string("asistenteFavorito.\(key)") }

        private static func porTipo(_ base: String, _ tipo: TransactionType) -> String {
            switch tipo {
            case .income: return s("\(base).income")
            case .transfer: return s("\(base).transfer")
            default: return s("\(base).expense")
            }
        }

        /// Lo que se crea, encima del progreso: el mismo título que el formulario.
        static var titulo: String { L10n.Favorites.newTitle }
        static var descartarTitulo: String { s("discard.title") }
        static var crear: String { s("create") }
        /// «Crear», a tamaños de accesibilidad: «Crear favorito» puede no caber junto a Atrás en un iPhone SE.
        static var crearCorto: String { s("createShort") }

        static var tipoPregunta: String { s("kind.question") }
        static var tipoDetalle: String { s("kind.detail") }
        static func tipoPista(_ tipo: TransactionType) -> String { porTipo("kind.hint", tipo) }

        static var categoriaPregunta: String { s("category.question") }
        static var categoriaDetalle: String { s("category.detail") }
        static var sinCategoria: String { s("category.none") }
        static var sinCategoriaPista: String { s("category.noneHint") }
        static var otraCategoria: String { s("category.other") }

        static var nombrePregunta: String { s("name.question") }
        static var nombreDetalle: String { s("name.detail") }

        static func montoPregunta(_ tipo: TransactionType) -> String { porTipo("amount.question", tipo) }
        static var montoDetalle: String { s("amount.detail") }

        static func cuentaPregunta(_ tipo: TransactionType) -> String { porTipo("account.question", tipo) }
        static var cuentaDetalle: String { s("account.detail") }
        static var sinCuenta: String { s("account.none") }
        static var sinCuentaPista: String { s("account.noneHint") }

        static var destinoPregunta: String { s("destination.question") }
        static var destinoDetalle: String { s("destination.detail") }

        static var resumenPregunta: String { s("summary.question") }
        static var resumenDetalle: String { s("summary.detail") }
        static var resumenTipo: String { s("summary.kind") }
        static var resumenCategoria: String { s("summary.category") }
        static var resumenNombre: String { s("summary.name") }
        static var resumenMonto: String { s("summary.amount") }
        static var resumenMontoVacio: String { s("summary.amountEmpty") }
        static var resumenCuenta: String { s("summary.account") }
        static var resumenOrigen: String { s("summary.origin") }
        static var resumenDestino: String { s("summary.destination") }
    }
}
