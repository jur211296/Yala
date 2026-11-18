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

        var enPagoProgramado: Bool { pagoID != nil }
    }

    /// Una línea del plan, sin sus montos.
    struct Linea {
        let id: UUID
        let esIngreso: Bool
        let categoriaID: PersistentIdentifier?
        let subcategoriaID: PersistentIdentifier?
        /// Línea de método «pago programado»: lo que le falta son los pagos pendientes de ese pago.
        let pagoID: UUID?
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

    struct OtrosMes {
        let real: Double
        let fechado: Double
        let pendiente: Double
        let falta: Double
        /// Lo real por categoría (`nil` = sin categoría), sin ceros.
        let porCategoria: [(categoria: Category?, importe: Double)]
        var esperado: Double { real + fechado + pendiente + falta }
    }

    struct Lado {
        let lineas: [UUID: LineaMes]
        let grupos: [GrupoMes]
        let otros: OtrosMes
        var real: Double {
            lineas.values.reduce(0) { $0 + $1.real } + grupos.reduce(0) { $0 + $1.sinSubcategoriaReal } + otros.real
        }
        /// Todo lo que el mes suma en este lado: lo real más lo que falta.
        var total: Double {
            lineas.values.reduce(0) { $0 + $1.esperado } + grupos.reduce(0) { $0 + $1.sinSubcategoria } + otros.esperado
        }
        /// Lo que falta en este lado: fechado, pendiente, lo que queda a las líneas y a «otros».
        var resto: Double { total - real }
        /// Lo que falta que no está ya en un pago pendiente ni en un movimiento fechado: lo que el flujo proyectado
        /// reparte entre los días que quedan.
        var faltaRepartible: Double { lineas.values.reduce(0) { $0 + $1.falta } + otros.falta }
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
        let medianaOtros = medianaDeOtros(entrada, dueños: dueños)
        return entrada.meses.map { mes in
            let esPasado = mes < entrada.mesEnCurso
            let esEnCurso = mes == entrada.mesEnCurso
            let proyecta = !esPasado && (!esEnCurso || entrada.quedanDiasEnElMes)
            let movimientos = entrada.movimientos.filter { $0.mes == mes }
            let pendientes = proyecta ? entrada.pendientes.filter { $0.mes == mes } : []
            return Mes(
                inicio: mes, esPasado: esPasado, esEnCurso: esEnCurso,
                ingresos: lado(
                    esIngreso: true, mes: mes, proyecta: proyecta, movimientos: movimientos, pendientes: pendientes,
                    entrada: entrada, dueños: dueños, medianaOtros: 0
                ),
                gastos: lado(
                    esIngreso: false, mes: mes, proyecta: proyecta, movimientos: movimientos, pendientes: pendientes,
                    entrada: entrada, dueños: dueños, medianaOtros: medianaOtros
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
        entrada: Entrada, dueños: Dueños, medianaOtros: Double
    ) -> Lado {
        var porDueño: [Dueño: Suma] = [:]
        var otrosSinPago = 0.0
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
            if dueño == .otros {
                if !mov.enPagoProgramado { otrosSinPago += mov.importe }
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
            let conSub = ids.filter { dueños.esPorSubcategoria($0) && dueños.pagoDe($0) == nil }
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
        let faltaLibres = dueños.libres(esIngreso: esIngreso).reduce(0.0) { $0 + (lineas[$1]?.falta ?? 0) }
        let faltaOtros = proyecta ? max(medianaOtros - otrosSinPago - faltaLibres, 0) : 0
        return Lado(
            lineas: lineas,
            grupos: grupos,
            otros: OtrosMes(
                real: otros.real, fechado: otros.fechado, pendiente: otros.pendiente, falta: faltaOtros,
                porCategoria: otrosPorCategoria.values
                    .filter { abs($0.1) > 0.000_5 }
                    .sorted { $0.1 > $1.1 }
                    .map { (categoria: $0.0, importe: $0.1) }
            )
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
        private var pagos: [UUID: UUID] = [:]

        init(lineas: [Linea]) {
            for linea in lineas {
                let lado = linea.esIngreso
                if let pago = linea.pagoID {
                    if porPago[lado]?[pago] == nil { porPago[lado, default: [:]][pago] = linea.id } else { repetidas.insert(linea.id) }
                    pagos[linea.id] = pago
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
        func pagoDe(_ id: UUID) -> UUID? { pagos[id] }
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
