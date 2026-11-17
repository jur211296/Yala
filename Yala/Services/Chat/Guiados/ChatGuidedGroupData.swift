//
//  ChatGuidedGroupData.swift
//  Yala
//
//  Lo que leen los guiados de Grupos: tus grupos con sus personas, dónde puedes anotar un gasto o una deuda de antes, y
//  lo que ya se sabe antes de la primera pregunta. Solo lee. Las mismas reglas que los formularios:
//  `GroupExpenseEligibilityLogic` (gasto) y `OpeningBalancePermissionLogic` (deuda de antes).
//

import Foundation
import SwiftData

/// Un grupo tal como lo ofrece el guiado.
struct ChatGuidedGroupOption: Identifiable, Equatable {
    struct Member: Identifiable, Equatable {
        /// `SplitMember.id.uuidString`.
        let id: String
        let name: String
        let isMe: Bool
        /// El nombre plegado, para encontrarlo en la frase.
        var foldedName: String { ChatGuidedIntentDetector.fold(name) }
    }

    /// `SplitGroup.cloudKitZoneID`.
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let currencyCode: String
    /// Las personas activas, tú primero.
    let members: [Member]
    /// Puedes anotar un gasto (`GroupExpenseEligibilityLogic.canCreateExpense`).
    let canAddExpense: Bool
    /// Puedes anotar una deuda de antes: además, dueño o administrador y con dos personas o más.
    let canManageOpeningBalances: Bool

    var me: Member? { members.first(where: \.isMe) }
    var foldedName: String { ChatGuidedIntentDetector.fold(name) }

    func member(_ id: String?) -> Member? {
        id.flatMap { id in members.first { $0.id == id } }
    }

    /// Los grupos donde cabe lo que pide cada guiado.
    func fits(_ kind: ChatGuidedKind) -> Bool {
        switch kind {
        case .groupExpense: canAddExpense
        case .groupOpeningBalance: canManageOpeningBalances
        default: false
        }
    }
}

/// Por qué un guiado de Grupos no abre su tarjeta: Yala IA lo dice en una frase.
enum ChatGuidedGroupBlock: Equatable {
    /// Crear un grupo necesita la cuenta de Yala y el permiso de Grupos.
    case needsGroupsAccount
    /// El canal de Grupos está apagado (el texto que ya usa Grupos).
    case channelOff
    /// No hay ningún grupo donde anotar el gasto.
    case noGroupForExpense
    /// No hay ningún grupo donde anotar una deuda de antes.
    case noGroupForOpeningBalance
}

extension ChatGuidedData {
    func group(_ zoneID: String?) -> ChatGuidedGroupOption? {
        zoneID.flatMap { id in groups.first { $0.id == id } }
    }
}

extension ChatGuidedDataSource {

    /// Tus grupos visibles con sus personas activas. Un grupo cuyas personas no se dejan leer no se ofrece: anotar en él
    /// sin saber quién está sería adivinar.
    static func groupOptions(_ context: ModelContext) -> [ChatGuidedGroupOption] {
        let groups: [SplitGroup]
        do {
            groups = try context.fetch(FetchDescriptor<SplitGroup>(sortBy: [SortDescriptor(\.name)]))
        } catch {
            #if DEBUG
            print("ChatGuidedDataSource: Error: loading the groups: \(error)")
            #endif
            return []
        }
        return groups.compactMap { group -> ChatGuidedGroupOption? in
            guard !group.isHiddenForAll, !group.isArchived else { return nil }
            let members: [SplitMember]
            do {
                members = try GroupService.shared.fetchMembers(for: group, context: context)
            } catch {
                #if DEBUG
                print("ChatGuidedDataSource: Error: loading the members of a group: \(error)")
                #endif
                return nil
            }
            let active = members.filter(\.isActive)
            let me = GroupExpenseService.resolveCurrentUserMember(from: active)
            let canAddExpense = GroupExpenseEligibilityLogic.canCreateExpense(
                currentMemberStatus: GroupExpenseService.resolveCurrentUserMember(from: members)?.memberStatus,
                isArchived: group.isArchived,
                isHiddenForAll: group.isHiddenForAll,
                isMigratedFrozen: group.isMigratedFrozen
            )
            let options = active.map {
                ChatGuidedGroupOption.Member(id: $0.id.uuidString, name: $0.resolvedDisplayName, isMe: $0.id == me?.id)
            }
            // Tú primero; los demás, en el orden de siempre (por nombre).
            let ordered = options.filter(\.isMe) + options.filter { !$0.isMe }
            return ChatGuidedGroupOption(
                id: group.cloudKitZoneID,
                name: group.name,
                iconName: group.iconName,
                colorHex: group.colorHex,
                currencyCode: group.currencyCode.uppercased(),
                members: ordered,
                canAddExpense: canAddExpense,
                canManageOpeningBalances: canAddExpense && active.count >= 2
                    && OpeningBalancePermissionLogic.canManage(group: group, members: members)
            )
        }
    }

    /// Lo que pinta la tarjeta de un guiado de Grupos: los grupos donde cabe (crear un grupo no los necesita).
    static func loadGroups(_ kind: ChatGuidedKind, into data: inout ChatGuidedData, context: ModelContext) {
        guard kind == .groupExpense || kind == .groupOpeningBalance else { return }
        data.groups = groupOptions(context).filter { $0.fits(kind) }
    }

    /// ¿Se puede abrir este guiado? `nil`: sí.
    static func groupBlock(_ kind: ChatGuidedKind, groups: [ChatGuidedGroupOption],
                           route: GroupCreateRoutingLogic.Route) -> ChatGuidedGroupBlock? {
        switch kind {
        case .group:
            switch route {
            case .backend: return nil
            case .channelOff: return .channelOff
            case .needsConsent, .needsSignIn: return .needsGroupsAccount
            }
        case .groupExpense:
            return groups.contains { $0.fits(.groupExpense) } ? nil : .noGroupForExpense
        case .groupOpeningBalance:
            return groups.contains { $0.fits(.groupOpeningBalance) } ? nil : .noGroupForOpeningBalance
        default:
            return nil
        }
    }

    /// Lo que ya se sabe antes de la primera pregunta de un guiado de Grupos.
    ///
    /// - Crear un grupo: tu nombre si Yala ya lo sabe (el del perfil, el que usa «Nuevo grupo»), y con una sola moneda en
    ///   Yala, «cada gasto en su moneda» en la tuya. Con «todo en una moneda» se pregunta cuál (salvo si la frase la dijo).
    /// - Deuda y gasto: con un solo grupo donde cabe, ese grupo (y no se pregunta); con el grupo ya sabido, su moneda.
    static func prepareGroupStart(_ detection: ChatGuidedDetection, catalog: ChatGuidedCatalog,
                                  profileName: String?) -> ChatGuidedDetection {
        var prepared = detection
        var notApplicable = prepared.answers.notApplicable ?? []
        switch detection.kind {
        case .group:
            let known = (profileName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !known.isEmpty {
                prepared.answers.groupDisplayName = known
                notApplicable.append(.groupYourName)
            }
            if prepared.answers.groupSingleCurrency == nil,
               Set(catalog.accountCurrencies + [catalog.mainCurrency.uppercased()]).count <= 1 {
                prepared.answers.groupSingleCurrency = false
                notApplicable.append(.groupCurrencyMode)
            }
        case .groupExpense, .groupOpeningBalance:
            let fitting = catalog.groups.filter { $0.fits(detection.kind) }
            if fitting.count == 1, let only = fitting.first {
                if prepared.answers.groupZoneID == nil { prepared.answers.groupZoneID = only.id }
                notApplicable.append(.groupPick)
            }
            if let group = fitting.first(where: { $0.id == prepared.answers.groupZoneID }) {
                if prepared.answers.currencyCode == nil { prepared.answers.currencyCode = group.currencyCode }
                prepared.answers = completeTwoPersonDebt(prepared.answers, group: group)
            }
        default:
            break
        }
        prepared.answers.notApplicable = notApplicable.isEmpty ? nil : notApplicable
        return prepared
    }

    /// En un grupo de dos, quien no debe es la otra persona: «¿A quién?» no se pregunta.
    static func completeTwoPersonDebt(_ answers: ChatGuidedAnswers, group: ChatGuidedGroupOption) -> ChatGuidedAnswers {
        var answers = answers
        guard group.members.count == 2, let debtor = answers.debtorMemberID,
              let other = group.members.first(where: { $0.id != debtor }) else { return answers }
        if answers.creditorMemberID == nil || answers.creditorMemberID == debtor { answers.creditorMemberID = other.id }
        return answers
    }
}
