//
//  SaludFinancieraDetalleLogica.swift
//  Yala
//
//  La hoja de la nota de salud en tres secciones y en tono de consejero (opción A de Jürgen, 20-nov-2026): la nota, y
//  una sección por cada parte (Presupuestos, Compromisos, Ritmo) que dice cómo va, enseña lo suyo y propone qué hacer.
//  Aquí vive lo que no es pantalla: el estado de cada sección, el texto de cada cápsula, la comparación de tu dinero con
//  tus pagos, la propuesta de límite, el recorte y la tarjeta de IA guardada.
//
//  No hay cálculos nuevos de dinero: lo gastado de un presupuesto es el de Planificación
//  (`BudgetsViewModel.calculateSpending`), «Tu dinero hoy» el del hero del Panel (`PanelMoneyScopeLogic`) y lo que falta
//  pagar lo mismo que cuenta la nota (`FinancialScoreCalculator.pendingOccurrences`). Nunca «Al 30 tendrías»
//  (`MonthEndBalanceLogic`): parte del saldo con tarjetas y suma gasto estimado. La nota no se recalcula: llega del Panel.
//

import Foundation
import SwiftData

enum SaludFinancieraDetalleLogica {

    // MARK: - Piezas

    /// Un presupuesto con su barra.
    struct Presupuesto: Equatable, Identifiable {
        let id: UUID
        let nombre: String
        let icono: String
        /// Color del presupuesto en hex, el de su fila en Planificación.
        let color: String
        let gastado: Double
        let limite: Double
        let moneda: String
        /// Lo gastado en los períodos completos anteriores, del más reciente al más antiguo (hasta 4).
        var historial: [Double] = []
        /// Lo que más pesa dentro del presupuesto en el período en curso, de más a menos (hasta 3).
        var dondeMasPesa: [Recorte] = []

        var porcentaje: Double { limite > 0 ? gastado / limite * 100 : 0 }
        var estado: BudgetCounterStatus { BudgetStatusCounter.classify(spent: gastado, limit: limite) }
        /// Lo que queda (negativo: lo que se pasó), con la regla de «Te quedan / Te pasaste por».
        var restante: Double { BudgetRemainingLogic.remaining(limit: limite, spent: gastado) }
        var sePaso: Bool { estado == .overLimit }
    }

    /// Una subcategoría o categoría con su gasto dentro de un presupuesto.
    struct Recorte: Equatable, Identifiable {
        enum Filtro: Equatable, Hashable {
            case subcategoria(PersistentIdentifier)
            case categoria(PersistentIdentifier)
            /// «Sin categoría»: no se puede filtrar por ella, abre Registros sin filtro de categoría.
            case ninguno
        }
        let nombre: String
        let monto: Double
        let filtro: Filtro
        var id: String { "\(nombre)-\(filtro)" }
    }

    /// Lo que la persona podría poner como límite si se pasa casi siempre.
    struct PropuestaDeLimite: Equatable {
        let vecesPasado: Int
        let periodos: Int
        let promedio: Double
        let limite: Double
    }

    /// Un pago que falta este mes.
    struct Pago: Equatable, Identifiable {
        let id: UUID
        let nombre: String
        let fecha: Date
        /// Días de calendario desde hoy: 0 hoy, 1 mañana, negativo si ya venció.
        let dias: Int
        /// En la moneda del pago.
        let monto: Double
        let moneda: String
        /// En la moneda de la app, con el tipo de cambio de hoy.
        let montoConvertido: Double
        let esAproximado: Bool

        var vencido: Bool { dias < 0 }
    }

    /// Un ingreso planificado que llega antes de fin de mes. Se nombra, no se suma.
    struct IngresoEsperado: Equatable {
        let nombre: String
        let fecha: Date
        let monto: Double
        let moneda: String
    }

    /// «Te falta pagar este mes» frente a «Tu dinero hoy». La marca «≈» de cada cifra sigue el umbral de la app
    /// (`ApproximateMarkThreshold`): lo convertido con una tasa dudosa, en magnitudes, sobre el número que se pinta.
    struct Comparacion: Equatable {
        let dineroHoy: Double
        /// Lo convertido con una tasa que no era la de hoy dentro de «Tu dinero hoy» (magnitud).
        let dineroDudoso: Double
        let faltaPagar: Double
        /// Lo convertido con una tasa dudosa dentro de lo que falta pagar (magnitud).
        let faltaDudosa: Double
        let moneda: String
        /// Lo apuntado con fecha posterior a hoy en las cuentas de «Tu dinero hoy» (con signo: un gasto resta). La cifra
        /// de «Tu dinero hoy» es la del hero y no lo cuenta; la nota sí (`asOf: .distantFuture`, `currency-fx.md`): el
        /// alquiler apuntado hoy para el 25 y enlazado a su pago ya no está en lo pendiente. Sin restarlo aquí, la hoja
        /// decía «Te alcanza» con ese importe de más (ticket `hoja-y-nota-difieren-con-pagos-apuntados-a-futuro`).
        var apuntadoFuturo: Double = 0

        /// Lo que queda tras pagar todo (negativo: lo que falta para cubrirlo). Cuenta lo apuntado a futuro, como la nota.
        var diferencia: Double { dineroHoy + apuntadoFuturo - faltaPagar }
        /// Si la hoja tiene que decir que la diferencia ya cuenta lo apuntado a futuro.
        var cuentaApuntadoFuturo: Bool { !CurrencyFormattingHelper.isShownAsZero(apuntadoFuturo) }
        var dineroEsAproximado: Bool { ApproximateMarkThreshold.marks(approximate: dineroDudoso, total: abs(dineroHoy)) }
        var faltaEsAproximado: Bool { ApproximateMarkThreshold.marks(approximate: faltaDudosa, total: abs(faltaPagar)) }
        /// La diferencia es una resta: su incertidumbre es la de las dos, sobre lo que se pinta (`|diferencia|`).
        var diferenciaEsAproximada: Bool {
            ApproximateMarkThreshold.marks(approximate: dineroDudoso + faltaDudosa, total: abs(diferencia))
        }
        var alcanza: Bool { diferencia >= 0 || CurrencyFormattingHelper.isShownAsZero(diferencia) }
        /// Proporción de cada barra sobre la mayor de las dos (misma escala). Un dinero negativo pinta la barra vacía.
        var barraFalta: Double { escala > 0 ? max(0, faltaPagar) / escala : 0 }
        var barraDinero: Double { escala > 0 ? max(0, dineroHoy) / escala : 0 }
        private var escala: Double { max(max(0, faltaPagar), max(0, dineroHoy)) }
    }

    /// Días seguidos registrando y la tira de los últimos días.
    struct Racha: Equatable {
        /// Días seguidos con algún movimiento, contando desde hoy (o desde ayer si hoy aún no hay).
        let dias: Int
        /// Los últimos `diasEnTira` días, del más antiguo a hoy: `true` si ese día hay movimiento.
        let tira: [Bool]
        let registroHoy: Bool
    }

    /// La tarjeta del resumen con IA de Estadísticas ya guardada (solo Pro). Nunca se pide una nueva.
    struct TarjetaIA: Equatable {
        let texto: String
        let consejo: String
    }

    /// Las secciones, en el orden de las cápsulas. «Lo que te queda» (lote 2 de la nota) no sale en «Solo gastos».
    enum Seccion: String, CaseIterable, Identifiable {
        case presupuestos, compromisos, ritmo, teQueda
        var id: String { rawValue }

        var parte: FinancialScoreDetailKind {
            switch self {
            case .presupuestos: .budget
            case .compromisos: .bills
            case .ritmo: .activity
            case .teQueda: .savings
            }
        }

        var peso: Double {
            switch self {
            case .presupuestos: FinancialScoreCalculator.weightBudget
            case .compromisos: FinancialScoreCalculator.weightCommitments
            case .ritmo: FinancialScoreCalculator.weightRhythm
            case .teQueda: FinancialScoreCalculator.weightSavings
            }
        }

        /// Las que se pintan: sin «Lo que te queda» en «Solo gastos».
        static func visibles(isExpensesOnlyMode: Bool) -> [Seccion] {
            isExpensesOnlyMode ? allCases.filter { $0 != .teQueda } : allCases
        }
    }

    /// La palabra de estado de cada sección.
    enum Estado: Equatable {
        case bien, paraRevisar, sinDatos
    }

    /// Lo que dice una cápsula cuando su parte no tiene número.
    enum MotivoSinNota: Equatable {
        case creaUno
        case agregaPagos
        case registraHoy
        case sinDatos
        /// «Lo que te queda» sin ingresos en el período.
        case sinIngresos
    }

    /// La frase de consejero bajo la nota: qué mueve más la nota este mes.
    enum Consejo: Equatable {
        case noAlcanza(finDeMes: Date)
        case presupuestoPasado(nombre: String)
        case variosPasados(Int)
        case pagoVencido(nombre: String)
        case creaPresupuesto
        case agregaPagos
        case registraMasSeguido
        case todoBien
    }

    // MARK: - Constantes

    /// Los días que pinta la tira de la racha.
    static let diasEnTira = 14
    /// Cuántos presupuestos se enseñan antes de «Ver todos».
    static let maximoPresupuestos = 4
    /// Cuántos pagos pendientes se enseñan antes de «Ver todos».
    static let maximoPagos = 5
    /// Períodos completos que mira la propuesta de límite, y en cuántos tiene que haberse pasado.
    static let periodosDeHistorial = 4
    static let vecesPasadoParaProponer = 3
    /// Cuántas filas de «recorta donde más pesa».
    static let maximoRecortes = 3

    // MARK: - Presupuestos

    /// Primero los que van peor: pasados, al límite, y luego por lo gastado. Empate, por nombre.
    static func ordenar(_ presupuestos: [Presupuesto]) -> [Presupuesto] {
        presupuestos.sorted { a, b in
            let ra = rango(a.estado), rb = rango(b.estado)
            if ra != rb { return ra < rb }
            if a.porcentaje != b.porcentaje { return a.porcentaje > b.porcentaje }
            return a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending
        }
    }

    private static func rango(_ estado: BudgetCounterStatus) -> Int {
        switch estado {
        case .overLimit: 0
        case .reachedLimit: 1
        case .atLimit: 2
        case .onTrack: 3
        }
    }

    /// Si se pasó en al menos 3 de los últimos 4 períodos completos, el promedio de esos 4 y un límite redondeado hacia
    /// arriba. Con menos de 4 períodos de historia no propone nada: no hay base.
    static func propuestaDeLimite(historial: [Double], limite: Double) -> PropuestaDeLimite? {
        let periodos = Array(historial.prefix(periodosDeHistorial))
        guard limite > 0, periodos.count == periodosDeHistorial else { return nil }
        let veces = periodos.filter { $0 > limite && !CurrencyFormattingHelper.isShownAsZero($0 - limite) }.count
        guard veces >= vecesPasadoParaProponer else { return nil }
        let promedio = periodos.reduce(0, +) / Double(periodos.count)
        let propuesto = redondearHaciaArriba(promedio)
        guard propuesto > limite else { return nil }
        return PropuestaDeLimite(vecesPasado: veces, periodos: periodos.count, promedio: promedio, limite: propuesto)
    }

    /// Un monto «redondo»: de 10 en 10 hasta 500, de 50 en 50 hasta 5.000 y de 100 en 100 por encima.
    static func redondearHaciaArriba(_ monto: Double) -> Double {
        guard monto > 0 else { return 0 }
        let paso: Double = monto < 500 ? 10 : (monto < 5_000 ? 50 : 100)
        return (monto / paso).rounded(.up) * paso
    }

    /// Las `maximoRecortes` con más gasto, de más a menos. Sin categoría no se puede filtrar, pero cuenta.
    static func dondeMasPesa(_ recortes: [Recorte]) -> [Recorte] {
        Array(recortes.filter { $0.monto > 0 }.sorted { a, b in
            if a.monto != b.monto { return a.monto > b.monto }
            return a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending
        }.prefix(maximoRecortes))
    }

    static func estadoPresupuestos(_ presupuestos: [Presupuesto]) -> Estado {
        guard !presupuestos.isEmpty else { return .sinDatos }
        return presupuestos.contains { $0.sePaso || $0.estado == .reachedLimit } ? .paraRevisar : .bien
    }

    /// El primero que se pasó: es el que recibe los consejos de «Para mejorar esta parte».
    static func presupuestoAMejorar(_ presupuestos: [Presupuesto]) -> Presupuesto? {
        ordenar(presupuestos).first(where: \.sePaso)
    }

    /// Lo que queda entre todos, solo si se puede sumar (misma moneda) y todos van dentro del límite.
    static func quedaEntreTodos(_ presupuestos: [Presupuesto]) -> (monto: Double, moneda: String)? {
        guard presupuestos.count > 1, let moneda = presupuestos.first?.moneda,
              presupuestos.allSatisfy({ $0.moneda == moneda && !$0.sePaso }) else { return nil }
        return (presupuestos.reduce(0) { $0 + max(0, $1.restante) }, moneda)
    }

    // MARK: - Compromisos

    /// Los pagos que faltan este mes, convertidos y ordenados: los vencidos primero, luego por fecha.
    static func pagosPendientes(
        _ ocurrencias: [(id: UUID, nombre: String, fecha: Date, monto: Double, moneda: String, convertido: Double,
                         aproximado: Bool)],
        now: Date,
        calendar: Calendar
    ) -> [Pago] {
        let hoy = calendar.startOfDay(for: now)
        return ocurrencias.map { o in
            let dias = calendar.dateComponents([.day], from: hoy, to: calendar.startOfDay(for: o.fecha)).day ?? 0
            return Pago(id: o.id, nombre: o.nombre, fecha: o.fecha, dias: dias, monto: abs(o.monto), moneda: o.moneda,
                        montoConvertido: abs(o.convertido), esAproximado: o.aproximado)
        }
        .sorted { a, b in
            if a.fecha != b.fecha { return a.fecha < b.fecha }
            return a.nombre.localizedStandardCompare(b.nombre) == .orderedAscending
        }
    }

    static func comparacion(
        pagos: [Pago], dineroHoy: Double, dineroDudoso: Double = 0, apuntadoFuturo: Double = 0, moneda: String
    ) -> Comparacion {
        Comparacion(
            dineroHoy: dineroHoy,
            dineroDudoso: dineroDudoso,
            faltaPagar: pagos.reduce(0) { $0 + $1.montoConvertido },
            faltaDudosa: pagos.filter(\.esAproximado).reduce(0) { $0 + abs($1.montoConvertido) },
            moneda: moneda,
            apuntadoFuturo: apuntadoFuturo
        )
    }

    static func estadoCompromisos(tienePagos: Bool, pagos: [Pago], comparacion: Comparacion?) -> Estado {
        guard tienePagos else { return .sinDatos }
        if pagos.contains(where: \.vencido) { return .paraRevisar }
        if let comparacion, !comparacion.alcanza { return .paraRevisar }
        return .bien
    }

    // MARK: - Ritmo

    /// La racha a partir de los días con algún movimiento. Si hoy aún no hay, cuenta desde ayer: la racha sigue viva
    /// hasta que termina el día.
    static func racha(diasConMovimiento: Set<Date>, now: Date, calendar: Calendar) -> Racha {
        let hoy = calendar.startOfDay(for: now)
        let dias = Set(diasConMovimiento.map { calendar.startOfDay(for: $0) })
        let registroHoy = dias.contains(hoy)

        var cuenta = 0
        var cursor: Date? = registroHoy ? hoy : calendar.date(byAdding: .day, value: -1, to: hoy)
        while let dia = cursor, dias.contains(dia) {
            cuenta += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: dia)
        }

        let tira: [Bool] = (0..<diasEnTira).reversed().map { atras in
            guard let dia = calendar.date(byAdding: .day, value: -atras, to: hoy) else { return false }
            return dias.contains(dia)
        }
        return Racha(dias: cuenta, tira: tira, registroHoy: registroHoy)
    }

    static func estadoRitmo(score: FinancialScore) -> Estado {
        guard let activity = score.activity else { return .sinDatos }
        return activity >= 70 ? .bien : .paraRevisar
    }

    // MARK: - Lo que te queda

    /// Con 50 o más aún queda algo de lo que entra; por debajo, sale más de lo que entra.
    static func estadoTeQueda(score: FinancialScore) -> Estado {
        guard let savings = score.savings else { return .sinDatos }
        return savings >= 50 ? .bien : .paraRevisar
    }

    // MARK: - Nota

    /// Lo que dice la cápsula de una parte sin número. `nil` si la parte tiene nota.
    static func motivoSinNota(
        _ seccion: Seccion,
        score: FinancialScore,
        presupuestos: [Presupuesto],
        tienePagos: Bool
    ) -> MotivoSinNota? {
        switch seccion {
        case .presupuestos:
            guard score.budget == nil else { return nil }
            // Un presupuesto cuenta desde el período en que se creó: sin nota con presupuestos es que ninguno cubre
            // este período (p. ej. «Mes pasado» con uno creado este mes).
            if presupuestos.isEmpty { return .creaUno }
            return .sinDatos
        case .compromisos:
            guard score.bills == nil else { return nil }
            return tienePagos ? .sinDatos : .agregaPagos
        case .ritmo:
            guard score.activity == nil else { return nil }
            return .registraHoy
        case .teQueda:
            guard score.savings == nil else { return nil }
            return .sinIngresos
        }
    }

    /// La frase bajo la nota, lo que más la mueve primero: no llegar con los pagos, pasarse de un presupuesto, un pago
    /// vencido; después, la parte que falta (la que más pesa primero) y el ritmo bajo. Si nada, que va en orden.
    static func consejo(
        score: FinancialScore,
        presupuestos: [Presupuesto],
        pagos: [Pago],
        comparacion: Comparacion?,
        tienePagos: Bool,
        isExpensesOnlyMode: Bool,
        finDeMes: Date
    ) -> Consejo {
        if !isExpensesOnlyMode, let comparacion, comparacion.faltaPagar > 0, !comparacion.alcanza {
            return .noAlcanza(finDeMes: finDeMes)
        }
        let pasados = ordenar(presupuestos).filter(\.sePaso)
        if pasados.count == 1, let primero = pasados.first { return .presupuestoPasado(nombre: primero.nombre) }
        if pasados.count > 1 { return .variosPasados(pasados.count) }
        if let vencido = pagos.first(where: \.vencido) { return .pagoVencido(nombre: vencido.nombre) }
        if score.budget == nil, presupuestos.isEmpty { return .creaPresupuesto }
        if !tienePagos { return .agregaPagos }
        if let activity = score.activity, activity < 70 { return .registraMasSeguido }
        if score.activity == nil { return .registraMasSeguido }
        return .todoBien
    }

    // MARK: - Tarjeta de IA

    /// La primera tarjeta del resumen guardado que pide atención y trae un consejo. Nada si no hay resumen.
    static func tarjetaIA(_ respuesta: LLMInsightResponse?) -> TarjetaIA? {
        guard let respuesta else { return nil }
        for card in respuesta.cards where card.sentiment == "attention" {
            let consejo = (card.tip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let texto = card.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !consejo.isEmpty, !texto.isEmpty else { continue }
            return TarjetaIA(texto: texto, consejo: consejo)
        }
        return nil
    }

    /// De los resúmenes guardados, el último del mes natural de `now`. Sin ranura de «Este mes» que se pueda leer desde
    /// fuera de Estadísticas, «del mes» es «guardado este mes».
    static func resumenDelMes(
        _ guardados: [(guardado: Date, respuesta: LLMInsightResponse)],
        now: Date,
        calendar: Calendar
    ) -> LLMInsightResponse? {
        guardados
            .filter { calendar.isDate($0.guardado, equalTo: now, toGranularity: .month) && $0.guardado <= now }
            .max { $0.guardado < $1.guardado }?
            .respuesta
    }
}
