//
//  GroupSettingsView.swift
//  Yala
//
//  Sheet de ajustes del grupo — info, miembros, opciones, acciones destructivas.
//

import SwiftUI
import SwiftData

struct GroupSettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState

    // MARK: - Input

    let group: SplitGroup
    @Bindable var viewModel: GroupDetailViewModel

    // MARK: - State

    @State private var editName: String = ""
    @State private var editIconName: String = ""
    @State private var editColorHex: String = ""
    @State private var showIconPicker: Bool = false
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var showCurrencyPicker: Bool = false
    @State private var defaultSplitType: SplitType = .equal

    @State private var showArchiveConfirm = false

    /// Cache del check `anyMemberHasOutstandingBalance` para evitar 4 fetches SwiftData
    /// por cada re-evaluación del body de SwiftUI. Se recalcula en `.onAppear` +
    /// `.onChange(of: sessionState.dataVersion)`.
    @State private var hasOutstandingDebt: Bool = false

    // Leave group
    @State private var showLeaveGroupConfirm = false
    @State private var isLeavingGroup = false
    @State private var showLeaveError = false
    @State private var leaveErrorMessage: String = ""
    @State private var showActionError = false
    @State private var actionErrorMessage: String = ""

    // FU-02: soft-delete owner-only.
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false

    // G6-3 (C5): "Borrar mi copia congelada" (owner-only, grupo migrado). Confirmación DOBLE.
    // D4: paso 1 = hoja de alcance (`.sheet`, `showDeleteCopyConfirm1`); "Borrar copia" fija
    // `pendingDeleteCopyConfirm2` y cierra la hoja; su `onDismiss` presenta el paso 2 (dialog corto) sin carrera.
    @State private var showDeleteCopyConfirm1 = false
    @State private var pendingDeleteCopyConfirm2 = false
    @State private var showDeleteCopyConfirm2 = false
    @State private var isDeletingCopy = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Info section
                    infoSection

                    // Group options section — visible para todos los miembros activos.
                    // simplify/split los edita cualquiera; moneda única queda owner-only (dimmed).
                    if viewModel.canCurrentUserParticipate {
                        optionsSection
                    }

                    // Integración personal (F4): visible solo para members .isActive.
                    if viewModel.canCurrentUserParticipate {
                        personalIntegrationSection
                    }

                    // Leave group (non-owner)
                    if !group.isOwner {
                        leaveGroupSection
                    }

                    // Danger zone (archive)
                    if viewModel.isCurrentUserAdmin {
                        dangerZoneSection
                    }

                    // FU-02: soft-delete (owner-only).
                    if group.isOwner {
                        deleteGroupSection
                    }

                    // G6-3 (C5): "Borrar mi copia congelada" — owner del grupo YA migrado a backend (la zona
                    // CloudKit sigue viva pero es basura). Owner-only v1 (el path del member queda fuera).
                    if group.isOwner && group.movedToBackendAt != nil && group.ckSystemFieldsData != nil {
                        migratedDeleteCopySection
                    }

                    // C-10: gate INVERSO al de arriba — el grupo AÚN no se movió, y no se moverá mientras
                    // alguien no pueda seguirle. Nombrar a los rezagados convierte un bloqueo silencioso
                    // en algo sobre lo que el owner puede actuar.
                    //
                    // Espeja el gate del uploader (`GroupMigrationUploader.run` + candidatos) A PROPÓSITO:
                    // sin sesión, sin consent o sin zona CloudKit, quien bloquea la migración es el PROPIO
                    // owner, y nombrar entonces a los miembros sería culpar a quien no tiene la culpa.
                    if group.isOwner && group.movedToBackendAt == nil && group.ckSystemFieldsData != nil
                        && CloudSyncFlags.groupsBackendEnabled
                        && CloudAuthService.shared.hasSession && GroupsConsentState.isAccepted
                        && !migrationLaggards.isEmpty {
                        migrationWaitingSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .onDisappear { saveIdentity() }
            .onAppear { recomputeOutstandingDebt() }
            .onChange(of: sessionState.dataVersion) { _, _ in
                recomputeOutstandingDebt()
            }
            .navigationTitle(L10n.Groups.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
            }
            .confirmationDialog(
                L10n.Groups.Settings.leaveGroup,
                isPresented: $showLeaveGroupConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) {
                    Task { await leaveGroup() }
                }
            } message: {
                if hasOutstandingBalance {
                    Text(L10n.Groups.Settings.leaveGroupWithDebtWarning)
                } else {
                    Text(L10n.Groups.Settings.leaveGroupConfirm)
                }
            }
            .confirmationDialog(
                L10n.Groups.Settings.archive,
                isPresented: $showArchiveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.archive, role: .destructive) {
                    performArchiveToggle(isArchiving: true)
                }
            } message: {
                if hasOutstandingDebt {
                    Text(L10n.Groups.Settings.archiveWithDebtWarning)
                } else {
                    Text(L10n.Groups.Settings.archiveConfirm)
                }
            }
            .alert(L10n.Common.error, isPresented: $showLeaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(leaveErrorMessage)
            }
            .alert(L10n.Common.error, isPresented: $showActionError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(actionErrorMessage)
            }
            .confirmationDialog(
                L10n.Groups.Settings.deleteGroupConfirm,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    Task { await performSoftDelete() }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Groups.Settings.deleteGroupFinalConfirm)
            }
            // G6-3 (C5) + D4: paso 1 = hoja de alcance (📱/☁️/👥). "Borrar copia" fija el flag y cierra la
            // hoja; el `onDismiss` presenta el paso 2 (dialog corto EXISTENTE) sin carrera same-anchor.
            .sheet(isPresented: $showDeleteCopyConfirm1, onDismiss: {
                if pendingDeleteCopyConfirm2 {
                    pendingDeleteCopyConfirm2 = false
                    showDeleteCopyConfirm2 = true
                }
            }) {
                DestructiveScopeSheet(config: .make(
                    operation: .deleteFrozenCopy,
                    cloudLabel: .icloud,  // la copia congelada es siempre la zona CloudKit vieja de iCloud
                    onConfirm: { pendingDeleteCopyConfirm2 = true }))
            }
            .confirmationDialog(
                L10n.Groups.Migrated.deleteCopyConfirmTitle,
                isPresented: $showDeleteCopyConfirm2,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Migrated.deleteCopyConfirmButton, role: .destructive) {
                    performDeleteFrozenCopy()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Groups.Migrated.deleteCopyConfirmBody)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        SectionBox(title: L10n.Groups.Settings.info) {
            HStack(spacing: DS.Spacing.md) {
                if viewModel.isCurrentUserAdmin {
                    // Group icon — tappable to change (admin only)
                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: editColorHex))
                                .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                            Image(systemName: editIconName)
                                .font(DS.Typography.title2)
                                .foregroundStyle(.white)

                            // A11Y-DT: decorative edit badge on group icon
                            Image(systemName: "pencil.circle.fill")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color(hex: editColorHex))
                                .background(Circle().fill(.white).frame(width: 16, height: 16))
                                .offset(x: 16, y: 16)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Form.icon)

                    // Group name — editable inline (admin only)
                    TextField(L10n.Groups.Form.namePlaceholder, text: $editName)
                        .font(DS.Typography.headline)
                        .onSubmit { saveIdentity() }
                } else {
                    // Group icon — static (non-admin)
                    ZStack {
                        Circle()
                            .fill(Color(hex: editColorHex))
                            .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                        Image(systemName: editIconName)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                    }

                    // Group name — read-only (non-admin)
                    Text(editName)
                        .font(DS.Typography.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .onAppear {
            editName = group.name
            editIconName = group.iconName
            editColorHex = group.colorHex
        }
        .sheet(isPresented: $showIconPicker, onDismiss: {
            saveIdentity()
        }) {
            IconColorPickerSheet(
                selectedIconName: $editIconName,
                selectedColorHex: $editColorHex
            )
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        SectionBox(title: L10n.Groups.Settings.options) {
            VStack(spacing: DS.Spacing.none) {
                // Simplify Debts — cualquier miembro activo
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.simplifyDebts, isOn: $simplifyDebts)
                        .font(DS.Typography.body)

                    Text(L10n.Groups.Form.simplifyDebtsHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: simplifyDebts) { _, newValue in
                    // Guard de igualdad: el `.onAppear` siembra el @State desde el group, lo que
                    // dispararía un save+sync espurio en cada apertura sin este check.
                    guard newValue != group.simplifyDebts else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        updateMemberOption { $0.simplifyDebts = newValue }
                    }
                }

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Show debts in single currency — owner-only (visible para todos, dimmed si no-owner)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.showDebtsInSingleCurrency, isOn: $showDebtsInSingleCurrency)
                        .font(DS.Typography.body)

                    Text(L10n.Groups.Form.showDebtsInSingleCurrencyHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    if showDebtsInSingleCurrency {
                        Button {
                            showCurrencyPicker = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                let info = currencyInfo(for: selectedCurrency)
                                Text(info.flag)
                                    .font(DS.Typography.body)

                                Text(info.code)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(info.name.capitalized)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if !group.isOwner {
                        Text(L10n.Groups.Options.ownerOnlyHint)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!group.isOwner)
                .opacity(group.isOwner ? 1 : 0.5)
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: showDebtsInSingleCurrency) { _, newValue in
                    guard newValue != group.showDebtsInSingleCurrency else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        updateGroupOption { group in
                            group.showDebtsInSingleCurrency = newValue
                            if !newValue {
                                group.currencyCode = appPreferences.defaultCurrencyCode.rawValue
                            }
                        }
                        if !newValue {
                            selectedCurrency = appPreferences.defaultCurrencyCode
                        }
                    }
                }
                .onChange(of: selectedCurrency) { _, newValue in
                    guard newValue.rawValue != group.currencyCode else { return }
                    updateGroupOption { $0.currencyCode = newValue.rawValue }
                }

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Default split type — cualquier miembro activo
                HStack {
                    Text(L10n.Groups.Form.defaultSplitType)
                        .font(DS.Typography.body)

                    Spacer()

                    Picker("", selection: $defaultSplitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: defaultSplitType) { _, newValue in
                    guard newValue.rawValue != group.defaultSplitType else { return }
                    updateMemberOption { $0.defaultSplitType = newValue.rawValue }
                }
            }
        }
        .onAppear {
            simplifyDebts = group.simplifyDebts
            showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
            selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
            defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        }
    }

    // MARK: - Personal Integration (Bridge Override per-grupo, F4)

    @State private var showPerGroupDeactivationSheet: Bool = false

    private var personalIntegrationState: OverrideStateLogic.UIState {
        OverrideStateLogic.compute(
            global: appPreferences.bridgeGroupExpensesToPersonalAccounts,
            override: BridgeModeResolver.shared.override(forZoneID: group.cloudKitZoneID, context: modelContext),
            memberIsActive: viewModel.canCurrentUserParticipate
        )
    }

    /// Binding al estado visual del toggle. Lectura: deriva del state computed.
    /// Escritura: invoca el resolver para persistir override.
    private var personalIntegrationToggle: Binding<Bool> {
        Binding(
            get: {
                switch personalIntegrationState {
                case .enabledOnInheriting, .enabledOnLocal: return true
                case .enabledOffLocal, .disabledOff, .hiddenSection: return false
                }
            },
            set: { newValue in
                let global = appPreferences.bridgeGroupExpensesToPersonalAccounts
                guard global else { return }  // disabled cuando global OFF
                do {
                    // ON estando OFF → setOverride(nil) (volver a heredar).
                    // OFF estando ON → setOverride(false) (override OFF explícito).
                    let override: Bool? = newValue ? nil : false
                    try BridgeModeResolver.shared.setOverride(for: group, override: override, in: modelContext)
                    // Si user desactivó (newValue==false) Y hay TX bridgeadas para este
                    // grupo, presenta BridgeDeactivationSheet scoped (plan F4) para que
                    // el user decida freeze vs delete.
                    if !newValue && hasBridgedTransactionsForGroup() {
                        showPerGroupDeactivationSheet = true
                    }
                } catch {
                    #if DEBUG
                    print("personalIntegrationToggle: setOverride failed: \(error)")
                    #endif
                }
            }
        )
    }

    @ViewBuilder
    private var personalIntegrationSection: some View {
        let state = personalIntegrationState
        if state != .hiddenSection {
            SectionBox(title: L10n.Groups.Settings.personalIntegrationSectionTitle) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(
                        L10n.Groups.Settings.personalIntegrationToggleLabel,
                        isOn: personalIntegrationToggle
                    )
                    .font(DS.Typography.body)
                    .disabled(state == .disabledOff)

                    Text(personalIntegrationHint(for: state))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
            }
            .sheet(isPresented: $showPerGroupDeactivationSheet) {
                BridgeDeactivationSheet(
                    scope: .perGroup(zoneID: group.cloudKitZoneID, groupName: group.name),
                    onConfirm: { /* cleanup hecho dentro del sheet */ },
                    onCancel: revertPerGroupOverride
                )
            }
        }
    }

    /// Revierte el override per-grupo cuando user cancela el sheet de deactivation
    /// (restauración del intent: si user cancela, no quiere desactivar).
    private func revertPerGroupOverride() {
        do {
            try BridgeModeResolver.shared.setOverride(for: group, override: nil, in: modelContext)
        } catch {
            #if DEBUG
            print("revertPerGroupOverride failed: \(error)")
            #endif
        }
    }

    /// Conteo de TX bridgeadas para este grupo (`splitGroupZoneID == cloudKitZoneID`).
    private func hasBridgedTransactionsForGroup() -> Bool {
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> {
                $0.splitGroupZoneID == zoneID &&
                ($0.splitExpenseID != nil || $0.splitSettlementID != nil)
            }
        )
        do {
            return try modelContext.fetchCount(descriptor) > 0
        } catch {
            #if DEBUG
            print("hasBridgedTransactionsForGroup: fetchCount failed: \(error)")
            #endif
            return false
        }
    }

    private func personalIntegrationHint(for state: OverrideStateLogic.UIState) -> String {
        switch state {
        case .hiddenSection: return ""
        case .disabledOff: return L10n.Groups.Settings.personalIntegrationHintBlockedByGlobal
        case .enabledOnInheriting, .enabledOnLocal: return L10n.Groups.Settings.personalIntegrationHintInheritOn
        case .enabledOffLocal: return L10n.Groups.Settings.personalIntegrationHintLocalOff
        }
    }

    // MARK: - Danger Zone (Archive)

    private var dangerZoneSection: some View {
        VStack(spacing: DS.Spacing.none) {
            Button {
                toggleArchive()
            } label: {
                HStack {
                    Image(systemName: group.isArchived ? "archivebox.fill" : "archivebox")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(group.isArchived ? L10n.Groups.Settings.unarchive : L10n.Groups.Settings.archive)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .solidCard(radius: DS.Radius.card)
    }

    // MARK: - Leave Group

    private var leaveGroupSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                showLeaveGroupConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Settings.leaveGroup)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isLeavingGroup {
                        ProgressView()
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLeavingGroup)
        }
        .solidCard(radius: DS.Radius.card)
    }

    // MARK: - FU-02 Soft-delete (owner-only)

    private var deleteGroupSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                // Refresh cache antes de mostrar el dialog — simétrico con toggleArchive,
                // evita falsos negativos si el sync trajo deuda después del último
                // onAppear/dataVersion change.
                recomputeOutstandingDebt()
                guard !hasOutstandingDebt else { return }
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Settings.deleteGroup)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isDeleting {
                        ProgressView()
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(hasOutstandingDebt || isDeleting)

            if hasOutstandingDebt {
                Text(L10n.Groups.Settings.deleteGroupDisabledHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.bottom, DS.FormRow.paddingV)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .solidCard(radius: DS.Radius.card)
    }

    // G6-3 (C5): sección "Borrar mi copia congelada" (owner del grupo migrado).
    private var migratedDeleteCopySection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                showDeleteCopyConfirm1 = true
            } label: {
                HStack {
                    Image(systemName: "trash.slash.fill")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Migrated.deleteCopyRow)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isDeletingCopy { ProgressView() }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDeletingCopy)

            Text(L10n.Groups.Migrated.deleteCopyHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.bottom, DS.FormRow.paddingV)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .solidCard(radius: DS.Radius.card)
    }

    // MARK: - C-10: espera de capacidad de los miembros

    /// Miembros que hoy BLOQUEAN la migración de este grupo (sin beacon de capacidad, con beacon caducado
    /// o sin `cloudKitUserRecordID`). Vacío ⇒ la sección no se muestra.
    private var migrationLaggards: [SplitMember] {
        let snapshots = viewModel.members.map { member in
            MemberCapabilitySnapshot(
                memberKey: member.id.uuidString,
                isGroupOwner: member.isGroupOwner,
                status: member.memberStatus,
                hasRecordName: !member.cloudKitUserRecordID.isEmpty,
                capability: member.clientCapability,
                capabilityAt: member.clientCapabilityAt
            )
        }
        let blockingKeys = Set(
            GroupMigrationReadinessLogic.laggards(members: snapshots, now: .now).map(\.memberKey)
        )
        return viewModel.members.filter { blockingKeys.contains($0.id.uuidString) }
    }

    /// C-10: sección owner-only que nombra a quien falta y explica la ÚNICA salida (quitar a quien ya no
    /// participa). No hay botón "Mover de todos modos" a propósito: forzar la migración dejaría al
    /// rezagado exactamente en el estado que este trabajo cierra.
    private var migrationWaitingSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(L10n.Groups.Migrated.waitingSectionTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                Spacer()
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.top, DS.FormRow.paddingV)

            ForEach(migrationLaggards, id: \.id) { member in
                Text(member.resolvedDisplayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(L10n.Groups.Migrated.waitingHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.bottom, DS.FormRow.paddingV)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .solidCard(radius: DS.Radius.card)
    }

    /// G6-3 (C5): borra la zona CloudKit congelada (private engine del owner — `deleteZone` no tiene guard
    /// isBackendGroup). Limpia el `ckSystemFieldsData` local (la sección se oculta) y cierra. La verdad del
    /// grupo sigue viva en el backend.
    /// RESIDUAL R3/LOW-2 (review G6-3, aceptado): el `deleteZone` es un ENQUEUE durable a CKSyncEngine
    /// (fire-and-forget — no hay ack awaitable); si el delete fallara PERMANENTE server-side, la zona
    /// quedaría huérfana en CloudKit con la fila local ya "sin copia" (cosmético: el guard de PULL la
    /// ignora y el path C5 desaparece — sin reintento). Sin daño de datos: el backend es la verdad.
    private func performDeleteFrozenCopy() {
        guard !isDeletingCopy else { return }
        isDeletingCopy = true
        SplitZoneManager(syncManager: .shared).deleteZone(for: group)
        group.ckSystemFieldsData = nil
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("GroupSettingsView: performDeleteFrozenCopy save failed: \(error)")
            #endif
        }
        isDeletingCopy = false
        DS.Haptic.success()
        dismiss()
    }

    private func performSoftDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try GroupService.shared.softDelete(group)
            DS.Haptic.warning()
            dismiss()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    private func hasNonZeroBalance(for memberID: String) -> Bool {
        viewModel.balances
            .filter { $0.memberID == memberID }
            .contains { abs($0.netBalance) > 0.01 }
    }

    private var hasOutstandingBalance: Bool {
        let current: SplitMember? = {
            if let recordName = GroupUserIdentityService.shared.cachedRecordName, !recordName.isEmpty {
                return viewModel.members.first(where: { $0.cloudKitUserRecordID == recordName })
            }
            return viewModel.currentUserMember
        }()
        guard let current else { return false }
        return hasNonZeroBalance(for: current.id.uuidString)
    }

    /// Alcance global: cualquier miembro con balance pendiente. Cubre cross-currency
    /// automáticamente porque `MemberBalance` tiene una entry por memberID×currencyCode.
    ///
    /// Bypass del cache `viewModel.balances` con fetches directos del context — defense
    /// in depth para casos donde `loadData` no haya corrido al momento del tap archive
    /// (race con sync, cold launch del settings, etc). Fallback graceful al cache del VM
    /// si los fetches throw. El resultado se cachea en `hasOutstandingDebt`
    /// (recalculado en `.onAppear` + `onChange(dataVersion)` + pre-tap de archive/delete)
    /// para evitar fetches por cada re-evaluación del body de SwiftUI.
    private func recomputeOutstandingDebt() {
        let zoneID = group.cloudKitZoneID
        do {
            // Early exit: si el grupo no tiene expenses, no hay deuda posible — skip los
            // otros 3 fetches + `calculateBalances`. `fetchCount` es O(1) en SwiftData
            // (delega a SQL COUNT). Ahorra ~50ms en grupos vacíos/recién creados.
            let expensesCount = try modelContext.fetchCount(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            guard expensesCount > 0 else {
                hasOutstandingDebt = false
                return
            }

            let expenses = try modelContext.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let shares = try modelContext.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let settlements = try modelContext.fetch(FetchDescriptor<SplitSettlement>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let members = try modelContext.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let balances = GroupBalanceService.calculateBalances(
                expenses: expenses,
                shares: shares,
                members: members,
                settlements: settlements
            )
            hasOutstandingDebt = balances.contains { abs($0.netBalance) > 0.01 }
        } catch {
            #if DEBUG
            print("GroupSettingsView: recomputeOutstandingDebt fetch error \(error), fallback to cache")
            #endif
            hasOutstandingDebt = viewModel.balances.contains { abs($0.netBalance) > 0.01 }
        }
    }

    private func leaveGroup() async {
        guard !isLeavingGroup else { return }
        isLeavingGroup = true
        defer { isLeavingGroup = false }

        do {
            try await GroupService.shared.leaveGroup(group)
            DS.Haptic.success()
            dismiss()
        } catch {
            DS.Haptic.warning()
            leaveErrorMessage = error.localizedDescription
            showLeaveError = true
        }
    }

    // MARK: - Actions

    private func saveIdentity() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let nameChanged = trimmedName != group.name
        let iconChanged = editIconName != group.iconName
        let colorChanged = editColorHex != group.colorHex
        guard nameChanged || iconChanged || colorChanged else { return }

        do {
            try GroupService.shared.updateGroup(
                group,
                name: trimmedName,
                iconName: editIconName,
                colorHex: editColorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    private func toggleArchive() {
        let willArchive = !group.isArchived
        // Refresca el cache antes del check para evitar valor stale si el sync trajo
        // data después del último onAppear/dataVersion change.
        if willArchive { recomputeOutstandingDebt() }
        if willArchive && hasOutstandingDebt {
            showArchiveConfirm = true
            return
        }
        performArchiveToggle(isArchiving: willArchive)
    }

    private func performArchiveToggle(isArchiving: Bool) {
        do {
            try GroupService.shared.setArchived(group, isArchived: isArchiving)
            DS.Haptic.success()
            viewModel.loadData()
            if group.isArchived {
                dismiss()
            }
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    private func updateGroupOption(_ update: (SplitGroup) -> Void) {
        update(group)
        do {
            try GroupService.shared.updateGroup(
                group,
                name: group.name,
                iconName: group.iconName,
                colorHex: group.colorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    /// Variante de `updateGroupOption` para las opciones que cualquier miembro activo puede
    /// cambiar (simplify/split). Usa `updateMemberEditableOptions` (guard de miembro activo, no
    /// admin) para no reintroducir el alert "solo admins" de B-19.
    private func updateMemberOption(_ update: (SplitGroup) -> Void) {
        update(group)
        do {
            try GroupService.shared.updateMemberEditableOptions(
                group,
                simplifyDebts: group.simplifyDebts,
                defaultSplitType: group.defaultSplitType
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

}
