//
//  CashFlowAmountChangeLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L18-8 (opción A de Jürgen): «noviembre y los siguientes» cambiaba también setiembre y octubre,
//  porque el ajuste pasaba la línea entera a «monto fijo» sin un «desde qué mes». Ahora la línea guarda sus cambios
//  «desde este mes» (`CashFlowLine.amountChangesRaw`) y un mes usa, por orden:
//   1. su ajuste de un solo mes (`CashFlowOverride`), si lo tiene;
//   2. el último cambio cuyo mes es igual o anterior a ese mes;
//   3. el método de la línea.
//  Así un cambio desde noviembre no toca los meses anteriores, y otro desde febrero no borra el de noviembre a enero.
//
//  Formato guardado (viaja por iCloud y por la nube tal cual): `yyyy-MM=monto` separados por coma, ordenados por mes.
//  El monto se escribe con `String(Double)`, que no depende del idioma («9000.0»). Una entrada que no se entiende se
//  descarta al leer y no se vuelve a escribir.
//
//  Lógica pura: sin SwiftData.
//

import Foundation

nonisolated enum CashFlowAmountChangeLogic {

    /// Un cambio de monto «desde este mes».
    struct Change: Equatable, Sendable {
        let monthKey: String
        let amount: Double
    }

    /// Lee los cambios guardados, ordenados por mes. Un mes repetido conserva el último escrito.
    static func parse(_ raw: String?) -> [Change] {
        guard let raw, !raw.isEmpty else { return [] }
        var byMonth: [String: Double] = [:]
        for entry in raw.split(separator: ",") {
            let parts = entry.split(separator: "=", omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            guard isMonthKey(key),
                  let amount = Double(String(parts[1]).trimmingCharacters(in: .whitespaces)),
                  amount.isFinite, amount >= 0
            else { continue }
            byMonth[key] = amount
        }
        return byMonth.keys.sorted().compactMap { key in byMonth[key].map { Change(monthKey: key, amount: $0) } }
    }

    /// Lo que se guarda. `nil` sin cambios: un opcional a `nil` no viaja a iCloud ni a la nube.
    static func encode(_ changes: [Change]) -> String? {
        let valid = changes.filter { isMonthKey($0.monthKey) && $0.amount.isFinite && $0.amount >= 0 }
        guard !valid.isEmpty else { return nil }
        var byMonth: [String: Double] = [:]
        for change in valid { byMonth[change.monthKey] = change.amount }
        return byMonth.keys.sorted().compactMap { key in
            byMonth[key].map { "\(key)=\(String($0))" }
        }.joined(separator: ",")
    }

    /// El cambio que vale para `monthKey`: el último cuyo mes es igual o anterior. `nil` si el mes es anterior a todos.
    static func change(for monthKey: String, in changes: [Change]) -> Change? {
        changes.last { $0.monthKey <= monthKey }
    }

    /// «Este mes y los siguientes»: el monto nuevo vale desde `change.monthKey`. Los cambios posteriores se retiran
    /// —contradecirían «y los siguientes»—; los anteriores se quedan intactos.
    static func applying(_ change: Change, to changes: [Change]) -> [Change] {
        changes.filter { $0.monthKey < change.monthKey } + [change]
    }

    /// `yyyy-MM` con mes entre 01 y 12.
    static func isMonthKey(_ key: String) -> Bool {
        // Solo dígitos y sin trozos vacíos: «2026--05» o «+026-05» ordenarían como texto antes de tiempo.
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1])
        else { return false }
        return year > 0 && (1...12).contains(month)
    }
}
