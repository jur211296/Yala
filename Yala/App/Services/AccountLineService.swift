//
//  AccountLineService.swift
//  Yala
//
//  Lo que toca SwiftData de la tarjeta con varias divisas (entrega 1). Las reglas viven en
//  `AccountLineLogic`; aquí solo se leen cuentas, se le pregunta y se escribe `parentAccountID`.
//
//  Dos escritores, y ninguno toca un movimiento:
//   - `link`: vincular una cuenta como línea de otra (lo usará la entrega 2; hoy solo los tests).
//   - `relinkAfterIdentityRegeneration`: la principal cambió de `shortcutID` al reparar una identidad
//     colapsada → sus líneas pasan a apuntar al valor nuevo.
//
//  Lo que NO hay, a propósito: un escritor que desvincule la línea duplicada que dos teléfonos crearon para la misma
//  (tarjeta, divisa). La deduplicación es de LECTURA: `AccountLineLogic.resolve` da la ranura al menor `shortcutID`
//  y lee la otra suelta, igual en todos los teléfonos que ven lo mismo. Desvincular en cada teléfono se probó y la
//  review lo tumbó: con un archivado en vuelo, o un `shortcutID` reparado solo en un teléfono, cada uno desvinculaba
//  una distinta y la tarjeta se quedaba sin ninguna. Sin escritura no hay nada que se cruce, y si la ganadora se
//  archiva, la otra pasa a ser la línea sola.
//

import Foundation
import SwiftData

enum AccountLineService {

    enum LinkError: Error, Equatable {
        case rejected(AccountLinkRejection)
    }

    /// Vincula `line` como línea en otra divisa de `principal`. Escribe SOLO `parentAccountID`: ningún
    /// movimiento cambia de cuenta, de divisa ni de importe (decisión 4 de Jürgen). Lanza si la regla lo
    /// rechaza o si el guardado falla; con el rechazo no escribe nada.
    static func link(_ line: Account, to principal: Account, in context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        if let rejection = AccountLineLogic.linkRejection(
            lineID: line.shortcutID, principalID: principal.shortcutID,
            among: accounts.map { AccountLineNode($0) }) {
            throw LinkError.rejected(rejection)
        }
        line.parentAccountID = principal.shortcutID
        try context.save()
    }

    /// Reenlaza las líneas cuya principal acaba de cambiar de `shortcutID`. `linesBefore` = las cuentas que
    /// apuntaban a un valor regenerado, leídas ANTES de regenerar; `regenerated` = los pares viejo→nuevo
    /// con la cuenta ya regenerada. No guarda: va en la transacción del llamador, junto a la regeneración.
    /// Devuelve cuántas reenlazó.
    @discardableResult
    static func relinkAfterIdentityRegeneration(
        linesBefore: [Account],
        regenerated: [(account: Account, oldID: UUID)]
    ) -> Int {
        guard !linesBefore.isEmpty, !regenerated.isEmpty else { return 0 }
        var lines: [Int: AccountLineNode] = [:]
        for (index, account) in linesBefore.enumerated() { lines[index] = AccountLineNode(account) }
        let identities = regenerated.map { entry in
            RegeneratedAccountIdentity(
                oldID: entry.oldID, newID: entry.account.shortcutID, parentID: entry.account.parentAccountID,
                currencyCode: entry.account.currencyCode, isSystem: entry.account.isSystemAccount)
        }
        let targets = AccountLineLogic.relinkTargets(lines: lines, regenerated: identities)
        for (index, newParentID) in targets { linesBefore[index].parentAccountID = newParentID }
        return targets.count
    }
}
