//
//  AccountLinkReemit.swift
//  Yala
//
//  Tarjeta con varias divisas + `SyncCapability`: lo que hace el teléfono cuando pasa de hablar `v1` a hablar una
//  versión que conoce `accounts.parent_account_id`. Mientras hablaba `v1`:
//   (a) lo que BAJÓ llegó proyectado sin la columna, y el cursor ya pasó de largo: aquí puede haber una línea que
//       se lee suelta porque otro teléfono la vinculó;
//   (b) lo que ESTE teléfono cambió en la columna no subió (la emisión la filtra, a propósito: el Worker viejo
//       rechazaría la fila entera). Quien la filtró lo apuntó (`SyncCapability.noteSuppressedAccountLink`).
//
//  Al subir, en este orden y antes de pedir la página siguiente:
//   1. se encola (b): una fila por cuenta apuntada, con SOLO esa columna. En el outbox, el guard del apply (D-1)
//      protege su unidad de lo que baje;
//   2. el cursor del pull vuelve a 0: el re-pull con la versión nueva repone (a). Es el mismo re-pull completo que
//      la remediación del Merkle, una vez en la vida del teléfono;
//   3. se retira la petición.
//  Si (1) o (2) fallan, la petición se queda y el pull se corta: re-bajar sin haber encolado (b) pisaría esos
//  enlaces con el valor del servidor, que no los tiene.
//
//  Desde la v3 (UX 2.2 · L18-8) hace lo mismo con los cambios de monto «desde este mes» de las líneas del flujo de
//  caja (`cashflow_lines.amount_changes_raw`), apuntados por `SyncCapability.noteSuppressedCashFlowAmountChange`.
//  Y desde la v4 (card da5d), con el destino de los favoritos de transferencia (`favorite_payments.destination_account_ref`).
//  Y desde la v5 (card nmtk), con el día de corte y los días de aviso de una tarjeta (`accounts.credit_card_statement_day`,
//  `accounts.credit_card_reminder_days_before`).
//  Y desde la v6 (Grupos B, card 1), con la receta de líneas de tu parte de un gasto de grupo (`tx_items.split_lines_raw`).
//
//  Por qué no «reemitir toda cuenta con enlace»: subiría con un HLC fresco copias de lo que bajó antes de que otro
//  teléfono lo cambiara, y le ganaría por LWW a ese cambio más nuevo (lo cazó la review).
//
//  Residual aceptado: lo apuntado sale con el HLC de AHORA, no el de cuando se hizo (`enqueueSnapshotRows` estampa con
//  `send(now)`). Si en esa ventana otro teléfono cambió el MISMO enlace, gana el de este. Solo existe si la app habló
//  `v1` con enlaces creados, es decir, si la app salió antes que el Worker.
//

import Foundation
import SwiftData

extension CloudSyncEngine {

    /// Cumple la subida de versión si está pedida (`SyncCapability.upgradePending`) y el teléfono ya habla una
    /// versión que conoce los enlaces. Devuelve `true` si la cumplió. LANZA si no pudo leer, encolar o mover el
    /// cursor: entonces la petición sigue puesta y quien llama no debe aplicar nada (el bucle del pull se corta).
    @discardableResult
    func applyCapabilityUpgradeIfPending(context: ModelContext, now: Date = .now) throws -> Bool {
        guard SyncCapability.upgradeDue else { return false }
        let level = SyncCapability.declaredLevel

        let pendingIDs = SyncCapability.suppressedAccountLinks
        var reemitted = 0
        if !pendingIDs.isEmpty {
            let accounts = try context.fetch(FetchDescriptor<Account>()).filter { pendingIDs.contains($0.shortcutID) }
            let emission = EntityEmissionMap.account
            let groupedColumns = Set(emission.groupByColumn.keys)
            let inputs = accounts.map { account in
                SnapshotRowInput(syncID: account.shortcutID, entityType: SyncEntityType.account) { hlc in
                    let result = DeltaEmitter.emit(model: account, emission: emission,
                                                   changedColumns: ["parent_account_id"], hlc: hlc,
                                                   capabilityLevel: level)
                    do {
                        let fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: groupedColumns)
                        return (fieldsJSON, self.encodeFieldHlcs(result.fieldHlcs))
                    } catch {
                        #if DEBUG
                        print("CloudSyncEngine.applyCapabilityUpgrade: codec c1 rechazó la fila: \(error)")
                        #endif
                        CloudSyncBreadcrumb.encodeRejected(entity: SyncEntityType.account, reason: "linkReemit:\(error)")
                        return nil
                    }
                }
            }
            try enqueueSnapshotRows(inputs, context: context, now: now)
            reemitted = inputs.count
        }

        // Los cambios de monto «desde este mes» del flujo de caja (v3, UX 2.2 · L18-8), con el mismo molde. Solo si el
        // teléfono ya habla la versión que los conoce: con un Worker vuelto atrás a la v2 la columna no viajaría y lo
        // apuntado se queda para la subida siguiente.
        let pendingLineIDs = level >= SyncCapability.cashFlowAmountChangesSince
            ? SyncCapability.suppressedCashFlowAmountChanges : []
        if !pendingLineIDs.isEmpty {
            let lines = try context.fetch(FetchDescriptor<CashFlowLine>()).filter { pendingLineIDs.contains($0.id) }
            let emission = EntityEmissionMap.cashFlowLine
            let groupedColumns = Set(emission.groupByColumn.keys)
            let inputs = lines.map { line in
                SnapshotRowInput(syncID: line.id, entityType: SyncEntityType.cashFlowLine) { hlc in
                    let result = DeltaEmitter.emit(model: line, emission: emission,
                                                   changedColumns: ["amount_changes_raw"], hlc: hlc,
                                                   capabilityLevel: level)
                    do {
                        let fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: groupedColumns)
                        return (fieldsJSON, self.encodeFieldHlcs(result.fieldHlcs))
                    } catch {
                        #if DEBUG
                        print("CloudSyncEngine.applyCapabilityUpgrade: codec c1 rechazó la línea: \(error)")
                        #endif
                        CloudSyncBreadcrumb.encodeRejected(entity: SyncEntityType.cashFlowLine,
                                                           reason: "amountChangesReemit:\(error)")
                        return nil
                    }
                }
            }
            try enqueueSnapshotRows(inputs, context: context, now: now)
            reemitted += inputs.count
        }

        // El destino de un favorito de transferencia (v4, card da5d), con el mismo molde.
        let pendingFavoriteIDs = level >= SyncCapability.favoriteDestinationSince
            ? SyncCapability.suppressedFavoriteDestinations : []
        if !pendingFavoriteIDs.isEmpty {
            let favorites = try context.fetch(FetchDescriptor<FavoritePayment>()).filter {
                $0.syncID.map(pendingFavoriteIDs.contains) ?? false
            }
            let emission = EntityEmissionMap.favoritePayment
            let groupedColumns = Set(emission.groupByColumn.keys)
            let inputs: [SnapshotRowInput] = favorites.compactMap { favorite in
                guard let syncID = favorite.syncID else { return nil }
                return SnapshotRowInput(syncID: syncID, entityType: SyncEntityType.favoritePayment) { hlc in
                    let result = DeltaEmitter.emit(model: favorite, emission: emission,
                                                   changedColumns: ["destination_account_ref"], hlc: hlc,
                                                   capabilityLevel: level)
                    do {
                        let fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: groupedColumns)
                        return (fieldsJSON, self.encodeFieldHlcs(result.fieldHlcs))
                    } catch {
                        #if DEBUG
                        print("CloudSyncEngine.applyCapabilityUpgrade: codec c1 rechazó el favorito: \(error)")
                        #endif
                        CloudSyncBreadcrumb.encodeRejected(entity: SyncEntityType.favoritePayment,
                                                           reason: "favoriteDestinationReemit:\(error)")
                        return nil
                    }
                }
            }
            try enqueueSnapshotRows(inputs, context: context, now: now)
            reemitted += inputs.count
        }

        // El día de corte y los días de aviso de una tarjeta (v5, card nmtk), con el mismo molde.
        // Por columna: solo sube la que este teléfono cambió, o pisaría la del otro (`SyncCapability`).
        let pendingCycles = level >= SyncCapability.creditCardCycleSince
            ? SyncCapability.suppressedCreditCardCycles : [:]
        if !pendingCycles.isEmpty {
            let accounts = try context.fetch(FetchDescriptor<Account>()).filter { pendingCycles[$0.shortcutID] != nil }
            let emission = EntityEmissionMap.account
            let groupedColumns = Set(emission.groupByColumn.keys)
            let inputs = accounts.map { account in
                SnapshotRowInput(syncID: account.shortcutID, entityType: SyncEntityType.account) { hlc in
                    let result = DeltaEmitter.emit(model: account, emission: emission,
                                                   changedColumns: pendingCycles[account.shortcutID] ?? [], hlc: hlc,
                                                   capabilityLevel: level)
                    do {
                        let fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: groupedColumns)
                        return (fieldsJSON, self.encodeFieldHlcs(result.fieldHlcs))
                    } catch {
                        #if DEBUG
                        print("CloudSyncEngine.applyCapabilityUpgrade: codec c1 rechazó la tarjeta: \(error)")
                        #endif
                        CloudSyncBreadcrumb.encodeRejected(entity: SyncEntityType.account,
                                                           reason: "creditCardCycleReemit:\(error)")
                        return nil
                    }
                }
            }
            try enqueueSnapshotRows(inputs, context: context, now: now)
            reemitted += inputs.count
        }

        // La receta de líneas de tu parte de un gasto de grupo (v6, Grupos B · card 1), con el mismo molde.
        let pendingSplitLines = level >= SyncCapability.splitLinesSince ? SyncCapability.suppressedSplitLines : []
        if !pendingSplitLines.isEmpty {
            let items = try context.fetch(FetchDescriptor<TransactionItem>()).filter {
                $0.syncID.map(pendingSplitLines.contains) ?? false
            }
            let emission = EntityEmissionMap.transactionItem
            let groupedColumns = Set(emission.groupByColumn.keys)
            let inputs: [SnapshotRowInput] = items.compactMap { item in
                guard let syncID = item.syncID else { return nil }
                return SnapshotRowInput(syncID: syncID, entityType: SyncEntityType.transactionItem) { hlc in
                    let result = DeltaEmitter.emit(model: item, emission: emission,
                                                   changedColumns: ["split_lines_raw"], hlc: hlc,
                                                   capabilityLevel: level)
                    do {
                        let fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: groupedColumns)
                        return (fieldsJSON, self.encodeFieldHlcs(result.fieldHlcs))
                    } catch {
                        #if DEBUG
                        print("CloudSyncEngine.applyCapabilityUpgrade: codec c1 rechazó el movimiento: \(error)")
                        #endif
                        CloudSyncBreadcrumb.encodeRejected(entity: SyncEntityType.transactionItem,
                                                           reason: "splitLinesReemit:\(error)")
                        return nil
                    }
                }
            }
            try enqueueSnapshotRows(inputs, context: context, now: now)
            reemitted += inputs.count
        }

        let cursor = try loadOrCreateCursor(context)
        if cursor.serverSeqCursor != 0 {
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                cursor.serverSeqCursor = 0
            }
        }
        // Lo apuntado de cuentas que ya no existen se retira igual: no hay nada que subir de ellas.
        SyncCapability.clearSuppressedAccountLinks(pendingIDs)
        SyncCapability.clearSuppressedCashFlowAmountChanges(pendingLineIDs)
        SyncCapability.clearSuppressedFavoriteDestinations(pendingFavoriteIDs)
        SyncCapability.clearSuppressedCreditCardCycles(pendingCycles)
        SyncCapability.clearSuppressedSplitLines(pendingSplitLines)
        SyncCapability.upgradePending = false
        CloudSyncBreadcrumb.capabilityUpgradeApplied(reemittedLinks: reemitted)
        return true
    }
}
