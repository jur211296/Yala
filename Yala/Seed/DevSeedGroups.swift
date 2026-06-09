//
//  DevSeedGroups.swift
//  Yala
//
//  Seed dev de un grupo de gastos compartidos (perfil `.grupos`). Datos LOCALES
//  (sin CKShare ni zona real): los modelos Split* se enlazan por IDs string
//  (groupZoneID / memberID / expenseID), así que el tab Grupos los muestra desde
//  SwiftData directo. El sync (SplitSyncManager) está gateado en modo uitest, por
//  lo que estos records no se suben a CloudKit.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroups {
    static func create(in context: ModelContext) {
        // 1. Grupo (yo soy owner)
        let group = SplitGroup(
            name: "Viaje a Cusco",
            iconName: "airplane",
            currencyCode: "PEN",
            isOwner: true
        )
        context.insert(group)
        let zoneID = group.cloudKitZoneID

        // 2. Miembros: tú + 2 amigos (todos activos)
        let me = SplitMember(
            groupZoneID: zoneID, displayName: "Tú",
            cloudKitUserRecordID: "uitest-current-user",
            role: "admin", status: .active, isGroupOwner: true, isCurrentUser: true
        )
        let ana = SplitMember(
            groupZoneID: zoneID, displayName: "Ana",
            cloudKitUserRecordID: "uitest-member-ana", status: .active
        )
        let beto = SplitMember(
            groupZoneID: zoneID, displayName: "Beto",
            cloudKitUserRecordID: "uitest-member-beto", status: .active
        )
        let members = [me, ana, beto]
        for m in members { context.insert(m) }
        let memberIDs = members.map { $0.id.uuidString }

        // 3. Gastos + shares (split equal entre los 3)
        let expenses: [(desc: String, amount: Double, payer: SplitMember)] = [
            ("Hospedaje", 600, me),
            ("Cena grupal", 240, ana),
            ("Transporte", 90, beto),
        ]
        for e in expenses {
            let expense = SplitExpense(
                groupZoneID: zoneID, amount: e.amount, currencyCode: "PEN",
                expenseDescription: e.desc, paidByMemberID: e.payer.id.uuidString,
                splitType: "equal"
            )
            context.insert(expense)
            let perHead = ((e.amount / Double(memberIDs.count)) * 100).rounded() / 100
            for mid in memberIDs {
                let share = SplitShare(
                    expenseID: expense.id, memberID: mid, amount: perHead,
                    isPaid: mid == e.payer.id.uuidString, groupZoneID: zoneID
                )
                context.insert(share)
            }
        }

        do {
            try context.save()
        } catch {
            print("DevSeedGroups: save error: \(error)")
        }
    }

    /// Borra TODOS los modelos de grupos (Split* + GroupBridgePreference) del store local.
    /// Lo usa el reset del modo uitest: `DataWipeService.wipeAllUserData` los preserva a
    /// propósito (decisión de producto — los grupos son compartidos vía CloudKit y el
    /// usuario los abandona, no los borra). Sin esto, re-sembrar el perfil `.grupos`
    /// apilaría un "Viaje a Cusco" duplicado encima del residual de la corrida anterior.
    /// Los Split* no tienen `@Relationship` entre sí (se enlazan por `groupZoneID`), así
    /// que el orden de borrado es indiferente.
    static func reset(in context: ModelContext) {
        deleteAll(SplitShare.self, in: context)
        deleteAll(SplitExpense.self, in: context)
        deleteAll(SplitSettlement.self, in: context)
        deleteAll(SplitMember.self, in: context)
        deleteAll(SplitGroup.self, in: context)
        deleteAll(GroupBridgePreference.self, in: context)
        do {
            try context.save()
        } catch {
            print("DevSeedGroups: reset save error: \(error)")
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        do {
            try context.delete(model: T.self)
        } catch {
            print("DevSeedGroups: Error deleting \(T.self): \(error)")
        }
    }
}
#endif
