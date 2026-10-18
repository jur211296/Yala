//
//  AccountLineService.swift
//  Yala
//
//  Lo que toca SwiftData de la tarjeta con varias divisas (entrega 1). Las reglas viven en
//  `AccountLineLogic`; aquí solo se leen cuentas, se le pregunta y se escribe `parentAccountID`.
//
//  Escritores, y ninguno cambia un movimiento que ya existe:
//   - `link` / `unlink`: vincular una cuenta como línea de otra y devolverla a suelta (formulario de cuenta).
//   - `addLine`: una línea nueva; solo crea su saldo de partida si el usuario lo escribe.
//   - `archiveLines`: la cascada de archivar la tarjeta (formulario y downgrade de plan).
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
        let previous = line.parentAccountID
        line.parentAccountID = principal.shortcutID
        do {
            try context.save()
        } catch {
            // El contexto es compartido: sin deshacerlo, el siguiente guardado de otra pantalla escribiría el enlace
            // que esta pantalla acaba de decir que falló.
            line.parentAccountID = previous
            throw error
        }
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

    // MARK: - Entrega 2: añadir, desvincular y archivar en cascada

    enum AddLineError: Error, Equatable {
        /// La cuenta no puede tener líneas: es una línea, de sistema o está archivada.
        case cannotHaveLines
        case rejected(AccountLinkRejection)
        /// Hay saldo que apuntar y no se encontró ni se pudo crear la subcategoría «Ajustes de saldo».
        case missingBalanceSubcategory
    }

    /// Crea una línea nueva de `principal` en `currencyCode`: otra `Account` de una sola divisa con el tipo, el color,
    /// el icono y la exclusión de estadísticas de la tarjeta, y `parentAccountID` apuntando a ella. Con `initialBalance`
    /// apunta su saldo de partida como al crear una cuenta. Guarda; si algo se rechaza, no escribe nada.
    @discardableResult
    static func addLine(
        currencyCode rawCode: String,
        to principal: Account,
        initialBalance: Double?,
        in context: ModelContext
    ) throws -> Account {
        let currencyCode = normalizeCurrencyCode(rawCode)
        guard AccountCardLogic.canHaveLines(AccountLineNode(principal)) else { throw AddLineError.cannotHaveLines }
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let nodes = accounts.map { AccountLineNode($0) }
        guard AccountCardLogic.addableCurrencies(
            principalID: principal.shortcutID, nodes: nodes, available: [currencyCode]) == [currencyCode]
        else {
            if normalizeCurrencyCode(principal.currencyCode) == currencyCode {
                throw AddLineError.rejected(.sameCurrencyAsPrincipal)
            }
            let roles = AccountLineLogic.resolve(nodes)
            let existing = nodes.first { $0.currencyCode == currencyCode
                && roles[$0.id] == .line(principalID: principal.shortcutID) }
            throw AddLineError.rejected(.currencyAlreadyLinked(existingLineID: existing?.id ?? principal.shortcutID))
        }
        let subcategory: Subcategory?
        if initialBalance != nil {
            guard let found = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context) else {
                throw AddLineError.missingBalanceSubcategory
            }
            subcategory = found
        } else {
            subcategory = nil
        }

        let line = Account(
            name: AccountCardLogic.lineName(cardName: principal.name, currencyCode: currencyCode,
                                            taken: accounts.map(\.name)),
            currencyCode: currencyCode,
            colorHex: principal.colorHex,
            iconName: principal.iconName,
            type: principal.type,
            excludeFromStatistics: principal.excludeFromStatistics
        )
        line.parentAccountID = principal.shortcutID
        context.insert(line)
        var opening: TransactionItem?
        if let initialBalance, let subcategory {
            opening = InitialBalanceService.setInitialBalance(
                amount: initialBalance, for: line, subcategory: subcategory, allTransactions: [], context: context)
        }
        do {
            try context.save()
        } catch {
            // Se deshace solo lo propio: un `rollback()` del contexto compartido se llevaría cambios de otras pantallas.
            if let opening { context.delete(opening) }
            context.delete(line)
            throw error
        }
        return line
    }

    /// Devuelve una línea (o una cuenta con un enlace roto) a cuenta suelta. Escribe SOLO `parentAccountID`: su
    /// historial no se toca. Guarda.
    static func unlink(_ line: Account, in context: ModelContext) throws {
        guard let previous = line.parentAccountID else { return }
        line.parentAccountID = nil
        do {
            try context.save()
        } catch {
            line.parentAccountID = previous
            throw error
        }
    }

    /// Archiva las líneas vivas de `principal` (la cascada de archivar la tarjeta). No guarda: va en la transacción de
    /// quien archiva la principal. `excludeFromStatistics` = lo que hace archivar desde el formulario; el downgrade de
    /// plan archiva sin excluir (`session-filters.md`). Devuelve cuántas archivó.
    @discardableResult
    static func archiveLines(of principal: Account, among accounts: [Account], excludeFromStatistics: Bool) -> Int {
        let ids = Set(AccountCardLogic.linesToArchive(
            principalID: principal.shortcutID, nodes: accounts.map { AccountLineNode($0) }))
        var archived = 0
        for account in accounts where ids.contains(account.shortcutID) {
            account.isArchived = true
            if excludeFromStatistics { account.excludeFromStatistics = true }
            archived += 1
        }
        return archived
    }
}
