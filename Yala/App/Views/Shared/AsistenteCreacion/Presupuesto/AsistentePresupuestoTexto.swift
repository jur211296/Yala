//
//  AsistentePresupuestoTexto.swift
//  Yala
//
//  Los textos propios del asistente de «Nuevo presupuesto» (`asistentePresupuesto.*` en `AsistentePresupuesto.strings`,
//  los 16 idiomas). Las preguntas y sus opciones vienen de Primeros pasos (`L10n.PrimerosPasos23.Budget`).
//

import Foundation

extension L10n {
    enum AsistentePresupuesto {
        private static func s(_ key: String) -> String { AsistenteCreacionTexto.string("asistentePresupuesto.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        /// Lo que se crea, encima del progreso: el mismo título que el formulario.
        static var titulo: String { NSLocalizedString("budgets.new", comment: "") }
        static var descartarTitulo: String { s("discard.title") }
        static var crear: String { s("create") }
        /// «Crear», a tamaños de accesibilidad: «Crear presupuesto» no cabe en el botón de un iPhone SE.
        static var crearCorto: String { s("createShort") }
        static var resumenPregunta: String { s("summary.question") }
        static var resumenDetalle: String { s("summary.detail") }
        static var resumenCuenta: String { s("summary.counts") }
        static var resumenPeriodo: String { s("summary.period") }
        static var resumenFechas: String { s("summary.dates") }
        static var resumenTope: String { s("summary.limit") }
        static var resumenNombre: String { s("summary.name") }
        static var resumenAviso: String { s("summary.alert") }
        static var sinAvisos: String { s("alert.none") }
        static var sinCategorias: String { s("categories.empty") }

        /// «Mis gastos del mes», de la semana, del año; «Mis gastos» si es una sola vez.
        static func nombreTodos(_ periodo: BudgetPeriodType) -> String {
            switch periodo {
            case .weekly: return s("name.weekly")
            case .monthly: return s("name.monthly")
            case .yearly: return s("name.yearly")
            case .unique: return s("name.once")
            }
        }

        /// «El mes pasado gastaste S/ 480.00 en esto.» Con «Una sola vez» no se dice (no hay período anterior).
        static func gastadoAnterior(_ periodo: BudgetPeriodType, _ monto: String) -> String {
            switch periodo {
            case .weekly: return f("limit.last.weekly", monto)
            case .yearly: return f("limit.last.yearly", monto)
            case .monthly, .unique: return f("limit.last.monthly", monto)
            }
        }

        static func sugerencia(_ tipo: AsistentePresupuestoLogica.Sugerencia) -> String {
            switch tipo {
            case .igual: return s("limit.same")
            case .menos10: return s("limit.less10")
            case .menos20: return s("limit.less20")
            }
        }
    }
}
