//
//  AsistentePresupuestoLogica.swift
//  Yala
//
//  Las reglas, sin vista, del asistente de «Nuevo presupuesto» (encargo del 17-nov): qué preguntas tocan con lo
//  respondido, cuándo se puede seguir, los topes que se sugieren con lo gastado, el nombre que se propone y lo que pasa
//  al formulario con «Usar formulario». La vista es `AsistentePresupuestoView`; lo respondido vive en
//  `AsistentePresupuestoEstado`.
//

import Foundation

nonisolated enum AsistentePresupuestoLogica {

    enum Paso: String, Hashable, CaseIterable {
        /// ¿Qué gastos cuenta? (Todos mis gastos / Solo algunas categorías).
        case alcance
        /// ¿Cuáles? Solo con «Solo algunas categorías».
        case categorias
        /// ¿Cada cuánto se renueva?
        case periodo
        /// ¿Entre qué fechas? Solo con «Una sola vez».
        case fechas
        /// ¿Cuánto quieres gastar como máximo…?
        case tope
        /// ¿Cómo lo llamamos?
        case nombre
        /// ¿Te avisamos cuando vayas llegando al tope?
        case aviso
        /// ¿Lo creamos así? (el resumen, que crea).
        case resumen
    }

    typealias Alcance = FirstBudgetFlowLogic.Scope
    typealias Aviso = FirstBudgetFlowLogic.Alert

    /// Las preguntas, en orden, con lo respondido.
    static func pasos(alcance: Alcance, periodo: BudgetPeriodType) -> [Paso] {
        var pasos: [Paso] = [.alcance]
        if alcance == .categories { pasos.append(.categorias) }
        pasos.append(.periodo)
        if periodo == .unique { pasos.append(.fechas) }
        pasos += [.tope, .nombre, .aviso, .resumen]
        return pasos
    }

    /// Lo que se ha contestado en cada pregunta, para decidir si «Siguiente» se enciende.
    struct Respuestas: Equatable {
        var alcance: Alcance = .all
        var categoriasElegidas = 0
        var periodo: BudgetPeriodType = .monthly
        var inicio: Date = .now
        var fin: Date = .now
        var tope: Double?
        var nombre: String = ""
    }

    static func puedeSeguir(en paso: Paso, _ r: Respuestas, calendar: Calendar = .current) -> Bool {
        switch paso {
        case .alcance, .periodo, .aviso:
            return true
        case .categorias:
            return r.categoriasElegidas > 0
        case .fechas:
            return rangoValido(inicio: r.inicio, fin: r.fin, calendar: calendar)
        case .tope:
            return FirstBudgetFlowLogic.isValidLimit(r.tope)
        case .nombre:
            return !nombreLimpio(r.nombre).isEmpty
        case .resumen:
            // Todo lo obligatorio, por si algo se vació al volver atrás.
            return FirstBudgetFlowLogic.isValidLimit(r.tope) && !nombreLimpio(r.nombre).isEmpty
                && (r.alcance == .all || r.categoriasElegidas > 0)
                && (r.periodo != .unique
                    || rangoValido(inicio: r.inicio, fin: r.fin, calendar: calendar))
        }
    }

    /// Las fechas de «Una sola vez»: se comparan días, no instantes (la misma regla que
    /// `BudgetEditorView.uniqueRangeIsValid`; aquí sin la vista, que vive en el actor principal).
    static func rangoValido(inicio: Date, fin: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: inicio) <= calendar.startOfDay(for: fin)
    }

    static func nombreLimpio(_ nombre: String) -> String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tope sugerido

    /// Un día dentro del período ANTERIOR al de hoy: con él, `TutorialPlanningMath.budgetSpent(now:)` da lo gastado el
    /// período pasado. «Una sola vez» no tiene anterior.
    static func fechaDelPeriodoAnterior(_ periodo: BudgetPeriodType, ahora: Date = .now,
                                        calendar: Calendar = .current) -> Date? {
        switch periodo {
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: -1, to: ahora)
        case .monthly: return calendar.date(byAdding: .month, value: -1, to: ahora)
        case .yearly: return calendar.date(byAdding: .year, value: -1, to: ahora)
        case .unique: return nil
        }
    }

    /// Redondea hacia arriba a un número fácil: de 10 en 10 hasta 100, de 50 en 50 hasta 1.000, de 100 en 100 hasta
    /// 10.000 y de 1.000 en 1.000 por encima.
    static func redondeado(_ valor: Double) -> Double {
        guard valor > 0, valor.isFinite else { return 0 }
        let paso: Double
        switch valor {
        case ..<100: paso = 10
        case ..<1_000: paso = 50
        case ..<10_000: paso = 100
        default: paso = 1_000
        }
        return (valor / paso).rounded(.up) * paso
    }

    enum Sugerencia: Equatable {
        case igual
        case menos10
        case menos20
    }

    /// Los topes que se ofrecen con lo gastado el período pasado: lo mismo, un 10 % menos y un 20 % menos, redondeados
    /// y sin repetidos. Sin gasto, ninguno (sale la frase del número redondo).
    static func sugerencias(gastadoAnterior: Double) -> [(Sugerencia, Double)] {
        guard gastadoAnterior > 0, gastadoAnterior.isFinite else { return [] }
        var vistos: Set<Double> = []
        var result: [(Sugerencia, Double)] = []
        for (tipo, factor) in [(Sugerencia.igual, 1.0), (.menos10, 0.9), (.menos20, 0.8)] {
            let valor = redondeado(gastadoAnterior * factor)
            guard valor > 0, !vistos.contains(valor) else { continue }
            vistos.insert(valor)
            result.append((tipo, valor))
        }
        return result
    }

    // MARK: - Nombre propuesto

    /// `todos`: «Mis gastos del mes» (de la semana, del año; «Mis gastos» si es una sola vez) para todo; con categorías, la única
    /// elegida o las dos primeras unidas, como Primeros pasos.
    static func nombreSugerido(
        alcance: Alcance,
        periodo: BudgetPeriodType,
        categorias: [String],
        todos: String,
        unidas: (String, String) -> String,
        porDefecto: String
    ) -> String {
        switch alcance {
        case .all:
            return todos
        case .categories:
            return FirstBudgetFlowLogic.suggestedName(
                scope: .categories, categoryNames: categorias, allExpenses: todos, joined: unidas,
                fallback: porDefecto)
        }
    }

    // MARK: - Al formulario

    /// Lo respondido, tal cual lo recibe el formulario. Las subcategorías son las de las categorías elegidas (vacío con
    /// «Todos mis gastos»); el aviso, sus umbrales (vacío = apagado). Un tope o un nombre aún sin contestar no se pasan.
    static func alFormulario(
        _ r: Respuestas,
        subcategorias: [UUID],
        aviso: Aviso,
        calendar: Calendar = .current
    ) -> BudgetEditorPrefill {
        let nombre = nombreLimpio(r.nombre)
        return BudgetEditorPrefill(
            name: nombre,
            limit: FirstBudgetFlowLogic.isValidLimit(r.tope) ? r.tope : nil,
            periodType: r.periodo,
            startDate: calendar.startOfDay(for: r.inicio),
            endDate: calendar.startOfDay(for: r.fin),
            subcategoryIDs: r.alcance == .categories ? subcategorias : [],
            alertThresholds: aviso.thresholds
        )
    }
}
