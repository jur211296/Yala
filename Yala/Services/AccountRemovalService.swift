//
//  AccountRemovalService.swift
//  Yala
//
//  Eliminar una cuenta llevándose o moviendo lo que cuelga de ella.
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`, decisión A de Jürgen (2026-10-15).
//

import Foundation
import SwiftData

/// Mueve o borra lo que cuelga de una cuenta y después la elimina, en un solo guardado.
///
/// Las decisiones viven en `AccountRemovalLogic`; aquí solo se lee el store y se escribe. **Todo se lee con
/// `FetchDescriptor` y no por las relaciones inversas** (`account.transactions`, `account.budgets`): con el
/// espejo de CloudKit una inversa puede llegar `nil` mientras se hidrata, y una lista vacía aquí se leería «la
/// cuenta no tiene nada» y la eliminaría sin preguntar. Un fetch que falla LANZA: tampoco es «no hay nada».
///
/// **Si el guardado falla, se deshace todo con `rollback()`**: lo movido, lo convertido y lo borrado ya está en
/// el contexto principal, y sin deshacerlo el siguiente autoguardado lo consolidaría mientras la hoja dice «No
/// se eliminó la cuenta». Es el único `save()` de esta operación y quien la lanza es la hoja, con nada más
/// pendiente en el contexto.
@MainActor
enum AccountRemovalService {

    enum Failure: Error, Equatable {
        /// No se pudo leer lo que cuelga de la cuenta.
        case unreadable
        /// La operación ya no vale con lo que hay ahora (llegó algo por sync durante la espera).
        case noLongerAllowed
        /// Faltan tipos de cambio para convertir con el dato bueno: no se movió nada.
        case ratesUnavailable
        /// El guardado falló; no se cambió nada.
        case saveFailed
    }

    /// Lo que cuelga de la cuenta, leído del store.
    struct Inventory {
        let account: Account
        let transactions: [TransactionItem]
        /// Por id de transacción: la OTRA pata de su transferencia, si vive fuera de esta cuenta y la pareja
        /// es de dos filas exactas.
        let outsidePartners: [PersistentIdentifier: TransactionItem]
        let scheduled: [ScheduledPayment]
        let favorites: [FavoritePayment]
        let pendingDrafts: [InboxDraft]
        /// Presupuestos cuyo filtro incluye esta cuenta, con las cuentas que les quedarían sin ella.
        let budgets: [(budget: Budget, remaining: [Account])]

        /// La forma pura para `AccountRemovalLogic`.
        var shape: AccountRemovalLogic.Inventory<PersistentIdentifier> {
            let source = normalizeCurrencyCode(account.currencyCode)
            return AccountRemovalLogic.Inventory(
                sourceCurrencyCode: account.currencyCode,
                rows: transactions.map { tx in
                    AccountRemovalLogic.Row(
                        currencyCode: tx.currencyCode,
                        conversionBlock: AccountCurrencyChangeLogic.blockReason(for: .init(
                            isTransferType: tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
                            hasTransferPairID: tx.transferPairID != nil,
                            hasSplitExpenseID: tx.splitExpenseID != nil,
                            hasSplitSettlementID: tx.splitSettlementID != nil
                        )),
                        isGroupRecord: tx.splitExpenseID != nil || tx.splitSettlementID != nil,
                        transferPartnerAccount: outsidePartners[tx.persistentModelID]?.account?.persistentModelID
                    )
                },
                scheduled: scheduled.map {
                    .init(currencyCode: $0.currencyCode, isGroupPayment: $0.groupZoneID != nil)
                },
                favoriteCount: favorites.count,
                favoriteAmountCurrencies: favorites.filter { $0.amount != nil }.map { $0.currencyCode ?? source },
                pendingDraftCount: pendingDrafts.count,
                pendingDraftsNotConvertible: pendingDrafts.filter {
                    $0.amount != nil && !AccountRemovalService.draftConverts($0)
                }.count,
                pendingDraftsToConvert: pendingDrafts.filter(AccountRemovalService.draftConverts).count,
                budgetCount: budgets.count,
                budgetsOnlyThisAccount: budgets.filter { $0.remaining.isEmpty }.count
            )
        }
    }

    #if DEBUG
    /// Seam de tests: sustituye la petición de tasas, que en el simulador acaba en la red (y en un timeout).
    static var prepareRatesOverride: (
        ([TransactionItem], AccountCurrencyMigrationService.RateNeeds, String) async -> Bool
    )?
    #endif

    // MARK: - Leer

    /// **Se lee todo y se filtra por cuenta en memoria**, como `AccountFormViewModel.loadPlans`: un `#Predicate`
    /// sobre la relación (`$0.account?.persistentModelID`) es la forma que SwiftData no garantiza, y aquí un
    /// resultado corto es justo el bug que esto cierra (filas que se quedan sin cuenta sin que nadie lo diga).
    ///
    /// Las parejas de transferencia salen del mismo fetch, con el `transferPairID` normalizado (mayúsculas, sin
    /// espacios) como hace `TransferPairReconcileService`, y **solo cuentan las de dos filas exactas**: con tres
    /// o más (colisión) no se sabe cuál es la pareja, y ese reconciliador tampoco las toca.
    static func inventory(of account: Account, context: ModelContext) throws -> Inventory {
        let accountID = account.persistentModelID
        func belongs(_ other: Account?) -> Bool { other?.persistentModelID == accountID }
        do {
            let allTransactions = try context.fetch(FetchDescriptor<TransactionItem>())
            let transactions = allTransactions.filter { belongs($0.account) }
            let pairIDs = Set(transactions.compactMap { pairKey($0.transferPairID) })
            var legsByPair: [String: [TransactionItem]] = [:]
            if !pairIDs.isEmpty {
                for tx in allTransactions {
                    guard let key = pairKey(tx.transferPairID), pairIDs.contains(key) else { continue }
                    legsByPair[key, default: []].append(tx)
                }
            }
            var partners: [PersistentIdentifier: TransactionItem] = [:]
            for tx in transactions {
                guard let key = pairKey(tx.transferPairID), let legs = legsByPair[key], legs.count == 2,
                      let other = legs.first(where: { $0.persistentModelID != tx.persistentModelID }),
                      !belongs(other.account) else { continue }
                partners[tx.persistentModelID] = other
            }

            let scheduled = try context.fetch(FetchDescriptor<ScheduledPayment>()).filter { belongs($0.account) }
            let favorites = try context.fetch(FetchDescriptor<FavoritePayment>()).filter { belongs($0.account) }
            let pending = DraftStatus.pending.rawValue
            let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.statusRaw == pending })).filter { belongs($0.account) }

            // Presupuestos: el filtro se lee CSV-first (la M2M puede llegar sin hidratar) y la M2M de respaldo.
            let allAccounts = try context.fetch(FetchDescriptor<Account>())
            let accountsByShortcut = Dictionary(
                allAccounts.map { ($0.shortcutID, $0) }, uniquingKeysWith: { first, _ in first })
            var budgets: [(budget: Budget, remaining: [Account])] = []
            for budget in try context.fetch(FetchDescriptor<Budget>()) {
                let ids = budget.resolvedAccountIDs(scheduleBackfill: false) ?? []
                let inM2M = (budget.accounts ?? []).contains { belongs($0) }
                guard ids.contains(account.shortcutID) || inM2M else { continue }
                let remaining = ids.subtracting([account.shortcutID])
                    .compactMap { accountsByShortcut[$0] }
                    .filter { !belongs($0) }
                budgets.append((budget, remaining))
            }

            return Inventory(
                account: account,
                transactions: transactions,
                outsidePartners: partners,
                scheduled: scheduled,
                favorites: favorites,
                pendingDrafts: drafts,
                budgets: budgets
            )
        } catch {
            #if DEBUG
            print("AccountRemovalService: Error: \(error)")
            #endif
            throw Failure.unreadable
        }
    }

    /// Las cuentas a las que se puede mover: las demás del usuario, sin archivadas ni las de sistema de Grupos
    /// (no se eligen a mano en ningún selector).
    static func destinations(excluding account: Account, context: ModelContext) throws -> [Account] {
        let accountID = account.persistentModelID
        do {
            return try context.fetch(FetchDescriptor<Account>())
                .filter { $0.persistentModelID != accountID && isEligibleDestination($0) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            #if DEBUG
            print("AccountRemovalService: Error: \(error)")
            #endif
            throw Failure.unreadable
        }
    }

    // MARK: - Mover

    /// Mueve todo a `destination` y elimina la cuenta.
    ///
    /// Con otra divisa, **las tasas antes que los importes** (`AccountCurrencyMigrationService.prepareRates`):
    /// la columna `amount` no tiene reparador. Tras el `await` se vuelve a leer y a decidir, también el destino:
    /// en esa ventana el sync pudo traer un movimiento nuevo de esta cuenta, una transferencia que ya no se puede
    /// convertir, o archivar o borrar la cuenta destino.
    static func move(
        _ account: Account,
        to destination: Account,
        context: ModelContext,
        deleteAccount: (Account) throws -> Void
    ) async throws {
        let target = destination.currencyCode
        guard isEligibleDestination(destination) else { throw Failure.noLongerAllowed }
        let before = try inventory(of: account, context: context)
        guard case .allowed = AccountRemovalLogic.moveVerdict(before.shape, to: destinationShape(destination))
        else { throw Failure.noLongerAllowed }

        let rates = rateWork(before, to: destination)
        if !rates.rows.isEmpty || !rates.needs.isEmpty {
            let ready: Bool
            #if DEBUG
            if let override = prepareRatesOverride {
                ready = await override(rates.rows, rates.needs, target)
            } else {
                ready = await AccountCurrencyMigrationService.prepareRates(
                    rows: rates.rows, extra: rates.needs, to: target, context: context)
            }
            #else
            ready = await AccountCurrencyMigrationService.prepareRates(
                rows: rates.rows, extra: rates.needs, to: target, context: context)
            #endif
            guard ready else { throw Failure.ratesUnavailable }
        }

        guard isEligibleDestination(destination), !account.isDeleted, account.modelContext != nil
        else { throw Failure.noLongerAllowed }
        let inventory = try Self.inventory(of: account, context: context)
        guard case .allowed = AccountRemovalLogic.moveVerdict(inventory.shape, to: destinationShape(destination))
        else { throw Failure.noLongerAllowed }
        let work = rateWork(inventory, to: destination)
        guard AccountCurrencyMigrationService.missingRateDates(
            rows: work.rows, extra: work.needs, to: target, context: context
        ).isEmpty else { throw Failure.ratesUnavailable }

        let destinationID = destination.persistentModelID
        var moving: [TransactionItem] = []
        for tx in inventory.transactions {
            if let partner = inventory.outsidePartners[tx.persistentModelID],
               partner.account?.persistentModelID == destinationID {
                // Transferencia entre esta cuenta y el destino: dentro de una cuenta no mueve dinero.
                context.delete(partner)
                context.delete(tx)
            } else {
                moving.append(tx)
            }
        }

        let source = account.currencyCode
        AccountCurrencyMigrationService.convertHistory(rows: work.rows, to: target, context: context)
        AccountCurrencyMigrationService.convertPendingDrafts(
            inventory.pendingDrafts.filter(draftConverts), from: source, to: target, context: context)
        AccountCurrencyMigrationService.convertPlans(
            scheduled: inventory.scheduled.filter {
                AccountCurrencyPlanLogic.convertsScheduledPayment(isGroupPayment: $0.groupZoneID != nil)
            },
            favorites: inventory.favorites,
            fallbackSourceCode: source,
            to: target,
            context: context
        )

        for tx in moving {
            tx.account = destination
            // El saldo inicial de la cuenta que se va entra como un ajuste: la cuenta destino ya tiene el suyo,
            // y el modelo da por hecho uno por cuenta (`InitialBalanceService.findInitialBalanceTransaction`).
            if tx.balanceAdjustmentType == InitialBalanceService.typeInitialBalance {
                tx.balanceAdjustmentType = InitialBalanceService.typeAdjustment
            }
        }
        inventory.scheduled.forEach { $0.account = destination }
        inventory.favorites.forEach { $0.account = destination }
        inventory.pendingDrafts.forEach { $0.account = destination }
        for entry in inventory.budgets {
            let accounts = entry.remaining.contains { $0.persistentModelID == destinationID }
                ? entry.remaining
                : entry.remaining + [destination]
            setBudgetAccounts(entry.budget, accounts)
        }

        try finish(account, context: context, deleteAccount: deleteAccount)
    }

    // MARK: - Borrar

    /// Borra los movimientos de la cuenta y la elimina.
    ///
    /// **Solo si son los mismos que la persona confirmó** (`confirmedTransactionIDs`): la cifra de la confirmación
    /// se leyó al abrir la hoja, y mientras tanto el espejo o el pull pudieron traer más movimientos de esta
    /// cuenta. Borrarlos sería borrar algo que nadie vio.
    ///
    /// La otra pata de una transferencia, en otra cuenta, **se queda como movimiento normal**: el saldo de esa
    /// cuenta no cambia porque esta desaparezca de la app. Es la misma reparación que hace
    /// `TransferPairReconcileService` con una pareja ausente; dejarla con el tipo de transferencia y sin pareja la
    /// expondría a que ese reconciliador la empareje por heurística con otra.
    ///
    /// Programados, favoritos y borradores pendientes se quedan, sin cuenta: la cuenta se elige al registrarlos.
    static func deleteRecords(
        of account: Account,
        confirmedTransactionIDs: Set<PersistentIdentifier>,
        context: ModelContext,
        deleteAccount: (Account) throws -> Void
    ) throws {
        let inventory = try inventory(of: account, context: context)
        guard Set(inventory.transactions.map(\.persistentModelID)) == confirmedTransactionIDs,
              case .allowed = AccountRemovalLogic.deleteVerdict(inventory.shape)
        else { throw Failure.noLongerAllowed }

        for partner in inventory.outsidePartners.values {
            partner.transferPairID = nil
            partner.balanceAdjustmentType = nil
        }
        inventory.transactions.forEach { context.delete($0) }
        inventory.scheduled.forEach { $0.account = nil }
        inventory.favorites.forEach { $0.account = nil }
        inventory.pendingDrafts.forEach { $0.account = nil }
        for entry in inventory.budgets {
            setBudgetAccounts(entry.budget, entry.remaining)
        }

        try finish(account, context: context, deleteAccount: deleteAccount)
    }

    // MARK: - Piezas

    /// Elimina la cuenta, que guarda TODO lo anterior en el mismo `save()`. Si falla, lo deshace todo.
    private static func finish(
        _ account: Account,
        context: ModelContext,
        deleteAccount: (Account) throws -> Void
    ) throws {
        do {
            try deleteAccount(account)
        } catch {
            #if DEBUG
            print("AccountRemovalService: Error: \(error)")
            #endif
            context.rollback()
            throw Failure.saveFailed
        }
        WidgetDataCache.updateCache(context: context)
    }

    /// Escribe las dos mitades del filtro de cuentas de un presupuesto (M2M y espejo CSV) juntas.
    private static func setBudgetAccounts(_ budget: Budget, _ accounts: [Account]) {
        budget.accounts = accounts
        budget.setAccountIDs(from: accounts)
    }

    static func isEligibleDestination(_ account: Account) -> Bool {
        !account.isDeleted && account.modelContext != nil && !account.isArchived && !account.isSystemAccount
    }

    static func draftConverts(_ draft: InboxDraft) -> Bool {
        AccountCurrencyPlanLogic.convertsDraft(.init(
            isPending: draft.status == .pending,
            sourceType: draft.sourceType,
            hasGroupPointer: draft.splitExpenseID != nil
                || draft.splitSettlementID != nil
                || draft.splitGroupZoneID != nil,
            hasAmount: draft.amount != nil
        ))
    }

    private static func pairKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return key.isEmpty ? nil : key
    }

    private static func destinationShape(_ account: Account) -> AccountRemovalLogic.Destination<PersistentIdentifier> {
        .init(id: account.persistentModelID, currencyCode: account.currencyCode)
    }

    /// Las filas que se convierten y las fechas/divisas que la conversión hacia `destination` va a pedir. Las filas
    /// salen de `AccountRemovalLogic.rowConverts`, la misma regla que el veredicto que enseña la hoja.
    private static func rateWork(
        _ inventory: Inventory,
        to destination: Account
    ) -> (rows: [TransactionItem], needs: AccountCurrencyMigrationService.RateNeeds) {
        let target = normalizeCurrencyCode(destination.currencyCode)
        let destinationID = destination.persistentModelID
        let shapes = inventory.shape.rows
        let rows = zip(inventory.transactions, shapes).compactMap { tx, shape -> TransactionItem? in
            guard shape.transferPartnerAccount != destinationID,
                  AccountRemovalLogic.rowConverts(shape, to: target) else { return nil }
            return tx
        }
        var needs = AccountCurrencyMigrationService.RateNeeds()
        let source = normalizeCurrencyCode(inventory.account.currencyCode)
        if source != target {
            let drafts = inventory.pendingDrafts.filter(draftConverts)
            if !drafts.isEmpty {
                needs.currencies.insert(source)
                drafts.forEach { needs.dates.insert($0.date ?? $0.createdAt) }
            }
        }
        for payment in inventory.scheduled
        where AccountCurrencyPlanLogic.convertsScheduledPayment(isGroupPayment: payment.groupZoneID != nil)
            && normalizeCurrencyCode(payment.currencyCode) != target {
            needs.currencies.insert(normalizeCurrencyCode(payment.currencyCode))
        }
        for favorite in inventory.favorites where favorite.amount != nil {
            let code = normalizeCurrencyCode(favorite.currencyCode ?? source)
            if code != target { needs.currencies.insert(code) }
        }
        return (rows, needs)
    }
}
