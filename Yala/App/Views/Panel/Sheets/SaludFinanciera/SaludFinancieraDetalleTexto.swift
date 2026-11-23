//
//  SaludFinancieraDetalleTexto.swift
//  Yala
//
//  Los textos de la hoja de la nota de salud (`saludDetalle.*` en `SaludFinancieraDetalle.strings`, los 16 idiomas),
//  leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.AsistentePagoPlanificado`. Los que
//  ya existían (titulares y explicación de «¿Cómo se calcula?») siguen en `Localizable.strings`.
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
        /// Con el «%» pegado a su número: «40 %» no puede partirse en dos líneas.
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
                .replacingOccurrences(of: " %", with: "\u{00A0}%")
        }

        typealias L = SaludFinancieraDetalleLogica

        // MARK: Fechas

        /// «28 de noviembre»: día y mes, con el idioma de la app.
        static func diaYMes(_ date: Foundation.Date) -> String {
            date.formatted(.dateTime.day().month(.wide).locale(LanguageManager.resolved.locale))
        }

        /// «noviembre»: el mes de una fecha.
        static func mes(_ date: Foundation.Date) -> String {
            date.formatted(.dateTime.month(.wide).locale(LanguageManager.resolved.locale))
        }

        // MARK: Secciones y estados

        static var cargando: String { s("loading") }
        static func seccion(_ seccion: L.Seccion) -> String {
            switch seccion {
            case .presupuestos: s("section.budgets")
            case .compromisos: s("section.commitments")
            case .ritmo: s("section.rhythm")
            case .teQueda: L10n.NotaSaludTeQueda.nombre
            }
        }
        static var seccionComoSeCalcula: String { s("section.howItWorks") }
        static func peso(_ porcentaje: Int) -> String { f("section.weight", porcentaje) }
        static func estado(_ estado: L.Estado) -> String {
            switch estado {
            case .bien: s("status.good")
            case .paraRevisar: s("status.review")
            case .sinDatos: s("status.noData")
            }
        }

        // MARK: Cápsulas

        static func motivo(_ motivo: L.MotivoSinNota) -> String {
            switch motivo {
            case .creaUno: s("capsule.createOne")
            case .agregaPagos: s("capsule.addPayments")
            case .registraHoy: s("capsule.recordToday")
            case .sinDatos: s("capsule.noData")
            case .sinIngresos: L10n.NotaSaludTeQueda.capsulaSinIngresos
            }
        }
        static var capsulaPista: String { s("capsule.hint") }

        // MARK: Consejo bajo la nota

        static func consejo(_ consejo: L.Consejo) -> String {
            switch consejo {
            case .noAlcanza(let fin): f("advice.notEnough", diaYMes(fin))
            case .presupuestoPasado(let nombre): f("advice.overBudget", nombre)
            case .variosPasados(let n): f("advice.overMany", n)
            case .pagoVencido(let nombre): f("advice.overdue", nombre)
            case .creaPresupuesto: s("advice.createBudget")
            case .agregaPagos: s("advice.addPayments")
            case .registraMasSeguido: s("advice.rhythm")
            case .todoBien: s("advice.allGood")
            }
        }

        // MARK: Presupuestos

        static func unoDentro(_ nombre: String) -> String { f("budgets.oneWithin", nombre) }
        static func todosDentro(_ n: Int) -> String { f("budgets.allWithin", n) }
        static func todosDentroQueda(_ n: Int, monto: String) -> String { f("budgets.allWithinLeft", n, monto) }
        static func soloPasado(_ nombre: String, monto: String) -> String { f("budgets.onlyOver", nombre, monto) }
        static func pasadoYOtros(_ nombre: String, monto: String, otros: Int) -> String {
            otros == 1 ? f("budgets.overOneOther", nombre, monto) : f("budgets.overOthers", nombre, monto, otros)
        }
        static func variosPasados(_ n: Int) -> String { f("budgets.manyOver", n) }
        static func verTodosPresupuestos(_ total: Int) -> String { f("budgets.seeAll", total) }
        static var teQuedan: String { s("budgets.left") }
        static var tePasastePor: String { s("budgets.over") }
        static func sinPresupuestos(peso: Int) -> String { f("budgets.empty.lead", peso) }
        static var porDondeEmpezar: String { s("budgets.empty.tipTitle") }
        static func sugerencia(_ categoria: String, monto: String) -> String { f("budgets.empty.tip", categoria, monto) }
        static var crearPresupuesto: String { s("budgets.empty.cta") }

        static var paraMejorar: String { s("improve.title") }
        static var nadaQueAjustar: String { s("improve.nothing") }
        static var ajustarTitulo: String { s("improve.adjust.title") }
        static func ajustarDetalle(_ nombre: String, veces: Int, periodos: Int, promedio: String, limite: String)
            -> String { f("improve.adjust.detail", nombre, veces, periodos, promedio, limite) }
        static var ajustarBoton: String { s("improve.adjust.cta") }
        static func recortarTitulo(solo: Bool) -> String { solo ? s("improve.cut.titleAlone") : s("improve.cut.title") }
        static func recortarDetalle(_ nombre: String, lista: String) -> String { f("improve.cut.detail", nombre, lista) }
        static var recortarBoton: String { s("improve.cut.cta") }
        static var iaEtiqueta: String { s("improve.ai.label") }
        static var iaBoton: String { s("improve.ai.cta") }
        /// El resumen de Yala IA con su formato: el modelo escribe negritas en markdown (`**S/ 11,821**`) y la hoja las
        /// pintaba con los asteriscos. Pasa por la misma pieza que Estadísticas › Observaciones.
        static func iaCuerpo(_ tarjeta: L.TarjetaIA) -> AttributedString {
            AIInsightCardComponents.markdownAttributed("\(tarjeta.texto) \(tarjeta.consejo)")
        }
        static var iaSinResumenTitulo: String { s("improve.ai.none.title") }
        static var iaSinResumenDetalle: String { s("improve.ai.none.detail") }
        static var lineaPro: String { s("improve.pro") }
        static var lineaProBoton: String { s("improve.pro.cta") }

        // MARK: Compromisos

        static func compromisosFrase(falta: String, dinero: String) -> String { f("commit.lead", falta, dinero) }
        static func compromisosFraseSoloGastos(falta: String) -> String { f("commit.leadExpensesOnly", falta) }
        static func alcanza(sobra: String) -> String { f("commit.enough", sobra) }
        static func noAlcanza(mesSiguiente: String) -> String { f("commit.notEnough", mesSiguiente) }
        static var teFaltaPagar: String { s("commit.toPay") }
        static var tuDineroHoy: String { s("commit.moneyToday") }
        static func faltarian(_ monto: String) -> String { f("commit.short", monto) }
        /// Lo apuntado a futuro que ya cuenta la diferencia: `monto` en magnitud; `resta` si son gastos (neto negativo).
        static func apuntadoFuturo(_ monto: String, resta: Bool) -> String {
            resta ? f("commit.futureOut", monto) : f("commit.futureIn", monto)
        }
        static func ingreso(_ monto: String, de nombre: String, fecha: Foundation.Date, mas: Int) -> String {
            switch mas {
            case 0: f("commit.income", monto, nombre, diaYMes(fecha))
            case 1: f("commit.incomeMoreOne", monto, nombre, diaYMes(fecha))
            default: f("commit.incomeMoreOther", monto, nombre, diaYMes(fecha), mas)
            }
        }
        static func vencido(_ pago: L.Pago) -> String {
            pago.dias == -1
                ? f("commit.overdueYesterday", pago.nombre)
                : f("commit.overdueDate", pago.nombre, diaYMes(pago.fecha))
        }
        static func cuentaEnNegativo(_ nombre: String) -> String { f("commit.negativeAccount", nombre) }
        static func pendientes(_ n: Int, hasta fin: Foundation.Date) -> String {
            n == 1 ? f("commit.pendingOne", diaYMes(fin)) : f("commit.pendingOther", n, diaYMes(fin))
        }
        static var revisarOMover: String { s("commit.review") }
        static var verTusPagos: String { s("commit.seeAll") }
        static func todoPagado(_ mesActual: Foundation.Date) -> String { f("commit.allPaid", mes(mesActual)) }
        static func proximoPago(_ nombre: String, fecha: Foundation.Date) -> String { f("commit.next", nombre, diaYMes(fecha)) }
        static func sinPagos(dinero: String) -> String { f("commit.empty.lead", dinero) }
        static var sinPagosSinDinero: String { s("commit.empty.leadNoMoney") }
        static var cobrosTitulo: String { s("commit.recurring.title") }
        static func cobros(_ nombres: [String]) -> String {
            let lista = nombres.formatted(.list(type: .and).locale(LanguageManager.resolved.locale))
            return nombres.count == 1 ? f("commit.recurring.one", lista) : f("commit.recurring.other", lista)
        }
        static var cobrosBoton: String { s("commit.recurring.cta") }
        static var agregarPago: String { s("commit.empty.cta") }

        static func cuando(dias: Int) -> String {
            switch dias {
            case ..<0: s("payments.overdue")
            case 0: s("payments.today")
            case 1: s("payments.tomorrow")
            default: f("payments.inDays", dias)
            }
        }

        // MARK: Ritmo

        static func rachaDias(_ dias: Int) -> String { dias == 1 ? f("streak.days.one", dias) : f("streak.days.other", dias) }
        static var rachaHoy: String { s("streak.today") }
        static var rachaMantener: String { s("streak.keep") }
        static var rachaEmpezar: String { s("streak.start") }
        static var rachaBoton: String { s("streak.cta") }
        static func rachaTira(_ dias: Int) -> String { f("streak.caption", dias) }
    }
}
