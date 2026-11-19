//
//  SaludFinancieraDetalleTexto.swift
//  Yala
//
//  Los textos de la hoja de la nota de salud (`saludDetalle.*` en `SaludFinancieraDetalle.strings`, los 16 idiomas),
//  leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.AsistentePagoPlanificado`. Los que
//  ya existían (titulares, pesos de cada parte, «Al 30 de noviembre tendrías») siguen en `Localizable.strings`.
//

import Foundation

extension L10n {
    enum SaludFinancieraDetalle {
        static let tabla = "SaludFinancieraDetalle"

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

        private static func s(_ key: String) -> String { string("saludDetalle.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        // Secciones
        static var seccionAlertas: String { s("section.alerts") }
        static var seccionPresupuestos: String { s("section.budgets") }
        static var seccionPagos: String { s("section.payments") }
        static var seccionRacha: String { s("section.streak") }
        static var seccionSubir: String { s("section.improve") }
        static var seccionComoSeCalcula: String { s("section.howItWorks") }
        static var cargando: String { s("loading") }

        // Alertas
        static var sinAlertasTitulo: String { s("alerts.none.title") }
        static var sinAlertasDetalle: String { s("alerts.none.detail") }
        static func pasadoTitulo(_ nombre: String) -> String { f("alert.overBudget.title", nombre) }
        static var pasadoDetalle: String { s("alert.overBudget.detail") }
        static func alLimiteTitulo(_ nombre: String) -> String { f("alert.atLimit.title", nombre) }
        static func alLimiteDetalle(porcentaje: Int) -> String { f("alert.atLimit.detail", porcentaje) }
        static func llegoAlLimiteTitulo(_ nombre: String) -> String { f("alert.reachedLimit.title", nombre) }
        static func variosAlLimiteTitulo(_ total: Int) -> String { f("alert.atLimitMany.title", total) }
        static func cuentaEnRojoTitulo(_ nombre: String) -> String { f("alert.negativeAccount.title", nombre) }
        static var cuentaEnRojoDetalle: String { s("alert.negativeAccount.detail") }
        static func vencidoTitulo(_ nombre: String) -> String { f("alert.overdue.title", nombre) }
        static var vencidoDetalle: String { s("alert.overdue.detail") }
        static var sinCubrirTitulo: String { s("alert.notCovered.title") }
        static var sinCubrirDetalle: String { s("alert.notCovered.detail") }

        // Presupuestos
        static var presupuestosVacioTitulo: String { s("budgets.empty.title") }
        static var presupuestosVacioDetalle: String { s("budgets.empty.detail") }
        static var presupuestosVacioBoton: String { s("budgets.empty.cta") }
        static func verTodosPresupuestos(_ total: Int) -> String { f("budgets.seeAll", total) }
        static var teQuedan: String { s("budgets.left") }
        static var tePasastePor: String { s("budgets.over") }

        // Pagos
        static func cuando(dias: Int) -> String {
            switch dias {
            case ..<0: s("payments.overdue")
            case 0: s("payments.today")
            case 1: s("payments.tomorrow")
            default: f("payments.inDays", dias)
            }
        }
        static var sinPagosCerca: String { s("payments.none") }
        static var pagosVacioTitulo: String { s("payments.empty.title") }
        static var pagosVacioDetalle: String { s("payments.empty.detail") }
        static var pagosVacioBoton: String { s("payments.empty.cta") }
        static var verTodosPagos: String { s("payments.seeAll") }
        static var cubre: String { s("payments.covered") }
        static var noCubre: String { s("payments.notCovered") }

        // Racha
        static func rachaDias(_ dias: Int) -> String { dias == 1 ? f("streak.days.one", dias) : f("streak.days.other", dias) }
        static var rachaHoy: String { s("streak.today") }
        static var rachaMantener: String { s("streak.keep") }
        static var rachaEmpezar: String { s("streak.start") }
        static var rachaBoton: String { s("streak.cta") }
        static func rachaTira(_ dias: Int) -> String { f("streak.caption", dias) }
        static var diaConRegistro: String { s("streak.dayRecorded") }
        static var diaSinRegistro: String { s("streak.dayEmpty") }

        // Para subir la nota
        static func paso(_ paso: SaludFinancieraDetalleLogica.Paso) -> String {
            switch paso {
            case .crearPresupuesto: s("improve.crearPresupuesto")
            case .registrarHoy: s("improve.registrarHoy")
            case .agregarPagos: s("improve.agregarPagos")
            case .revisarPresupuestos: s("improve.revisarPresupuestos")
            case .revisarRitmo: s("improve.revisarRitmo")
            case .revisarPagos: s("improve.revisarPagos")
            }
        }
        static func pesoDeLaParte(_ parte: String, porcentaje: Int) -> String { f("improve.weight", parte, porcentaje) }
    }
}
