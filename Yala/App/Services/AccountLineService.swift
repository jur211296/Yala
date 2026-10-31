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
        // Con la tarjeta ya filtrada, la línea vinculada entra en el filtro (entrega 3, review del 2026-10-18).
        SessionState.shared.reapplyAccountSelection()
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
        SessionState.shared.reapplyAccountSelection()
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

    // MARK: - S30: el nombre de las líneas sigue al de la tarjeta

    /// Renombra las líneas de `principal` cuyo nombre empezaba por `oldName` (`AccountCardLogic.renamedLineName`). Va
    /// después de escribir el nombre nuevo en la principal y no guarda: entra en el guardado del formulario. Recorre
    /// todas las que apuntan a ella, archivadas incluidas (el nombre es de la tarjeta), en orden de `shortcutID` para que
    /// la numeración de un nombre repetido salga igual en cada teléfono. Devuelve cuántas renombró.
    @discardableResult
    static func renameLines(of principal: Account, from oldName: String, among accounts: [Account]) -> Int {
        let lines = accounts
            .filter { $0.parentAccountID == principal.shortcutID && $0.shortcutID != principal.shortcutID
                && !$0.isSystemAccount }
            .sorted { $0.shortcutID.uuidString < $1.shortcutID.uuidString }
        guard !lines.isEmpty else { return 0 }
        var renamed = 0
        for line in lines {
            let taken = accounts.filter { $0 !== line }.map(\.name)
            guard let name = AccountCardLogic.renamedLineName(
                current: line.name, oldCardName: oldName, newCardName: principal.name,
                currencyCode: normalizeCurrencyCode(line.currencyCode), taken: taken) else { continue }
            line.name = name
            renamed += 1
        }
        return renamed
    }

    /// La reparación del arranque (S30): las líneas válidas que conservan el nombre automático de una tarjeta que ya se
    /// llama de otra forma («BCP Débito Soles · USD» bajo «BCP Débito») pasan al nombre de hoy
    /// (`AccountCardLogic.repairedLineName`, que exige la relación de prefijo). Idempotente: una línea ya
    /// arreglada no vuelve a escribirse, así que puede correr en cada arranque y arregla también la que llega tarde por
    /// sincronización. Solo con UNA principal posible para el enlace (con un `shortcutID` colapsado no se elige). Guarda
    /// si cambió algo; con el guardado fallido deshace solo lo suyo. Devuelve cuántas renombró.
    @discardableResult
    static func repairStaleLineNames(in context: ModelContext) throws -> Int {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let byID = Dictionary(grouping: accounts, by: \.shortcutID)
        // Solo las líneas que la app trata como tales: un enlace roto se lee como cuenta suelta y su nombre es suyo.
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        let lines = accounts
            .filter { $0.parentAccountID != nil && !$0.isSystemAccount }
            .sorted { $0.shortcutID.uuidString < $1.shortcutID.uuidString }
        var changes: [(account: Account, previous: String)] = []
        for line in lines {
            guard let parentID = line.parentAccountID, parentID != line.shortcutID,
                  let candidates = byID[parentID], candidates.count == 1, let principal = candidates.first,
                  !principal.isSystemAccount, roles[line.shortcutID] == .line(principalID: parentID) else { continue }
            let taken = accounts.filter { $0 !== line }.map(\.name)
            guard let name = AccountCardLogic.repairedLineName(
                current: line.name, cardName: principal.name,
                currencyCode: normalizeCurrencyCode(line.currencyCode), taken: taken)
            else { continue }
            changes.append((line, line.name))
            line.name = name
        }
        guard !changes.isEmpty else { return 0 }
        do {
            try context.save()
        } catch {
            for change in changes { change.account.name = change.previous }
            throw error
        }
        return changes.count
    }
}
