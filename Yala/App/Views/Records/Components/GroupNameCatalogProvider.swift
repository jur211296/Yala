//
//  GroupNameCatalogProvider.swift
//  Yala
//
//  El nombre de cada grupo por su zona (`SplitGroup.cloudKitZoneID`), para que una fila de Registros que viene de un
//  gasto de grupo diga «Viaje a Lima» en vez de la cuenta de sistema «Grupos PEN» (auditoría UX 2.2, L8-5). Una sola
//  `@Query` para toda la lista, en vez de una consulta por fila; el molde de `TagCatalogProvider`.
//
//  Sin el proveedor (una fila montada en otra pantalla) el catálogo está vacío y la fila enseña la cuenta, como antes.
//

import SwiftData
import SwiftUI

private struct GroupNameCatalogKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

private struct GroupZoneByTransferPairKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

extension EnvironmentValues {
    /// Nombre del grupo por `cloudKitZoneID`.
    var groupNameCatalog: [String: String] {
        get { self[GroupNameCatalogKey.self] }
        set { self[GroupNameCatalogKey.self] = newValue }
    }

    /// Zona del grupo por `transferPairID` de las recargas de tu parte (card oibr): la entrada en tu cuenta no lleva
    /// puntero de grupo (D4) y dice su grupo por su salida en «Grupos».
    var groupZoneByTransferPair: [String: String] {
        get { self[GroupZoneByTransferPairKey.self] }
        set { self[GroupZoneByTransferPairKey.self] = newValue }
    }
}

struct GroupNameCatalogProvider: ViewModifier {
    @Query private var groups: [SplitGroup]
    /// Las salidas de las recargas de tu parte: patas con puntero de grupo que forman un par de transferencia.
    @Query(filter: #Predicate<TransactionItem> { $0.splitExpenseID != nil && $0.transferPairID != nil })
    private var bridgedPairLegs: [TransactionItem]

    func body(content: Content) -> some View {
        content
            .environment(\.groupNameCatalog, Self.catalog(groups))
            .environment(\.groupZoneByTransferPair, GroupSplitLineEntryGroupLogic.zoneByTransferPair(
                bridgedPairLegs.compactMap { leg in
                    leg.transferPairID.map { .init(transferPairID: $0, groupZoneID: leg.splitGroupZoneID) }
                }))
    }

    /// Una zona repetida (no debería) se queda con el primer nombre no vacío.
    static func catalog(_ groups: [SplitGroup]) -> [String: String] {
        var result: [String: String] = [:]
        for group in groups where !group.cloudKitZoneID.isEmpty {
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, result[group.cloudKitZoneID] == nil else { continue }
            result[group.cloudKitZoneID] = name
        }
        return result
    }
}

extension View {
    /// Pone a la vista el nombre de los grupos para las filas de Registros que vienen de un grupo (L8-5).
    func providesGroupNames() -> some View {
        modifier(GroupNameCatalogProvider())
    }
}
