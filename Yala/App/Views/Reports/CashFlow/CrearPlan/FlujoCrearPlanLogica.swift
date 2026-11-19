//
//  FlujoCrearPlanLogica.swift
//  Yala
//
//  Crear el plan del flujo de caja (S5 del replanteo, 18-nov-2026; decisiones en el «Paso 0» del encargo
//  `2026-11-18-flujo-crear-plan`):
//  - El detalle llega siempre a la subcategoría. Una sugerencia por categoría se retira si la categoría tiene
//    subcategorías visibles; lo anotado en la madre queda en «Sin subcategoría» del mes y, en los meses que vienen, en
//    «otros» por la mediana (P6). Sin subcategorías visibles, la categoría sí lleva línea: no hay detalle que perder.
//  - La categoría agrupa: cada sección del armado pinta sus líneas bajo su categoría, con la suma de lo elegido.
//  - El límite es un monto fijo sembrado con el promedio (P4): al crear, una línea por promedio pasa a monto fijo con la
//    cifra calculada.
//
//  Lógica pura salvo la lectura de los modelos que recibe.
//

import Foundation
import SwiftData

enum FlujoCrearPlanLogica {

    // MARK: - Solo subcategorías

    /// ¿Una línea de esta categoría se queda en la categoría? Solo si no tiene subcategorías visibles.
    static func categoriaSinSubcategorias(_ categoria: Category) -> Bool {
        (categoria.subcategories ?? []).allSatisfy { !$0.isVisible }
    }

    /// Las sugerencias del armado sin líneas por categoría que perderían el detalle de subcategoría. Un pago planificado
    /// conserva la suya.
    static func porSubcategoria(_ lineas: [SuggestedLine]) -> [SuggestedLine] {
        lineas.filter { linea in
            if linea.scheduledPayment != nil || linea.subcategory != nil { return true }
            guard let categoria = linea.category else { return true }
            return categoriaSinSubcategorias(categoria)
        }
    }

    // MARK: - Agrupado por categoría

    struct Grupo: Identifiable {
        /// La categoría como agrupador; `nil` reúne las líneas sin categoría (pagos sin subcategoría).
        let categoria: Category?
        let lineas: [SuggestedLine]

        var id: String {
            categoria.map { "\(ObjectIdentifier($0).hashValue)" } ?? "sin-categoria"
        }

        /// Lo elegido del grupo, sumado: la categoría es la suma de sus subcategorías.
        var totalElegido: Double {
            lineas.filter(\.isSelected).reduce(0) { $0 + $1.suggestedAmount }
        }

        var elegidas: Int { lineas.filter(\.isSelected).count }

        /// Va a la vista si alguna de sus líneas se repite cada mes (L18-5); si no, a «Gastos que cambian».
        var seRepite: Bool { lineas.contains(where: \.isRecurring) }
    }

    /// Agrupa por categoría conservando el orden de las líneas: un grupo sale donde aparece su primera línea, y dentro
    /// del grupo las líneas mantienen su orden (de mayor a menor monto, el del armado).
    static func agrupar(_ lineas: [SuggestedLine]) -> [Grupo] {
        var orden: [ObjectIdentifier?] = []
        var porClave: [ObjectIdentifier?: [SuggestedLine]] = [:]
        var categorias: [ObjectIdentifier: Category] = [:]
        for linea in lineas {
            let categoria = linea.category ?? linea.subcategory?.category
            let clave = categoria.map(ObjectIdentifier.init)
            if let categoria, let clave { categorias[clave] = categoria }
            if porClave[clave] == nil { orden.append(clave) }
            porClave[clave, default: []].append(linea)
        }
        return orden.map { clave in
            Grupo(categoria: clave.flatMap { categorias[$0] }, lineas: porClave[clave] ?? [])
        }
    }

    // MARK: - Límite fijo (P4)

    /// Los métodos que se mueven solos cada mes. Al crear, se siembran como monto fijo.
    static func esMetodoQueSeMueve(_ metodo: EstimationMethod) -> Bool {
        switch metodo {
        case .average3m, .average6m, .average12m, .lastMonth, .trend: return true
        default: return false
        }
    }

    /// Las sugerencias listas para guardar: lo calculado por promedio pasa a monto fijo con su cifra.
    static func conLimiteFijo(_ lineas: [SuggestedLine]) -> [SuggestedLine] {
        lineas.map { linea in
            guard esMetodoQueSeMueve(linea.estimationMethod) else { return linea }
            var fija = linea
            fija.estimationMethod = .manual
            return fija
        }
    }

    // MARK: - Agregar línea › Desde mis gastos

    /// Lo que entra en el cálculo del plan: con categoría, sin ajustes de saldo y sin subcategorías de sistema (el mismo
    /// filtro que el armado, `CashFlowPlanViewModel.generateSuggestions`).
    static func movimientosDelPlan(_ movimientos: [TransactionItem]) -> [TransactionItem] {
        movimientos.filter {
            $0.category != nil
                && $0.balanceAdjustmentType == nil
                && $0.subcategory?.isAnySystem != true
        }
    }

    /// El monto con que nace una línea nueva: el del método elegido, como lo calcula el motor (meses completos
    /// anteriores al mes en curso, con signo). Sin categoría ni subcategoría, 0.
    @MainActor
    static func semilla(
        metodo: EstimationMethod,
        categoria: Category?,
        subcategoria: Subcategory?,
        esIngreso: Bool,
        indice: TransactionIndex,
        ahora: Date = .now,
        calendario: Calendar = .current
    ) -> Double {
        guard categoria != nil || subcategoria != nil,
              let inicioMes = calendario.date(from: calendario.dateComponents([.year, .month], from: ahora))
        else { return 0 }
        let linea = CashFlowLine(
            name: "", isIncome: esIngreso, estimationMethod: metodo,
            category: categoria, subcategory: subcategoria
        )
        switch metodo {
        case .average3m:
            return CashFlowProjectionCalculator.estimateAverage(
                months: 3, line: linea, referenceDate: inicioMes, index: indice, calendar: calendario)
        case .lastMonth:
            return CashFlowProjectionCalculator.estimateLastMonth(
                line: linea, referenceDate: inicioMes, index: indice, calendar: calendario)
        default:
            return CashFlowProjectionCalculator.estimateAverage(
                months: 6, line: linea, referenceDate: inicioMes, index: indice, calendar: calendario)
        }
    }
}
