//
//  FlujoDetalleLineaTexto.swift
//  Yala
//
//  Los textos del detalle de una línea del flujo de caja (`flujoDetalleLinea.*` en `FlujoDetalleLinea.strings`, los 16
//  idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoCambiarLimite`.
//

import Foundation

extension L10n {
    enum FlujoDetalleLinea {
        static let tabla = "FlujoDetalleLinea"

        /// Todas las claves de la tabla (las fija `FlujoDetalleLineaTextosTests`).
        static let claves = [
            "flujoDetalleLinea.limit.expense",
            "flujoDetalleLinea.limit.income",
            "flujoDetalleLinea.change",
            "flujoDetalleLinea.change.a11y.expense",
            "flujoDetalleLinea.change.a11y.income",
            "flujoDetalleLinea.soFar.expense",
            "flujoDetalleLinea.soFar.income",
            "flujoDetalleLinea.ofLimit",
            "flujoDetalleLinea.left.expense",
            "flujoDetalleLinea.left.income",
            "flujoDetalleLinea.exceeded",
            "flujoDetalleLinea.pace",
            "flujoDetalleLinea.pace.over",
            "flujoDetalleLinea.scheduled",
            "flujoDetalleLinea.closed.expense",
            "flujoDetalleLinea.closed.income",
            "flujoDetalleLinea.diff.more",
            "flujoDetalleLinea.diff.less",
            "flujoDetalleLinea.parent.notice",
            "flujoDetalleLinea.month.previous",
            "flujoDetalleLinea.month.next",
            "flujoDetalleLinea.history.title",
            "flujoDetalleLinea.history.real.expense",
            "flujoDetalleLinea.history.real.income",
            "flujoDetalleLinea.history.limit.expense",
            "flujoDetalleLinea.history.limit.income",
            "flujoDetalleLinea.history.summary.expense",
            "flujoDetalleLinea.history.summary.income",
            "flujoDetalleLinea.history.month",
            "flujoDetalleLinea.records.title",
            "flujoDetalleLinea.records.seeInRecords",
            "flujoDetalleLinea.records.empty",
            "flujoDetalleLinea.records.scheduledDay",
            "flujoDetalleLinea.limits.moving",
            "flujoDetalleLinea.how.average",
            "flujoDetalleLinea.how.average.isolated",
            "flujoDetalleLinea.how.lastMonth",
            "flujoDetalleLinea.how.lastMonth.isolated",
            "flujoDetalleLinea.how.trend",
            "flujoDetalleLinea.how.trend.isolated",
            "flujoDetalleLinea.how.fixed",
            "flujoDetalleLinea.how.fixedFrom",
            "flujoDetalleLinea.how.noData",
            "flujoDetalleLinea.tip.isolated",
            "flujoDetalleLinea.tip.hint",
            "flujoDetalleLinea.sel.back",
            "flujoDetalleLinea.records.total",
            "flujoDetalleLinea.calc.methods",
            "flujoDetalleLinea.calc.would",
            "flujoDetalleLinea.calc.isolated",
            "flujoDetalleLinea.calc.noData",
            "flujoDetalleLinea.calc.fixed.field",
            "flujoDetalleLinea.calc.fixed.scope",
            "flujoDetalleLinea.calc.result.expense",
            "flujoDetalleLinea.calc.result.income",
            "flujoDetalleLinea.others.total",
            "flujoDetalleLinea.others.future.note.expense",
            "flujoDetalleLinea.others.future.note.income",
            "flujoDetalleLinea.others.future.empty.expense",
            "flujoDetalleLinea.others.future.empty.income",
            "flujoDetalleLinea.others.consider",
            "flujoDetalleLinea.others.reason.day",
            "flujoDetalleLinea.others.reason.noDay",
            "flujoDetalleLinea.others.isolated",
            "flujoDetalleLinea.others.scheduled",
            "flujoDetalleLinea.others.variable",
            "flujoDetalleLinea.others.add.a11y",
            "flujoDetalleLinea.others.parent",
            "flujoDetalleLinea.others.notConsidered",
        ] + clavesPagosYMoneda

        /// Las claves de los límites con pagos planificados y en otra moneda (encargo del 2026-11-20).
        static let clavesPagosYMoneda: [String] = [
            "flujoDetalleLinea.method.payments",
            "flujoDetalleLinea.method.payments.desc",
            "flujoDetalleLinea.pay.title",
            "flujoDetalleLinea.pay.add",
            "flujoDetalleLinea.pay.remove",
            "flujoDetalleLinea.pay.remove.a11y",
            "flujoDetalleLinea.pay.paused",
            "flujoDetalleLinea.pay.ended",
            "flujoDetalleLinea.pay.notThisMonth",
            "flujoDetalleLinea.pay.variable",
            "flujoDetalleLinea.pay.missing",
            "flujoDetalleLinea.pay.next",
            "flujoDetalleLinea.extra.toggle",
            "flujoDetalleLinea.extra.field",
            "flujoDetalleLinea.calc.sum.one",
            "flujoDetalleLinea.calc.sum.other",
            "flujoDetalleLinea.calc.sumExtra.one",
            "flujoDetalleLinea.calc.sumExtra.other",
            "flujoDetalleLinea.calc.onlyExtra",
            "flujoDetalleLinea.calc.updates",
            "flujoDetalleLinea.calc.empty",
            "flujoDetalleLinea.pick.title",
            "flujoDetalleLinea.pick.search",
            "flujoDetalleLinea.pick.free",
            "flujoDetalleLinea.pick.taken",
            "flujoDetalleLinea.pick.inLine",
            "flujoDetalleLinea.pick.willMove",
            "flujoDetalleLinea.pick.moveNotice",
            "flujoDetalleLinea.pick.footer",
            "flujoDetalleLinea.pick.empty.expense",
            "flujoDetalleLinea.pick.empty.income",
            "flujoDetalleLinea.pick.done",
            "flujoDetalleLinea.row.pay.one",
            "flujoDetalleLinea.row.pay.other",
            "flujoDetalleLinea.row.payExtra.one",
            "flujoDetalleLinea.row.payExtra.other",
            "flujoDetalleLinea.row.a11y.expense",
            "flujoDetalleLinea.row.a11y.income",
            "flujoDetalleLinea.capsule",
            "flujoDetalleLinea.capsule.estimated",
            "flujoDetalleLinea.convert.title",
            "flujoDetalleLinea.convert.limitOf.expense",
            "flujoDetalleLinea.convert.limitOf.income",
            "flujoDetalleLinea.convert.explain",
            "flujoDetalleLinea.convert.closed",
            "flujoDetalleLinea.convert.current.one",
            "flujoDetalleLinea.convert.current.other",
            "flujoDetalleLinea.convert.estimated",
            "flujoDetalleLinea.convert.foot",
            "flujoDetalleLinea.convert.source",
            "flujoDetalleLinea.convert.approx",
            "flujoDetalleLinea.convert.month.a11y",
            "flujoDetalleLinea.notice.deleted.fixed",
            "flujoDetalleLinea.notice.deleted",
            "flujoDetalleLinea.notice.moved.fixed",
            "flujoDetalleLinea.notice.moved",
            "flujoDetalleLinea.notice.unnamed.fixed",
            "flujoDetalleLinea.notice.unnamed",
            "flujoDetalleLinea.fx.exact",
            "flujoDetalleLinea.fx.within",
            "flujoDetalleLinea.how.fixedForeign",
            "flujoDetalleLinea.method.fixedIn",
            "flujoDetalleLinea.summary.one",
            "flujoDetalleLinea.summary.other",
            "flujoDetalleLinea.summary.future.one",
            "flujoDetalleLinea.summary.future.other",
            "flujoDetalleLinea.summary.many",
            "flujoDetalleLinea.summary.many.future",
        ]

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

        private static func s(_ key: String) -> String { string("flujoDetalleLinea.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: AppLocale.current, arguments: args)
        }
        private static func lado(_ esIngreso: Bool) -> String { esIngreso ? "income" : "expense" }

        /// «Límite de noviembre» (gastos) / «Esperado en noviembre» (ingresos).
        static func limite(mes: String, esIngreso: Bool) -> String { f("limit.\(lado(esIngreso))", mes) }
        /// «Cambiar».
        static var cambiar: String { s("change") }
        /// «Cambiar el límite» / «Cambiar el monto esperado», para VoiceOver.
        static func cambiarAccesible(esIngreso: Bool) -> String { s("change.a11y.\(lado(esIngreso))") }
        /// «Llevas» / «Recibiste».
        static func llevas(esIngreso: Bool) -> String { s("soFar.\(lado(esIngreso))") }
        /// «de S/ 900».
        static func deLimite(_ limite: String) -> String { f("ofLimit", limite) }
        /// «Te quedan S/ 300» / «Falta recibir S/ 300».
        static func quedan(_ monto: String, esIngreso: Bool) -> String { f("left.\(lado(esIngreso))", monto) }
        /// «Te pasaste por S/ 120. No se proyecta más.»
        static func excedida(_ monto: String) -> String { f("exceeded", monto) }
        /// «Al ritmo de este mes llegarías a ~S/ 1,100.»
        static func ritmo(_ monto: String) -> String { f("pace", monto) }
        /// «Al ritmo de este mes llegarías a ~S/ 1,100: S/ 200 más que el límite.»
        static func ritmoSePasa(_ monto: String, exceso: String) -> String { f("pace.over", monto, exceso) }
        /// «Ya programado: S/ 150».
        static func programado(_ monto: String) -> String { f("scheduled", monto) }
        /// «Gastaste S/ 820 de S/ 900» / «Recibiste S/ 820 de S/ 900».
        static func cerrado(_ real: String, de limite: String, esIngreso: Bool) -> String {
            f("closed.\(lado(esIngreso))", real, limite)
        }
        /// «S/ 80 menos que el límite» / «S/ 80 más que el límite».
        static func diferencia(_ monto: String, esMas: Bool) -> String { f(esMas ? "diff.more" : "diff.less", monto) }

        /// «Hay S/ 500 en Comida sin subcategoría. Cuentan en el mes, no en esta línea.»
        static func anotadoEnLaMadre(_ monto: String, categoria: String) -> String { f("parent.notice", monto, categoria) }

        /// «Mes anterior» / «Mes siguiente».
        static var mesAnterior: String { s("month.previous") }
        static var mesSiguiente: String { s("month.next") }

        /// «Últimos 6 meses».
        static var seisMesesTitulo: String { s("history.title") }
        /// «Gastado» / «Recibido» y «Límite» / «Esperado», la leyenda.
        static func seisMesesReal(esIngreso: Bool) -> String { s("history.real.\(lado(esIngreso))") }
        static func seisMesesLimite(esIngreso: Bool) -> String { s("history.limit.\(lado(esIngreso))") }
        /// «En 4 de 6 meses gastaste menos que el límite.» / «… recibiste lo esperado o más.»
        static func seisMesesResumen(dentro: Int, de total: Int, esIngreso: Bool) -> String {
            f("history.summary.\(lado(esIngreso))", dentro, total)
        }
        /// «junio: S/ 820 de S/ 900», lo que VoiceOver lee de cada mes.
        static func seisMesesMes(_ mes: String, real: String, limite: String) -> String { f("history.month", mes, real, limite) }

        /// «Registros de noviembre».
        static func registrosTitulo(mes: String) -> String { f("records.title", mes) }
        /// «Ver en Registros».
        static var verEnRegistros: String { s("records.seeInRecords") }
        /// «Sin registros en noviembre.»
        static func sinRegistros(mes: String) -> String { f("records.empty", mes) }
        /// «Programado», la marca de un día de mañana en adelante.
        static var programadoDia: String { s("records.scheduledDay") }

        // MARK: Límites móviles y aislados (19-nov-2026)

        /// «Cada límite se calcula con tus últimos meses, sin los montos aislados…», la nota de crear el plan y de
        /// «Agregar línea».
        static var limitesMoviles: String { s("limits.moving") }
        /// «Promedio de los últimos 6 meses[, sin agosto y octubre por ser montos aislados]. Se actualiza solo cada mes.»
        static func comoPromedio(meses: Int, aislados: String?) -> String {
            aislados.map { f("how.average.isolated", meses, $0) } ?? f("how.average", meses)
        }
        /// «Lo de octubre, el último mes completo…» / «Lo de septiembre: octubre se dejó fuera…».
        static func comoUltimoMes(_ mes: String, aislados: String?) -> String {
            aislados.map { f("how.lastMonth.isolated", mes, $0) } ?? f("how.lastMonth", mes)
        }
        /// «La tendencia de los últimos 6 meses[, sin …]…».
        static func comoTendencia(aislados: String?) -> String {
            aislados.map { f("how.trend.isolated", $0) } ?? s("how.trend")
        }
        /// «Monto fijo: el mismo número cada mes.»
        static var comoFijo: String { s("how.fixed") }
        /// «Monto fijo desde noviembre.»
        static func comoFijoDesde(_ mes: String) -> String { f("how.fixedFrom", mes) }
        /// «Todavía no hay meses con registros para calcularlo.»
        static var comoSinDatos: String { s("how.noData") }

        /// «Aislado: fuera del cálculo», en el tooltip de una barra.
        static var tooltipAislado: String { s("tip.isolated") }
        /// «Mantén presionada una barra… Tócala para ver sus registros.»
        static var tooltipAyuda: String { s("tip.hint") }
        /// «Volver a noviembre».
        static func volverA(_ mes: String) -> String { f("sel.back", mes) }
        /// «Total: S/ 1,600».
        static func totalRegistros(_ monto: String) -> String { f("records.total", monto) }

        // MARK: Cálculo del monto

        /// «Cómo calcularlo».
        static var calculoMetodos: String { s("calc.methods") }
        /// «Con tus registros: S/ 150».
        static func calculoDaria(_ monto: String) -> String { f("calc.would", monto) }
        /// «Sin agosto y octubre (montos aislados)».
        static func calculoSinAislados(_ meses: String) -> String { f("calc.isolated", meses) }
        /// «Sin registros suficientes».
        static var calculoSinDatos: String { s("calc.noData") }
        /// «Monto de cada mes».
        static var calculoCampoFijo: String { s("calc.fixed.field") }
        /// «Qué meses cambian».
        static var calculoAlcance: String { s("calc.fixed.scope") }
        /// «Límite de cada mes» / «Esperado cada mes».
        static func calculoResultado(esIngreso: Bool) -> String { s("calc.result.\(lado(esIngreso))") }

        // MARK: No considerados

        /// «Total en diciembre».
        static func otrosTotal(_ mes: String) -> String { f("others.total", mes) }
        /// «En los meses que vienen, fuera de tu plan solo se cuentan los gastos fijos…».
        static func otrosNotaFutura(esIngreso: Bool) -> String { s("others.future.note.\(lado(esIngreso))") }
        /// «No hay gastos fijos fuera de tu plan…».
        static func otrosFuturoVacio(esIngreso: Bool) -> String { s("others.future.empty.\(lado(esIngreso))") }
        /// «Considerar a futuro».
        static var otrosConsiderar: String { s("others.consider") }
        /// «Se repite cada mes: día 5, en 5 de 6 meses».
        static func otrosRazon(dia: Int?, vistos: Int, de total: Int) -> String {
            dia.map { f("others.reason.day", $0, vistos, total) } ?? f("others.reason.noDay", vistos, total)
        }
        /// «Aislado».
        static var otrosAislado: String { s("others.isolated") }
        /// «Programado: S/ 150».
        static func otrosProgramado(_ monto: String) -> String { f("others.scheduled", monto) }
        /// «Lo variable que falta este mes».
        static var otrosVariable: String { s("others.variable") }
        /// «Agregar Gimnasio al plan», para VoiceOver.
        static func otrosAgregar(_ nombre: String) -> String { f("others.add.a11y", nombre) }
        /// «Anotado en Comida sin subcategoría».
        static func otrosMadre(_ categoria: String) -> String { f("others.parent", categoria) }
        /// «No se cuenta a futuro».
        static var otrosNoConsiderado: String { s("others.notConsidered") }

        // MARK: Pagos planificados y otra moneda (encargo del 2026-11-20)

        /// «Pagos planificados» y su descripción, el método.
        static var metodoPagos: String { s("method.payments") }
        static var metodoPagosDesc: String { s("method.payments.desc") }
        /// «Monto fijo en USD».
        static func metodoFijoEn(_ moneda: String) -> String { f("method.fixedIn", moneda) }
        /// «Pagos de esta línea».
        static var pagosTitulo: String { s("pay.title") }
        static var agregarPago: String { s("pay.add") }
        static var quitarPago: String { s("pay.remove") }
        static func quitarPagoAccesible(_ nombre: String) -> String { f("pay.remove.a11y", nombre) }
        static var pagoPausado: String { s("pay.paused") }
        static func pagoTermino(_ mes: String) -> String { f("pay.ended", mes) }
        static func pagoNoCae(_ mes: String) -> String { f("pay.notThisMonth", mes) }
        static var pagoVariable: String { s("pay.variable") }
        static var pagoNoEsta: String { s("pay.missing") }
        /// «Mensual · próximo: 12 dic.».
        static func pagoProximo(_ frecuencia: String, _ fecha: String) -> String { f("pay.next", frecuencia, fecha) }
        static var extraInterruptor: String { s("extra.toggle") }
        static var extraCampo: String { s("extra.field") }
        /// «Suma de 4 pagos + S/ 30.00 extra.», «Suma de 1 pago.» o «Solo el monto extra: S/ 30.00.».
        static func calculoSumaPagos(_ cuantos: Int, extra: String?) -> String {
            guard cuantos > 0 else { return extra.map { f("calc.onlyExtra", $0) } ?? s("calc.empty") }
            if let extra {
                return cuantos == 1 ? f("calc.sumExtra.one", extra) : f("calc.sumExtra.other", cuantos, extra)
            }
            return cuantos == 1 ? s("calc.sum.one") : f("calc.sum.other", cuantos)
        }
        static var calculoSeActualiza: String { s("calc.updates") }
        static var calculoSinPagos: String { s("calc.empty") }
        static var elegirTitulo: String { s("pick.title") }
        static var elegirBuscar: String { s("pick.search") }
        static var elegirSinLinea: String { s("pick.free") }
        static var elegirEnOtra: String { s("pick.taken") }
        static func elegirEnLinea(_ linea: String) -> String { f("pick.inLine", linea) }
        static var elegirSeMovera: String { s("pick.willMove") }
        static func elegirAvisoMover(_ pago: String, desde linea: String) -> String { f("pick.moveNotice", pago, linea) }
        static var elegirPie: String { s("pick.footer") }
        static func elegirVacio(esIngreso: Bool) -> String { s("pick.empty.\(lado(esIngreso))") }
        static var elegirListo: String { s("pick.done") }
        /// «4 pagos» / «4 pagos + extra», bajo el nombre de la fila.
        static func filaPagos(_ cuantos: Int, conExtra: Bool) -> String {
            switch (cuantos == 1, conExtra) {
            case (true, false): s("row.pay.one")
            case (false, false): f("row.pay.other", cuantos)
            case (true, true): s("row.payExtra.one")
            case (false, true): f("row.payExtra.other", cuantos)
            }
        }
        /// «Renta, límite S/ 1,850.00, 500 USD convertidos», lo que lee VoiceOver de la fila.
        static func filaAccesible(_ nombre: String, limite: String, original: String, esIngreso: Bool) -> String {
            f("row.a11y.\(lado(esIngreso))", nombre, limite, original)
        }
        /// «500 USD · promedio de nov. 3.70» / «500 USD · último tipo de cambio ≈ 3.71».
        static func capsula(_ original: String, mes: String, tasa: String, estimada: Bool) -> String {
            estimada ? f("capsule.estimated", original, tasa) : f("capsule", original, mes, tasa)
        }
        static var convierteTitulo: String { s("convert.title") }
        static func convierteLimiteDe(_ nombre: String, esIngreso: Bool) -> String {
            f("convert.limitOf.\(lado(esIngreso))", nombre)
        }
        static func convierteExplica(_ moneda: String) -> String { f("convert.explain", moneda) }
        static var convierteCerrado: String { s("convert.closed") }
        static func convierteEnCurso(dias: Int) -> String {
            dias == 1 ? s("convert.current.one") : f("convert.current.other", dias)
        }
        static var convierteEstimado: String { s("convert.estimated") }
        static var conviertePie: String { s("convert.foot") }
        static var convierteFuente: String { s("convert.source") }
        static var convierteAproximado: String { s("convert.approx") }
        static func convierteMesAccesible(_ mes: String, estado: String, tasa: String, monto: String) -> String {
            f("convert.month.a11y", mes, estado, tasa, monto)
        }
        /// El aviso de una vez cuando un pago deja la línea.
        static func avisoPagoQuitado(nombre: String, destino: String?, fijoEn: String?) -> String {
            if let destino, !nombre.isEmpty {
                return fijoEn.map { f("notice.moved.fixed", nombre, destino, $0) } ?? f("notice.moved", nombre, destino)
            }
            if nombre.isEmpty {
                return fijoEn.map { f("notice.unnamed.fixed", $0) } ?? s("notice.unnamed")
            }
            return fijoEn.map { f("notice.deleted.fixed", nombre, $0) } ?? f("notice.deleted", nombre)
        }
        /// «Pagaste 500 USD: justo el límite. Los S/ 12 de más son del tipo de cambio del día del pago.»
        static func pagasteJusto(_ pagado: String, diferencia: String) -> String { f("fx.exact", pagado, diferencia) }
        /// «Pagaste 450 USD de 500 USD. Los S/ 12 de más son del tipo de cambio del día del pago.»
        static func pagasteDentro(_ pagado: String, de limite: String, diferencia: String) -> String {
            f("fx.within", pagado, limite, diferencia)
        }
        /// «Monto fijo de 500 USD cada mes. En PEN sube y baja con el tipo de cambio.»
        static func comoFijoEnMoneda(_ original: String, monedaPlan: String) -> String {
            f("how.fixedForeign", original, monedaPlan)
        }
        /// La nota del resumen del mes con los límites convertidos.
        static func resumenConvertidos(cuantos: Int, moneda: String?, mes: String, tasa: String?, futuro: Bool) -> String {
            guard let moneda, let tasa else {
                return futuro ? f("summary.many.future", cuantos) : f("summary.many", cuantos)
            }
            if futuro {
                return cuantos == 1 ? f("summary.future.one", moneda, tasa) : f("summary.future.other", cuantos, moneda, tasa)
            }
            return cuantos == 1 ? f("summary.one", moneda, mes, tasa) : f("summary.other", cuantos, moneda, mes, tasa)
        }

        /// «agosto y octubre», con la conjunción del idioma de la app.
        static func listaDeMeses(_ meses: [Foundation.Date]) -> String? {
            guard !meses.isEmpty else { return nil }
            let nombres = meses.sorted().map {
                $0.formatted(Foundation.Date.FormatStyle().month(.wide).locale(AppLocale.current))
            }
            return nombres.formatted(.list(type: .and).locale(AppLocale.current))
        }
    }
}
