//
//  ImportAccountChoiceLogic.swift
//  Yala
//
//  Las cuentas que ofrece «Importar archivo», en un solo sitio para sus dos selectores (`ImportIntroSheet` y
//  `ImportCurrencyMappingSheet`).
//
//  Hasta el 2026-10-22 los dos solo quitaban las archivadas, así que ofrecían la cuenta interna del puente de Grupos
//  («Grupos PEN», `isSystemAccount`): importar a ella mezclaría movimientos personales con los de los grupos (QA
//  guiado del 19-oct, ticket `import-offers-the-groups-system-account`). El formulario de movimiento, la voz y la
//  foto ya la excluían.
//

import Foundation

enum ImportAccountChoiceLogic {

    /// Las cuentas a las que se puede importar, por nombre: ni archivadas ni de sistema.
    static func importableAccounts(_ accounts: [Account]) -> [Account] {
        accounts
            .filter { !$0.isArchived && !$0.isSystemAccount }
            .sorted(by: { $0.name < $1.name })
    }
}
