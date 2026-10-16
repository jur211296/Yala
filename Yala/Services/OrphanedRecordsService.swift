//
//  OrphanedRecordsService.swift
//  Yala
//
//  Leer y mover los movimientos que se quedaron sin cuenta.
//  Cards `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw` y `tablero-eliminar-una-cuenta-todavia-puede-dejar-mjzx`.
//

import Foundation
import SwiftData

/// Lee los movimientos sin cuenta y los mueve a la cuenta que la persona elige. Las decisiones viven en
/// `OrphanedRecordsLogic` y `AccountRemovalLogic`; aquí solo se lee el store y se escribe.
///
/// Mismo molde que `AccountRemovalService.move`, con sus mismas razones: todo se lee con `FetchDescriptor` (un fetch que
/// falla LANZA: no es «no hay nada»), **las tasas antes que los importes**, se vuelve a leer y a decidir tras el `await`,
/// y si el guardado falla se deshace todo con `rollback()`.
@MainActor
enum OrphanedRecordsService {

    /// Los movimientos sin cuenta y, de cada uno que sea una pata de transferencia, la OTRA pata si vive en una cuenta
    /// y la pareja es de dos filas exactas (el criterio de `AccountRemovalService.inventory`).
    struct Inventory {
        let transactions: [TransactionItem]
        let outsidePartners: [PersistentIdentifier: TransactionItem]
        /// Patas de una transferencia de dos filas cuyas DOS patas están sin cuenta (se borraron las dos cuentas).
        let pairedWithinOrphans: Set<PersistentIdentifier>

        /// Por fila, en el orden de `transactions`: ¿su pareja también está aquí?
        var pairedFlags: [Bool] { transactions.map { pairedWithinOrphans.contains($0.persistentModelID) } }

        /// Qué pasa al moverlos a `destination` (`OrphanedRecordsLogic.moveOutcome`).
        func outcome(to destination: Account) -> OrphanedRecordsLogic.MoveOutcome {
            OrphanedRecordsLogic.moveOutcome(
                rows: rows, pairedWithinOrphans: pairedFlags,
                to: destination.persistentModelID, currencyCode: destination.currencyCode)
        }

        /// Las filas con la forma de `AccountRemovalLogic`, en el orden de `transactions`.
        var rows: [AccountRemovalLogic.Row<PersistentIdentifier>] {
            transactions.map { tx in
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
            }
        }
    }

    #if DEBUG
    /// Seam de tests: sustituye la petición de tasas, que en el simulador acaba en la red.
    static var prepareRatesOverride: (([TransactionItem], String) async -> Bool)?
    /// Seam de tests: la quietud del import (`SyncQuiescenceCoordinator`), que en el host de test siempre es `true`.
    static var importIsQuiescentOverride: (() -> Bool)?
    #endif

    /// ¿Está quieto el import? Mientras CloudKit o el pull de la nube aplican cambios, un movimiento puede verse sin
    /// cuenta solo porque su cuenta aún no ha llegado: moverlo ahí la reasignaría. El aviso ya espera a esto, pero la
    /// hoja puede quedarse abierta, así que mover vuelve a preguntarlo.
    private static var importIsQuiescent: Bool {
        #if DEBUG
        if let override = importIsQuiescentOverride { return override() }
        #endif
        return SyncQuiescenceCoordinator.shared.isImportQuiescent
    }

    // MARK: - Leer

    /// ¿Este movimiento cuenta como «sin cuenta»? (`OrphanedRecordsLogic.isOrphan`). `legEvidence` dice si una fila de
    /// grupo sin cuenta es la pata real: léela con `GroupLegEvidence.read(for:context:)` sobre las mismas filas.
    static func isOrphan(_ tx: TransactionItem, legEvidence: GroupLegEvidence) -> Bool {
        let hasGroupPointer = tx.splitExpenseID != nil || tx.splitSettlementID != nil
        return OrphanedRecordsLogic.isOrphan(.init(
            hasAccount: tx.account != nil,
            hasGroupPointer: hasGroupPointer,
            groupLegIsProvenReal: hasGroupPointer && tx.account == nil && legEvidence.kind(of: tx) == .real
        ))
    }

    /// Cuántos movimientos se quedaron sin cuenta, sobre movimientos ya leídos (el recuento del aviso del Panel).
    ///
    /// Con el import en marcha no lee la evidencia de grupos: el aviso no sale entonces (`showsNotice`), y es justo cuando
    /// puede haber miles de filas con la cuenta aún sin hidratar.
    static func orphanCount(in all: [TransactionItem], context: ModelContext) -> Int {
        let evidence = importIsQuiescent ? GroupLegEvidence.read(for: all, context: context) : .unreadable
        return all.count(where: { isOrphan($0, legEvidence: evidence) })
    }

    /// Lee todos los movimientos y filtra en memoria: un `#Predicate` sobre la relación es la forma que SwiftData no
    /// garantiza, y un resultado corto aquí escondería justo lo que el aviso viene a enseñar.
    static func inventory(context: ModelContext) throws -> Inventory {
        do {
            let all = try context.fetch(FetchDescriptor<TransactionItem>(
                sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]))
            return inventory(from: all, context: context)
        } catch {
            #if DEBUG
            print("OrphanedRecordsService: Error: \(error)")
            #endif
            throw AccountRemovalService.Failure.unreadable
        }
    }

    /// El inventario sobre movimientos ya leídos.
    ///
    /// Una pata REAL de grupo sin cuenta entra (`GroupLegKindLogic`) y al moverla **conserva sus punteros**: sigue
    /// siendo la pata real de su gasto, y `move` re-puentea el gasto para que el puente la reconozca. Soltarlos haría
    /// que el siguiente re-puente creara otra pata real al lado. Tampoco cambia de divisa: `AccountRemovalLogic.rowConverts`
    /// ya la deja pasar en la suya, como a una transferencia. La de una liquidación no se re-puentea (`bridgeSettlement`
    /// borra todas sus patas, también la movida); por eso solo entra si la Bandeja no pregunta ya por ella.
    static func inventory(from all: [TransactionItem], context: ModelContext) -> Inventory {
        let evidence = GroupLegEvidence.read(for: all, context: context)
        let orphans = all.filter { isOrphan($0, legEvidence: evidence) }
        let pairIDs = Set(orphans.compactMap { pairKey($0.transferPairID) })
        var legsByPair: [String: [TransactionItem]] = [:]
        if !pairIDs.isEmpty {
            for tx in all {
                guard let key = pairKey(tx.transferPairID), pairIDs.contains(key) else { continue }
                legsByPair[key, default: []].append(tx)
            }
        }
        var partners: [PersistentIdentifier: TransactionItem] = [:]
        var pairedInside: Set<PersistentIdentifier> = []
        for tx in orphans {
            guard let key = pairKey(tx.transferPairID), let legs = legsByPair[key], legs.count == 2,
                  let other = legs.first(where: { $0.persistentModelID != tx.persistentModelID }) else { continue }
            if other.account != nil {
                partners[tx.persistentModelID] = other
            } else if isOrphan(other, legEvidence: evidence) {
                pairedInside.insert(tx.persistentModelID)
            }
        }
        return Inventory(transactions: orphans, outsidePartners: partners, pairedWithinOrphans: pairedInside)
    }

    /// Las cuentas a las que se puede mover: las del usuario, sin archivadas ni las de sistema de Grupos.
    static func destinations(context: ModelContext) throws -> [Account] {
        do {
            return try context.fetch(FetchDescriptor<Account>())
                .filter(AccountRemovalService.isEligibleDestination)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            #if DEBUG
            print("OrphanedRecordsService: Error: \(error)")
            #endif
            throw AccountRemovalService.Failure.unreadable
        }
    }

    // MARK: - Mover

    /// Mueve a `destination` los movimientos de `confirmedIDs` que SIGUEN sin cuenta.
    ///
    /// **Solo los que la persona vio**: mientras la hoja estaba abierta el sync pudo traer más huérfanos (salen en el
    /// siguiente aviso) o devolverle la cuenta a alguno (ese ya no se toca).
    ///
    /// Con otra moneda, **las tasas antes que los importes** (`AccountCurrencyMigrationService.prepareRates`), y tras el
    /// `await` se vuelve a leer y a decidir, también el destino y la quietud del import. Una transferencia cuya otra pata
    /// ya está en el destino, o cuyas dos patas están sin cuenta, se quita entera (dentro de una cuenta no mueve dinero);
    /// una transferencia en otra moneda pasa tal cual; un saldo inicial pasa a ajuste: la cuenta destino ya tiene el
    /// suyo. Son las reglas de `AccountRemovalService.move`, sin su bloqueo por moneda (`OrphanedRecordsLogic.moveOutcome`).
    ///
    /// - Returns: cuántos movimientos quedaron en `destination` (los quitados por transferencia no cuentan).
    @discardableResult
    static func move(
        _ confirmedIDs: Set<PersistentIdentifier>,
        to destination: Account,
        context: ModelContext
    ) async throws -> Int {
        let target = destination.currencyCode
        guard AccountRemovalService.isEligibleDestination(destination) else {
            throw AccountRemovalService.Failure.noLongerAllowed
        }
        guard importIsQuiescent else { throw AccountRemovalService.Failure.noLongerAllowed }
        let before = try selection(confirmedIDs, context: context)
        guard !before.transactions.isEmpty else { throw AccountRemovalService.Failure.noLongerAllowed }

        let rates = rowsToConvert(before, to: destination)
        if !rates.isEmpty {
            let ready: Bool
            #if DEBUG
            if let override = prepareRatesOverride {
                ready = await override(rates, target)
            } else {
                ready = await AccountCurrencyMigrationService.prepareRates(rows: rates, to: target, context: context)
            }
            #else
            ready = await AccountCurrencyMigrationService.prepareRates(rows: rates, to: target, context: context)
            #endif
            guard ready else { throw AccountRemovalService.Failure.ratesUnavailable }
        }

        guard AccountRemovalService.isEligibleDestination(destination), importIsQuiescent else {
            throw AccountRemovalService.Failure.noLongerAllowed
        }
        let inventory = try selection(confirmedIDs, context: context)
        guard !inventory.transactions.isEmpty else { throw AccountRemovalService.Failure.noLongerAllowed }
        let convert = rowsToConvert(inventory, to: destination)
        guard AccountCurrencyMigrationService.missingRateDates(rows: convert, to: target, context: context).isEmpty
        else { throw AccountRemovalService.Failure.ratesUnavailable }

        let destinationID = destination.persistentModelID
        var moving: [TransactionItem] = []
        for tx in inventory.transactions {
            if inventory.pairedWithinOrphans.contains(tx.persistentModelID) {
                // Las dos patas sin cuenta: acabarían las dos en el destino. Cada una se borra en su vuelta.
                context.delete(tx)
            } else if let partner = inventory.outsidePartners[tx.persistentModelID],
               partner.account?.persistentModelID == destinationID {
                context.delete(partner)
                context.delete(tx)
            } else {
                moving.append(tx)
            }
        }
        AccountCurrencyMigrationService.convertHistory(rows: convert, to: target, context: context)
        for tx in moving {
            tx.account = destination
            if tx.balanceAdjustmentType == InitialBalanceService.typeInitialBalance {
                tx.balanceAdjustmentType = InitialBalanceService.typeAdjustment
            }
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("OrphanedRecordsService: Error: \(error)")
            #endif
            context.rollback()
            throw AccountRemovalService.Failure.saveFailed
        }
        rebridgeMovedGroupExpenses(moving, context: context)
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
        return moving.count
    }

    /// Re-puentea los gastos de las patas reales de grupo que se acaban de mover.
    ///
    /// **Por qué.** Mientras la pata real estaba sin cuenta, cualquier re-puente la ignoró (`bridgeExpense` busca la real
    /// por su cuenta) y dejó un borrador «¿de qué cuenta salió?» en la Bandeja, y con el puente apagado una virtual
    /// `-miParte` en vez del préstamo. Si la persona aprobaba después ese borrador, el gasto contaba dos veces (review
    /// adversarial del 2026-10-16). Con la pata ya en su cuenta, el re-puente la encuentra como real, retira el borrador
    /// y rehace las virtuales. Best-effort: si falla, el siguiente re-puente del gasto hace lo mismo.
    private static func rebridgeMovedGroupExpenses(_ moved: [TransactionItem], context: ModelContext) {
        let expenseIDs = Set(moved.compactMap { $0.splitSettlementID == nil ? $0.splitExpenseID : nil })
        guard !expenseIDs.isEmpty else { return }
        for expenseID in expenseIDs.sorted() {
            guard let uuid = UUID(uuidString: expenseID) else { continue }
            do {
                guard let expense = try context.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate<SplitExpense> { $0.id == uuid })).first else { continue }
                let zone = expense.groupZoneID
                guard let group = try context.fetch(FetchDescriptor<SplitGroup>(
                    predicate: #Predicate<SplitGroup> { $0.cloudKitZoneID == zone })).first else { continue }
                _ = try GroupTransactionBridge.shared.bridgeExpense(expense, in: group, isRemoteSync: true)
            } catch {
                #if DEBUG
                print("OrphanedRecordsService: re-puente del gasto movido falló, lo hará el siguiente: \(error)")
                #endif
            }
        }
    }

    // MARK: - Piezas

    /// El inventario de ahora, recortado a lo que la persona confirmó.
    private static func selection(
        _ confirmedIDs: Set<PersistentIdentifier>,
        context: ModelContext
    ) throws -> Inventory {
        let now = try inventory(context: context)
        let kept = now.transactions.filter { confirmedIDs.contains($0.persistentModelID) }
        let keptIDs = Set(kept.map(\.persistentModelID))
        // Una pata «emparejada dentro» solo se quita si su pareja también se confirmó: si no, se mueve sola.
        let pairedInside = now.pairedWithinOrphans.filter { id in
            guard keptIDs.contains(id), let tx = kept.first(where: { $0.persistentModelID == id }),
                  let key = pairKey(tx.transferPairID) else { return false }
            return kept.contains { $0.persistentModelID != id && pairKey($0.transferPairID) == key }
        }
        return Inventory(
            transactions: kept,
            outsidePartners: now.outsidePartners.filter { keptIDs.contains($0.key) },
            pairedWithinOrphans: pairedInside)
    }

    /// Las filas que se convierten hacia `destination`: la misma regla que `OrphanedRecordsLogic.moveOutcome`
    /// (`rowConverts`), sin las que se quitan por transferencia.
    private static func rowsToConvert(_ inventory: Inventory, to destination: Account) -> [TransactionItem] {
        let target = normalizeCurrencyCode(destination.currencyCode)
        let destinationID = destination.persistentModelID
        return zip(inventory.transactions, inventory.rows).compactMap { tx, row in
            guard !inventory.pairedWithinOrphans.contains(tx.persistentModelID),
                  row.transferPartnerAccount != destinationID,
                  AccountRemovalLogic.rowConverts(row, to: target) else { return nil }
            return tx
        }
    }

    private static func pairKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return key.isEmpty ? nil : key
    }
}
