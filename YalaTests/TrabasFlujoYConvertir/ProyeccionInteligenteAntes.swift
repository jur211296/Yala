//
//  ProyeccionInteligenteAntes.swift
//  YalaTests
//
//  Copia CONGELADA de `FlujoProyeccionInteligente` tal como estaba en `origin/2.3` el 27-nov-2026 (a5e93673fc), antes de
//  quitarle la traba de YALA-IOS-15. Es la referencia de la paridad: la detección nueva tiene que dar lo mismo con datos
//  grandes y con casos de borde. Solo comparte con producción los umbrales y `FlujoMotorMes.mediana`. No se mantiene: si
//  la regla de la detección cambia a propósito, esta copia y su paridad se retiran juntas.
//

import Foundation
import SwiftData

@testable import Yala

enum FlujoProyeccionInteligenteAntes {

    /// Los mismos umbrales que producción: la referencia solo congela el algoritmo.
    typealias Umbrales = FlujoProyeccionInteligente.Umbrales

    // MARK: - Salida

    /// De qué es un fijo: su subcategoría, su categoría o, sin categoría, nada; y dentro de eso, el comercio cuando el
    /// grupo entero no se repite pero un comercio sí (un cliente fijo dentro de «Freelance»).
    struct Clave: Hashable {
        enum Base: Hashable {
            case subcategoria(PersistentIdentifier)
            case categoria(PersistentIdentifier)
            case sinCategoria
        }
        let base: Base
        /// El comercio canónico (`MerchantCanonicalizer`), o `nil` si el fijo es del grupo entero.
        let comercio: String?
    }

    struct Fijo {
        let clave: Clave
        let esIngreso: Bool
        /// Lo que suma cada mes (la mediana de los meses en que se repitió).
        let monto: Double
        /// El día del mes en que suele llegar (la mediana de sus días).
        let dia: Int
        /// Llega una vez al mes: se dibuja en su día. Con varias (una quincena), se reparte en el mes.
        let unaVezAlMes: Bool
        /// En cuántos meses de la ventana apareció con un monto parecido, y cuántos mira.
        let mesesVistos: Int
        let mesesVentana: Int
        /// Para nombrarlo: la categoría, el nombre de la subcategoría y el comercio tal como lo escribe la persona.
        let categoria: YalaCategory?
        let subcategoriaNombre: String?
        let comercioVisible: String?
        /// La subcategoría, para la clave estable de «Considerar a futuro» y el + de la hoja.
        var subcategoria: Subcategory? = nil

        /// La clave con que se guarda «Considerar a futuro» (`FlujoFijosAFuturo`): no cambia entre arranques ni al
        /// pasar el almacén a la nube. Lado, subcategoría (su `shortcutID`), categoría (su `syncID` o su nombre) o sin
        /// categoría, y el comercio si el fijo es de uno.
        var claveEstable: String {
            let lado = esIngreso ? "in" : "out"
            let grupo: String
            switch clave.base {
            case .subcategoria:
                grupo = subcategoria.map { "s:\($0.shortcutID.uuidString)" }
                    ?? "s:\(categoria?.name ?? ""):\(subcategoriaNombre ?? "")"
            case .categoria:
                grupo = "c:" + (categoria?.syncID?.uuidString ?? categoria?.name ?? "")
            case .sinCategoria:
                grupo = "n"
            }
            return [lado, grupo, clave.comercio].compactMap { $0 }.joined(separator: "|")
        }
    }

    struct Aislado {
        let mes: Date
        let importe: Double
        let esIngreso: Bool
        let categoria: YalaCategory?
        let subcategoriaNombre: String?
        let comercioVisible: String?
    }

    /// Lo detectado en un lado (ingresos o gastos).
    struct Lado {
        let esIngreso: Bool
        /// Meses completos de historia en la ventana (desde el mes del primer movimiento, como mucho 6).
        let mesesDeHistoria: Int
        /// Hay historia para detectar fijos y aislados (`Umbrales.mesesMinimos`).
        var detecta: Bool { mesesDeHistoria >= Umbrales.mesesMinimos }
        let fijos: [Fijo]
        /// Lo que se proyecta en los meses que vienen con plan (decisión de Jürgen del 19-nov-2026, 10:47): en ingresos,
        /// los mismos fijos; en gastos, los fijos de verdad —una vez al mes, monto parecido, día regular, sin aislados—.
        /// Fuera de las líneas, nada más: ni la mediana ni un promedio de lo no planificado.
        var fijosAFuturo: [Fijo] = []
        /// Los aislados de la ventana: no entran en lo variable.
        let aisladosVentana: [Aislado]
        /// Lo que se proyecta cada mes por lo variable: la mediana mensual sin fijos ni aislados. 0 en ingresos.
        let variable: Double
        /// Lo que mide un mes típico del lado, sin aislados (la mediana de los meses con algo), para reconocer un aislado
        /// en los meses que se proyectan. 0 = no se reconoce ninguno.
        let mesTipico: Double
        /// El mayor importe de cada grupo en la ventana: un movimiento de un mes que se proyecta no es aislado si su
        /// grupo ya tuvo uno de al menos la mitad.
        let mayorPorGrupo: [Clave.Base: Double]

        static func vacio(esIngreso: Bool) -> Lado {
            Lado(esIngreso: esIngreso, mesesDeHistoria: 0, fijos: [], aisladosVentana: [], variable: 0, mesTipico: 0,
                 mayorPorGrupo: [:])
        }

        /// El fijo a futuro de un movimiento: en ingresos, el que lo reconoce (`fijoQueReconoce`); en gastos, el de su
        /// comercio y, si no, el de su grupo exacto (un gasto de otra subcategoría no paga el alquiler).
        func fijoAFuturo(de mov: FlujoMotorMes.Movimiento) -> Fijo? {
            guard mov.esIngreso == esIngreso else { return nil }
            if esIngreso { return fijoQueReconoce(mov) }
            let base = FlujoProyeccionInteligenteAntes.base(de: mov)
            if let comercio = mov.comercio,
               let fijo = fijosAFuturo.first(where: { $0.clave == Clave(base: base, comercio: comercio) }) {
                return fijo
            }
            return fijosAFuturo.first { $0.clave == Clave(base: base, comercio: nil) }
        }

        /// El fijo que reconoce un movimiento como suyo al contar lo que el mes ya cobró: el de su comercio o su grupo
        /// y, si no, uno de la misma categoría (o sin categoría en cualquiera de los dos lados) con un monto parecido. El
        /// sueldo anotado meses en «Sueldo › Empresa» y cobrado este mes en «Sueldo» es el mismo sueldo: contarlo aparte
        /// lo proyectaría otra vez. Reconocer de más solo deja de proyectar un ingreso, que es el lado seguro.
        func fijoQueReconoce(_ mov: FlujoMotorMes.Movimiento) -> Fijo? {
            if let exacto = fijo(de: mov) { return exacto }
            guard mov.esIngreso == esIngreso, mov.importe > 0 else { return nil }
            return fijos.first { fijo in
                let categoriaDelFijo = fijo.categoria?.persistentModelID
                let mismaCategoria = categoriaDelFijo == nil || mov.categoriaID == nil || categoriaDelFijo == mov.categoriaID
                return mismaCategoria && FlujoProyeccionInteligenteAntes.parecido(mov.importe, a: fijo.monto)
            }
        }

        /// El fijo de un movimiento, si tiene: el de su comercio y, si no, el de su grupo.
        func fijo(de mov: FlujoMotorMes.Movimiento) -> Fijo? {
            guard mov.esIngreso == esIngreso else { return nil }
            let base = FlujoProyeccionInteligenteAntes.base(de: mov)
            if fijos.contains(where: { $0.clave.comercio != nil }), let comercio = mov.comercio,
               let fijo = fijos.first(where: { $0.clave == Clave(base: base, comercio: comercio) }) {
                return fijo
            }
            return fijos.first { $0.clave == Clave(base: base, comercio: nil) }
        }

        /// Un movimiento de un mes que se proyecta (el en curso, o uno que viene con un fechado) que no mueve lo variable:
        /// mide al menos `factorAislado` meses típicos y su grupo no tuvo en la ventana uno de la mitad. Cuenta en su
        /// mes, pero no se come lo que falta por gastar de lo demás.
        func esAisladoEnMesProyectado(_ mov: FlujoMotorMes.Movimiento) -> Bool {
            guard detecta, mesTipico > 0, mov.importe > 0, mov.esIngreso == esIngreso, fijo(de: mov) == nil else {
                return false
            }
            guard mov.importe >= Umbrales.factorAislado * mesTipico else { return false }
            let previo = mayorPorGrupo[FlujoProyeccionInteligenteAntes.base(de: mov)] ?? 0
            return previo < Umbrales.repeticion * mov.importe
        }
    }

    // MARK: - Detección

    /// Lo que se detecta en los movimientos de «otros» de un lado. `historia` son los movimientos de «otros» del usuario
    /// (los dos lados; se filtra aquí); los enlazados a un pago programado y los fechados no cuentan, porque se
    /// proyectan aparte. `primerMes` es el del primer movimiento de toda la historia: un mes antes de empezar a usar
    /// Yala no es un mes sin gastos.
    static func detectar(
        esIngreso: Bool,
        historia: [FlujoMotorMes.Movimiento],
        primerMes: Date?,
        mesEnCurso: Date,
        calendar: Calendar
    ) -> Lado {
        guard let primerMes else { return .vacio(esIngreso: esIngreso) }
        // La ventana, del mes más reciente al más antiguo.
        let ventana: [Date] = (1...Umbrales.mesesVentana).compactMap { atras in
            calendar.date(byAdding: .month, value: -atras, to: mesEnCurso)
        }.filter { $0 >= primerMes }
        guard !ventana.isEmpty else { return .vacio(esIngreso: esIngreso) }
        let enVentana = Set(ventana)
        let delLado = historia.filter { $0.esIngreso == esIngreso && !$0.enPagoProgramado && !$0.esFechado }
        let movs = delLado.filter { enVentana.contains($0.mes) }

        var mayorPorGrupo: [Clave.Base: Double] = [:]
        // El mayor importe de cada grupo en cada mes: «se repite» mira los otros meses sin recorrer todo.
        var mayorPorGrupoYMes: [Clave.Base: [Date: Double]] = [:]
        for mov in movs where mov.importe > 0 {
            let grupo = base(de: mov)
            mayorPorGrupo[grupo] = max(mayorPorGrupo[grupo] ?? 0, mov.importe)
            mayorPorGrupoYMes[grupo, default: [:]][mov.mes] = max(mayorPorGrupoYMes[grupo]?[mov.mes] ?? 0, mov.importe)
        }

        // Historia corta: nada fijo ni aislado; lo variable es la mediana de todo, como antes de esta pieza.
        guard ventana.count >= Umbrales.mesesMinimos else {
            let total = totalesPorMes(movs, ventana: ventana)
            return Lado(
                esIngreso: esIngreso, mesesDeHistoria: ventana.count, fijos: [], aisladosVentana: [],
                variable: esIngreso ? 0 : max(FlujoMotorMes.mediana(Array(total.values)), 0), mesTipico: 0,
                mayorPorGrupo: mayorPorGrupo
            )
        }
        let enCurso = delLado.filter { $0.mes == mesEnCurso && $0.importe > 0 }

        // 1. Fijos por grupo (subcategoría, categoría o sin categoría), solo en ingresos: el sueldo o un alquiler que
        // cobras. En gastos lo que se repite ya entra entero en la mediana mensual; partirla por grupos cambiaría cómo se
        // compensan unos gastos con otros dentro del mes, y eso no es lo que se decidió.
        var fijos: [Fijo] = []
        var restantes: [Int] = []
        let porGrupo = Dictionary(grouping: movs.indices, by: { base(de: movs[$0]) })
        for (grupoBase, indices) in porGrupo.sorted(by: { orden($0.key) < orden($1.key) }) {
            guard esIngreso else { restantes += indices; continue }
            let delGrupo = indices.map { movs[$0] }
            if let fijo = fijo(Clave(base: grupoBase, comercio: nil), delGrupo, ventana: ventana, enCurso: enCurso) {
                fijos.append(fijo)
                continue
            }
            // 2. Dentro de un grupo que no se repite entero, un comercio que sí.
            let comercios: [Int: String] = Dictionary(uniqueKeysWithValues: indices.compactMap { i in
                movs[i].comercio.map { (i, $0) }
            })
            let porComercio = Dictionary(grouping: comercios.keys, by: { comercios[$0] ?? "" })
            var conFijo: Set<String> = []
            for (comercio, delComercio) in porComercio.sorted(by: { $0.key < $1.key }) {
                if let fijo = fijo(Clave(base: grupoBase, comercio: comercio), delComercio.map { movs[$0] },
                                   ventana: ventana, enCurso: enCurso) {
                    fijos.append(fijo)
                    conFijo.insert(comercio)
                }
            }
            restantes += indices.filter { i in comercios[i].map { !conFijo.contains($0) } ?? true }
        }

        // 3. Aislados entre lo que no es fijo: de mayor a menor, cada uno contra el mes típico del lado entero (con los
        // fijos) sin él ni los aislados ya apartados. Los totales por mes se llevan al día al apartar uno: cada candidato
        // cuesta lo que los 6 meses, no lo que la ventana entera (corre en el hilo principal, en cada cálculo).
        var fuera: Set<Int> = []
        var totalesSinAislados = totalesPorMes(movs, ventana: ventana)
        let candidatos = restantes.filter { movs[$0].importe > 0 }
            .sorted { (movs[$0].importe, $1) > (movs[$1].importe, $0) }
        for i in candidatos {
            let mov = movs[i]
            var sinEl = totalesSinAislados
            sinEl[mov.mes, default: 0] -= mov.importe
            let tipico = mesTipico(sinEl)
            guard tipico > 0, mov.importe >= Umbrales.factorAislado * tipico else { continue }
            let seRepite = (mayorPorGrupoYMes[base(de: mov)] ?? [:]).contains { mes, mayor in
                mes != mov.mes && mayor >= Umbrales.repeticion * mov.importe
            }
            guard !seRepite else { continue }
            fuera.insert(i)
            totalesSinAislados = sinEl
        }
        // La devolución de un aislado sale con él: si no, el mes de la devolución quedaría en negativo y lo variable
        // proyectaría de más (compra de 6,000 y devolución de 6,000 no son un mes de −6,000).
        var porDevolver: [Clave.Base: Double] = [:]
        for i in fuera { porDevolver[base(de: movs[i]), default: 0] += movs[i].importe }
        for i in restantes where movs[i].importe < 0 && !fuera.contains(i) {
            let grupo = base(de: movs[i])
            guard let resta = porDevolver[grupo], -movs[i].importe <= resta + 0.005 else { continue }
            porDevolver[grupo] = resta + movs[i].importe
            fuera.insert(i)
        }

        let variables = restantes.filter { !fuera.contains($0) }.map { movs[$0] }
        let sinAislados = movs.indices.filter { !fuera.contains($0) }.map { movs[$0] }
        // 4. Gastos fijos a futuro: entre lo que no es aislado, por grupo y, dentro de uno que no lo es, por comercio. Solo
        // lo que llega una vez al mes cerca de su día. No toca lo variable: en el mes en curso y sin plan se sigue
        // proyectando por la mediana, como hasta ahora.
        let fijosAFuturo: [Fijo] = esIngreso ? fijos : gastosFijos(
            variables.filter { $0.importe > 0 }, ventana: ventana, enCurso: enCurso
        )
        var lado = Lado(
            esIngreso: esIngreso,
            mesesDeHistoria: ventana.count,
            fijos: fijos.sorted { ($0.monto, nombreOrden($0)) > ($1.monto, nombreOrden($1)) },
            aisladosVentana: fuera.map { movs[$0] }.filter { $0.importe > 0 }
                .sorted { ($0.importe, $0.mes) > ($1.importe, $1.mes) }
                .map { aislado($0) },
            variable: esIngreso ? 0 : max(FlujoMotorMes.mediana(Array(totalesPorMes(variables, ventana: ventana).values)), 0),
            mesTipico: mesTipico(totalesPorMes(sinAislados, ventana: ventana)),
            mayorPorGrupo: mayorPorGrupo
        )
        lado.fijosAFuturo = fijosAFuturo.sorted { ($0.monto, nombreOrden($0)) > ($1.monto, nombreOrden($1)) }
        return lado
    }

    /// Los gastos fijos de verdad: por grupo y, dentro de un grupo que no lo es, por comercio; con la regla de un fijo
    /// (`fijo(_:_:ventana:enCurso:)`) y además una vez al mes y cerca de su día en todos los meses en que apareció.
    private static func gastosFijos(
        _ movs: [FlujoMotorMes.Movimiento], ventana: [Date], enCurso: [FlujoMotorMes.Movimiento]
    ) -> [Fijo] {
        var result: [Fijo] = []
        let porGrupo = Dictionary(grouping: movs, by: { base(de: $0) })
        for (grupoBase, delGrupo) in porGrupo.sorted(by: { orden($0.key) < orden($1.key) }) {
            if let fijo = fijo(Clave(base: grupoBase, comercio: nil), delGrupo, ventana: ventana, enCurso: enCurso),
               esFijoDeVerdad(fijo, delGrupo) {
                result.append(fijo)
                continue
            }
            let porComercio = Dictionary(grouping: delGrupo.filter { $0.comercio != nil }, by: { $0.comercio ?? "" })
            for (comercio, delComercio) in porComercio.sorted(by: { $0.key < $1.key }) {
                if let fijo = fijo(Clave(base: grupoBase, comercio: comercio), delComercio, ventana: ventana,
                                   enCurso: enCurso),
                   esFijoDeVerdad(fijo, delComercio) {
                    result.append(fijo)
                }
            }
        }
        return result
    }

    /// Un fijo de gasto llega una vez al mes y siempre cerca de su día típico.
    private static func esFijoDeVerdad(_ fijo: Fijo, _ movs: [FlujoMotorMes.Movimiento]) -> Bool {
        guard fijo.unaVezAlMes else { return false }
        let dias = movs.filter { $0.importe > 0 }.map(\.dia)
        guard !dias.isEmpty else { return false }
        return dias.allSatisfy { abs($0 - fijo.dia) <= Umbrales.toleranciaDia }
    }

    // MARK: - Aislados de una línea (por mes)

    /// Los meses aislados de una línea del plan: con al menos `mesesMinimos` meses con algo en la ventana, los que
    /// suman al menos `factorAislado` veces la mediana de esos meses. A nivel de mes y no de movimiento: dos meses
    /// fuertes en la misma línea se «repetirían» entre sí y ninguno saldría (el ejemplo de Jürgen del 19-nov, Fitness con
    /// agosto y octubre). La mediana aguanta menos de la mitad de meses raros, así que nunca se quita la mayoría; con
    /// historia corta no se quita nada.
    static func mesesAislados(_ totales: [Date: Double]) -> Set<Date> {
        let conAlgo = totales.filter { $0.value > 0 }
        guard conAlgo.count >= Umbrales.mesesMinimos else { return [] }
        let tipico = FlujoMotorMes.mediana(Array(conAlgo.values))
        guard tipico > 0 else { return [] }
        return Set(conAlgo.filter { $0.value >= Umbrales.factorAislado * tipico }.keys)
    }

    /// Un fijo de esos movimientos, si se repite: aparece con un monto parecido en al menos 2/3 de los meses de la
    /// ventana (nunca menos de 3) y sigue vivo: el último mes completo o el mes en curso traen uno de monto parecido.
    /// Si el último mes completo trajo menos (otro trabajo, un inquilino que se fue), se proyecta eso: es lo
    /// conservador, y si el nivel nuevo se queda, los meses siguientes lo confirman.
    private static func fijo(
        _ clave: Clave, _ movs: [FlujoMotorMes.Movimiento], ventana: [Date], enCurso: [FlujoMotorMes.Movimiento]
    ) -> Fijo? {
        let porMes = totalesPorMes(movs, ventana: ventana)
        let presentes = ventana.filter { (porMes[$0] ?? 0) > 0 }
        guard !presentes.isEmpty else { return nil }
        let tipico = FlujoMotorMes.mediana(presentes.map { porMes[$0] ?? 0 })
        guard tipico > 0 else { return nil }
        let parecidos = presentes.filter { abs((porMes[$0] ?? 0) - tipico) <= Umbrales.toleranciaMonto * tipico }
        let requeridos = max(Umbrales.mesesFijoMinimos,
                             Int((Umbrales.presenciaMinima * Double(ventana.count)).rounded(.up)))
        guard parecidos.count >= requeridos else { return nil }
        let recientes = Set(ventana.prefix(Umbrales.mesesRecientes))
        let delGrupoEnCurso = enCurso.filter { mov in
            base(de: mov) == clave.base && (clave.comercio == nil || mov.comercio == clave.comercio)
        }.reduce(0.0) { $0 + $1.importe }
        // Un reembolso chico en «Sueldo» no revive un sueldo que ya no llega: el mes en curso tiene que traer un monto
        // parecido (o, si llega en dos partes, al menos la mitad).
        let vivoEnCurso = delGrupoEnCurso >= (1 - Umbrales.toleranciaMonto) * tipico / 2
        let ultimoMes = ventana.first.map { porMes[$0] ?? 0 } ?? 0
        let vivoReciente = parecidos.contains(where: recientes.contains)
            || ultimoMes >= (1 - Umbrales.toleranciaMonto) * tipico / 2
        guard vivoEnCurso || vivoReciente else { return nil }
        let montoTipico = FlujoMotorMes.mediana(parecidos.map { porMes[$0] ?? 0 })
        // Bajó de nivel el último mes completo: se proyecta el nivel nuevo.
        let monto = ultimoMes > 0 && ultimoMes < montoTipico && !parecido(ultimoMes, a: montoTipico)
            ? ultimoMes : montoTipico

        let deMesesParecidos = movs.filter { parecidos.contains($0.mes) && $0.importe > 0 }
        let dias = deMesesParecidos.map { Double($0.dia) }
        let vecesPorMes = parecidos.map { mes in Double(deMesesParecidos.filter { $0.mes == mes }.count) }
        let muestra = deMesesParecidos.first ?? movs.first
        return Fijo(
            clave: clave,
            esIngreso: muestra?.esIngreso ?? false,
            monto: monto,
            dia: min(max(1, Int(FlujoMotorMes.mediana(dias).rounded())), 31),
            unaVezAlMes: FlujoMotorMes.mediana(vecesPorMes) <= 1,
            mesesVistos: parecidos.count,
            mesesVentana: ventana.count,
            categoria: muestra?.categoria,
            subcategoriaNombre: clave.base.esSubcategoria ? muestra?.subcategoriaNombre : nil,
            comercioVisible: clave.comercio == nil ? nil : movs.compactMap(\.comercioVisible).first,
            subcategoria: clave.base.esSubcategoria ? muestra?.subcategoria : nil
        )
    }

    // MARK: - Sin doble conteo con los pagos planificados

    /// Un pago programado pendiente cubre a un fijo si es del mismo grupo (su subcategoría o su categoría) o, de la misma
    /// categoría o sin ella, por un monto parecido (±25 %): el sueldo anotado a mano meses atrás y luego planificado es
    /// el mismo sueldo. De un fijo por comercio, solo uno de monto parecido.
    static func cubre(_ pendiente: FlujoMotorMes.Pendiente, a fijo: Fijo) -> Bool {
        let parecido = abs(pendiente.importe - fijo.monto) <= Umbrales.toleranciaMonto * fijo.monto
        let mismaCategoria: Bool
        let mismoGrupo: Bool
        switch fijo.clave.base {
        case .subcategoria(let id):
            mismoGrupo = pendiente.subcategoriaID == id
            mismaCategoria = mismoGrupo || (pendiente.categoriaID != nil
                && pendiente.categoriaID == fijo.categoria?.persistentModelID)
        case .categoria(let id):
            mismoGrupo = pendiente.subcategoriaID == nil && pendiente.categoriaID == id
            mismaCategoria = pendiente.categoriaID == id
        case .sinCategoria:
            // Un sueldo anotado sin categoría y luego planificado en «Sueldo» es el mismo: cualquiera de monto parecido.
            mismoGrupo = false
            mismaCategoria = true
        }
        if fijo.clave.comercio != nil { return mismaCategoria && parecido }
        return mismoGrupo || (mismaCategoria && parecido)
    }

    // MARK: - Piezas

    /// Un fijo ya llegó en el mes cuando lo que entró alcanza su monto dentro de la tolerancia.
    static func yaLlego(_ recibido: Double, de monto: Double) -> Bool {
        monto > 0 && recibido >= (1 - Umbrales.toleranciaMonto) * monto
    }

    /// Dos montos «parecidos»: dentro del ±25 % del segundo.
    static func parecido(_ importe: Double, a monto: Double) -> Bool {
        monto > 0 && abs(importe - monto) <= Umbrales.toleranciaMonto * monto
    }

    /// Lo que un fijo que suele llegar a primeros de mes trajo adelantado en los últimos días del mes anterior: cuenta
    /// como cobrado en este (si no, el sueldo pagado el 30 por un feriado del 1 se proyectaría otra vez). Una
    /// gratificación pagada a mitad de mes no se toma por un adelanto.
    static func adelantado(_ fijo: Fijo, enElMesAnterior movimientos: [FlujoMotorMes.Movimiento],
                           lado: Lado) -> Double {
        guard fijo.unaVezAlMes, fijo.dia <= Umbrales.diaTempranoHasta else { return 0 }
        let tardios = movimientos.filter { mov in
            mov.dia >= Umbrales.diaTardioDesde && lado.fijoQueReconoce(mov)?.clave == fijo.clave
        }
        let total = tardios.reduce(0.0) { $0 + $1.importe }
        return total > 0 ? min(total, fijo.monto) : 0
    }

    static func base(de mov: FlujoMotorMes.Movimiento) -> Clave.Base {
        if let sub = mov.subcategoriaID { return .subcategoria(sub) }
        if let cat = mov.categoriaID { return .categoria(cat) }
        return .sinCategoria
    }

    /// Suma por mes de la ventana, con los meses sin nada en 0.
    private static func totalesPorMes(_ movs: [FlujoMotorMes.Movimiento], ventana: [Date]) -> [Date: Double] {
        var result = Dictionary(uniqueKeysWithValues: ventana.map { ($0, 0.0) })
        for mov in movs where result[mov.mes] != nil { result[mov.mes, default: 0] += mov.importe }
        return result
    }

    /// Lo que mide un mes con algo: la mediana de los meses de la ventana que no quedaron en cero.
    private static func mesTipico(_ totales: [Date: Double]) -> Double {
        max(FlujoMotorMes.mediana(totales.values.filter { $0 > 0 }), 0)
    }

    static func aislado(_ mov: FlujoMotorMes.Movimiento) -> Aislado {
        Aislado(
            mes: mov.mes, importe: mov.importe, esIngreso: mov.esIngreso, categoria: mov.categoria,
            subcategoriaNombre: mov.subcategoriaNombre, comercioVisible: mov.comercioVisible
        )
    }

    /// Un orden estable entre grupos (por la descripción del id persistente).
    private static func orden(_ base: Clave.Base) -> String {
        switch base {
        case .subcategoria(let id): return "s\(String(describing: id))"
        case .categoria(let id): return "c\(String(describing: id))"
        case .sinCategoria: return "z"
        }
    }

    private static func nombreOrden(_ fijo: Fijo) -> String {
        fijo.comercioVisible ?? fijo.subcategoriaNombre ?? fijo.categoria?.name ?? ""
    }
}

extension FlujoProyeccionInteligenteAntes.Clave.Base {
    var esSubcategoria: Bool {
        if case .subcategoria = self { return true }
        return false
    }
}
