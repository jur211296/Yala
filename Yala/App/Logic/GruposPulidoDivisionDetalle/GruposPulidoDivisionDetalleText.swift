//
//  GruposPulidoDivisionDetalleText.swift
//  Yala
//
//  Textos nuevos de «¿Cómo se dividió?» en tarjetas y de la etiqueta real del reparto (encargo del 2026-11-26).
//  En su propia tabla (`GruposPulidoDivisionDetalle.strings`), leída con el idioma de la app como
//  `ExitoGruposBandejaText`. Lo que ya existía («Partes iguales», «Monto exacto»…) se lee de su clave.
//

import Foundation

enum GruposPulidoDivisionDetalleText {
    static let table = "GruposPulidoDivisionDetalle"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "gpdd.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// Cabecera de la fila de «¿Cómo se dividió?» cuando pagaste tú.
    static var youPaidHeader: String { string("twoPerson.youPaidHeader") }
    /// Cabecera cuando pagó la otra persona («Pagó Pia»).
    static func theyPaidHeader(_ name: String) -> String {
        String(format: string("twoPerson.theyPaidHeader"), name)
    }
    static var allForMe: String { string("split.allForMe") }
    static func allFor(_ name: String) -> String {
        String(format: string("split.allFor"), name)
    }
    static var custom: String { string("split.custom") }

    /// La etiqueta junto a «Reparto». `name` resuelve el nombre de un miembro.
    static func splitLabel(for kind: GroupSplitLabelLogic.Kind, name: (String) -> String) -> String {
        switch kind {
        case .equal: return L10n.Split.typeEqual
        case .allForMe: return allForMe
        case .allFor(let memberID): return allFor(name(memberID))
        case .exact: return L10n.Split.typeExact
        case .percentage: return L10n.Split.typePercentage
        case .shares: return L10n.Split.typeShares
        case .custom: return custom
        }
    }
}
