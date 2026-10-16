//
//  GroupLegEvidence.swift
//  Yala
//
//  Reúne del store lo que `GroupLegKindLogic` necesita para decidir si una pata de grupo SIN cuenta es real o virtual.
//  Ticket `orphaned-group-records-stay-out-of-the-notice`.
//

import Foundation
import SwiftData

/// Lee del store la evidencia de `GroupLegKindLogic` y clasifica transacciones puenteadas.
///
/// Las filas CON cuenta no leen nada: las decide su cuenta. Solo las que no tienen cuenta piden la evidencia, y por eso
/// el caso dominante (ninguna) sale gratis. **Si la lectura falla, toda fila sin cuenta es «no se sabe»**: quien decide
/// con eso no la toca, que es la dirección que no destruye ni materializa nada.
@MainActor
struct GroupLegEvidence {

    /// Subcategorías de sistema que solo llevan patas VIRTUALES (préstamo, cobro, pago de liquidación, saldos iniciales).
    private let virtualSubcategoryIDs: Set<PersistentIdentifier>
    /// «Liquidación enviada»: solo la lleva la pata REAL del Caso C.
    private let settlementSentSubcategoryIDs: Set<PersistentIdentifier>
    /// Evidencia por `splitExpenseID`, de los gastos que siguen aquí.
    private let sources: [String: GroupLegKindLogic.SourceEvidence]
    /// Liquidaciones con un borrador pendiente en la Bandeja (sin contar el aviso de importe cambiado).
    private let settlementsWithPendingDraft: Set<String>
    /// `false` si alguna lectura falló: entonces toda fila sin cuenta es «no se sabe».
    private let isReadable: Bool

    /// Evidencia vacía: toda fila sin cuenta es «no se sabe».
    static let unreadable = GroupLegEvidence(
        virtualSubcategoryIDs: [], settlementSentSubcategoryIDs: [], sources: [:], settlementsWithPendingDraft: [],
        isReadable: false)

    private init(
        virtualSubcategoryIDs: Set<PersistentIdentifier>,
        settlementSentSubcategoryIDs: Set<PersistentIdentifier>,
        sources: [String: GroupLegKindLogic.SourceEvidence],
        settlementsWithPendingDraft: Set<String>,
        isReadable: Bool
    ) {
        self.virtualSubcategoryIDs = virtualSubcategoryIDs
        self.settlementSentSubcategoryIDs = settlementSentSubcategoryIDs
        self.sources = sources
        self.settlementsWithPendingDraft = settlementsWithPendingDraft
        self.isReadable = isReadable
    }

    /// Lee la evidencia para las filas sin cuenta de `transactions`. Nunca lanza: un fallo de lectura da `.unreadable`.
    ///
    /// - Parameter readSources: `false` cuando los gastos ya no existen por definición (el barredor de huérfanas) o se van a
    ///   purgar: entonces solo cuenta la subcategoría.
    static func read(
        for transactions: [TransactionItem],
        context: ModelContext,
        readSources: Bool = true
    ) -> GroupLegEvidence {
        let withoutAccount = transactions.filter {
            $0.account == nil && ($0.splitExpenseID != nil || $0.splitSettlementID != nil)
        }
        guard !withoutAccount.isEmpty else {
            return GroupLegEvidence(
                virtualSubcategoryIDs: [], settlementSentSubcategoryIDs: [], sources: [:], settlementsWithPendingDraft: [],
                isReadable: true)
        }
        do {
            let byRole = try GroupBridgeSystemEntities.subcategoryIDs(
                roles: [.loanToGroups, .loanCollection, .settlementPayment, .settlementSent,
                        .openingBalanceOwed, .openingBalanceDebt],
                context: context)
            var virtualIDs: Set<PersistentIdentifier> = []
            for role in [GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups, .loanCollection,
                         .settlementPayment, .openingBalanceOwed, .openingBalanceDebt] {
                virtualIDs.formUnion(byRole[role] ?? [])
            }
            let sentIDs = byRole[.settlementSent] ?? []
            var sources: [String: GroupLegKindLogic.SourceEvidence] = [:]
            if readSources {
                let expenseIDs = Set(withoutAccount.compactMap { tx -> String? in
                    tx.splitSettlementID == nil ? tx.splitExpenseID : nil
                })
                // Las hermanas se cuentan en memoria, sobre las filas recibidas: los llamadores pasan todas las de las
                // zonas que deciden (el aviso, todas las transacciones), así que la pata real con cuenta está ahí.
                var realAccountExpenseIDs: Set<String> = []
                for tx in transactions where tx.account?.isSystemAccount == false {
                    if let expenseID = tx.splitExpenseID, expenseIDs.contains(expenseID) {
                        realAccountExpenseIDs.insert(expenseID)
                    }
                }
                var memberByZone: [String: String?] = [:]
                for expenseID in expenseIDs {
                    if let source = try sourceEvidence(
                        expenseID: expenseID, siblingHasRealAccount: realAccountExpenseIDs.contains(expenseID),
                        memberByZone: &memberByZone, context: context) {
                        sources[expenseID] = source
                    }
                }
            }
            var pendingSettlements: Set<String> = []
            if withoutAccount.contains(where: { $0.splitSettlementID != nil }) {
                let pending = try context.fetch(FetchDescriptor<InboxDraft>(
                    predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" && $0.splitSettlementID != nil }))
                pendingSettlements = Set(pending.filter { !$0.isSettlementAmountChangeNotice }
                    .compactMap(\.splitSettlementID))
            }
            return GroupLegEvidence(
                virtualSubcategoryIDs: virtualIDs.subtracting(sentIDs),
                settlementSentSubcategoryIDs: sentIDs,
                sources: sources,
                settlementsWithPendingDraft: pendingSettlements,
                isReadable: true)
        } catch {
            #if DEBUG
            print("GroupLegEvidence: lectura fallida, las filas sin cuenta quedan como «no se sabe»: \(error)")
            #endif
            return .unreadable
        }
    }

    /// Qué es esta transacción puenteada.
    func kind(of tx: TransactionItem) -> GroupLegKindLogic.Kind {
        if let account = tx.account { return account.isSystemAccount ? .virtual : .real }
        guard isReadable else { return .unknown }
        return GroupLegKindLogic.classify(shape(of: tx))
    }

    /// La forma pura de la fila, con la evidencia leída.
    func shape(of tx: TransactionItem) -> GroupLegKindLogic.LegShape {
        let isSettlementLeg = tx.splitSettlementID != nil
        let subcategory: GroupLegKindLogic.SubcategoryClass
        if let sub = tx.subcategory {
            let id = sub.persistentModelID
            if settlementSentSubcategoryIDs.contains(id) {
                subcategory = .settlementSent
            } else if virtualSubcategoryIDs.contains(id) {
                subcategory = .otherSystem
            } else {
                subcategory = .user
            }
        } else {
            subcategory = .none
        }
        return GroupLegKindLogic.LegShape(
            accountIsSystem: tx.account.map(\.isSystemAccount),
            subcategory: subcategory,
            isSettlementLeg: isSettlementLeg,
            amount: tx.amount,
            currencyCode: tx.currencyCode,
            source: isSettlementLeg ? nil : tx.splitExpenseID.flatMap { sources[$0] },
            settlementHasPendingDraft: tx.splitSettlementID.map { settlementsWithPendingDraft.contains($0) } ?? false)
    }

    /// Lo que se sabe del gasto, si sigue aquí. Lanza si una lectura falla. El miembro propio se resuelve una vez por
    /// zona.
    private static func sourceEvidence(
        expenseID: String,
        siblingHasRealAccount: Bool,
        memberByZone: inout [String: String?],
        context: ModelContext
    ) throws -> GroupLegKindLogic.SourceEvidence? {
        guard let uuid = UUID(uuidString: expenseID) else { return nil }
        guard let expense = try context.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate<SplitExpense> { $0.id == uuid })).first else { return nil }
        let zone = expense.groupZoneID
        let memberID: String?
        if let cached = memberByZone[zone] {
            memberID = cached
        } else {
            memberID = try GroupExpenseService.resolveCurrentUserMember(inZone: zone, context: context)?.id.uuidString
            memberByZone[zone] = memberID
        }
        return GroupLegKindLogic.SourceEvidence(
            currentUserPaid: memberID == expense.paidByMemberID,
            isOpeningBalance: expense.isOpeningBalance,
            amount: expense.amount,
            currencyCode: expense.currencyCode,
            siblingHasRealAccount: siblingHasRealAccount)
    }
}
