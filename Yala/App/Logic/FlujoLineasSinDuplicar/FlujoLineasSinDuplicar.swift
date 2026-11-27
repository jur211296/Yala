//
//  FlujoLineasSinDuplicar.swift
//  Yala
//
//  Una línea del flujo de caja por cosa (encargo del 27-nov-2026, flujo de caja duplicado y promedios). «Agregar línea»
//  y «Agregar a mi plan» dejaban crear una segunda línea sobre lo mismo: el motor la absorbía en las cifras (queda
//  «repetida» y no proyecta), pero la tabla enseñaba dos filas.
//
//  «Lo mismo» es lo que decide el motor al repartir cada movimiento (`FlujoMotorMes.Dueños`): el mismo lado (gasto o
//  ingreso) y, en este orden, el mismo pago planificado (solo en una línea de método «Pagos planificados»), la misma
//  subcategoría, o la misma categoría sin subcategoría. Una línea de subcategoría junto a una de su categoría no choca: el
//  motor reparte lo de la subcategoría a la suya. Una línea sin categoría ni pago (personalizada) nunca choca. Cuentan las
//  líneas activas y sin borrar, las mismas que ve el motor.
//

import Foundation
import SwiftData

enum FlujoLineasSinDuplicar {

    /// De qué se queda dueña una línea en el motor.
    enum Base: Hashable {
        case pago(UUID)
        case subcategoria(PersistentIdentifier)
        case categoria(PersistentIdentifier)
    }

    struct Clave: Hashable {
        let esIngreso: Bool
        let base: Base
    }

    /// Lo que reclama una línea del motor: uno por pago si es de pagos; si no, su subcategoría o su categoría; nada si no
    /// tiene ninguna de las dos.
    static func claves(de linea: FlujoMotorMes.Linea) -> [Clave] {
        if !linea.pagoIDs.isEmpty {
            return linea.pagoIDs.map { Clave(esIngreso: linea.esIngreso, base: .pago($0)) }
        }
        if let sub = linea.subcategoriaID { return [Clave(esIngreso: linea.esIngreso, base: .subcategoria(sub))] }
        if let cat = linea.categoriaID { return [Clave(esIngreso: linea.esIngreso, base: .categoria(cat))] }
        return []
    }

    /// La primera línea de `existentes` que ya es dueña de lo que pide `nueva`, o `nil`. Como en el motor, una línea de
    /// pagos solo choca si ya tienen dueño TODOS sus pagos (con uno libre, se queda con ese).
    static func existente(para nueva: FlujoMotorMes.Linea, en existentes: [FlujoMotorMes.Linea]) -> FlujoMotorMes.Linea? {
        let pide = claves(de: nueva)
        guard !pide.isEmpty else { return nil }
        var dueña: [Clave: FlujoMotorMes.Linea] = [:]
        for linea in existentes where linea.id != nueva.id {
            for clave in claves(de: linea) where dueña[clave] == nil { dueña[clave] = linea }
        }
        let dueñas = pide.compactMap { dueña[$0] }
        return dueñas.count == pide.count ? dueñas.first : nil
    }

    // MARK: - Con los modelos

    /// Las líneas que ve el motor: activas y sin borrar, en el orden del plan.
    @MainActor
    static func lineasDelMotor(_ lineas: [CashFlowLine]) -> [CashFlowLine] {
        lineas.filter { !$0.isDeleted && $0.isEnabled }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
    }

    /// La línea del plan que ya cubre lo que `nueva` cubriría, o `nil` si `nueva` no repite nada.
    @MainActor
    static func existente(para nueva: CashFlowLine, en lineas: [CashFlowLine]) -> CashFlowLine? {
        let candidatas = lineasDelMotor(lineas).filter { $0 !== nueva }
        guard let hallada = existente(
            para: FlujoMotorMesEntrada.linea(nueva), en: candidatas.map(FlujoMotorMesEntrada.linea)
        ) else { return nil }
        return candidatas.first { $0.id == hallada.id }
    }

    /// ¿Ya hay en el plan una línea por promedio para esta subcategoría (o esta categoría sin subcategorías), en este
    /// lado? Es la pregunta de «Desde mis gastos» antes de dejar elegir la fila.
    @MainActor
    static func yaEnElPlan(
        categoria: Category?, subcategoria: Subcategory?, esIngreso: Bool, lineas: [CashFlowLine]
    ) -> Bool {
        let pedida = FlujoMotorMes.Linea(
            id: UUID(), esIngreso: esIngreso,
            categoriaID: (categoria ?? subcategoria?.category)?.persistentModelID,
            subcategoriaID: subcategoria?.persistentModelID,
            pagoIDs: []
        )
        let candidatas = lineasDelMotor(lineas)
        return existente(para: pedida, en: candidatas.map(FlujoMotorMesEntrada.linea)) != nil
    }
}
