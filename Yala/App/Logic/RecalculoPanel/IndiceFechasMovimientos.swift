//
//  IndiceFechasMovimientos.swift
//  Yala
//
//  Lote 4 de eficiencia (26-nov-2026). Índice por fecha de los movimientos del Panel, armado una vez por recálculo.
//
//  Leer `TransactionItem.date` de SwiftData era el 40 % del recálculo de 7 s con 16.004 movimientos en el iPhone 14, y
//  no porque una lectura sea cara sino porque se repetía: cada presupuesto (dos veces: lo gastado y lo de hoy), cada
//  ciclo de presupuesto de la nota de salud y cada alerta volvían a leer la fecha de los 16 mil para quedarse con los de
//  su intervalo. El índice la lee una vez y contesta «qué movimientos caen en este intervalo» con una búsqueda binaria.
//
//  **Devuelve los movimientos en el orden del arreglo original, no por fecha.** Una suma de `Double` en otro orden
//  puede cambiar en el último bit, y las cifras tienen que salir idénticas. Quien después filtre por el mismo intervalo
//  (`interval.contains`, como `BudgetsViewModel.filterTransactions`) recibe exactamente los mismos elementos y en el
//  mismo orden que si filtrara el arreglo entero.
//
//  El intervalo es CERRADO en los dos extremos, como `DateInterval.contains` (CLAUDE.md, «Cálculos con fechas»).
//

import Foundation

struct IndiceFechasMovimientos<Elemento> {

    private let elementos: [Elemento]
    private let fechas: [Date]
    /// Posiciones de `elementos`, de la fecha más vieja a la más nueva (a igual fecha, por posición).
    private let porFecha: [Int]

    /// Arma el índice leyendo `fecha` una vez por elemento.
    init(_ elementos: [Elemento], fecha: (Elemento) -> Date) {
        self.init(elementos, fechas: elementos.map(fecha))
    }

    /// Con las fechas ya leídas (`fechas[i]` es la de `elementos[i]`). Si no casan en número, el índice queda vacío de
    /// fechas y cada consulta devuelve el arreglo entero: quien filtre después por su intervalo sigue dando lo correcto.
    init(_ elementos: [Elemento], fechas: [Date]) {
        self.elementos = elementos
        guard fechas.count == elementos.count else {
            #if DEBUG
            print("IndiceFechasMovimientos: \(fechas.count) fechas para \(elementos.count) elementos — sin índice")
            #endif
            self.fechas = []
            self.porFecha = []
            return
        }
        self.fechas = fechas
        self.porFecha = fechas.indices.sorted { a, b in
            fechas[a] != fechas[b] ? fechas[a] < fechas[b] : a < b
        }
    }

    /// Arma el índice cediendo el hilo por el camino (lee la fecha de cada `@Model` en tramos).
    @MainActor
    static func armar(
        _ elementos: [Elemento], fecha: (Elemento) -> Date, cesion: CesionDelHilo
    ) async throws -> IndiceFechasMovimientos {
        let fechas = try await cesion.transformar(elementos, fecha)
        try await cesion.cederSiToca()
        return IndiceFechasMovimientos(elementos, fechas: fechas)
    }

    /// Tiene una fecha por elemento. Sin ellas, las consultas devuelven el arreglo entero y `ultimaFecha`, `nil`.
    var tieneIndice: Bool { fechas.count == elementos.count && porFecha.count == elementos.count }

    var count: Int { elementos.count }

    /// Primera posición de `porFecha` cuya fecha no es menor que `fecha` (o mayor, con `estricto`).
    private func cota(_ fecha: Date, estricto: Bool) -> Int {
        var bajo = 0
        var alto = porFecha.count
        while bajo < alto {
            let medio = (bajo + alto) / 2
            let f = fechas[porFecha[medio]]
            if estricto ? f <= fecha : f < fecha {
                bajo = medio + 1
            } else {
                alto = medio
            }
        }
        return bajo
    }

    /// Los elementos con fecha dentro de `intervalo` (extremos incluidos), en el orden del arreglo original.
    func elementos(en intervalo: DateInterval) -> [Elemento] {
        guard tieneIndice else { return elementos }
        let desde = cota(intervalo.start, estricto: false)
        let hasta = cota(intervalo.end, estricto: true)
        guard desde < hasta else { return [] }
        return porFecha[desde..<hasta].sorted().map { elementos[$0] }
    }

    /// Los elementos que caen en ALGUNO de los intervalos, en el orden del arreglo original (sin repetir).
    func elementos(enAlguno intervalos: [DateInterval]) -> [Elemento] {
        guard tieneIndice else { return elementos }
        var posiciones = Set<Int>()
        for intervalo in intervalos {
            let desde = cota(intervalo.start, estricto: false)
            let hasta = cota(intervalo.end, estricto: true)
            if desde < hasta { posiciones.formUnion(porFecha[desde..<hasta]) }
        }
        return posiciones.sorted().map { elementos[$0] }
    }

    /// La fecha más nueva, hasta `limite` (incluido), de un elemento que cumpla `cumple`. Lo mismo que
    /// `elementos.filter { fecha <= limite && cumple($0) }.map(fecha).max()`, sin recorrer los que no hacen falta.
    func ultimaFecha(hasta limite: Date, donde cumple: (Elemento) -> Bool) -> Date? {
        guard tieneIndice else { return nil }
        var posicion = cota(limite, estricto: true)
        while posicion > 0 {
            posicion -= 1
            let indice = porFecha[posicion]
            if cumple(elementos[indice]) { return fechas[indice] }
        }
        return nil
    }
}
