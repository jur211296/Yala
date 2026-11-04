//
//  MultiDraftReviewLogic.swift
//  Yala
//
//  Lo que decide sin vista la hoja de varios registros de foto y voz (propuesta C de Jürgen, 2026-11-03, card va62):
//  qué está marcado, el resumen de arriba (total, barra por categoría, fechas), los bloques por día con su subtotal y
//  cuándo «Guardar» puede aprobar. Los desmarcados no se tocan: siguen pendientes en la Bandeja, como al cerrar sin
//  guardar (decisión de Jürgen). Puro, para probarlo sin simulador.
//

import Foundation

enum MultiDraftReviewLogic {

    /// Lo justo de un borrador para la hoja. `amount` lleva el signo del borrador (negativo es gasto).
    struct Item<ID: Hashable>: Equatable {
        var id: ID
        var amount: Double?
        /// La divisa en que se pinta su importe (la de su cuenta, o la principal).
        var currencyCode: String
        var date: Date
        /// `nil` si falta la categoría: va a su tramo gris de la barra.
        var categoryKey: String?
        var categoryName: String
        var colorHex: String?
        var isPending: Bool
        var isSaved: Bool
        var isComplete: Bool
    }

    struct Slice: Equatable {
        var key: String?
        var name: String
        var colorHex: String?
        var value: Double
    }

    struct Day<ID: Hashable>: Equatable {
        var day: Date
        var ids: [ID]
    }

    // MARK: - Selección

    /// Qué está marcado. Todo lo que llega, marcado por defecto; lo que la persona desmarcó se queda así aunque lleguen
    /// más (reintentar las fotos que fallaron añade borradores a la misma hoja).
    struct Selection<ID: Hashable>: Equatable {
        private(set) var selected: Set<ID> = []
        private(set) var seen: Set<ID> = []

        init() {}

        /// Marca lo nuevo. Sin borradores (grabar otra vez, otra foto) empieza de cero.
        mutating func sync(with ids: [ID]) {
            guard !ids.isEmpty else {
                selected = []
                seen = []
                return
            }
            for id in ids where !seen.contains(id) {
                seen.insert(id)
                selected.insert(id)
            }
        }

        func contains(_ id: ID) -> Bool { selected.contains(id) }

        mutating func toggle(_ id: ID) {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        }

        /// «Marcar todos» / «Quitar todos» sobre lo que aún se puede elegir. Lo ya guardado se queda marcado.
        mutating func setAll(_ on: Bool, pending: [ID]) {
            for id in pending {
                if on { selected.insert(id) } else { selected.remove(id) }
            }
        }
    }

    // MARK: - Resumen

    static func marked<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> [Item<ID>] {
        items.filter { selection.contains($0.id) }
    }

    /// Lo que se registra: los marcados, guardados o por guardar. Sin signo, como el importe de cada fila.
    static func total<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Double {
        marked(items, selection).reduce(0) { $0 + abs($1.amount ?? 0) }
    }

    /// La divisa de una suma, o `nil` si mezcla divisas: sumar soles con dólares no es un total, así que entonces la hoja
    /// no pinta cifra (ni el total, ni el subtotal, ni el botón).
    static func sharedCurrency<ID>(_ items: [Item<ID>]) -> String? {
        let codes = Set(items.map(\.currencyCode))
        return codes.count == 1 ? codes.first : nil
    }

    /// La barra: un tramo por categoría de los marcados, de mayor a menor. Lo que no tiene categoría va junto, en gris.
    static func slices<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> [Slice] {
        var order: [String?] = []
        var byKey: [String?: Slice] = [:]
        for item in marked(items, selection) {
            let key = item.categoryKey
            if byKey[key] == nil {
                order.append(key)
                byKey[key] = Slice(key: key, name: item.categoryName, colorHex: item.colorHex, value: 0)
            }
            byKey[key]?.value += abs(item.amount ?? 0)
        }
        return order.compactMap { byKey[$0] }
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }

    /// La leyenda nombra solo categorías de verdad, las tres con más peso.
    static func legend(_ slices: [Slice]) -> [Slice] {
        Array(slices.filter { $0.key != nil }.prefix(3))
    }

    /// De la fecha más antigua a la más reciente de lo leído (marcado o no): es lo que trae la foto o la nota.
    static func dateRange<ID>(_ items: [Item<ID>]) -> ClosedRange<Date>? {
        guard let low = items.map(\.date).min(), let high = items.map(\.date).max() else { return nil }
        return low...high
    }

    // MARK: - Por día

    /// Un bloque por día, del más reciente al más antiguo; dentro, el orden en que llegaron.
    static func days<ID>(_ items: [Item<ID>], calendar: Calendar = .current) -> [Day<ID>] {
        var order: [Date] = []
        var byDay: [Date: [ID]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: item.date)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(item.id)
        }
        return order.sorted(by: >).map { Day(day: $0, ids: byDay[$0] ?? []) }
    }

    /// El subtotal de un día cuenta solo lo marcado, como el total de arriba.
    static func subtotal<ID>(_ ids: [ID], items: [Item<ID>], _ selection: Selection<ID>) -> Double {
        let set = Set(ids)
        return marked(items, selection).filter { set.contains($0.id) }.reduce(0) { $0 + abs($1.amount ?? 0) }
    }

    // MARK: - Guardar

    /// Lo que «Guardar» aprueba: los marcados que siguen pendientes.
    static func toSave<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> [Item<ID>] {
        marked(items, selection).filter(\.isPending)
    }

    static func saveTotal<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Double {
        toSave(items, selection).reduce(0) { $0 + abs($1.amount ?? 0) }
    }

    /// Solo se enciende si hay algo marcado por guardar y todo lo marcado está completo. Lo incompleto se completa o se
    /// desmarca.
    static func canSave<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Bool {
        let pending = toSave(items, selection)
        return !pending.isEmpty && pending.allSatisfy(\.isComplete)
    }

    /// Cuántos marcados le impiden guardar.
    static func incompleteMarked<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Int {
        toSave(items, selection).filter { !$0.isComplete }.count
    }

    /// Tras guardar lo marcado ya no queda nada que hacer en la hoja: «Listo», aunque queden desmarcados en la Bandeja.
    static func isFinished<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Bool {
        guard !items.isEmpty else { return false }
        if items.allSatisfy({ !$0.isPending }) { return true }
        return items.contains(where: \.isSaved) && toSave(items, selection).isEmpty
    }

    /// Hay pendientes sin marcar: se quedan en la Bandeja y la hoja lo dice.
    static func leavesUnmarkedInInbox<ID>(_ items: [Item<ID>], _ selection: Selection<ID>) -> Bool {
        items.contains { $0.isPending && !selection.contains($0.id) }
    }
}
