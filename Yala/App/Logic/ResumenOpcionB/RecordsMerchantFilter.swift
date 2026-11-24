//
//  RecordsMerchantFilter.swift
//  Yala
//
//  Registros de un comercio (Estadísticas › Resumen, opción B): tocar un gasto hormiga, una unión de Yala IA o «Ver las
//  compras» abre el chip Registros solo con esos registros. Es efímero, como el modo duplicados: vive en el
//  `RecordsViewModel` de Estadísticas y se quita al salir del chip o con la ✕ de su cápsula.
//
//  El comercio se reconoce con la MISMA clave que agrupa los gastos hormiga (`AntExpensesCalculator.groupKey`: la
//  descripción normalizada, o la subcategoría si no hay descripción). Con otra regla, la lista enseñaría compras que la
//  tarjeta no contó, o al revés.
//

import Foundation

struct RecordsMerchantFilter: Equatable {
    /// Lo que dice la cápsula: el nombre del comercio, o «Gastos hormiga» con todos.
    let label: String
    /// Las claves de `AntExpensesCalculator.groupKey`. Varias en una unión de Yala IA o en «Ver las compras».
    let keys: Set<String>

    func matches(_ record: TransactionItem) -> Bool {
        guard let key = AntExpensesCalculator.groupKey(for: record)?.key else { return false }
        return keys.contains(key)
    }

    /// Deja en cada día solo los registros del comercio y quita los días que se quedan vacíos. Sin filtro, igual.
    static func applying(
        _ filter: RecordsMerchantFilter?,
        to groups: [(date: Date, records: [TransactionItem])]
    ) -> [(date: Date, records: [TransactionItem])] {
        guard let filter, !filter.keys.isEmpty else { return groups }
        return groups.compactMap { group in
            let kept = group.records.filter(filter.matches)
            return kept.isEmpty ? nil : (group.date, kept)
        }
    }
}
