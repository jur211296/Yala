//
//  CompartidoPersonDetailView.swift
//  Yala
//
//  El detalle de una persona en Compartido (lote 2, 26-nov-2026): espejo del detalle de grupo (`GroupDetailView`) con el
//  mismo título grande, los mismos chips «Gastos · Saldos · Estadísticas» (icono en los tres, nombre solo en el elegido)
//  y, junto al rótulo de la cifra de las tres páginas, un filtro de grupo («Todos los grupos · <grupos> · Sin grupo»).
//  Las tres páginas son las del grupo (`GroupRecordsView`, `GroupBalancesView`, `GroupStatsView`) con los datos de los
//  grupos que compartes con la persona; lo que se apunta o se salda va por los formularios de siempre.
//

import SwiftUI
import SwiftData

struct CompartidoPersonDetailView: View {

    typealias Filter = CompartidoPersonDetailLogic.Filter

    /// Una hoja del detalle, sobre el grupo de cada cosa.
    enum Sheet: Identifiable {
        case expenseDetail(groupKey: String, expense: SplitExpense)
        case editExpense(groupKey: String, expense: SplitExpense)
        case openingBalanceDetail(groupKey: String, expense: SplitExpense)
        case newOpeningBalance(groupKey: String)
        case settlement(groupKey: String, debt: Debt)
        case settleAll([CompartidoPersonDetailLogic.SettleItem])

        var id: String {
            switch self {
            case .expenseDetail(_, let expense): "detail-\(expense.id)"
            case .editExpense(_, let expense): "edit-\(expense.id)"
            case .openingBalanceDetail(_, let expense): "opening-\(expense.id)"
            case .newOpeningBalance(let key): "new-opening-\(key)"
            case .settlement(let key, let debt): "settle-\(key)-\(debt.id)"
            case .settleAll(let items): "settle-all-\(items.map(\.id).joined(separator: ","))"
            }
        }
    }

    /// «Nuevo gasto» y lo que trae Voz o Foto: el compositor de Grupos con los grupos que compartes con la persona.
    struct ComposerPayload: Identifiable {
        let id = UUID()
        let groups: [SplitGroup]
        let initialGroup: SplitGroup
        var receiptSplit: GroupExpensePrefillTemplate?
    }

    enum Presentation { case pushed, column }

    // MARK: - Entorno

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isRootPageShown) private var isRootPageShown
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Entrada

    let person: CompartidoPersonasLogic.Person
    var presentation: Presentation = .pushed
    var onCloseColumn: (() -> Void)?

    // MARK: - Estado

    @State private var viewModel: CompartidoPersonDetailModel
    @State private var frescura = FrescuraAlVolver()
    @State private var pages = StagedTabSelection<GroupDetailTab>(.records)
    private var selectedTab: GroupDetailTab { pages.shown }
    @State private var filter: Filter = .all
    @State private var sheet: Sheet?
    /// «Editar» desde el detalle de un gasto: se abre al cerrarse esa hoja.
    @State private var pendingEdit: (groupKey: String, expense: SplitExpense)?
    @State private var composerPayload: ComposerPayload?
    @State private var receiptRequest: GroupReceiptRequest?
    @State private var showFloatingNew = false

    init(person: CompartidoPersonasLogic.Person, presentation: Presentation = .pushed, onCloseColumn: (() -> Void)? = nil) {
        self.person = person
        self.presentation = presentation
        self.onCloseColumn = onCloseColumn
        self._viewModel = State(initialValue: CompartidoPersonDetailModel(
            person: person, noGroupLabel: L10n.Compartido.noGroup))
    }

    // MARK: - Body

    var body: some View {
        tabContent
            .yalaSkeleton(!viewModel.isReady)
            .overlay(alignment: .topLeading) {
                if UITestHooks.isActive, viewModel.isReady {
                    Color.clear.frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("compartido_person_detail_ready")
                }
            }
            .overlay(alignment: .bottomTrailing) { floatingNew }
            .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)
            .yalaScreenBackground(.panel)
            .navigationChipsInset { chipsBar }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.large)
            .modifier(CompartidoPersonPushedChrome(isPushed: presentation == .pushed))
            .toolbar {
                if presentation == .pushed {
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) { dismiss() }
                            .accessibilityIdentifier("compartido_person_detail_back")
                    }
                }
            }
            .sheet(item: $sheet, onDismiss: sheetDismissed) { sheet in sheetContent(sheet) }
            .sheet(item: $composerPayload) { payload in composer(payload) }
            .groupReceiptSplitFlow(
                request: $receiptRequest,
                activeMembers: { activeMembers(of: $0) },
                memberCount: { activeMembers(of: $0).count },
                onReady: { group, template in startComposer(initial: group, receiptSplit: template) },
                onManualEntry: { group in startComposer(initial: group, receiptSplit: nil) }
            )
            .modifier(CompartidoPersonLifecycle(
                model: viewModel, modelContext: modelContext, dataVersion: sessionState.dataVersion))
            .onChange(of: scenePhase) { _, newPhase in handleScenePhase(newPhase) }
            .onChange(of: filterOptions) { _, options in
                filter = CompartidoPersonDetailLogic.resolved(filter, options: options)
            }
    }

    // MARK: - Chips

    private var chipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(GroupDetailTab.allCases) { tab in
                    NavigationChipButton(
                        title: tab.displayName, icon: tab.icon, isSelected: selectedTab == tab, animatesSwitch: true
                    ) {
                        selectPage(tab)
                    }
                    .accessibilityIdentifier("compartido_person_tab_\(tab.rawValue)")
                }
            }
            .scrollTargetLayout()
        }
        .fadesTowardVerticalBar()
        .contentMargins(.horizontal, DS.Spacing.lg)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .animation(reduceMotion ? nil : StagedTabSelection<GroupDetailTab>.animation, value: selectedTab)
    }

    private func selectPage(_ tab: GroupDetailTab) {
        if tab != selectedTab { showFloatingNew = false }
        StagedTabSelection.select(tab, in: $pages, reduceMotion: reduceMotion)
    }

    private var tabContent: some View {
        StagedTabPages(selection: $pages) { tab in
            page(for: tab)
        }
    }

    @ViewBuilder
    private func page(for tab: GroupDetailTab) -> some View {
        switch tab {
        case .records: recordsPage
        case .balances: balancesPage
        case .stats: statsPage
        }
    }

    // MARK: - Filtro y cifra

    private var slices: [CompartidoPersonDetailLogic.Slice] { viewModel.slices }

    private var filterOptions: [Filter] { CompartidoPersonDetailLogic.filterOptions(slices) }

    private func filterLabel(_ option: Filter) -> String {
        switch option {
        case .all: L10n.Compartido.Detail.filterAll
        case .group(let key): viewModel.tagName(for: key)
        case .noGroup: L10n.Compartido.noGroup
        }
    }

    private var filterMenu: CompartidoGroupFilterMenu {
        CompartidoGroupFilterMenu(options: filterOptions, selection: $filter, label: filterLabel)
    }

    private func hero(onTap: (() -> Void)?) -> AnyView {
        let groupName: String
        if case .group(let key) = filter { groupName = viewModel.tagName(for: key) } else { groupName = "" }
        return AnyView(CompartidoPersonHero(
            personName: person.name,
            hero: CompartidoPersonDetailLogic.hero(slices, filter: filter),
            filter: filter,
            filterGroupName: groupName,
            estimatedCurrencies: CompartidoPersonDetailLogic.estimatedCurrencies(slices, filter: filter),
            hasOpposingGroups: CompartidoPersonDetailLogic.hasOpposingGroups(slices, filter: filter),
            filterMenu: filterMenu,
            onTap: onTap))
    }

    // MARK: - Gastos

    private var recordsPage: some View {
        let entries = viewModel.entries(in: filter)
        var expenses: [SplitExpense] = []
        var shares: [SplitShare] = []
        var settlements: [SplitSettlement] = []
        var names: [String: String] = [:]
        var bridges: [String: TransactionItem] = [:]
        var myShares: [UUID: SplitShare] = [:]
        var groupOfItem: [UUID: String] = [:]
        for entry in entries {
            let vm = entry.model
            let key = entry.group.cloudKitZoneID
            let personIDs = viewModel.personMemberIDs(in: key)
            let participants = Dictionary(grouping: vm.shares, by: \.expenseID).mapValues { Set($0.map(\.memberID)) }
            let mine = vm.expenses.filter { expense in
                CompartidoPersonDetailLogic.isSharedExpense(
                    paidBy: expense.paidByMemberID, participants: participants[expense.id] ?? [],
                    myMemberID: vm.currentMemberID, personMemberIDs: personIDs)
            }
            let ids = Set(mine.map(\.id))
            expenses += mine
            shares += vm.shares.filter { ids.contains($0.expenseID) }
            let pairSettlements = vm.settlements.filter {
                CompartidoPersonDetailLogic.isSharedSettlement(
                    from: $0.fromMemberID, to: $0.toMemberID, myMemberID: vm.currentMemberID, personMemberIDs: personIDs)
            }
            settlements += pairSettlements
            names.merge(vm.memberNameLookup) { first, _ in first }
            bridges.merge(vm.txBridgeMap) { first, _ in first }
            myShares.merge(vm.mySharesByExpense.filter { ids.contains($0.key) }) { first, _ in first }
            for expense in mine { groupOfItem[expense.id] = key }
            for settlement in pairSettlements { groupOfItem[settlement.id] = key }
        }
        let canAdd = !eligibleGroups.isEmpty
        return GroupRecordsView(
            expenses: expenses,
            shares: shares,
            memberNameLookup: names,
            currencyCode: entries.first?.group.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue,
            txBridgeMap: bridges,
            subcategoryNameLookup: entries.first?.model.subcategoryNameLookup ?? [:],
            mySharesByExpense: myShares,
            currentMemberID: nil,
            settlements: settlements,
            onTapExpense: { expense in openExpense(expense, groupKey: groupOfItem[expense.id]) },
            onEditExpense: { expense in
                guard let key = groupOfItem[expense.id], canParticipate(in: key) else { return }
                sheet = .editExpense(groupKey: key, expense: expense)
            },
            onDeleteExpense: { expense in
                guard let key = groupOfItem[expense.id], canParticipate(in: key) else { return }
                viewModel.viewModel(for: key)?.deleteExpense(expense)
            },
            onNewExpense: canAdd ? { startComposer(initial: initialGroup, receiptSplit: nil) } : nil,
            onReceipt: canAdd ? { source in startReceipt(source) } : nil,
            onRefresh: { await viewModel.refreshFromCloud() },
            showsFloatingNew: $showFloatingNew,
            header: hero(onTap: { selectPage(.balances) }),
            currentMemberIDForExpense: { expense in
                groupOfItem[expense.id].flatMap { viewModel.viewModel(for: $0)?.currentMemberID }
            },
            rowTag: { id in
                guard let key = groupOfItem[id], let group = viewModel.group(for: key) else { return nil }
                return GroupRecordRowTag(name: viewModel.tagName(for: key), colorHex: group.isPerson ? nil : group.colorHex)
            }
        )
        .id(filter)
    }

    private func openExpense(_ expense: SplitExpense, groupKey: String?) {
        guard let groupKey, canParticipate(in: groupKey) else { return }
        sheet = expense.isOpeningBalance
            ? .openingBalanceDetail(groupKey: groupKey, expense: expense)
            : .expenseDetail(groupKey: groupKey, expense: expense)
    }

    private func canParticipate(in groupKey: String) -> Bool {
        viewModel.viewModel(for: groupKey)?.canCurrentUserParticipate == true
    }

    // MARK: - Saldos

    @ViewBuilder
    private var balancesPage: some View {
        let entries = viewModel.entries(in: filter)
        if entries.count == 1, let entry = entries.first {
            singleGroupBalances(entry.group, entry.model)
        } else {
            allGroupsBalances
        }
    }

    /// Un grupo (o lo sin grupo): la página de Saldos del grupo, con lo que hay entre los dos. Saldar es el de hoy.
    private func singleGroupBalances(_ group: SplitGroup, _ vm: GroupDetailViewModel) -> some View {
        let key = group.cloudKitZoneID
        let personIDs = viewModel.personMemberIDs(in: key)
        let slice = slices.first { $0.groupKey == key }
        let pairSettlements = vm.settlements.filter {
            CompartidoPersonDetailLogic.isSharedSettlement(
                from: $0.fromMemberID, to: $0.toMemberID, myMemberID: vm.currentMemberID, personMemberIDs: personIDs)
        }
        let canWrite = vm.canRecordNewEntries && !group.isMigratedFrozen
        return GroupBalancesView(
            balances: [],
            debts: slice.map { CompartidoPersonDetailLogic.pairDebts($0) } ?? [],
            settlements: pairSettlements,
            memberNameLookup: vm.memberNameLookup,
            currentUserMemberID: vm.currentMemberID,
            activeMemberIDs: Set(vm.activeMembers.map { $0.id.uuidString }),
            groupColorHex: group.colorHex,
            balancesWereConverted: vm.balancesWereConverted,
            debtsWereConverted: vm.debtsWereConverted,
            onSettleDebt: canWrite ? { sheet = .settlement(groupKey: key, debt: $0) } : nil,
            onConfirmSettlement: vm.canCurrentUserParticipate ? { vm.confirmSettlement($0) } : nil,
            onRejectSettlement: vm.canCurrentUserParticipate ? { vm.rejectSettlement($0) } : nil,
            onDeleteSettlement: vm.canCurrentUserParticipate ? { vm.deleteConfirmedSettlement($0) } : nil,
            onAddOpeningBalance: vm.canManageOpeningBalances ? { sheet = .newOpeningBalance(groupKey: key) } : nil,
            hasExpenses: !vm.expenses.isEmpty,
            hasSettlements: !pairSettlements.isEmpty,
            header: hero(onTap: nil)
        )
        .id(filter)
    }

    /// «Todos los grupos» con varios grupos: la cifra, la tarjeta con el desglose y «Saldar todo».
    private var allGroupsBalances: some View {
        let breakdown = CompartidoPersonDetailLogic.breakdown(slices, filter: filter)
        let heroValue = CompartidoPersonDetailLogic.hero(slices, filter: filter)
        let plan = CompartidoPersonDetailLogic.settlePlan(slices, filter: filter)
        let writable = plan.allSatisfy { item in
            guard let group = viewModel.group(for: item.groupKey), let vm = viewModel.viewModel(for: item.groupKey) else {
                return false
            }
            return vm.canRecordNewEntries && !group.isMigratedFrozen
        }
        let hasPending = viewModel.entries(in: filter).contains { entry in
            entry.model.settlements.contains { !$0.isConfirmed }
        }
        return ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                hero(onTap: nil)
                if !plan.isEmpty {
                    CompartidoSettleAllCard(
                        personName: person.name,
                        personKey: person.id,
                        hero: heroValue,
                        breakdown: breakdown,
                        estimatedCurrencies: CompartidoPersonDetailLogic.estimatedCurrencies(slices, filter: filter),
                        onSettleAll: writable ? { settleAll(plan) } : nil)
                }
                if hasPending {
                    Text(L10n.Compartido.Detail.pickGroupHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("compartido_pick_group_hint")
                }
            }
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.safeBottom)
            .readableColumn()
        }
        .scrollViewGlassEdges()
    }

    /// Un solo pago: el formulario de «Saldar» de siempre. Varios: la hoja que los enumera.
    private func settleAll(_ plan: [CompartidoPersonDetailLogic.SettleItem]) {
        if plan.count == 1, let item = plan.first {
            sheet = .settlement(groupKey: item.groupKey, debt: item.debt)
        } else {
            sheet = .settleAll(plan)
        }
    }

    /// Apunta un pago por grupo y moneda, con el mismo servicio que «Saldar». Si uno falla, deshace los que entraron:
    /// a medias, la cifra de la persona no diría ni lo de antes ni lo pedido.
    private func recordAll(_ plan: [CompartidoPersonDetailLogic.SettleItem]) -> Bool {
        var saved: [(SplitSettlement, GroupDetailViewModel)] = []
        for item in plan {
            guard let group = viewModel.group(for: item.groupKey), let vm = viewModel.viewModel(for: item.groupKey) else {
                rollback(saved)
                return false
            }
            do {
                let settlement = try GroupExpenseService.shared.createSettlement(
                    in: group,
                    fromMemberID: item.debt.fromMemberID,
                    toMemberID: item.debt.toMemberID,
                    amount: item.debt.amount,
                    currencyCode: item.debt.currencyCode,
                    note: nil,
                    date: .now,
                    confirmed: SettlementSaldar23Logic.confirmsOnRecord(
                        recorderMemberID: item.myMemberID, fromMemberID: item.debt.fromMemberID,
                        toMemberID: item.debt.toMemberID)
                )
                saved.append((settlement, vm))
            } catch {
                #if DEBUG
                print("CompartidoPersonDetailView: Error recording settlement: \(error)")
                #endif
                rollback(saved)
                return false
            }
        }
        DS.Haptic.success()
        for vm in viewModel.viewModels.values { vm.loadData() }
        let undoable = saved
        DraftDiscardUndoNotice.show(
            message: L10n.Compartido.Detail.settleSaved(saved.count, person.name),
            systemImage: "checkmark.circle",
            undoTitle: L10n.UXL19.undo,
            noticeIdentifier: "compartido_settle_all_notice",
            undoIdentifier: "compartido_settle_all_undo",
            onUndo: { rollback(undoable) }
        )
        return true
    }

    private func rollback(_ saved: [(SplitSettlement, GroupDetailViewModel)]) {
        for (settlement, vm) in saved { vm.undoSettlement(settlement) }
    }

    // MARK: - Estadísticas

    private var statsPage: some View {
        let entries = viewModel.entries(in: filter)
        let filtered = CompartidoPersonDetailLogic.slices(slices, in: filter)
        let aliases = CompartidoPersonDetailLogic.memberAliases(filtered)
        var expenses: [SplitExpense] = []
        var shares: [SplitShare] = []
        var members: [SplitMember] = []
        var settlements: [SplitSettlement] = []
        for entry in entries {
            let vm = entry.model
            let personIDs = viewModel.personMemberIDs(in: entry.group.cloudKitZoneID)
            let participants = Dictionary(grouping: vm.shares, by: \.expenseID).mapValues { Set($0.map(\.memberID)) }
            let mine = vm.expenses.filter { expense in
                CompartidoPersonDetailLogic.isSharedExpense(
                    paidBy: expense.paidByMemberID, participants: participants[expense.id] ?? [],
                    myMemberID: vm.currentMemberID, personMemberIDs: personIDs)
            }
            let ids = Set(mine.map(\.id))
            expenses += mine
            shares += vm.shares.filter { ids.contains($0.expenseID) }
            members += vm.members
            settlements += vm.settlements
        }
        let byGroup = filter == .all ? CompartidoPersonDetailLogic.byGroup(slices) : []
        return GroupStatsView(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements,
            currentUserMemberID: aliases.me,
            currencyCode: entries.first?.group.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue,
            memberAliases: aliases.aliases,
            heroTitle: L10n.Compartido.Detail.statsTotalTogether,
            filterAccessory: AnyView(filterMenu),
            extraSection: byGroup.isEmpty ? nil : AnyView(CompartidoByGroupSection(
                rows: byGroup,
                colorHex: { key in viewModel.group(for: key).flatMap { $0.isPerson ? nil : $0.colorHex } }))
        )
        // Estadísticas lee sus datos al aparecer: otro filtro u otros gastos son otra vista.
        .id("\(filter)-\(expenses.count)-\(shares.count)")
    }

    // MARK: - Apuntar

    /// Los grupos compartidos donde se puede apuntar (ni archivados ni congelados).
    private var eligibleGroups: [SplitGroup] {
        viewModel.liveGroups.filter { group in
            guard let vm = viewModel.viewModel(for: group.cloudKitZoneID) else { return false }
            return vm.canRecordNewEntries && !group.isMigratedFrozen
        }
    }

    /// El grupo del filtro; con «Todos», lo sin grupo y, si no hay, el primero.
    private var initialGroup: SplitGroup? {
        let eligible = eligibleGroups
        switch filter {
        case .group(let key):
            if let group = eligible.first(where: { $0.cloudKitZoneID == key }) { return group }
        case .noGroup, .all:
            if let group = eligible.first(where: \.isPerson) { return group }
        }
        return eligible.first
    }

    private func startComposer(initial: SplitGroup?, receiptSplit: GroupExpensePrefillTemplate?) {
        guard let initial else { return }
        composerPayload = ComposerPayload(groups: eligibleGroups, initialGroup: initial, receiptSplit: receiptSplit)
    }

    private func startReceipt(_ source: GroupReceiptEntryKind) {
        guard let initial = initialGroup else { return }
        receiptRequest = GroupReceiptRequest(groups: eligibleGroups, preselected: initial, source: source)
    }

    private func activeMembers(of group: SplitGroup) -> [SplitMember] {
        viewModel.viewModel(for: group.cloudKitZoneID)?.activeMembers ?? []
    }

    private func composer(_ payload: ComposerPayload) -> some View {
        GroupExpenseComposerView(
            groups: payload.groups,
            initialGroup: payload.initialGroup,
            activeMembers: { activeMembers(of: $0) },
            memberNameLookup: { viewModel.viewModel(for: $0.cloudKitZoneID)?.memberNameLookup ?? [:] },
            memberCount: { activeMembers(of: $0).count },
            receiptSplit: payload.receiptSplit,
            onSave: { viewModel.loadGroups() }
        )
        .yalaSheetDetents([.large])
    }

    @ViewBuilder
    private var floatingNew: some View {
        if selectedTab == .records, showFloatingNew, let initial = initialGroup {
            CircularPlusFAB(
                tint: theme.accent,
                accessibilityLabel: L10n.Groups.Expense.newExpense,
                accessibilityIdentifier: "compartido_person_fab_new_expense"
            ) {
                startComposer(initial: initial, receiptSplit: nil)
            }
            .dsFloatingShadow()
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .transition(.opacity)
        }
    }

    // MARK: - Hojas

    private func sheetDismissed() {
        if let edit = pendingEdit {
            pendingEdit = nil
            sheet = edit.expense.isOpeningBalance
                ? nil
                : .editExpense(groupKey: edit.groupKey, expense: edit.expense)
        } else {
            for vm in viewModel.viewModels.values { vm.loadData() }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .expenseDetail(let key, let expense):
            if let vm = viewModel.viewModel(for: key) {
                GroupExpenseDetailSheet(
                    expense: expense,
                    share: vm.mySharesByExpense[expense.id],
                    allShares: vm.sharesForExpense(expense),
                    bridgeTransaction: vm.txBridgeMap[expense.id.uuidString],
                    subcategoryNameLookup: vm.subcategoryNameLookup,
                    memberNameLookup: vm.memberNameLookup,
                    currentMemberID: vm.currentMemberID,
                    onEdit: {
                        pendingEdit = (key, expense)
                        self.sheet = nil
                    }
                )
            }
        case .editExpense(let key, let expense):
            if let group = viewModel.group(for: key), let vm = viewModel.viewModel(for: key) {
                GroupExpenseFormView(
                    group: group,
                    members: membersForForm(expense, vm),
                    memberNameLookup: vm.memberNameLookup,
                    groupChip: .readOnly,
                    expenseToEdit: expense,
                    existingShares: sharesForSheet(expense, vm),
                    onSave: {},
                    onDelete: vm.canCurrentUserParticipate ? { vm.deleteExpense($0) } : nil
                )
                .yalaSheetDetents([.large])
                .presentationDragIndicator(.visible)
            }
        case .openingBalanceDetail(let key, let expense):
            if let vm = viewModel.viewModel(for: key) {
                GroupOpeningBalanceDetailSheet(
                    expense: expense,
                    debtorMemberID: sharesForSheet(expense, vm).first?.memberID,
                    memberNameLookup: vm.memberNameLookup,
                    canManage: false,
                    onEdit: {},
                    onDelete: {}
                )
            }
        case .newOpeningBalance(let key):
            if let group = viewModel.group(for: key), let vm = viewModel.viewModel(for: key) {
                GroupOpeningBalanceFormView(
                    group: group,
                    members: vm.activeMembers,
                    memberNameLookup: vm.memberNameLookup,
                    onSave: {}
                )
                .yalaSheetDetents([.large])
                .presentationDragIndicator(.visible)
            }
        case .settlement(let key, let debt):
            if let group = viewModel.group(for: key), let vm = viewModel.viewModel(for: key) {
                SettlementFormView(
                    group: group,
                    debt: debt,
                    memberNameLookup: vm.memberNameLookup,
                    currentUserMemberID: vm.currentMemberID,
                    onSave: { announceSavedSettlement($0, undoable: $1, vm: vm) }
                )
                .yalaSheetDetents([.large])
                .presentationDragIndicator(.visible)
            }
        case .settleAll(let plan):
            CompartidoSettleAllSheet(
                personName: person.name,
                items: plan,
                onConfirm: { recordAll(plan) }
            )
            .yalaSheetDetents([.medium, .large])
        }
    }

    /// El aviso de «Saldar» del detalle de grupo (decisión 37 de 2.3, C3): qué pasó, cómo queda la pareja y «Deshacer».
    private func announceSavedSettlement(_ settlement: SplitSettlement, undoable: Bool, vm: GroupDetailViewModel) {
        vm.loadData()
        let me = vm.currentMemberID
        let converted = vm.debtsWereConverted
        let keepTogether = { (text: String) in text.replacingOccurrences(of: " ", with: "\u{00A0}") }
        let message = SettlementSaldar23Logic.savedNotice(
            fromMemberID: settlement.fromMemberID,
            toMemberID: settlement.toMemberID,
            currentUserMemberID: me,
            isConfirmed: settlement.isConfirmed,
            amount: keepTogether(appPreferences.currency(settlement.amount, currencyCode: settlement.currencyCode)),
            remainder: SettlementSaldar23Logic.pairRemainder(
                debts: vm.debts, fromMemberID: settlement.fromMemberID, toMemberID: settlement.toMemberID),
            name: { id in id == me ? L10n.UXL13.you : vm.memberName(for: id) },
            format: { debts in
                debts.map {
                    keepTogether(appPreferences.currency($0.amount, currencyCode: $0.currencyCode, isEstimate: converted))
                }
                .joined(separator: " + ")
            }
        )
        let undo: (@MainActor () -> Void)?
        if undoable {
            undo = { vm.undoSettlement(settlement) }
        } else {
            undo = nil
        }
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "checkmark.circle",
            undoTitle: L10n.UXL19.undo,
            noticeIdentifier: "settlement_saved_notice",
            undoIdentifier: "settlement_saved_undo",
            onUndo: undo
        )
    }

    private func sharesForSheet(_ expense: SplitExpense, _ vm: GroupDetailViewModel) -> [SplitShare] {
        guard !expense.isDeleted, expense.modelContext != nil else { return [] }
        return vm.sharesForExpense(expense)
    }

    private func membersForForm(_ expense: SplitExpense, _ vm: GroupDetailViewModel) -> [SplitMember] {
        guard !expense.isDeleted, expense.modelContext != nil else { return vm.activeMembers }
        let referenced = Set([expense.paidByMemberID] + sharesForSheet(expense, vm).map(\.memberID))
        return vm.members.filter { $0.isActive || referenced.contains($0.id.uuidString) }
    }

    // MARK: - Vuelta a primer plano (molde de `GroupDetailView`, lote 1 de eficiencia)

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            frescura.alIrse(currentFirma())
            viewModel.setBackground(true)
        case .active:
            VueltaAPrimerPlano.alVolver(
                "detalle-persona",
                paginaVisible: isRootPageShown,
                soltarFreno: { viewModel.setBackground(false) },
                comprobar: {
                    let reload = frescura.alVolverVisible(
                        ahora: currentFirma(),
                        trabajoSinTerminar: viewModel.hasUnfinishedRecalculation,
                        cambiosSinGuardar: modelContext.hasChanges)
                    if reload { viewModel.reloadAndRecalculate() }
                },
                alQuedarOculta: { frescura = FrescuraAlVolver() }
            )
        @unknown default:
            break
        }
    }

    private func currentFirma() -> FirmaAlVolver {
        FirmaAlVolver.tomar(
            dataVersion: sessionState.dataVersion, storeSaves: StoreSaveCounter.shared.count, now: .now, calendar: .current)
    }
}

/// Empujado: sin barra de pestañas y con el gesto de volver, como el detalle de grupo. En columna, nada de eso.
private struct CompartidoPersonPushedChrome: ViewModifier {
    let isPushed: Bool

    func body(content: Content) -> some View {
        content
            .swipeBack(isEnabled: isPushed)
            .toolbar(isPushed ? .hidden : .automatic, for: .tabBar)
    }
}

/// Carga al aparecer, recarga con lo que baja por sync y frena en segundo plano. Aparte del `body` por el presupuesto
/// del type-checker del CI (`swiftui-ds.md`: tres modificadores por `ViewModifier`, cierres de una línea).
private struct CompartidoPersonLifecycle: ViewModifier {
    let model: CompartidoPersonDetailModel
    let modelContext: ModelContext
    let dataVersion: Int

    func body(content: Content) -> some View {
        content
            .onAppear { start() }
            .onDisappear { model.cancelRecalculation() }
            .onChange(of: dataVersion) { model.reloadAndRecalculate() }
    }

    private func start() {
        model.setContext(modelContext)
        Task { await model.refreshFromCloud() }
    }
}
