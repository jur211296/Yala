//
//  GroupTransactionBridge+Receivables.swift
//  Yala
//
//  Grupos B · card 10: el ingreso de una venta cuenta con la fecha del pago. Qué parte de cada venta está cobrada lo decide
//  `GroupReceivableCoverageLogic` (tu saldo en el grupo, lo más antiguo primero); aquí se escribe en tus cuentas:
//
//    · la pata POR COBRAR (`balanceAdjustmentType = "receivable"`, card 8) guarda solo lo que falta; sin nada pendiente,
//      no hay pata;
//    · cada parte cobrada es una pata de INGRESO normal en «Grupos», con la categoría de la venta, la fecha del movimiento
//      que la cubrió y la marca `{"k":"c","of":<movimiento>,"v":1}` en `splitLinesRaw`. Estadísticas la cuenta ese día.
//
//  «Grupos» suma lo mismo que antes (por cobrar + cobrado = lo que te debían), así que sigue coincidiendo con el saldo del
//  grupo, y la liquidación de siempre no cambia.
//
//  UNA PASADA POR GRUPO. Lo cobrado de una venta depende de TODO el grupo (un almuerzo que pagó otro también baja tu
//  saldo), así que `reconcileReceivables` corre al final de cada puente de gasto o de liquidación del grupo y de cada
//  borrado, y rehace todas las ventas del grupo. Si el grupo no tiene ninguna pata de venta, no lee nada más.
//
//  IDENTIDAD. Una parte cobrada se identifica por (venta, movimiento) en su marca, no por su fila: cada aparato que repasa
//  antes de recibir la del otro crea la suya, y al sincronizarse hay dos. El repaso siguiente de esa zona funde las copias
//  y conserva la misma en los dos (`GroupSplitLinesBridgeLogic.survivorFirst`). Para que ese repaso no espere a la
//  próxima actividad del grupo, `reconcileAllReceivables` repasa cada grupo con ventas al volver a primer plano.
//
//  LOTES. En un lote (pull de Grupos, reintento del arranque, importar el historial) el repaso se aplaza al final y corre
//  una vez por grupo (`batchingReceivables`): repasar en cada gasto leería el grupo entero N veces.
//
//  PUERTA. Con el dominio de Grupos cerrado (`isDomainOpenForBridge`) el repaso no escribe: también lo llaman los
//  borrados, que esa puerta no frena.
//

import Foundation
import OSLog
import SwiftData

extension GroupTransactionBridge {

    private static var receivablesLogger: Logger { Logger(subsystem: "com.yala", category: "GroupBridge") }

    /// El repaso de lo cobrado del grupo `zoneID`: ahora, o al final del lote en curso.
    func reconcileReceivablesOrDefer(zoneID: String, context: ModelContext) throws {
        if receivableBatchZones != nil {
            receivableBatchZones?.insert(zoneID)
        } else {
            try reconcileReceivables(zoneID: zoneID, context: context)
        }
    }

    /// Ejecuta `body` (un lote de puentes) y repasa lo cobrado una vez por grupo al terminar, antes del `save()` de quien
    /// llama. Dentro de otro lote, solo ejecuta `body`: el repaso es del lote de fuera.
    func batchingReceivables<T>(context: ModelContext, _ body: () throws -> T) throws -> T {
        guard receivableBatchZones == nil else { return try body() }
        receivableBatchZones = []
        let result: T
        do {
            result = try body()
        } catch {
            receivableBatchZones = nil
            throw error
        }
        let zones = receivableBatchZones ?? []
        receivableBatchZones = nil
        for zone in zones.sorted() { try reconcileReceivables(zoneID: zone, context: context) }
        return result
    }

    /// Repasa lo cobrado de todos los grupos con alguna pata de venta y guarda si algo cambió. Lo llama el arranque al
    /// volver a primer plano: funde las copias que dos aparatos escribieron a la vez y recoge lo que un camino sin repaso
    /// dejó atrás. Sin patas de venta no lee nada más que dos consultas.
    func reconcileAllReceivables() {
        guard Self.isDomainOpenForBridge(), let context = contextForReceivables else { return }
        do {
            let receivableRaw = TransactionItem.adjustmentTypeReceivable
            let receivables = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate {
                $0.balanceAdjustmentType == receivableRaw
            }))
            let marked = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate {
                $0.splitLinesRaw != nil
            })).filter { GroupCollectedLegLogic.isCollected($0.splitLinesRaw) }
            let zones = Set((receivables + marked).compactMap(\.splitGroupZoneID).filter { !$0.isEmpty })
            guard !zones.isEmpty else { return }
            for zone in zones.sorted() { try reconcileReceivables(zoneID: zone, context: context) }
            guard context.hasChanges else { return }
            try context.save()
            SessionState.shared.incrementDataVersion()
            WidgetDataCache.updateCache(context: context)
        } catch {
            // Sin `rollback()`: el contexto es el compartido de la app. Lo escrito a medias se guarda en el siguiente
            // `save()`, y el repaso siguiente lo corrige.
            #if DEBUG
            Self.receivablesLogger.error("reconcileAllReceivables: Error: \(error)")
            #endif
        }
    }

    /// Las patas de venta de un grupo que escribe esta pasada: las por cobrar y las cobradas.
    static func saleLegs(inZone zoneID: String, context: ModelContext) throws -> [TransactionItem] {
        let receivableRaw = TransactionItem.adjustmentTypeReceivable
        let receivables = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate {
            $0.splitGroupZoneID == zoneID && $0.balanceAdjustmentType == receivableRaw
        }))
        let marked = try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate {
            $0.splitGroupZoneID == zoneID && $0.splitLinesRaw != nil
        })).filter { GroupCollectedLegLogic.isCollected($0.splitLinesRaw) }
        return (receivables + marked).filter { !$0.isDeleted }
    }

    /// Rehace lo por cobrar y lo cobrado de todas las ventas del grupo `zoneID`. No guarda: lo hace quien llama, en el mismo
    /// `save()` que el puente que la dispara.
    ///
    /// - Parameters:
    ///   - excludingExpenses: gastos que se están borrando en este mismo gesto (aún en el store).
    ///   - excludingSettlements: liquidaciones que se están borrando en este mismo gesto.
    func reconcileReceivables(
        zoneID: String,
        excludingExpenses: Set<UUID> = [],
        excludingSettlements: Set<UUID> = [],
        context: ModelContext
    ) throws {
        // Con el dominio cerrado no se escribe nada en el corpus personal (ver «PUERTA» arriba).
        guard Self.isDomainOpenForBridge() else { return }
        let legs = try Self.saleLegs(inZone: zoneID, context: context)
        guard !legs.isEmpty else { return }

        let group = try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
            .first
        guard let group, !group.isHiddenForAll else { return }
        guard let me = try GroupExpenseService.resolveCurrentUserMember(inZone: zoneID, context: context),
              me.isActive else { return }
        let memberID = me.id.uuidString

        let expenses = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneID }))
            .filter { !excludingExpenses.contains($0.id) }
        let shares = try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneID }))
        let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate {
            $0.groupZoneID == zoneID
        })).filter { !excludingSettlements.contains($0.id) }
        let sharesByExpense = Dictionary(grouping: shares, by: \.expenseID)

        // Qué gastos son ventas: los mismos que decide `bridgeExpense` (pagaste tú y la categoría es de ingreso).
        var subcategoryByName: [String: Subcategory?] = [:]
        func subcategory(named name: String?) -> Subcategory? {
            guard let name else { return nil }
            if let cached = subcategoryByName[name] { return cached }
            let found = GroupTransactionBridge.matchSubcategory(name: name, context: context)
            subcategoryByName[name] = found
            return found
        }
        var sales: [UUID: SplitExpense] = [:]
        var inputs: [GroupReceivableCoverageLogic.ExpenseInput] = []
        for expense in expenses {
            var isSale = false
            if expense.paidByMemberID == memberID, !expense.isOpeningBalance {
                let matched = subcategory(named: expense.subcategoryName)
                isSale = GroupSaleBridgeLogic.isSale(
                    isCaseA: true, subcategoryIsIncome: matched.map { $0.safeCategory.isIncome },
                    subcategoryIsSystem: matched?.isAnySystem == true)
            }
            if isSale { sales[expense.id] = expense }
            inputs.append(.init(
                id: expense.id, date: expense.date, amount: expense.amount, currencyCode: expense.currencyCode,
                paidByMemberID: expense.paidByMemberID, isSettled: expense.isSettled,
                shares: (sharesByExpense[expense.id] ?? []).map { .init(memberID: $0.memberID, amount: $0.amount) },
                isSale: isSale))
        }
        let settlementInputs = settlements.map {
            GroupReceivableCoverageLogic.SettlementInput(
                id: $0.id, date: $0.date, amount: $0.amount, currencyCode: $0.currencyCode,
                fromMemberID: $0.fromMemberID, toMemberID: $0.toMemberID, isConfirmed: $0.isConfirmed)
        }

        // Con «deudas en una sola moneda» el grupo neta todas las divisas, y un pago en otra cubre la venta con el tipo de
        // cambio del día del pago (decisión A, 2026-11-02). Sin la opción, cada divisa va por su lado.
        let events = GroupReceivableCoverageLogic.events(
            for: memberID, currencyCode: nil, expenses: inputs, settlements: settlementInputs)
        let convert: GroupReceivableCoverageLogic.Convert? = group.showDebtsInSingleCurrency
            ? { amount, from, to, date in Self.convertAtPaymentDay(amount, from: from, to: to, on: date, context: context) }
            : nil
        let coverage = GroupReceivableCoverageLogic.coverage(of: events, convert: convert)

        // Las patas de venta que ya no son de ninguna venta (el gasto dejó de serlo o se está borrando). Las de un gasto
        // que ya no está en el store las recoge su borrado o el barrido de huérfanas.
        let existingExpenseIDs = Set(expenses.map(\.id.uuidString))
        let legsBySale = Dictionary(grouping: legs) { $0.splitExpenseID ?? "" }
        for (saleID, saleLegs) in legsBySale {
            guard let uuid = UUID(uuidString: saleID), coverage[uuid] == nil else { continue }
            let stillExists = existingExpenseIDs.contains(saleID)
            let excluded = excludingExpenses.contains(uuid)
            guard stillExists || excluded else { continue }
            // También una venta en la que nadie te debe nada: ni por cobrar ni cobrado.
            for leg in saleLegs { context.delete(leg) }
        }

        for (saleID, saleCoverage) in coverage {
            guard let sale = sales[saleID] else { continue }
            try writeSaleLegs(
                sale: sale, coverage: saleCoverage, existing: legsBySale[saleID.uuidString] ?? [],
                saleSubcategory: subcategory(named: sale.subcategoryName), group: group, context: context)
        }
    }

    /// La pata por cobrar y las cobradas de UNA venta, actualizadas en sitio.
    private func writeSaleLegs(
        sale: SplitExpense,
        coverage: GroupReceivableCoverageLogic.Coverage,
        existing: [TransactionItem],
        saleSubcategory: Subcategory?,
        group: SplitGroup,
        context: ModelContext
    ) throws {
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: sale.currencyCode, colorHint: group.colorHex, context: context)
        let note = sale.expenseDescription.isEmpty ? nil : sale.expenseDescription

        func shape(_ leg: TransactionItem, amount: Double, date: Date, adjustmentType: String?, marker: String?) {
            if leg.amount != amount { leg.amount = amount }
            if leg.date != date { leg.date = date }
            if leg.note != note { leg.note = note }
            if leg.currencyCode != sale.currencyCode { leg.currencyCode = sale.currencyCode }
            if leg.account?.persistentModelID != virtualAccount.persistentModelID { leg.account = virtualAccount }
            if leg.subcategory?.persistentModelID != saleSubcategory?.persistentModelID {
                leg.subcategory = saleSubcategory
                leg.category = saleSubcategory?.safeCategory
            }
            if leg.balanceAdjustmentType != adjustmentType { leg.balanceAdjustmentType = adjustmentType }
            if leg.splitLinesRaw != marker { leg.splitLinesRaw = marker }
            if leg.transferPairID != nil { leg.transferPairID = nil }
            if leg.splitExpenseID != sale.id.uuidString { leg.splitExpenseID = sale.id.uuidString }
            if leg.splitGroupZoneID != sale.groupZoneID { leg.splitGroupZoneID = sale.groupZoneID }
            if leg.splitTotalAmount != sale.amount { leg.splitTotalAmount = sale.amount }
            if leg.splitType != sale.splitType { leg.splitType = sale.splitType }
            leg.recalculatePreferredCurrency(context: context)
        }

        func newLeg(amount: Double, date: Date) -> TransactionItem {
            let leg = TransactionItem(
                date: date, amount: amount, currencyCode: sale.currencyCode, note: note,
                category: saleSubcategory?.safeCategory, subcategory: saleSubcategory, account: virtualAccount)
            context.insert(leg)
            return leg
        }

        // Lo que falta: en la pata por cobrar, con la fecha de la venta.
        let receivables = existing
            .filter { GroupSaleBridgeLogic.isReceivable($0.balanceAdjustmentType) }
            .sorted(by: GroupSplitLinesBridgeLogic.survivorFirst)
        let remaining = coverage.remaining
        if remaining > GroupReceivableCoverageLogic.epsilon {
            let amount = GroupReceivableCoverageLogic.double(remaining)
            let leg = receivables.first ?? newLeg(amount: amount, date: sale.date)
            shape(leg, amount: amount, date: sale.date,
                  adjustmentType: TransactionItem.adjustmentTypeReceivable, marker: nil)
            for duplicate in receivables.dropFirst() { context.delete(duplicate) }
        } else {
            for leg in receivables { context.delete(leg) }
        }

        // Lo cobrado: una pata por movimiento que cubrió la venta, con su fecha.
        let collected = existing.filter { GroupCollectedLegLogic.isCollected($0.splitLinesRaw) }
        let byEvent = Dictionary(grouping: collected) { GroupCollectedLegLogic.collectedEventID($0.splitLinesRaw) }
        var wanted: Set<UUID> = []
        for portion in coverage.collected where portion.amount > GroupReceivableCoverageLogic.epsilon {
            wanted.insert(portion.eventID)
            let amount = GroupReceivableCoverageLogic.double(portion.amount)
            let copies = (byEvent[portion.eventID] ?? []).sorted(by: GroupSplitLinesBridgeLogic.survivorFirst)
            let leg = copies.first ?? newLeg(amount: amount, date: portion.date)
            shape(leg, amount: amount, date: portion.date, adjustmentType: nil,
                  marker: GroupSplitLinesRecipe.encodeCollectedMarker(eventID: portion.eventID))
            for duplicate in copies.dropFirst() { context.delete(duplicate) }
        }
        for leg in collected {
            guard let eventID = GroupCollectedLegLogic.collectedEventID(leg.splitLinesRaw), !wanted.contains(eventID)
            else { continue }
            context.delete(leg)
        }

        #if DEBUG
        Self.receivablesLogger.info(
            "reconcileReceivables sale=\(sale.id.uuidString, privacy: .public) owed=\(coverage.owed, privacy: .public) collectedParts=\(coverage.collected.count, privacy: .public)")
        #endif
    }

    /// Un importe de un movimiento del grupo en otra divisa, con el tipo de cambio del día del pago (su mediodía, como
    /// lee las tasas `BalanceValuation.rateDay`). Es la misma conversión que propone el «Sugerido» de la liquidación
    /// (`SettlementFormView.suggestedAmount`): pagar lo sugerido cubre la venta entera.
    static func convertAtPaymentDay(
        _ amount: Decimal, from: String, to: String, on date: Date, context: ModelContext
    ) -> Decimal {
        CurrencyConverter.shared.convert(
            amount, from: from, to: to, on: BalanceValuation.rateDay(of: date, calendar: .current), context: context)
    }

    /// Las zonas de unas patas que se van a borrar: las que hay que repasar después.
    static func zones(of legs: [TransactionItem]) -> Set<String> {
        Set(legs.compactMap(\.splitGroupZoneID).filter { !$0.isEmpty })
    }
}
