//
//  InboxView.swift
//  Yala
//
//  Bandeja de entrada para borradores de transacciones.
//  Fase 8: Registro Inteligente
//

import SwiftData
import SwiftUI

// MARK: - InboxView

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(DraftService.self) private var draftService
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Callback for navigating to Records tab (bulk approve success)
    var onNavigateToRecords: (() -> Void)?

    @State private var viewModel = InboxViewModel()
    @State private var selectedFilter: InboxFilter = .pending
    @State private var selectedDraft: InboxDraft?
    @State private var selectedTransaction: TransactionItem?

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedDraftIDs: Set<PersistentIdentifier> = []
    @State private var showBulkActions = false

    // Success view state (for swipe approve)
    @State private var showSwipeSuccessView = false
    @State private var swipeSuccessData: InboxApproveSuccessData?
    @State private var swipeApprovedTransaction: TransactionItem?

    // Pending next draft (for "Approve Next" flow)
    @State private var pendingNextDraftID: PersistentIdentifier?

    // Auto-dismiss when last draft approved via edit sheet
    @State private var shouldDismissAfterApproval = false

    // Archived account alert
    @State private var showArchivedAccountAlert = false

    // «Guardar los N listos» (UX 2.2 · L4-7): confirmación y pantalla final.
    @State private var showSaveReadyConfirmation = false
    @State private var showSaveReadySuccess = false
    @State private var saveReadyCount = 0
    @State private var saveReadySummary = InboxBulkApproveSummaryLogic.Summary(total: nil, currencyCode: nil, accountName: nil)
    @State private var saveReadyLeftover: String?

    // Group conversion flow (draft personal de gasto → SplitExpense de grupo). Approach A: el
    // edit sheet cierra y notifica; InboxView rutea. Un solo sheet activo a la vez (delays).
    @State private var pendingConversion: PendingConversion?
    @State private var conversionPicker: ConversionPickerData?
    @State private var conversionContext: ConversionContext?

    private var filteredDrafts: [InboxDraft] {
        viewModel.filteredDrafts(for: selectedFilter)
    }

    private var groupedDrafts: [(date: Date, drafts: [InboxDraft])] {
        viewModel.groupedDrafts(for: selectedFilter)
    }

    // MARK: - Group Scheduled Expense (F4)

    /// Carga el contexto (grupo + miembros + plantilla) para abrir el form de grupo prellenado
    /// desde un draft `.groupScheduledExpense`. Retorna nil si el grupo o el pago no están
    /// disponibles (borrados o sync pendiente) → el caller degrada al editor de draft personal.
    private func loadGroupScheduledContext(for draft: InboxDraft) -> (group: SplitGroup, members: [SplitMember], lookup: [String: String], template: GroupExpensePrefillTemplate)? {
        guard let zone = draft.splitGroupZoneID,
              let paymentIDString = draft.sourceScheduledPaymentID,
              let paymentUUID = UUID(uuidString: paymentIDString) else { return nil }

        let group: SplitGroup
        do {
            var d = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })
            d.fetchLimit = 1
            guard let found = try modelContext.fetch(d).first else { return nil }
            group = found
        } catch {
            #if DEBUG
            print("InboxView: error fetching group for scheduled expense: \(error)")
            #endif
            return nil
        }

        let payment: ScheduledPayment
        do {
            var d = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == paymentUUID })
            d.fetchLimit = 1
            guard let found = try modelContext.fetch(d).first else { return nil }
            payment = found
        } catch {
            #if DEBUG
            print("InboxView: error fetching payment for scheduled expense: \(error)")
            #endif
            return nil
        }

        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group, context: modelContext)
        } catch {
            #if DEBUG
            print("InboxView: error fetching members for scheduled expense: \(error)")
            #endif
            return nil
        }
        guard !members.isEmpty else { return nil }
        let lookup = Dictionary(members.map { ($0.id.uuidString, $0.resolvedDisplayName) }, uniquingKeysWith: { first, _ in first })

        // `effectiveDate` y no `date`: éste es opcional y su fallback (`createdAt`) es el que el resto
        // del Inbox ya usa para mostrar y ordenar. Por qué la del draft y no la del pago: en la lógica.
        let template = GroupScheduledExpenseTemplateLogic.buildTemplate(
            payment: payment, draftDate: draft.effectiveDate
        )
        return (group, members, lookup, template)
    }

    private func finalizeGroupScheduledExpense(draft: InboxDraft, expenseID: String) {
        // Poda la fila del Inbox ANTES de que el service borre el @Model (crash iOS 27, misma
        // clase que la conversión; ver InboxRowPruneCoordinator). El service solo borra ESTE
        // draft (sin hermanos) y aún lo lee (date/sourceScheduledPaymentID) antes del delete, así
        // que podar el array ahora es seguro. Se poda aquí — no vía el coordinador en el service —
        // porque este finalizer tiene el VM a mano y el service vive fuera del subsistema Inbox.
        viewModel.removeDraft(draft)
        ScheduledPaymentDraftService.handleGroupScheduledExpenseApproved(
            draft: draft, expenseID: expenseID, context: modelContext
        )
        shouldDismissAfterApproval = true
    }

    // MARK: - Convert Draft to Group Expense

    private struct PendingConversion {
        let draft: InboxDraft
        let groups: [SplitGroup]
    }
    private struct ConversionPickerData: Identifiable {
        let id = UUID()
        let draft: InboxDraft
        let groups: [SplitGroup]
        let memberCounts: [UUID: Int]
    }
    private struct ConversionContext: Identifiable {
        let id = UUID()
        let draft: InboxDraft
        let group: SplitGroup
        let members: [SplitMember]
        let lookup: [String: String]
        let template: GroupExpensePrefillTemplate
    }

    /// Arranca el flujo tras cerrarse el edit sheet: 1 grupo → form directo; >1 → picker.
    /// Delay para no apilar sobre la transición de cierre del edit sheet (patrón existente).
    private func startConversionFlow(_ pending: PendingConversion) {
        Task {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            if pending.groups.count == 1 {
                conversionContext = buildConversionContext(draft: pending.draft, group: pending.groups[0])
            } else {
                var counts: [UUID: Int] = [:]
                for group in pending.groups {
                    do {
                        counts[group.id] = try GroupService.shared.fetchMembers(for: group, context: modelContext)
                            .filter(\.isActive).count
                    } catch {
                        #if DEBUG
                        print("InboxView: error counting members for conversion picker: \(error)")
                        #endif
                        counts[group.id] = 0
                    }
                }
                conversionPicker = ConversionPickerData(draft: pending.draft, groups: pending.groups, memberCounts: counts)
            }
        }
    }

    /// Construye el contexto (miembros + lookup + plantilla) para abrir el form de grupo
    /// prellenado desde un draft personal. nil si el grupo no tiene miembros activos.
    private func buildConversionContext(draft: InboxDraft, group: SplitGroup) -> ConversionContext? {
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group, context: modelContext)
        } catch {
            #if DEBUG
            print("InboxView: error fetching members for conversion: \(error)")
            #endif
            return nil
        }
        let activeMembers = members.filter(\.isActive)
        guard !activeMembers.isEmpty else { return nil }
        let lookup = Dictionary(members.map { ($0.id.uuidString, $0.resolvedDisplayName) }, uniquingKeysWith: { first, _ in first })
        let template = DraftToGroupExpenseTemplateLogic.buildTemplate(
            amount: draft.amount ?? 0,
            cachedCurrencyCode: draft.cachedCurrencyCode,
            note: draft.note,
            activeMemberIDs: activeMembers.map { $0.id },
            groupCurrencyCode: group.currencyCode,
            accountPrefill: draft.account,
            // `effectiveDate`: `date` es opcional y su fallback (`createdAt`) es el que el resto
            // del Inbox usa para mostrar y ordenar.
            date: draft.effectiveDate,
            subcategory: draft.subcategory
        )
        return ConversionContext(draft: draft, group: group, members: members, lookup: lookup, template: template)
    }

    /// Cierra el ciclo tras crear el SplitExpense desde un draft personal: borra el draft.
    /// (No usa el expenseID — a diferencia del scheduled, no hay pago recurrente que vincular.)
    private func finalizeConvertedDraft(draft: InboxDraft) {
        // El service poda la fila del Inbox antes de borrar el @Model (crash iOS 27, ver
        // InboxRowPruneCoordinator).
        draftService.handleDraftConvertedToGroupExpense(draft, context: modelContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: DS.Spacing.none) {
                    // Mini-hero (panel-aligned). Pending-global; oculto en selection mode.
                    miniHero

                    // Filter chips
                    filterChips
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.md)

                    // Lo común —guardar lo que ya está listo— a un toque (UX 2.2 · L4-7). Antes eran cuatro: ✓,
                    // Seleccionar todo, Editar y Aprobar.
                    if !isSelectionMode && selectedFilter == .pending && readyDrafts.count >= 2 {
                        saveReadyButton
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.sm)
                    }

                    // Bulk action hint (shown when 2+ pending drafts and not in selection mode).
                    // Sin contador: el badge del mini-hero ya transmite la cantidad.
                    if !isSelectionMode && selectedFilter == .pending && filteredDrafts.count >= 2 {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "hand.tap")
                                .font(DS.Typography.captionSmall)
                                .accessibilityHidden(true)
                            Text(L10n.Inbox.bulkHint)
                                .font(DS.Typography.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.bottom, DS.Spacing.sm)
                    }

                    // Contextual guide for new users
                    ContextualGuideBanner.inbox()
                        .padding(.horizontal, DS.Spacing.lg)

                    // Content
                    if filteredDrafts.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        draftsList
                    }
                }
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Inbox.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isSelectionMode {
                    // Selection mode: Cancel left, Select All right
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.Action.cancel) {
                            dsWithAnimation(reduceMotion) {
                                exitSelectionMode()
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        let allSelected = selectedDraftIDs.count == filteredDrafts.count
                        Button(allSelected ? L10n.Export.deselectAll : L10n.Export.selectAll) {
                            dsWithAnimation(reduceMotion) {
                                if allSelected {
                                    selectedDraftIDs.removeAll()
                                } else {
                                    selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                                }
                            }
                        }
                    }
                } else {
                    // Normal mode: X left, selection icon right
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                            dismiss()
                        }
                        .accessibilityIdentifier("inbox_close")
                    }
                    if !filteredDrafts.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            // Este botón no aprueba nada: entra en modo selección. VoiceOver decía «Aprobar todo».
                            YalaToolbarButton(systemName: "checkmark.circle", label: L10n.Common.select) {
                                dsWithAnimation(reduceMotion) {
                                    isSelectionMode = true
                                }
                            }
                        }
                    }
                }
            }
            .tint(.primary)
            .sheet(item: $selectedDraft, onDismiss: {
                if shouldDismissAfterApproval {
                    shouldDismissAfterApproval = false
                    dismissIfNoPendingDrafts()
                } else {
                    viewModel.loadData()
                }
            }) { draft in
                // A0-Bridge V2.0 (P1-4): drafts de grupo usan sheets dedicadas que solo permiten
                // asignar lo que falta (subcat para groupExpense, cuenta para groupSettlement).
                // Drafts personales mantienen el flujo edit-completo existente.
                switch draft.sourceType {
                case .groupExpense:
                    // M6 + Enfoque B: route según qué falta. Account-only (sheet cuenta),
                    // account+subcategory (sheet combinado, Enfoque B), o subcategory-only
                    // (TX-puntero M5 heredado o fallback Caso A/B). El helper centraliza la
                    // decisión y la mantiene en sync con la intención del bridge.
                    let route = GroupDraftFinalizationLogic.route(
                        targetTransactionIDIsNil: draft.targetTransactionID == nil,
                        needsAccount: draft.needsUserInput.contains(DraftInputRequirement.account),
                        needsSubcategory: draft.needsUserInput.contains(DraftInputRequirement.subcategory)
                    )
                    switch route {
                    case .accountOnly:
                        GroupExpenseAccountFinalizationSheet(draft: draft) {
                            shouldDismissAfterApproval = true
                        }
                    case .accountAndSubcategory:
                        GroupExpenseAccountAndSubcategoryFinalizationSheet(draft: draft) {
                            shouldDismissAfterApproval = true
                        }
                    case .subcategoryOnly:
                        GroupExpenseDraftFinalizationSheet(draft: draft) {
                            shouldDismissAfterApproval = true
                        }
                    }
                case .groupSettlement:
                    // El aviso de importe cambiado de una liquidación ya aprobada tiene su hoja: ajustar o dejarla.
                    if draft.isSettlementAmountChangeNotice {
                        GroupSettlementAmountChangeSheet(draft: draft) {
                            shouldDismissAfterApproval = true
                        }
                    } else {
                        GroupSettlementDraftFinalizationSheet(draft: draft) {
                            shouldDismissAfterApproval = true
                        }
                    }
                case .groupScheduledExpense:
                    // F4: abre el form de gasto de grupo prellenado desde el pago planificado.
                    if let ctx = loadGroupScheduledContext(for: draft) {
                        GroupExpenseFormView(
                            group: ctx.group,
                            members: ctx.members,
                            memberNameLookup: ctx.lookup,
                            groupChip: .readOnly,
                            initialTemplate: ctx.template,
                            onSave: { shouldDismissAfterApproval = true },
                            onExpenseCreated: { expenseID in
                                finalizeGroupScheduledExpense(draft: draft, expenseID: expenseID)
                            },
                            presentsSuccessScreen: false
                        )
                    } else {
                        // Grupo/pago no disponible (borrado o sync pendiente): degradar al editor
                        // de draft personal — mi parte ya está en el draft; aprobarlo cierra el
                        // ciclo vía el path genérico (handleDraftApproved).
                        InboxDraftEditSheet(
                            draft: draft,
                            onApproved: { shouldDismissAfterApproval = true },
                            onApproveNext: { _ in },
                            onEditTransaction: { _ in }
                        )
                    }
                default:
                    InboxDraftEditSheet(
                        draft: draft,
                        onApproved: { shouldDismissAfterApproval = true },
                        onApproveNext: { nextDraft in
                            // Store the ID and close sheet - onChange will open the next
                            pendingNextDraftID = nextDraft.persistentModelID
                        },
                        onEditTransaction: { transaction in
                            // Open transaction editor after sheet dismiss
                            Task {
                                do {
                                    try await Task.sleep(for: .milliseconds(300))
                                } catch { return }
                                selectedTransaction = transaction
                            }
                        },
                        onConvertToGroupExpense: { convertDraft, groups in
                            // El sheet ya hizo saveDraft() + dismiss(); onChange arranca el flujo.
                            pendingConversion = PendingConversion(draft: convertDraft, groups: groups)
                        }
                    )
                }
            }
            .onChange(of: selectedDraft) { oldValue, newValue in
                guard oldValue != nil, newValue == nil else { return }
                // Prioridad: conversión a grupo sobre "abrir siguiente draft". Son mutuamente
                // excluyentes en la práctica (convertir no setea pendingNextDraftID), pero explícito.
                if let pending = pendingConversion {
                    pendingConversion = nil
                    pendingNextDraftID = nil
                    startConversionFlow(pending)
                    return
                }
                // When sheet closes and we have a pending next draft, open it
                if let nextID = pendingNextDraftID {
                    pendingNextDraftID = nil
                    // Find the draft by ID and open it
                    if let nextDraft = viewModel.findPendingDraft(by: nextID) {
                        openDraftAfterDelay(nextDraft)
                    }
                }
            }
            .sheet(item: $selectedTransaction, onDismiss: { viewModel.loadData() }) { transaction in
                NewTransactionView(transactionToEdit: transaction)
                    .presentationDetents([.large])
            }
            .sheet(item: $conversionPicker, onDismiss: { viewModel.loadData() }) { data in
                // >1 grupo elegible: elegir cuál antes de abrir el form prellenado.
                GroupPickerSheet(
                    groups: data.groups,
                    selectedGroupID: data.groups.first?.id ?? UUID(),
                    memberCount: { data.memberCounts[$0.id] ?? 0 }
                ) { picked in
                    let draft = data.draft
                    conversionPicker = nil
                    // Cerrar el picker y abrir el form con delay (evita apilar sheets).
                    Task {
                        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                        conversionContext = buildConversionContext(draft: draft, group: picked)
                    }
                }
                .yalaSheetDetents([.medium, .large])
            }
            .sheet(item: $conversionContext, onDismiss: { viewModel.loadData() }) { ctx in
                GroupExpenseFormView(
                    group: ctx.group,
                    members: ctx.members,
                    memberNameLookup: ctx.lookup,
                    groupChip: .readOnly,
                    initialTemplate: ctx.template,
                    onSave: {},
                    onExpenseCreated: { _ in
                        finalizeConvertedDraft(draft: ctx.draft)
                    },
                    presentsSuccessScreen: false
                )
            }
            .sheet(isPresented: $showBulkActions, onDismiss: { viewModel.loadData() }) {
                InboxBulkActionsSheet(
                    selectedDrafts: selectedDrafts,
                    filter: selectedFilter,
                    onComplete: {
                        exitSelectionMode()
                    },
                    onNavigateToRecords: {
                        // Call parent's navigation callback and dismiss
                        onNavigateToRecords?()
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showSwipeSuccessView) {
                if let data = swipeSuccessData {
                    InboxApproveSuccessView(
                        data: data,
                        hasNextDraft: viewModel.hasPendingDrafts,
                        onEdit: {
                            showSwipeSuccessView = false
                            if let transaction = swipeApprovedTransaction {
                                Task {
                                    do {
                                        try await Task.sleep(for: .milliseconds(300))
                                    } catch { return }
                                    selectedTransaction = transaction
                                }
                            }
                        },
                        onAccept: {
                            showSwipeSuccessView = false
                            dismissIfNoPendingDrafts()
                        },
                        onApproveNext: {
                            showSwipeSuccessView = false
                            if let next = viewModel.firstPendingDraft() {
                                openDraftAfterDelay(next)
                            }
                        }
                    )
                }
            }
            .alert(L10n.Inbox.cannotApprove, isPresented: $showArchivedAccountAlert) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.Inbox.errorArchivedAccount)
            }
            .modifier(InboxSaveReadyPresentations(
                showConfirmation: $showSaveReadyConfirmation,
                showSuccess: $showSaveReadySuccess,
                count: saveReadyCount,
                confirmCount: readyDrafts.count,
                summary: saveReadySummary,
                leftover: saveReadyLeftover,
                onConfirm: saveReadyDrafts,
                onViewRecords: {
                    showSaveReadySuccess = false
                    onNavigateToRecords?()
                    dismiss()
                },
                onBackToInbox: {
                    showSaveReadySuccess = false
                    dismissIfNoPendingDrafts()
                }
            ))
            .safeAreaInset(edge: .bottom) {
                if isSelectionMode {
                    selectionBar
                }
            }
            // Note: NO .appliesPendingRemoteChanges here — InboxView is always
            // presented as a sheet, and mutating @Observable during sheet transition
            // causes watchdog 0x8BADF00D. Reacts to remote changes via .onChange below.
            .task {
                viewModel.setContext(modelContext)
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                viewModel.loadData()
            }
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Select all / Deselect all
            Button {
                dsWithAnimation(reduceMotion) {
                    if selectedDraftIDs.count == filteredDrafts.count {
                        selectedDraftIDs.removeAll()
                    } else {
                        selectedDraftIDs = Set(filteredDrafts.map { $0.persistentModelID })
                    }
                }
            } label: {
                Image(systemName: selectedDraftIDs.count == filteredDrafts.count ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title)
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(selectedDraftIDs.count == filteredDrafts.count ? L10n.Filters.deselectAll : L10n.Filters.selectAll)

            // Count
            Text(L10n.Inbox.selectedCount(selectedDraftIDs.count))
                .font(DS.Typography.label)

            Spacer()

            // Actions button
            Button {
                showBulkActions = true
            } label: {
                Text(L10n.Action.edit)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(minHeight: 44)
                    .background(
                        Capsule()
                            .fill(selectedDraftIDs.isEmpty ? DS.Semantic.disabledForeground : theme.accent)
                    )
            }
            .disabled(selectedDraftIDs.isEmpty)
            .accessibilityHint(selectedDraftIDs.isEmpty ? L10n.Accessibility.selectAtLeastOneDraft : "")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private var selectedDrafts: [InboxDraft] {
        filteredDrafts.filter { selectedDraftIDs.contains($0.persistentModelID) }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedDraftIDs.removeAll()
    }

    // MARK: - Mini-hero (panel-aligned)

    @ViewBuilder
    private var miniHero: some View {
        if !isSelectionMode {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if pendingCount > 0 {
                    Text(L10n.Inbox.pendingBadge(pendingCount))
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, DS.Chip.paddingH)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Capsule().fill(theme.accent.opacity(0.15)))
                }
                // Qué es la Bandeja, siempre (UX 2.2 · L4-8): antes «2 transacciones esperando, paso a paso».
                Text(L10n.Inbox.explainer)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("inbox_explainer")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(heroAccessibilityLabel)
        }
    }

    private var pendingCount: Int {
        viewModel.countForFilter(.pending)
    }

    private var heroAccessibilityLabel: String {
        if pendingCount > 0 {
            return "\(L10n.Inbox.pendingBadge(pendingCount)). \(L10n.Inbox.explainer)"
        }
        return L10n.Inbox.explainer
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(InboxFilter.allCases, id: \.self) { filter in
                filterChip(for: filter)
            }
            Spacer()
        }
    }

    private func filterChip(for filter: InboxFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(DS.Typography.caption)
                Text(filter.displayName)
                    .font(DS.Typography.label)
                if count > 0 {
                    Text("\(count)")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, DS.Chip.paddingV)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("inbox_filter_\(filter.rawValue)")
    }

    private func countForFilter(_ filter: InboxFilter) -> Int {
        viewModel.countForFilter(filter)
    }

    // MARK: - Drafts List

    private var draftsList: some View {
        List {
            ForEach(groupedDrafts, id: \.date) { group in
                Section {
                    ForEach(group.drafts, id: \.persistentModelID) { draft in
                        draftRow(for: draft)
                    }
                } header: {
                    Text(formattedDate(group.date))
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.sectionDateFormatter.string(from: date)
    }

    private func draftRow(for draft: InboxDraft) -> some View {
        InboxDraftRowView(
            draft: draft,
            currencyCode: draft.displayCurrencyCode ?? appPreferences.defaultCurrencyCode.rawValue,
            isSelectionMode: isSelectionMode,
            isSelected: selectedDraftIDs.contains(draft.persistentModelID),
            onTap: {
                if isSelectionMode {
                    toggleSelection(draft)
                } else {
                    handleDraftTap(draft)
                }
            }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.lg, bottom: DS.Spacing.xs, trailing: DS.Spacing.lg))
        // «Quitar de aquí» no va con deslizamiento completo: no tiene «deshacer», y un gesto largo accidental lo escondería.
        // Deslizar del todo DESCARTA (va a Archivados, se puede deshacer); borrar para siempre es la segunda acción y
        // pide un toque a propósito (UX 2.2 · L4-6). En Archivados no hay deslizamiento completo: ahí la única acción
        // es borrar para siempre.
        .swipeActions(edge: .trailing, allowsFullSwipe: !isSelectionMode && selectedFilter == .pending
                      && !viewModel.canHideHere(draft)) {
            if !isSelectionMode {
                if selectedFilter == .pending && viewModel.canHideHere(draft) {
                    // Gasto de grupo sin su grupo en este teléfono: no se rechaza ni se borra (viajaría al otro
                    // dispositivo); se quita de la Bandeja solo aquí (`InboxGroupDraftsHiddenHere`).
                    Button {
                        hideDraftHere(draft)
                    } label: {
                        Label(L10n.Inbox.hideHere, systemImage: "eye.slash")
                    }
                    .tint(DS.Semantic.warningForeground)
                    .accessibilityHint(L10n.Inbox.hideHereHint)
                    .accessibilityIdentifier("inbox_hide_here")
                } else if selectedFilter == .pending {
                    // Pending: Descartar (primera: la del deslizamiento completo) + Eliminar. El aviso de importe
                    // cambiado no se borra (`DraftService.deleteDraft`): descartarlo es «dejarla como está».
                    Button {
                        rejectDraft(draft)
                    } label: {
                        Label(L10n.Inbox.reject, systemImage: "archivebox")
                    }
                    .tint(DS.Semantic.warningForeground)
                    .accessibilityIdentifier("inbox_swipe_reject")

                    if !draft.isSettlementAmountChangeNotice {
                        Button {
                            deleteDraftPermanently(draft)
                        } label: {
                            Label(L10n.Inbox.delete, systemImage: "trash")
                        }
                        .tint(DS.Semantic.errorForeground)
                        .accessibilityIdentifier("inbox_swipe_delete")
                    }
                } else if draft.status == .rejected && !draft.isSettlementAmountChangeNotice {
                    // Archived (rejected only): Delete
                    Button {
                        deleteDraftPermanently(draft)
                    } label: {
                        Label(L10n.Inbox.delete, systemImage: "trash")
                    }
                    .tint(DS.Semantic.errorForeground)
                }
                // Approved drafts in archived: no swipe actions
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: !isSelectionMode && draft.isReadyToApprove && !draft.requiresApprovalForm && selectedFilter == .pending) {
            if !isSelectionMode && draft.isReadyToApprove && !draft.requiresApprovalForm && selectedFilter == .pending {
                Button {
                    approveDraft(draft)
                } label: {
                    Label(L10n.Inbox.approve, systemImage: "checkmark.circle")
                }

            }
        }
    }

    private func toggleSelection(_ draft: InboxDraft) {
        dsWithAnimation(reduceMotion) {
            if selectedDraftIDs.contains(draft.persistentModelID) {
                selectedDraftIDs.remove(draft.persistentModelID)
            } else {
                selectedDraftIDs.insert(draft.persistentModelID)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        switch selectedFilter {
        case .pending:
            YalaEmptyState(
                icon: "tray",
                title: L10n.Inbox.noPending,
                message: L10n.Inbox.noPendingDescription
            )
        case .archived:
            YalaEmptyState(
                icon: "archivebox",
                title: L10n.Inbox.noArchived,
                message: L10n.Inbox.noArchivedDescription
            )
        }
    }

    // MARK: - Actions

    /// Descartar deslizando dice a dónde fue y deja deshacerlo (UX 2.2 · L4-6), con el mismo aviso que el editor.
    private func rejectDraft(_ draft: InboxDraft) {
        removeDraftWithAnimation(draft, hapticStyle: .light, onPersisted: { showDiscardedNotice(for: draft) }) { service, d in
            try service.rejectDraft(d)
        }
    }

    private func showDiscardedNotice(for draft: InboxDraft) {
        let draftService = draftService
        let context = modelContext
        let viewModel = viewModel
        DraftDiscardUndoNotice.show {
            guard !draft.isDeleted, draft.status == .rejected else { return }
            draftService.setContext(context)
            do {
                try draftService.returnToPending(draft)
            } catch {
                #if DEBUG
                print("InboxView: Error undoing discard: \(error)")
                #endif
            }
            viewModel.loadData()
        }
    }

    // MARK: - Guardar los listos (UX 2.2 · L4-7)

    private var readyDrafts: [InboxDraft] {
        InboxSaveReadyLogic.ready(viewModel.filteredDrafts(for: .pending))
    }

    private var saveReadyButton: some View {
        Button {
            showSaveReadyConfirmation = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
                Text(L10n.Inbox.saveReady(readyDrafts.count))
            }
            .font(DS.Typography.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(Color.selectedIndigoFill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("inbox_save_ready")
    }

    private func saveReadyDrafts() {
        let ready = readyDrafts
        guard !ready.isEmpty else { return }
        if ready.contains(where: { $0.account?.isArchived == true }) {
            showArchivedAccountAlert = true
            return
        }
        draftService.setContext(modelContext)
        do {
            let transactions = try draftService.bulkApprove(ready, currencyConverter: currencyConverter)
            viewModel.loadData()
            saveReadyCount = transactions.count
            saveReadySummary = InboxBulkApproveSummaryLogic.summary(
                of: transactions.map {
                    .init(amount: $0.amount, currencyCode: $0.currencyCode, accountName: $0.account?.name)
                }
            )
            saveReadyLeftover = InboxSaveReadyLogic.leftoverLine(viewModel.filteredDrafts(for: .pending))
            guard !transactions.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            // La alerta de confirmación se está cerrando: la hoja de éxito espera a que termine (mismo anchor).
            Task {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                showSaveReadySuccess = true
            }
        } catch {
            #if DEBUG
            print("InboxView: Error saving ready drafts: \(error)")
            #endif
        }
    }

    /// Quita el gasto de grupo de la Bandeja SOLO en este teléfono. No toca la fila: nada viaja al otro dispositivo.
    private func hideDraftHere(_ draft: InboxDraft) {
        guard InboxGroupDraftsHiddenHere.hide(draft, context: modelContext) else {
            viewModel.loadData()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dsWithAnimation(reduceMotion) {
            viewModel.removeDraft(draft)
        }
    }

    private func deleteDraftPermanently(_ draft: InboxDraft) {
        removeDraftWithAnimation(draft, hapticStyle: .rigid) { service, d in
            try service.deleteDraft(d)
        }
    }

    /// Animate draft removal from UI, then persist after animation completes.
    /// Delay avoids accessing invalidated SwiftData relationships during animation.
    private func removeDraftWithAnimation(
        _ draft: InboxDraft,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle,
        onPersisted: (() -> Void)? = nil,
        persist: @escaping (DraftService, InboxDraft) throws -> Void
    ) {
        UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()

        dsWithAnimation(reduceMotion) {
            viewModel.removeDraft(draft)
        }

        Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch { return }
            draftService.setContext(modelContext)
            do {
                try persist(draftService, draft)
                onPersisted?()
            } catch {
                #if DEBUG
                print("InboxView: Error persisting draft removal: \(error)")
                #endif
            }
            // Recargar SIEMPRE, también si guardó bien: la retirada optimista lo quitó de `allDrafts`, y sin recargar
            // un borrador recién rechazado no salía en Archivados hasta cerrar y volver a abrir la Bandeja.
            viewModel.loadData()
        }
    }

    /// Reload data and dismiss InboxView if no pending drafts remain.
    private func dismissIfNoPendingDrafts() {
        viewModel.loadData()
        if !viewModel.hasPendingDrafts {
            dismiss()
        }
    }

    /// Open a draft sheet after a delay, guarding against concurrent sheet presentations.
    private func openDraftAfterDelay(_ draft: InboxDraft) {
        Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch { return }
            guard selectedDraft == nil else { return }
            selectedDraft = draft
        }
    }

    private func approveDraft(_ draft: InboxDraft) {
        // Gasto planificado de grupo: no se aprueba inline (crearía una TX personal por el path
        // genérico). Abre el form dedicado que crea el SplitExpense de grupo.
        if draft.requiresApprovalForm {
            selectedDraft = draft
            return
        }
        guard let account = draft.account,
              let amount = draft.amount,
              let subcategory = draft.subcategory else { return }

        // Block approval if account is archived
        if account.isArchived {
            showArchivedAccountAlert = true
            return
        }

        // Haptic feedback for positive action
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // DB work OUTSIDE animation — only animate UI state changes
        draftService.setContext(modelContext)
        do {
            let transaction = try draftService.approveDraft(
                draft,
                currencyConverter: currencyConverter
            )

            // Animate only the UI transition
            dsWithAnimation(reduceMotion) {
                swipeApprovedTransaction = transaction
                swipeSuccessData = InboxApproveSuccessData(
                    date: draft.effectiveDate,
                    accountName: account.name,
                    accountColorHex: account.colorHex,
                    note: draft.note,
                    amount: amount,
                    currencyCode: account.currencyCode,
                    subcategoryName: subcategory.name,
                    categoryName: subcategory.safeCategory.name,
                    categoryColorHex: subcategory.safeCategory.colorHex,
                    isExpense: amount < 0
                )
                showSwipeSuccessView = true
            }
        } catch {
            #if DEBUG
            print("InboxView: Error approving draft: \(error)")
            #endif
        }
    }

    private func handleDraftTap(_ draft: InboxDraft) {
        switch draft.status {
        case .pending:
            // Show edit sheet for pending drafts
            selectedDraft = draft

        case .approved:
            // Check if we have a linked transaction
            if let transaction = draft.approvedTransaction {
                // Show the linked transaction
                selectedTransaction = transaction
            } else {
                // No linked transaction (old draft or transaction was deleted)
                // Allow re-approval by changing status to pending
                draftService.setContext(modelContext)
                do {
                    try draftService.returnToPending(draft)
                } catch {
                    #if DEBUG
                    print("InboxView: Error returning draft to pending: \(error)")
                    #endif
                }
                selectedDraft = draft
            }

        case .rejected:
            // Open editor for rejected drafts (status stays .rejected until user takes action)
            selectedDraft = draft
        }
    }

}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: InboxDraft.self, inMemory: true)
        .previewAppPreferences()
}

// MARK: - Guardar los listos: confirmación y pantalla final (UX 2.2 · L4-7)

/// Aparte del cuerpo de `InboxView`, que ya está al límite de lo que el compilador del CI tipa.
private struct InboxSaveReadyPresentations: ViewModifier {
    @Binding var showConfirmation: Bool
    @Binding var showSuccess: Bool
    let count: Int
    let confirmCount: Int
    let summary: InboxBulkApproveSummaryLogic.Summary
    let leftover: String?
    let onConfirm: () -> Void
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.Inbox.saveReadyConfirmTitle(confirmCount), isPresented: $showConfirmation) {
                Button(L10n.Inbox.saveReadyConfirmButton) { onConfirm() }
                    .accessibilityIdentifier("inbox_save_ready_confirm")
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Inbox.saveReadyConfirmMessage)
            }
            .sheet(isPresented: $showSuccess) {
                InboxBulkApproveSuccessView(
                    approvedCount: count,
                    summary: summary,
                    leftoverLine: leftover,
                    onViewRecords: onViewRecords,
                    onBackToInbox: onBackToInbox
                )
            }
    }
}
