//
//  FlujoMotorMes.swift
//  Yala
//
//  Un solo motor del mes para el flujo de caja (S1 del replanteo, decisiones de Jürgen del 18-nov-2026, ticket
//  `2026-11-17-flujo-de-caja-replanteo`). Cada mes es lo REAL —con signo, con lo sin categoría, fechado antes de
//  mañana— más LO QUE FALTA: lo fechado por delante, los pagos programados pendientes, lo que le queda a cada línea
//  hasta su límite y, en gastos, «otros» por la mediana de 6 meses. Un movimiento pertenece a un solo dueño (su línea,
//  el «sin subcategoría» de su categoría o «otros»), así que nada se cuenta dos veces.
//
//  Lógica pura sobre importes ya resueltos: de dónde salen (cuentas, divisas, grupos) lo decide quien la llama
//  (`FlujoMotorMesEntrada`). Lo usan el flujo de caja (`CashFlowProjectionCalculator`) y lo que falta del plan en el
//  flujo proyectado del Panel (`ProjectedFlowBuilder.planRemaining`), y por eso «Al 30 tendrías» es la misma cifra en
//  los dos sitios.
//

import Foundation
import SwiftData

enum FlujoMotorMes {

    // MARK: - Entrada

    /// Un movimiento resuelto a la divisa del plan.
    struct Movimiento {
        let mes: Date
        /// Con signo del lado: en un gasto, lo gastado es positivo y una devolución, negativa.
        let importe: Double
        let esIngreso: Bool
        let categoriaID: PersistentIdentifier?
        let subcategoriaID: PersistentIdentifier?
        /// Para el desglose de «otros»: `nil` es «Sin categoría».
        let categoria: Category?
        /// El pago programado al que se enlazó: es de la línea de ese pago, y su pago ya se proyecta aparte, así que no
        /// entra en la mediana de «otros».
        let pagoID: UUID?
        /// Fechado de mañana en adelante: aún no es real, y entra una vez, en lo que falta.
        let esFechado: Bool
        /// Para reconocer lo fijo y lo aislado (`FlujoProyeccionInteligente`): el día del mes, la nota (de ella sale el
        /// comercio) y el nombre de su subcategoría.
        var dia: Int = 1
        var nota: String? = nil
        var subcategoriaNombre: String? = nil
        /// La subcategoría, para nombrar las partidas de «otros» y agregarla al plan desde la hoja.
        var subcategoria: Subcategory? = nil

        /// El comercio canónico de la nota (`MerchantCanonicalizer`), `nil` sin nota. Se calcula al leerlo: solo lo leen
        /// los movimientos de la ventana de la detección y, con un fijo por comercio, los del mes.
        var comercio: String? {
            guard let nota, !nota.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let canonico = MerchantCanonicalizer.canonicalize(nota)
            return canonico.isEmpty ? nil : canonico
        }
        /// El comercio como lo escribió la persona, sin el prefijo del procesador de pago.
        var comercioVisible: String? {
            guard comercio != nil, let nota else { return nil }
            return MerchantCanonicalizer.displayName(for: nota)
        }

        var enPagoProgramado: Bool { pagoID != nil }
    }

    /// Una línea del plan, sin sus montos.
    struct Linea {
        let id: UUID
        let esIngreso: Bool
        let categoriaID: PersistentIdentifier?
        let subcategoriaID: PersistentIdentifier?
        /// Línea de método «Pagos planificados»: recibe los movimientos de sus pagos, y lo que le falta descuenta los
        /// pendientes de todos (encargo del 2026-11-20: uno o varios).
        let pagoIDs: [UUID]

        init(id: UUID, esIngreso: Bool, categoriaID: PersistentIdentifier?, subcategoriaID: PersistentIdentifier?,
             pagoIDs: [UUID]) {
            self.id = id
            self.esIngreso = esIngreso
            self.categoriaID = categoriaID
            self.subcategoriaID = subcategoriaID
            self.pagoIDs = pagoIDs
        }

        /// Una línea con un pago o ninguno, la forma de antes.
        init(id: UUID, esIngreso: Bool, categoriaID: PersistentIdentifier?, subcategoriaID: PersistentIdentifier?,
             pagoID: UUID?) {
            self.init(id: id, esIngreso: esIngreso, categoriaID: categoriaID, subcategoriaID: subcategoriaID,
                      pagoIDs: pagoID.map { [$0] } ?? [])
        }
    }

    /// Un pago programado pendiente en el mes en que se proyecta.
    struct Pendiente {
        let mes: Date
        let pagoID: UUID
        let categoriaID: PersistentIdentifier?
        let subcategoriaID: PersistentIdentifier?
        let esIngreso: Bool
        let importe: Double
    }

    struct Entrada {
        /// Inicio de cada mes del horizonte, en orden.
        let meses: [Date]
        let mesEnCurso: Date
        /// Al mes en curso aún le quedan días por delante (de mañana a fin de mes). El último día del mes no queda
        /// nada por proyectar, como en el flujo proyectado (`ProjectedFlowCalculator.futureDays`).
        let quedanDiasEnElMes: Bool
        let lineas: [Linea]
        /// El límite de una línea en un mes.
        let limite: (UUID, Date) -> Double
        let movimientos: [Movimiento]
        let pendientes: [Pendiente]
        let calendar: Calendar
        /// Los movimientos de los que sale la mediana de «otros» (todo el historial del usuario, sea quien sea quien
        /// llama: así el Panel y el flujo de caja proyectan lo mismo). `nil` = los mismos `movimientos`.
        var historia: [Movimiento]? = nil
        /// Con plan, en los meses que vienen «otros» proyecta solo lo fijo de los dos lados (decisión de Jürgen del
        /// 19-nov-2026, 10:47: «lo único que estoy presupuestando es lo que tiene líneas»). Sin plan (el Panel sin plan),
        /// `false`: se sigue proyectando lo variable por la mediana, o la cifra saldría optimista sin nada que la acote.
        var soloFijosEnMesesFuturos = false
        /// Las partidas fijas que la persona apagó en «Considerar a futuro» (`Fijo.claveEstable`): en los meses que
        /// vienen no se proyectan.
        var excluidosAFuturo: Set<String> = []
    }

    // MARK: - Salida

    struct LineaMes {
        let limite: Double
        let real: Double
        let fechado: Double
        /// Pagos programados pendientes de la línea en el mes.
        let pendiente: Double
        /// Lo que le queda hasta su límite (sin lo fechado ni lo pendiente, que ya cuentan aparte).
        let falta: Double
        /// Lo real y lo fechado pasan del límite: cuenta lo que hay y no proyecta más (P2).
        let excedida: Bool
        /// Lo que la línea suma al mes: real + fechado + pendiente + falta.
        var esperado: Double { real + fechado + pendiente + falta }
    }

    /// Una categoría como agrupador de sus líneas (la subcategoría es el id base; la categoría es su suma).
    struct GrupoMes {
        let categoriaID: PersistentIdentifier
        let esIngreso: Bool
        let lineas: [UUID]
        /// Lo anotado en la categoría madre sin subcategoría cuando sus líneas son por subcategoría: es del grupo, y
        /// descuenta de lo que les falta a sus líneas (hallazgo 10).
        let sinSubcategoriaReal: Double
        let sinSubcategoriaFechado: Double
        let sinSubcategoriaPendiente: Double
        var sinSubcategoria: Double { sinSubcategoriaReal + sinSubcategoriaFechado + sinSubcategoriaPendiente }
    }

    /// Un fijo detectado (`FlujoProyeccionInteligente`) en un mes: lo que ya llevó y lo que le falta.
    struct FijoMes {
        let fijo: FlujoProyeccionInteligente.Fijo
        /// Lo que ya tiene el mes de ese fijo (real o fechado, enlazado a un pago o no).
        let llevado: Double
        /// Pagos programados pendientes del mismo grupo en el mes: ya se proyectan en su día.
        let pendiente: Double
        let falta: Double
        /// Lo que de verdad entró este mes de ese fijo (sin lo fechado ni lo adelantado): «Ya llegó» sale de aquí.
        var cobrado: Double = 0
    }

    /// Lo de «otros» de una subcategoría (o una categoría sin subcategoría, o sin categoría) en un mes: la fila de la hoja
    /// de no considerados. La suma de las partidas más lo que falta de lo variable es lo que «otros» suma al mes.
    struct PartidaOtros {
        let base: FlujoProyeccionInteligente.Clave.Base
        let categoriaID: PersistentIdentifier?
        var categoria: Category?
        var subcategoria: Subcategory?
        var subcategoriaNombre: String?
        /// Lo real del mes (con signo).
        var real = 0.0
        /// Lo fechado por delante y los pagos planificados pendientes.
        var programado = 0.0
        /// Lo que se proyecta por sus fijos (lo que les falta).
        var proyectado = 0.0
        /// Lo real de esta partida que se dejó fuera por aislado (cuenta en el mes, no mueve lo proyectado).
        var aislado = 0.0
        /// Sus fijos en el mes, con lo que llevan y lo que les falta; los apagados en «Considerar a futuro» también, con
        /// lo que les falta en 0.
        var fijos: [FijoMes] = []
        var total: Double { real + programado + proyectado }
    }

    struct OtrosMes {
        let real: Double
        let fechado: Double
        let pendiente: Double
        /// Lo que falta: lo de los fijos más lo variable.
        let falta: Double
        /// Lo real por categoría (`nil` = sin categoría), sin ceros.
        let porCategoria: [(categoria: Category?, importe: Double)]
        /// Cada fijo del lado en el mes (vacío en un mes cerrado y sin historia).
        var fijos: [FijoMes] = []
        /// Lo que falta por lo variable (la mediana sin fijos ni aislados).
        var faltaVariable: Double = 0
        /// Los aislados de este mes (en curso o que viene): cuentan en él, pero no se comen lo que falta de lo variable.
        var aislados: [FlujoProyeccionInteligente.Aislado] = []
        /// Las filas de la hoja, por subcategoría: su suma más `faltaVariable` es `esperado` (una sola fuente para el
        /// total y la lista).
        var partidas: [PartidaOtros] = []
        /// El mes proyecta solo lo fijo (con plan, un mes que viene).
        var soloFijos = false
        /// Las claves de los fijos apagados en «Considerar a futuro» que este mes dejó de proyectar.
        var fijosApagados: [FijoMes] = []
        var faltaFijos: Double { fijos.reduce(0) { $0 + $1.falta } }
        var esperado: Double { real + fechado + pendiente + falta }
    }

    struct Lado {
        let lineas: [UUID: LineaMes]
        let grupos: [GrupoMes]
        let otros: OtrosMes
        /// Lo que se detectó en los registros de este lado: fijos, aislados y lo variable.
        var deteccion: FlujoProyeccionInteligente.Lado = .vacio(esIngreso: false)
        var real: Double {
            lineas.values.reduce(0) { $0 + $1.real } + grupos.reduce(0) { $0 + $1.sinSubcategoriaReal } + otros.real
        }
        /// Todo lo que el mes suma en este lado: lo real más lo que falta.
        var total: Double {
            lineas.values.reduce(0) { $0 + $1.esperado } + grupos.reduce(0) { $0 + $1.sinSubcategoria } + otros.esperado
        }
        /// Lo que falta en este lado: fechado, pendiente, lo que queda a las líneas y a «otros».
        var resto: Double { total - real }
        /// Lo que falta que no está ya en un pago pendiente ni en un movimiento fechado ni es un fijo de un día: lo que
        /// el flujo proyectado reparte entre los días que quedan.
        var faltaRepartible: Double {
            lineas.values.reduce(0) { $0 + $1.falta } + otros.falta - faltaPorDia.values.reduce(0, +)
        }
        /// Lo que les falta a los fijos que llegan una vez al mes, por su día típico: el flujo proyectado lo dibuja ese
        /// día (o mañana, si ya pasó sin llegar).
        var faltaPorDia: [Int: Double] {
            var result: [Int: Double] = [:]
            for item in otros.fijos where item.fijo.unaVezAlMes && item.falta > 0 {
                result[item.fijo.dia, default: 0] += item.falta
            }
            return result
        }
    }

    struct Mes {
        let inicio: Date
        let esPasado: Bool
        let esEnCurso: Bool
        let ingresos: Lado
        let gastos: Lado
    }

    // MARK: - Cálculo

    static func calcular(_ entrada: Entrada) -> [Mes] {
        let dueños = Dueños(lineas: entrada.lineas)
        let deteccion = detectar(entrada, dueños: dueños)
        return entrada.meses.map { mes in
            let esPasado = mes < entrada.mesEnCurso
            let esEnCurso = mes == entrada.mesEnCurso
            let proyecta = !esPasado && (!esEnCurso || entrada.quedanDiasEnElMes)
            let movimientos = entrada.movimientos.filter { $0.mes == mes }
            let pendientes = proyecta ? entrada.pendientes.filter { $0.mes == mes } : []
            let mesAnterior = entrada.calendar.date(byAdding: .month, value: -1, to: mes)
            let anteriores = proyecta ? entrada.movimientos.filter { $0.mes == mesAnterior && $0.esIngreso } : []
            return Mes(
                inicio: mes, esPasado: esPasado, esEnCurso: esEnCurso,
                ingresos: lado(
                    esIngreso: true, mes: mes, proyecta: proyecta, movimientos: movimientos, pendientes: pendientes,
                    entrada: entrada, dueños: dueños, deteccion: deteccion.ingresos, mesAnterior: anteriores
                ),
                gastos: lado(
                    esIngreso: false, mes: mes, proyecta: proyecta, movimientos: movimientos, pendientes: pendientes,
                    entrada: entrada, dueños: dueños, deteccion: deteccion.gastos, mesAnterior: []
                )
            )
        }
    }

    private struct Suma {
        var real = 0.0
        var fechado = 0.0
        var pendiente = 0.0
    }

    private static func lado(
        esIngreso: Bool, mes: Date, proyecta: Bool,
        movimientos: [Movimiento], pendientes: [Pendiente],
        entrada: Entrada, dueños: Dueños, deteccion: FlujoProyeccionInteligente.Lado,
        mesAnterior: [Movimiento]
    ) -> Lado {
        // Con plan, un mes que viene proyecta en «otros» solo lo fijo (de los dos lados), sin lo apagado a futuro.
        let soloFijos = entrada.soloFijosEnMesesFuturos && mes > entrada.mesEnCurso
        let fijosDelMes: [FlujoProyeccionInteligente.Fijo] = soloFijos ? deteccion.fijosAFuturo : deteccion.fijos
        let reconoce: (Movimiento) -> FlujoProyeccionInteligente.Fijo? = { mov in
            soloFijos ? deteccion.fijoAFuturo(de: mov) : deteccion.fijoQueReconoce(mov)
        }
        var partidas: [FlujoProyeccionInteligente.Clave.Base: PartidaOtros] = [:]
        func partida(_ base: FlujoProyeccionInteligente.Clave.Base, categoriaID: PersistentIdentifier?) -> PartidaOtros {
            partidas[base] ?? PartidaOtros(base: base, categoriaID: categoriaID)
        }
        var porDueño: [Dueño: Suma] = [:]
        // Lo que el mes ya tiene de lo variable de «otros»: sin lo enlazado a un pago (se proyecta por su pago), sin lo
        // de un fijo (tiene su cuenta) y sin un aislado (cuenta en el mes, pero no se come lo que falta de lo demás).
        var otrosVariable = 0.0
        var aisladosDelMes: [FlujoProyeccionInteligente.Aislado] = []
        // Lo que el mes ya tiene de cada fijo, con o sin pago y sea de quien sea: un sueldo cobrado por su pago
        // programado ya es el sueldo del mes.
        var llevadoPorFijo: [FlujoProyeccionInteligente.Clave: Double] = [:]
        var cobradoPorFijo: [FlujoProyeccionInteligente.Clave: Double] = [:]
        // Lo apartado como aislado y lo devuelto de su mismo grupo en el mes: la devolución sale con él.
        var aisladoPorGrupo: [FlujoProyeccionInteligente.Clave.Base: Double] = [:]
        var devueltoPorGrupo: [FlujoProyeccionInteligente.Clave.Base: Double] = [:]
        var otrosPorCategoria: [PersistentIdentifier?: (Category?, Double)] = [:]
        for mov in movimientos where mov.esIngreso == esIngreso {
            let dueño = dueños.dueño(
                esIngreso: esIngreso, categoriaID: mov.categoriaID, subcategoriaID: mov.subcategoriaID,
                pagoID: mov.pagoID
            )
            if mov.esFechado {
                porDueño[dueño, default: Suma()].fechado += mov.importe
            } else {
                porDueño[dueño, default: Suma()].real += mov.importe
            }
            if let fijo = reconoce(mov) {
                llevadoPorFijo[fijo.clave, default: 0] += mov.importe
                if !mov.esFechado { cobradoPorFijo[fijo.clave, default: 0] += mov.importe }
            }
            if dueño == .otros {
                let base = FlujoProyeccionInteligente.base(de: mov)
                var fila = partida(base, categoriaID: mov.categoriaID)
                fila.categoria = fila.categoria ?? mov.categoria
                fila.subcategoria = fila.subcategoria ?? mov.subcategoria
                fila.subcategoriaNombre = fila.subcategoriaNombre ?? mov.subcategoriaNombre
                if mov.esFechado { fila.programado += mov.importe } else { fila.real += mov.importe }
                partidas[base] = fila
                if !mov.enPagoProgramado, deteccion.fijo(de: mov) == nil {
                    let grupo = FlujoProyeccionInteligente.base(de: mov)
                    if proyecta, deteccion.esAisladoEnMesProyectado(mov) {
                        aisladosDelMes.append(FlujoProyeccionInteligente.aislado(mov))
                        aisladoPorGrupo[grupo, default: 0] += mov.importe
                        partidas[grupo]?.aislado += mov.importe
                    } else {
                        otrosVariable += mov.importe
                        if mov.importe < 0 { devueltoPorGrupo[grupo, default: 0] -= mov.importe }
                    }
                }
                if !mov.esFechado {
                    let previo = otrosPorCategoria[mov.categoriaID]?.1 ?? 0
                    otrosPorCategoria[mov.categoriaID] = (mov.categoria, previo + mov.importe)
                }
            }
        }
        for pendiente in pendientes where pendiente.esIngreso == esIngreso {
            let dueño = dueños.dueño(
                esIngreso: esIngreso, categoriaID: pendiente.categoriaID,
                subcategoriaID: pendiente.subcategoriaID, pagoID: pendiente.pagoID
            )
            porDueño[dueño, default: Suma()].pendiente += pendiente.importe
            if dueño == .otros {
                let base: FlujoProyeccionInteligente.Clave.Base = pendiente.subcategoriaID.map { .subcategoria($0) }
                    ?? pendiente.categoriaID.map { .categoria($0) } ?? .sinCategoria
                var fila = partida(base, categoriaID: pendiente.categoriaID)
                fila.programado += pendiente.importe
                partidas[base] = fila
            }
        }

        // Lo que le falta a cada línea hasta su límite.
        var lineas: [UUID: LineaMes] = [:]
        for linea in entrada.lineas where linea.esIngreso == esIngreso {
            let suma = porDueño[.linea(linea.id)] ?? Suma()
            let limite = entrada.limite(linea.id, mes)
            let llevado = suma.real + suma.fechado
            // Un mes cerrado no proyecta, y una línea repetida (otra anterior del plan ya es dueña de lo mismo) tampoco:
            // proyectaría dos veces el mismo gasto. Una línea de pago programado sigue la misma cuenta que las demás:
            // sus pagos pendientes ya cuentan, y lo que falta es lo que su límite (con su ajuste) pide de más; si el pago
            // no genera pendientes (de grupo, pausado, sin cuenta), proyecta su límite.
            let falta = proyecta && !dueños.esRepetida(linea.id) ? max(limite - llevado - suma.pendiente, 0) : 0
            lineas[linea.id] = LineaMes(
                limite: limite, real: suma.real, fechado: suma.fechado, pendiente: suma.pendiente, falta: falta,
                excedida: llevado > 0 && llevado >= limite
            )
        }

        // Grupos por categoría y, en los que tienen líneas por subcategoría, lo anotado en la categoría madre
        // descuenta de lo que les falta a esas líneas, en proporción a lo que le falta a cada una.
        var grupos: [GrupoMes] = []
        for (categoriaID, ids) in dueños.lineasPorCategoria(esIngreso: esIngreso) {
            let sinSub = porDueño[.sinSubcategoria(categoriaID)] ?? Suma()
            // Lo ANOTADO (real y fechado): un pago pendiente aún no lo está y se suma aparte, como en «otros».
            let absorbe = sinSub.real + sinSub.fechado
            let conSub = ids.filter { dueños.esPorSubcategoria($0) && dueños.pagoDe($0).isEmpty }
            let faltaTotal = conSub.reduce(0.0) { $0 + (lineas[$1]?.falta ?? 0) }
            if absorbe > 0, faltaTotal > 0 {
                let factor = max(faltaTotal - absorbe, 0) / faltaTotal
                for id in conSub {
                    guard let actual = lineas[id] else { continue }
                    lineas[id] = LineaMes(
                        limite: actual.limite, real: actual.real, fechado: actual.fechado,
                        pendiente: actual.pendiente, falta: actual.falta * factor, excedida: actual.excedida
                    )
                }
            }
            grupos.append(GrupoMes(
                categoriaID: categoriaID, esIngreso: esIngreso, lineas: ids,
                sinSubcategoriaReal: sinSub.real, sinSubcategoriaFechado: sinSub.fechado,
                sinSubcategoriaPendiente: sinSub.pendiente
            ))
        }

        let otros = porDueño[.otros] ?? Suma()
        // Una línea libre (sin categoría ni pago) no recibe nada real: su gasto cae en «otros». Lo que le falta y lo que
        // a «otros» le falta por la mediana son el mismo gasto sin categoría del plan; cuenta el mayor de los dos.
        // Con los fijos detectados vale lo mismo: una línea libre de ingresos «Sueldo» y el sueldo fijo de «otros» son el
        // mismo dinero. La línea absorbe primero lo variable y después, en proporción, lo que les falta a los fijos.
        let faltaLibres = dueños.libres(esIngreso: esIngreso).reduce(0.0) { $0 + (lineas[$1]?.falta ?? 0) }
        // La devolución de un aislado del mes no cuenta como gasto negativo de lo demás.
        for (grupo, devuelto) in devueltoPorGrupo {
            otrosVariable += min(devuelto, aisladoPorGrupo[grupo] ?? 0)
        }
        let variableQueFalta = proyecta && !soloFijos ? max(deteccion.variable - otrosVariable, 0) : 0
        let faltaVariable = max(variableQueFalta - faltaLibres, 0)
        let libresSobrantes = max(faltaLibres - variableQueFalta, 0)
        // Cada fijo: su monto menos lo que el mes ya tiene de él, lo que llegó adelantado a fin del mes anterior y los
        // pagos pendientes de su grupo (de un fijo por comercio, solo uno de monto parecido), nunca negativo. Si ya llegó
        // casi entero (dentro de la tolerancia: un sueldo en dólares a otra tasa), no falta nada: proyectar la
        // diferencia inventaría un ingreso.
        let fijosBrutos: [FijoMes] = proyecta ? fijosDelMes.map { fijo in
            let pendiente = pendientes.filter { pendiente in
                guard pendiente.esIngreso == esIngreso else { return false }
                // Un gasto fijo solo lo cubre un pago planificado de «otros» de su mismo grupo: el pago de una línea ya
                // cuenta en ella (un seguro de 140 en su línea no paga el gimnasio de 150 que vive en «otros»). El
                // emparejamiento por monto parecido de `cubre` se pensó para el sueldo y sigue en ingresos.
                if !esIngreso {
                    let dueño = dueños.dueño(
                        esIngreso: false, categoriaID: pendiente.categoriaID, subcategoriaID: pendiente.subcategoriaID,
                        pagoID: pendiente.pagoID
                    )
                    let base: FlujoProyeccionInteligente.Clave.Base = pendiente.subcategoriaID.map { .subcategoria($0) }
                        ?? pendiente.categoriaID.map { .categoria($0) } ?? .sinCategoria
                    return dueño == .otros && base == fijo.clave.base
                }
                return FlujoProyeccionInteligente.cubre(pendiente, a: fijo)
            }.reduce(0.0) { $0 + $1.importe }
            let llevado = (llevadoPorFijo[fijo.clave] ?? 0)
                + FlujoProyeccionInteligente.adelantado(fijo, enElMesAnterior: mesAnterior, lado: deteccion)
            let yaLlego = FlujoProyeccionInteligente.yaLlego(llevado, de: fijo.monto)
            // Apagado en «Considerar a futuro»: en un mes que viene no se proyecta (sigue en la hoja, con su interruptor).
            let apagado = soloFijos && entrada.excluidosAFuturo.contains(fijo.claveEstable)
            return FijoMes(fijo: fijo, llevado: llevado, pendiente: pendiente,
                           falta: yaLlego || apagado ? 0 : max(fijo.monto - llevado - pendiente, 0),
                           cobrado: cobradoPorFijo[fijo.clave] ?? 0)
        } : []
        let fijosApagados = soloFijos
            ? fijosBrutos.filter { entrada.excluidosAFuturo.contains($0.fijo.claveEstable) } : []
        let faltaFijosBruta = fijosBrutos.reduce(0.0) { $0 + $1.falta }
        let factorFijos = faltaFijosBruta > 0 ? max(faltaFijosBruta - libresSobrantes, 0) / faltaFijosBruta : 0
        let fijos = fijosBrutos.map { item in
            FijoMes(fijo: item.fijo, llevado: item.llevado, pendiente: item.pendiente, falta: item.falta * factorFijos,
                    cobrado: item.cobrado)
        }
        let faltaFijos = fijos.reduce(0.0) { $0 + $1.falta }
        // Cada fijo en su partida: lo que le falta es lo que la partida proyecta.
        for item in fijos {
            let base = item.fijo.clave.base
            var fila = partida(base, categoriaID: item.fijo.categoria?.persistentModelID)
            fila.categoria = fila.categoria ?? item.fijo.categoria
            fila.subcategoria = fila.subcategoria ?? item.fijo.subcategoria
            fila.subcategoriaNombre = fila.subcategoriaNombre ?? item.fijo.subcategoriaNombre
            fila.proyectado += item.falta
            fila.fijos.append(item)
            partidas[base] = fila
        }
        return Lado(
            lineas: lineas,
            grupos: grupos,
            otros: OtrosMes(
                real: otros.real, fechado: otros.fechado, pendiente: otros.pendiente,
                falta: faltaVariable + faltaFijos,
                porCategoria: otrosPorCategoria.values
                    .filter { abs($0.1) > 0.000_5 }
                    .sorted { $0.1 > $1.1 }
                    .map { (categoria: $0.0, importe: $0.1) },
                fijos: fijos,
                faltaVariable: faltaVariable,
                aislados: aisladosDelMes.sorted { $0.importe > $1.importe },
                partidas: partidas.values
                    .filter { abs($0.total) > 0.000_5 || !$0.fijos.isEmpty }
                    .sorted { ($0.total, orden($0.base)) > ($1.total, orden($1.base)) },
                soloFijos: soloFijos,
                fijosApagados: fijosApagados
            ),
            deteccion: deteccion
        )
    }

    /// Un orden estable entre partidas con el mismo total.
    private static func orden(_ base: FlujoProyeccionInteligente.Clave.Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(String(describing: id))"
        case .categoria(let id): return "c\(String(describing: id))"
        case .sinCategoria: return "z"
        }
    }

    // MARK: - Fijos y aislados

    /// Lo detectado en los dos lados sobre los movimientos de «otros» de la historia (sin línea con el plan de hoy).
    static func detectar(_ entrada: Entrada) -> (ingresos: FlujoProyeccionInteligente.Lado,
                                                 gastos: FlujoProyeccionInteligente.Lado) {
        detectar(entrada, dueños: Dueños(lineas: entrada.lineas))
    }

    private static func detectar(_ entrada: Entrada, dueños: Dueños) -> (ingresos: FlujoProyeccionInteligente.Lado,
                                                                        gastos: FlujoProyeccionInteligente.Lado) {
        let historia = entrada.historia ?? entrada.movimientos
        let primerMes = historia.map(\.mes).min()
        let esDeOtros: (Movimiento) -> Bool = { mov in
            dueños.dueño(esIngreso: mov.esIngreso, categoriaID: mov.categoriaID, subcategoriaID: mov.subcategoriaID,
                         pagoID: nil) == .otros
        }
        // Los gastos, de toda la historia, como la mediana desde S1 (el Panel y el flujo de caja proyectan lo mismo). Los
        // ingresos fijos, solo de lo que cuenta para esta cifra (con Saldo, las cuentas que suman): un cobro que cae en
        // una cuenta excluida nunca llega a ese saldo, y proyectarlo inventaría un ingreso.
        return (
            FlujoProyeccionInteligente.detectar(esIngreso: true, historia: entrada.movimientos.filter(esDeOtros),
                                                primerMes: primerMes, mesEnCurso: entrada.mesEnCurso,
                                                calendar: entrada.calendar),
            FlujoProyeccionInteligente.detectar(esIngreso: false, historia: historia.filter(esDeOtros),
                                                primerMes: primerMes, mesEnCurso: entrada.mesEnCurso,
                                                calendar: entrada.calendar)
        )
    }

    // MARK: - «Otros» por la mediana

    /// Mediana de lo que «otros» gastó cada mes en los 6 meses completos anteriores al mes en curso, desde el mes del
    /// primer movimiento: un mes antes de empezar a usar Yala no es un mes sin gastos. Sin los movimientos de pagos
    /// programados, que se proyectan por sus pagos. Un gasto puntual grande no la mueve (hallazgo 10).
    static func medianaDeOtros(_ entrada: Entrada) -> Double {
        medianaDeOtros(entrada, dueños: Dueños(lineas: entrada.lineas))
    }

    private static func medianaDeOtros(_ entrada: Entrada, dueños: Dueños) -> Double {
        let historia = entrada.historia ?? entrada.movimientos
        guard let primerMes = historia.map(\.mes).min() else { return 0 }
        let meses: [Date] = (1...6).compactMap { atras in
            entrada.calendar.date(byAdding: .month, value: -atras, to: entrada.mesEnCurso)
        }.filter { $0 >= primerMes }
        guard !meses.isEmpty else { return 0 }
        var porMes: [Date: Double] = Dictionary(uniqueKeysWithValues: meses.map { ($0, 0) })
        for mov in historia where !mov.esIngreso && !mov.enPagoProgramado && porMes[mov.mes] != nil {
            let dueño = dueños.dueño(
                esIngreso: false, categoriaID: mov.categoriaID, subcategoriaID: mov.subcategoriaID, pagoID: nil
            )
            guard dueño == .otros else { continue }
            porMes[mov.mes, default: 0] += mov.importe
        }
        return max(mediana(Array(porMes.values)), 0)
    }

    static func mediana(_ valores: [Double]) -> Double {
        guard !valores.isEmpty else { return 0 }
        let orden = valores.sorted()
        let medio = orden.count / 2
        return orden.count % 2 == 0 ? (orden[medio - 1] + orden[medio]) / 2 : orden[medio]
    }

    // MARK: - De quién es cada movimiento

    enum Dueño: Hashable {
        case linea(UUID)
        case sinSubcategoria(PersistentIdentifier)
        case otros
    }

    /// Reparte cada movimiento y cada pago pendiente a un solo dueño, por su lado: la línea de su pago programado; la
    /// de su subcategoría; la de su categoría; el «sin subcategoría» de su categoría si sus líneas son por
    /// subcategoría; si no, «otros». Con dos líneas para lo mismo gana la primera del plan (en el orden de
    /// `lineas`: quien llama las pasa por `sortOrder`) y la otra queda «repetida».
    struct Dueños {
        private var porPago: [Bool: [UUID: UUID]] = [:]
        private var repetidas: Set<UUID> = []
        private var sinDueño: [Bool: [UUID]] = [:]
        private var porSubcategoria: [Bool: [PersistentIdentifier: UUID]] = [:]
        private var porCategoria: [Bool: [PersistentIdentifier: UUID]] = [:]
        private var conLineasPorSub: [Bool: Set<PersistentIdentifier>] = [:]
        private var grupos: [Bool: [(PersistentIdentifier, [UUID])]] = [:]
        private var subcategoriaDe: Set<UUID> = []
        private var pagos: [UUID: Set<UUID>] = [:]

        init(lineas: [Linea]) {
            for linea in lineas {
                let lado = linea.esIngreso
                if !linea.pagoIDs.isEmpty {
                    // Cada pago apunta a su línea. Un pago no puede estar en dos (la app lo mueve), pero si llega así
                    // de dos teléfonos gana la primera del plan; una línea que no se queda con ninguno queda repetida.
                    var propios = Set<UUID>()
                    for pago in linea.pagoIDs where porPago[lado]?[pago] == nil {
                        porPago[lado, default: [:]][pago] = linea.id
                        propios.insert(pago)
                    }
                    if propios.isEmpty { repetidas.insert(linea.id) }
                    pagos[linea.id] = propios
                    continue
                }
                if let sub = linea.subcategoriaID {
                    subcategoriaDe.insert(linea.id)
                    if porSubcategoria[lado]?[sub] == nil {
                        porSubcategoria[lado, default: [:]][sub] = linea.id
                    } else {
                        repetidas.insert(linea.id)
                    }
                    if let cat = linea.categoriaID { conLineasPorSub[lado, default: []].insert(cat) }
                } else if let cat = linea.categoriaID {
                    if porCategoria[lado]?[cat] == nil {
                        porCategoria[lado, default: [:]][cat] = linea.id
                    } else {
                        repetidas.insert(linea.id)
                    }
                } else {
                    sinDueño[lado, default: []].append(linea.id)
                }
            }
            // El grupo de una categoría: todas sus líneas del lado, en el orden del plan (las de pago incluidas).
            for linea in lineas {
                guard let cat = linea.categoriaID else { continue }
                var lista = grupos[linea.esIngreso] ?? []
                if let i = lista.firstIndex(where: { $0.0 == cat }) {
                    lista[i].1.append(linea.id)
                } else {
                    lista.append((cat, [linea.id]))
                }
                grupos[linea.esIngreso] = lista
            }
        }

        func dueño(
            esIngreso: Bool, categoriaID: PersistentIdentifier?, subcategoriaID: PersistentIdentifier?, pagoID: UUID?
        ) -> Dueño {
            if let pagoID, let linea = porPago[esIngreso]?[pagoID] { return .linea(linea) }
            if let sub = subcategoriaID, let linea = porSubcategoria[esIngreso]?[sub] { return .linea(linea) }
            guard let cat = categoriaID else { return .otros }
            if let linea = porCategoria[esIngreso]?[cat] { return .linea(linea) }
            if subcategoriaID == nil, conLineasPorSub[esIngreso]?.contains(cat) == true { return .sinSubcategoria(cat) }
            return .otros
        }

        func lineasPorCategoria(esIngreso: Bool) -> [(PersistentIdentifier, [UUID])] { grupos[esIngreso] ?? [] }
        func esPorSubcategoria(_ id: UUID) -> Bool { subcategoriaDe.contains(id) }
        /// Los pagos que esta línea se quedó en el reparto (vacío si no es de pagos).
        func pagoDe(_ id: UUID) -> Set<UUID> { pagos[id] ?? [] }
        func esRepetida(_ id: UUID) -> Bool { repetidas.contains(id) }
        /// Las líneas libres: sin categoría, subcategoría ni pago.
        func libres(esIngreso: Bool) -> [UUID] { sinDueño[esIngreso] ?? [] }
    }

    // MARK: - Lo real de cada línea, mes a mes

    /// Lo que el reparto de dueños da a cada línea en cada mes, con signo: de aquí salen los promedios de su límite
    /// (antes salían de toda su categoría, y una línea por categoría contaba en su promedio lo de sus subcategorías
    /// con línea propia y lo de los pagos con línea).
    static func importesPorLinea(_ movimientos: [Movimiento], lineas: [Linea]) -> [UUID: [Date: Double]] {
        let dueños = Dueños(lineas: lineas)
        var result: [UUID: [Date: Double]] = [:]
        for mov in movimientos {
            guard case .linea(let id) = dueños.dueño(
                esIngreso: mov.esIngreso, categoriaID: mov.categoriaID, subcategoriaID: mov.subcategoriaID,
                pagoID: mov.pagoID
            ) else { continue }
            result[id, default: [:]][mov.mes, default: 0] += mov.importe
        }
        return result
    }
}
