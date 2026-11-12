//
//  ImportGroupRowFilter.swift
//  Yala
//
//  Qué filas de un archivo importado son de Grupos (H5 de la auditoría del import 2.2, card l2g9).
//
//  Decisión de Jürgen (2026-10-29): el import NO acepta nada de Grupos. Ni las subcategorías del puente («Préstamo a
//  grupos», «Cobro de préstamo», las liquidaciones, los saldos iniciales de grupo) ni las categorías «Grupos» y
//  «Cobros de grupos». Reimportadas entraban en una cuenta real como transferencias, sin enlace al gasto del grupo:
//  salían de gastos e ingresos y la heurística podía emparejarlas. Esas filas se saltan con su motivo; Grupos tendrá
//  su propia importación. Las transferencias entre cuentas y los ajustes de saldo SÍ siguen entrando.
//
//  Se reconocen por NOMBRE en todos los idiomas (y los nombres viejos), antes de resolver nada: así una categoría
//  «Grupos» que el usuario no tiene tampoco se crea al importar.
//

import Foundation

enum ImportGroupRowFilter {

    /// Las claves de las categorías de sistema de Grupos.
    static let categoryKeys = [
        "category.system.\(GroupBridgeSystemRole.categoryGroups)",
        "category.system.\(GroupBridgeSystemRole.categoryGroupCollections)",
    ]

    /// Las claves de las siete subcategorías del puente.
    static let subcategoryKeys = [
        GroupBridgeSystemRole.subcategoryLoanToGroups,
        GroupBridgeSystemRole.subcategoryLoanCollection,
        GroupBridgeSystemRole.subcategorySettlementPayment,
        GroupBridgeSystemRole.subcategorySettlementSent,
        GroupBridgeSystemRole.subcategorySettlementReceived,
        GroupBridgeSystemRole.subcategoryOpeningBalanceOwed,
        GroupBridgeSystemRole.subcategoryOpeningBalanceDebt,
    ].map { "subcategory.system.\($0)" }

    /// Los nombres, en minúsculas, de las categorías y subcategorías de Grupos en los 16 idiomas.
    static let groupNames: Set<String> = {
        var names = Set<String>()
        for key in categoryKeys + subcategoryKeys {
            for name in L10n.allLocalizedValues(forKey: key).union(SystemSubcategoryNameLogic.legacyNames(forLocalizationKey: key)) {
                names.insert(normalized(name))
            }
        }
        return names
    }()

    /// ¿La fila es de Grupos por su categoría o su subcategoría?
    static func isGroupRow(category: String, subcategory: String) -> Bool {
        groupNames.contains(normalized(category)) || groupNames.contains(normalized(subcategory))
    }

    /// Los nombres de la cuenta interna de Grupos en los 16 idiomas («Grupos %@», «Groups %@», «グループ %@»…), como
    /// prefijo y sufijo alrededor del código de moneda.
    static let groupAccountFormats: [(prefix: String, suffix: String)] = {
        L10n.allLocalizedValues(forKey: "account.system.groups").compactMap { format in
            let parts = format.components(separatedBy: "%@")
            guard parts.count == 2 else { return nil }
            return (normalized(parts[0]), normalized(parts[1]))
        }
    }()

    /// ¿Es el nombre de la cuenta interna de Grupos, en cualquier idioma y moneda, también con el « (Yala)» que se le
    /// añade cuando el usuario ya tenía una cuenta con ese nombre? Sus movimientos llevan la categoría real del gasto
    /// («Comida › Restaurante»), así que sin esto entraban como una cuenta personal nueva (review de S27m).
    static func isGroupAccountName(_ raw: String) -> Bool {
        var name = normalized(raw).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return false }
        if name.hasSuffix(" (yala)") { name = String(name.dropLast(" (yala)".count)) }
        for (prefix, suffix) in groupAccountFormats where name.hasPrefix(prefix) && name.hasSuffix(suffix) {
            let code = name.dropFirst(prefix.count).dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
            if code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) { return true }
        }
        return false
    }

    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
