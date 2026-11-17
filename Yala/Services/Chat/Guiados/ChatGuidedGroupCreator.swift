//
//  ChatGuidedGroupCreator.swift
//  Yala
//
//  Lo que guardan los guiados de Grupos al tocar «Crear», por las mismas piezas que sus formularios:
//  - la deuda de antes por `GroupExpenseService.setOpeningBalance` (si esas dos personas ya tenían una en esa moneda, la
//    reemplaza, como el formulario tras su pregunta);
//  - el gasto por `GroupExpenseViewModel.save`, con su puente a tus cuentas;
//  - el grupo por `GroupBackendMembershipService.createGroup`, con los mismos efectos que «Nuevo grupo».
//  Los errores salen con el texto de cada formulario (`OpeningBalanceErrorCopyLogic`, `GroupActionErrorLogic`).
//

import Foundation
import SwiftData

/// Lo que se manda al crear un grupo: lo que pide `GroupBackendMembershipService.createGroup`.
struct ChatGuidedGroupRequest: Equatable {
    let name: String
    let iconName: String
    let colorHex: String
    let currencyCode: String
    let displayName: String
    let defaultSplitType: String
    let simplifyDebts: Bool
    let showDebtsInSingleCurrency: Bool
}

extension ChatGuidedCreator {

    // MARK: - Deuda de antes

    static func createOpeningBalance(_ answers: ChatGuidedAnswers, context: ModelContext,
                                     now: Date = .now) throws -> ChatGuidedCreation {
        guard let debtor = answers.debtorMemberID, let creditor = answers.creditorMemberID, debtor != creditor,
              let amount = answers.amount, ChatGuidedEngine.isValidAmount(amount),
              let currency = answers.currencyCode else { throw ChatGuidedCreationError.incomplete }
        let group = try splitGroup(answers.groupZoneID, context: context)
        do {
            _ = try GroupExpenseService.shared.setOpeningBalance(
                in: group,
                debtorMemberID: debtor,
                creditorMemberID: creditor,
                amount: amount,
                currencyCode: currency,
                // Solo fechas pasadas, como el formulario.
                date: min(answers.groupDate ?? now, now)
            )
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: saving the opening balance: \(error)")
            #endif
            throw ChatGuidedCreationError.message(OpeningBalanceErrorCopyLogic.message(for: error))
        }
        return ChatGuidedCreation(id: group.id, name: group.name, dueDate: nil, zoneID: group.cloudKitZoneID)
    }

    /// La deuda de antes que esta reemplazaría (la que ya tienen esas dos personas en esa moneda), para avisarlo en la
    /// confirmación. `nil`: ninguna, o no se pudo mirar (el guardado lo dirá).
    static func openingBalanceToReplace(_ answers: ChatGuidedAnswers, context: ModelContext) -> SplitExpense? {
        guard let debtor = answers.debtorMemberID, let creditor = answers.creditorMemberID, debtor != creditor,
              let currency = answers.currencyCode else { return nil }
        do {
            let group = try splitGroup(answers.groupZoneID, context: context)
            return try GroupExpenseService.shared.openingBalanceThatAddingWouldReplace(
                in: group, debtorMemberID: debtor, creditorMemberID: creditor, currencyCode: currency)
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: looking for an opening balance to replace: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Gasto de grupo

    static func createGroupExpense(_ answers: ChatGuidedAnswers, context: ModelContext,
                                   now: Date = .now) throws -> ChatGuidedCreation {
        let description = ChatGuidedEngine.trimmed(answers.expenseDescription)
        guard !description.isEmpty, ChatGuidedEngine.isValidAmount(answers.amount),
              ChatGuidedEngine.isSplitValid(answers) else { throw ChatGuidedCreationError.incomplete }
        let viewModel = try groupExpenseViewModel(answers, context: context, now: now)
        guard viewModel.canSave else { throw ChatGuidedCreationError.incomplete }
        guard viewModel.save() else {
            throw ChatGuidedCreationError.message(viewModel.saveError ?? L10n.Common.saveError)
        }
        return ChatGuidedCreation(id: viewModel.group.id, name: description, dueDate: nil,
                                  zoneID: viewModel.group.cloudKitZoneID)
    }

    /// ¿El gasto pide la cuenta con la que pagaste? La misma regla del formulario (`isAccountRequired`: pagaste tú, no
    /// es una venta, tienes tus finanzas en Yala y el gasto se refleja en tus cuentas).
    static func groupExpenseNeedsAccount(_ answers: ChatGuidedAnswers, context: ModelContext) -> Bool {
        do {
            return try groupExpenseViewModel(answers, context: context, now: .now).isAccountRequired
        } catch {
            return false
        }
    }

    /// El ViewModel del formulario, relleno con las respuestas. Es el que guarda: mismo reparto, mismo puente.
    static func groupExpenseViewModel(_ answers: ChatGuidedAnswers, context: ModelContext,
                                      now: Date) throws -> GroupExpenseViewModel {
        let group = try splitGroup(answers.groupZoneID, context: context)
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group, context: context)
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: loading the members: \(error)")
            #endif
            throw ChatGuidedCreationError.notSaved
        }
        let lookup = Dictionary(members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
                                uniquingKeysWith: { first, _ in first })
        let viewModel = GroupExpenseViewModel(group: group, members: members, memberNameLookup: lookup)
        viewModel.setContext(context)
        viewModel.expenseDescription = ChatGuidedEngine.trimmed(answers.expenseDescription)
        if let amount = answers.amount { viewModel.amountString = AmountInputHelper.formatWithGrouping(amount) }
        viewModel.currencyCode = answers.currencyCode ?? group.currencyCode
        if let payer = answers.payerMemberID { viewModel.paidByMemberID = payer }
        viewModel.date = min(answers.groupDate ?? now, now)
        viewModel.subcategoryName = answers.expenseSubcategoryName
        let everyone = Set(members.filter(\.isActive).map { $0.id.uuidString })
        switch answers.splitMode {
        case .equalAll, nil:
            viewModel.splitType = .equal
            viewModel.selectedMemberIDs = everyone
        case .equalSome:
            viewModel.splitType = .equal
            viewModel.selectedMemberIDs = Set(answers.participantIDs ?? []).intersection(everyone)
        case .exact:
            viewModel.splitType = .exact
            let participants = Set(answers.participantIDs ?? []).intersection(everyone)
            viewModel.selectedMemberIDs = participants
            var amounts: [String: String] = [:]
            for id in participants {
                if let value = answers.exactShares?[id] { amounts[id] = AmountInputHelper.formatWithGrouping(value) }
            }
            viewModel.exactAmounts = amounts
        }
        if let accountID = answers.accountID, let account = liveAccount(accountID, context: context) {
            viewModel.selectedAccount = account
        }
        return viewModel
    }

    // MARK: - Crear un grupo

    /// Lo que se manda, con las mismas reglas del formulario: la moneda elegida con «todo en una», y si no, la tuya; tu
    /// nombre el que dijiste, o el del perfil, o el de siempre (`create_group` no admite un nombre vacío).
    static func groupRequest(_ answers: ChatGuidedAnswers, preferredCurrency: String,
                             profileName: String?) throws -> ChatGuidedGroupRequest {
        let name = ChatGuidedEngine.trimmed(answers.groupName)
        guard !name.isEmpty, let purpose = answers.groupPurpose else { throw ChatGuidedCreationError.incomplete }
        let single = answers.groupSingleCurrency == true
        let typed = ChatGuidedEngine.trimmed(answers.groupDisplayName)
        let profile = ChatGuidedEngine.trimmed(profileName)
        let displayName = !typed.isEmpty ? typed : (!profile.isEmpty ? profile : L10n.Profile.defaultName)
        let splitType = answers.groupSplitType.flatMap { ChatGuidedEngine.groupSplitTypes.contains($0) ? $0 : nil }
            ?? "equal"
        return ChatGuidedGroupRequest(
            name: name,
            iconName: purpose.iconName,
            colorHex: purpose.colorHex,
            currencyCode: (single ? answers.currencyCode : nil)?.uppercased() ?? preferredCurrency.uppercased(),
            displayName: displayName,
            defaultSplitType: splitType,
            simplifyDebts: answers.groupSimplifyDebts ?? GroupFormDefaults.simplifyDebtsForNewGroup,
            showDebtsInSingleCurrency: single
        )
    }

    /// Crea el grupo en el servidor y lo deja en el teléfono. Sin la cuenta de Yala o el permiso de Grupos no se crea
    /// (el chat ya no abrió la tarjeta, pero pudo cambiar después). `create` se sustituye en los tests.
    static func createGroup(
        _ answers: ChatGuidedAnswers,
        context: ModelContext,
        preferredCurrency: String,
        profileName: String?,
        route: GroupCreateRoutingLogic.Route,
        create: ((ChatGuidedGroupRequest) async throws -> SplitGroup)? = nil
    ) async throws -> ChatGuidedCreation {
        switch route {
        case .backend: break
        case .channelOff: throw ChatGuidedCreationError.message(L10n.Welcome.Groups.channelOffBody)
        case .needsConsent, .needsSignIn: throw ChatGuidedCreationError.message(L10n.IAGuiados.groupNeedsAccount)
        }
        let request = try groupRequest(answers, preferredCurrency: preferredCurrency, profileName: profileName)
        let created: SplitGroup
        do {
            if let create {
                created = try await create(request)
            } else {
                created = try await GroupBackendMembershipService(
                    client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                    .createGroup(
                        name: request.name,
                        iconName: request.iconName,
                        colorHex: request.colorHex,
                        currencyCode: request.currencyCode,
                        displayName: request.displayName,
                        defaultSplitType: request.defaultSplitType,
                        simplifyDebts: request.simplifyDebts,
                        showDebtsInSingleCurrency: request.showDebtsInSingleCurrency,
                        membersCanInvite: false,
                        context: context
                    )
            }
        } catch let error as ChatGuidedCreationError {
            throw error
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: creating the group: \(error)")
            #endif
            throw ChatGuidedCreationError.message(GroupActionErrorLogic.message(for: error))
        }
        // Los mismos efectos que «Nuevo grupo» (el servicio del backend no los emite).
        SessionState.shared.incrementDataVersion()
        NudgeService.shared.recordGroupJoinIfNeeded()
        return ChatGuidedCreation(id: created.id, name: created.name, dueDate: nil, zoneID: created.cloudKitZoneID)
    }

    // MARK: - Piezas

    /// La cuenta por su id, solo si sigue viva y sin archivar. `model(for:)` fabrica un objeto aunque la fila ya no
    /// exista, y leerlo cerraría la app: se busca entre las que hay.
    static func liveAccount(_ id: PersistentIdentifier, context: ModelContext) -> Account? {
        do {
            return try context.fetch(FetchDescriptor<Account>())
                .first { $0.persistentModelID == id && !$0.isArchived && !$0.isSystemAccount }
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: loading the accounts: \(error)")
            #endif
            return nil
        }
    }

    /// El grupo por su zona. Si ya no está (se borró, saliste), no se guarda nada.
    static func splitGroup(_ zoneID: String?, context: ModelContext) throws -> SplitGroup {
        guard let zoneID, !zoneID.isEmpty else { throw ChatGuidedCreationError.incomplete }
        do {
            let groups = try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
            guard let group = groups.first(where: { !$0.isHiddenForAll }) else { throw ChatGuidedCreationError.notSaved }
            return group
        } catch let error as ChatGuidedCreationError {
            throw error
        } catch {
            #if DEBUG
            print("ChatGuidedCreator: Error: loading the group: \(error)")
            #endif
            throw ChatGuidedCreationError.notSaved
        }
    }
}
