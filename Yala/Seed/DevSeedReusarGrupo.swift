//
//  DevSeedReusarGrupo.swift
//  Yala
//
//  Fixture de QA de «Reusar» con gastos de grupo (encargo del 21-nov, `-uitest-seed-reusar-grupo`). Siembra en Registros
//  gastos de grupo con la anatomía que deja el puente (`GroupTransactionBridge.bridgeExpense`), sin pasar por él: el
//  puente pide cuenta y sesión para «yo pagué», y aquí hace falta que la fila exista ya.
//
//  - «Jurpi» (tú y Pía, activos):
//    - «Luz Del Sur» S/ 120, pagaste tú, a partes iguales: la pata REAL (−120 en tu cuenta, con su subcategoría) y la de
//      PRÉSTAMO (+60 en la cuenta de sistema «Grupos», subcategoría «Préstamo a grupos»). Solo la real se ofrece.
//    - «Mantenimiento» S/ 300, pagó Pía, exacto (tú 100, Pía 200): tu parte, −100 en «Grupos».
//  - «Casa vieja» archivado, con «Internet viejo»: sale deshabilitado.
//  - «Depa Miraflores», del que saliste, con «Agua»: sale deshabilitado.
//
//  Discriminante: con el selector de antes (`offersMakeRecurring`), ninguna de estas filas sale; con el de ahora salen
//  cuatro, dos tocables y dos con su motivo, y la pata de préstamo sigue fuera.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedReusarGrupo {

    // MARK: - Asideros (deliberadamente sin localizar: no son copy)

    static let groupName = "Jurpi"
    static let archivedGroupName = "Casa vieja"
    static let leftGroupName = "Depa Miraflores"
    static let accountName = "BCP Reusar"
    static let paidByMeNote = "Luz Del Sur"
    static let paidByOtherNote = "Mantenimiento"
    static let archivedNote = "Internet viejo"
    static let leftNote = "Agua"

    @MainActor
    static func create(in context: ModelContext) {
        let name = groupName
        var existing = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.name == name })
        existing.fetchLimit = 1
        do {
            if try !context.fetch(existing).isEmpty {
                print("DevSeedReusarGrupo: el escenario ya estaba sembrado — no se duplica.")
                return
            }
        } catch {
            print("DevSeedReusarGrupo: Error: \(error)")
            return
        }

        let currency = CurrencyDefaults.currentPreferred
        let systemAccount: Account
        let loanSubcategory: Subcategory
        do {
            systemAccount = try GroupBridgeSystemEntities.ensureSystemAccount(currencyCode: currency, context: context)
            loanSubcategory = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
        } catch {
            print("DevSeedReusarGrupo: no se pudo preparar la cuenta/subcategoría de sistema: \(error)")
            return
        }

        let account = Account(name: accountName, currencyCode: currency, colorHex: "#0EA5E9",
                              iconName: "building.columns", type: AccountType.checking.rawValue)
        context.insert(account)

        let utilities = subcategory(named: L10n.Subcategory.utilities, in: context)
        let maintenance = subcategory(named: L10n.Subcategory.maintenance, in: context)

        // «Jurpi»: tú y Pía.
        let jurpi = makeGroup(groupName, currency: currency, in: context)
        let me = makeMember(zone: jurpi.cloudKitZoneID, name: "Tú", isMe: true, in: context)
        let pia = makeMember(zone: jurpi.cloudKitZoneID, name: "Pía", isMe: false, in: context)

        // «Luz Del Sur»: pagaste tú, a partes iguales.
        let luz = makeExpense(in: jurpi, amount: 120, currency: currency, description: paidByMeNote,
                              paidBy: me, splitType: "equal", daysAgo: 3,
                              shares: [(me, 60), (pia, 60)], context: context)
        insertLeg(amount: -120, date: luz.date, subcategory: utilities, account: account,
                  expense: luz, context: context)
        insertLeg(amount: 60, date: luz.date.addingTimeInterval(1), subcategory: loanSubcategory,
                  account: systemAccount, expense: luz, context: context)

        // «Mantenimiento»: pagó Pía, exacto.
        let mant = makeExpense(in: jurpi, amount: 300, currency: currency, description: paidByOtherNote,
                               paidBy: pia, splitType: "exact", daysAgo: 5,
                               shares: [(me, 100), (pia, 200)], context: context)
        insertLeg(amount: -100, date: mant.date, subcategory: maintenance, account: systemAccount,
                  expense: mant, context: context)

        // «Casa vieja», archivado.
        let archived = makeGroup(archivedGroupName, currency: currency, in: context)
        archived.isArchived = true
        let meArchived = makeMember(zone: archived.cloudKitZoneID, name: "Tú", isMe: true, in: context)
        let otherArchived = makeMember(zone: archived.cloudKitZoneID, name: "Leo", isMe: false, in: context)
        let internet = makeExpense(in: archived, amount: 90, currency: currency, description: archivedNote,
                                   paidBy: meArchived, splitType: "equal", daysAgo: 8,
                                   shares: [(meArchived, 45), (otherArchived, 45)], context: context)
        insertLeg(amount: -90, date: internet.date, subcategory: utilities, account: account,
                  expense: internet, context: context)

        // «Depa Miraflores», del que saliste.
        let left = makeGroup(leftGroupName, currency: currency, in: context)
        let meLeft = makeMember(zone: left.cloudKitZoneID, name: "Tú", isMe: true, in: context)
        meLeft.status = SplitMemberStatus.left.rawValue
        let otherLeft = makeMember(zone: left.cloudKitZoneID, name: "Sol", isMe: false, in: context)
        let agua = makeExpense(in: left, amount: 60, currency: currency, description: leftNote,
                               paidBy: meLeft, splitType: "equal", daysAgo: 10,
                               shares: [(meLeft, 30), (otherLeft, 30)], context: context)
        insertLeg(amount: -60, date: agua.date, subcategory: utilities, account: account,
                  expense: agua, context: context)

        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            print("DevSeedReusarGrupo: Error: \(error)")
        }
    }

    // MARK: - Piezas

    @MainActor
    private static func subcategory(named name: String, in context: ModelContext) -> Subcategory? {
        var descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            print("DevSeedReusarGrupo: Error: \(error)")
            return nil
        }
    }

    private static func makeGroup(_ name: String, currency: String, in context: ModelContext) -> SplitGroup {
        let group = SplitGroup(name: name, iconName: "house", currencyCode: currency, isOwner: true)
        // Del canal backend: sin esto `LegacyGroupsRetirement` lo oculta en el arranque siguiente.
        group.isBackendGroup = true
        context.insert(group)
        return group
    }

    private static func makeMember(zone: String, name: String, isMe: Bool, in context: ModelContext) -> SplitMember {
        let member = SplitMember(
            groupZoneID: zone, displayName: name,
            cloudKitUserRecordID: isMe ? "uitest-current-user" : "uitest-member-\(name.lowercased())",
            role: isMe ? "admin" : "member", status: .active, isGroupOwner: isMe, isCurrentUser: isMe)
        context.insert(member)
        return member
    }

    // swiftlint:disable:next function_parameter_count
    private static func makeExpense(
        in group: SplitGroup, amount: Double, currency: String, description: String, paidBy: SplitMember,
        splitType: String, daysAgo: Int, shares: [(SplitMember, Double)], context: ModelContext
    ) -> SplitExpense {
        let calendar = Calendar.current
        // A mediodía: lejos de la medianoche que comparten dos días.
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now) ?? Date.now
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: noon) ?? noon
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: amount, currencyCode: currency,
                                   expenseDescription: description, date: date,
                                   paidByMemberID: paidBy.id.uuidString, splitType: splitType)
        context.insert(expense)
        for (member, share) in shares {
            context.insert(SplitShare(expenseID: expense.id, memberID: member.id.uuidString, amount: share,
                                      isPaid: member.id == paidBy.id, groupZoneID: group.cloudKitZoneID))
        }
        return expense
    }

    @MainActor
    private static func insertLeg(
        amount: Double, date: Date, subcategory: Subcategory?, account: Account,
        expense: SplitExpense, context: ModelContext
    ) {
        let leg = TransactionItem(date: date, amount: amount, currencyCode: expense.currencyCode,
                                  note: expense.expenseDescription, category: subcategory?.category,
                                  subcategory: subcategory, account: account)
        leg.splitExpenseID = expense.id.uuidString
        leg.splitGroupZoneID = expense.groupZoneID
        leg.splitTotalAmount = expense.amount
        leg.splitType = expense.splitType
        leg.createdAt = date
        context.insert(leg)
        leg.recalculatePreferredCurrency(context: context)
    }
}
#endif
