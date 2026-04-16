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

    // MARK: - Input

    let group: SplitGroup
    @Bindable var viewModel: GroupDetailViewModel

    // MARK: - State

    @State private var editName: String = ""
    @State private var editIconName: String = ""
    @State private var editColorHex: String = ""
    @State private var showIconPicker: Bool = false
    @State private var isCreatingShare = false
    @State private var shareURL: URL?
    @State private var hasExistingShare = false
    @State private var showShareSheet = false
    @State private var showRemoveMemberConfirm = false
    @State private var memberToRemove: SplitMember?
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var showCurrencyPicker: Bool = false
    @State private var defaultSplitType: SplitType = .equal
    @State private var membersCanInvite: Bool = true
    @State private var showRegenerateLinkConfirm = false
    @State private var isRegeneratingLink = false
    @State private var personalAutoCreate: Bool = true
    @State private var groupCurrencies: [String] = []
    @State private var accountPrefs: [String: String] = [:]   // currencyCode → accountName
    @State private var accountsByCurrency: [String: [Account]] = [:]
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Info section
                    infoSection

                    // Members section
                    membersSection

                    // Group options section
                    optionsSection

                    // Personal settings section
                    mySettingsSection

                    // Danger zone (archive)
                    if viewModel.isCurrentUserAdmin {
                        dangerZoneSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.thBackground)
            .onDisappear { saveIdentity() }
            .task {
                hasExistingShare = await SplitZoneManager(syncManager: .shared).hasShare(for: group)
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
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                        }
            }
            .confirmationDialog(
                L10n.Groups.Member.remove,
                isPresented: $showRemoveMemberConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Member.remove, role: .destructive) {
                    removeMember()
                }
            } message: {
                Text(L10n.Groups.Member.removeConfirm)
            }
            .confirmationDialog(
                L10n.Groups.Settings.regenerateLink,
                isPresented: $showRegenerateLinkConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.regenerateLink, role: .destructive) {
                    Task { await regenerateShareLink() }
                }
            } message: {
                Text(L10n.Groups.Settings.regenerateLinkConfirm)
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

    // MARK: - Members Section

    private var membersSection: some View {
        SectionBox(title: L10n.Groups.Settings.members) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(viewModel.members, id: \.id) { member in
                    GroupMemberRow(
                        member: member,
                        groupColorHex: group.colorHex,
                        isCurrentUserAdmin: viewModel.isCurrentUserAdmin,
                        onChangeRole: { changeRole(member) },
                        onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        }
                    )

                    if member.id != viewModel.members.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }

                // Invite by link
                if viewModel.isCurrentUserAdmin || group.membersCanInvite {
                    Divider()
                    Button {
                        Task { await createShareLink() }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "link.badge.plus")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.thAccent)

                            Text(L10n.Groups.Settings.invite)
                                .font(DS.Typography.body)
                                .foregroundStyle(.thAccent)

                            Spacer()

                            if isCreatingShare {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingShare)

                    // Regenerate link (visible if a share exists in CloudKit)
                    if hasExistingShare {
                        Divider()
                        Button {
                            showRegenerateLinkConfirm = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(DS.Typography.title2)
                                    .foregroundStyle(DS.Semantic.errorForeground)

                                Text(L10n.Groups.Settings.regenerateLink)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Semantic.errorForeground)

                                Spacer()

                                if isRegeneratingLink {
                                    ProgressView()
                                }
                            }
                            .padding(.horizontal, DS.FormRow.paddingH)
                            .padding(.vertical, DS.FormRow.paddingV)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRegeneratingLink)
                    }
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        SectionBox(title: L10n.Groups.Settings.options) {
            VStack(spacing: DS.Spacing.none) {
                // Simplify Debts
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        updateGroupOption { $0.simplifyDebts = newValue }
                    }
                }

                // Admin-only options
                if viewModel.isCurrentUserAdmin {
                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    // Show debts in single currency
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
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .onChange(of: showDebtsInSingleCurrency) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            updateGroupOption { $0.showDebtsInSingleCurrency = newValue }
                        }
                    }
                    .onChange(of: selectedCurrency) { _, newValue in
                        updateGroupOption { $0.currencyCode = newValue.rawValue }
                    }

                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    // Default split type
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
                        updateGroupOption { $0.defaultSplitType = newValue.rawValue }
                    }

                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    // Members can invite
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Toggle(L10n.Groups.Form.membersCanInvite, isOn: $membersCanInvite)
                            .font(DS.Typography.body)

                        Text(L10n.Groups.Form.membersCanInviteHint)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .onChange(of: membersCanInvite) { _, newValue in
                        updateGroupOption { $0.membersCanInvite = newValue }
                    }
                }
            }
        }
        .onAppear {
            simplifyDebts = group.simplifyDebts
            showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
            selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
            defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
            membersCanInvite = group.membersCanInvite
        }
    }

    // MARK: - My Settings Section

    private var mySettingsSection: some View {
        SectionBox(title: L10n.Groups.Settings.mySettings) {
            VStack(spacing: DS.Spacing.none) {
                // Auto-create transaction (personal)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.autoCreate, isOn: $personalAutoCreate)
                        .font(DS.Typography.body)

                    Text(L10n.Groups.Form.autoCreateHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: personalAutoCreate) { _, newValue in
                    GroupPersonalPreferences.setAutoCreateTransaction(newValue, for: group.cloudKitZoneID)
                }

                if personalAutoCreate {
                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    Text(L10n.Groups.Form.defaultAccountPickerHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.top, DS.Spacing.sm)

                    ForEach(groupCurrencies, id: \.self) { code in
                        let info = currencyInfo(for: CurrencyCode(rawValue: code) ?? .usd)

                        HStack(spacing: DS.Spacing.md) {
                            Text(info.flag)
                                .font(DS.Typography.body)

                            Text(info.code)
                                .font(DS.Typography.body)

                            Spacer()

                            Picker("", selection: accountBinding(for: code)) {
                                Text(L10n.Groups.Form.none).tag("")
                                ForEach(accountsByCurrency[code] ?? [], id: \.persistentModelID) { account in
                                    Text(account.name).tag(account.name)
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)

                        if code != groupCurrencies.last {
                            Divider()
                                .padding(.leading, DS.FormRow.paddingH)
                        }
                    }
                }

                // Hint
                Text(L10n.Groups.Settings.mySettingsHint)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .onAppear {
            personalAutoCreate = GroupPersonalPreferences.autoCreateTransaction(for: group.cloudKitZoneID)
                ?? group.autoCreateTransaction
            loadAccountPreferences()
        }
        .onChange(of: selectedCurrency) {
            loadAccountPreferences()
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
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.thCard))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(.thCardBorder, lineWidth: 1))
    }

    // MARK: - Bindings

    private func accountBinding(for code: String) -> Binding<String> {
        Binding<String>(
            get: { accountPrefs[code] ?? "" },
            set: { newValue in
                accountPrefs[code] = newValue
                GroupPersonalPreferences.setAccountName(
                    newValue.isEmpty ? nil : newValue,
                    for: group.cloudKitZoneID,
                    currencyCode: code
                )
            }
        )
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
            #if DEBUG
            print("GroupSettingsView: Error saving identity: \(error)")
            #endif
        }
    }

    private func createShareLink() async {
        guard !isCreatingShare else { return }

        // Return cached URL if available
        if shareURL != nil {
            showShareSheet = true
            return
        }

        isCreatingShare = true
        do {
            let (_, ckURL) = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            if let ckURL {
                shareURL = buildBrandedInviteURL(from: ckURL)
            }
            isCreatingShare = false
            if shareURL != nil {
                hasExistingShare = true
                showShareSheet = true
            }
        } catch {
            isCreatingShare = false
            #if DEBUG
            print("GroupSettingsView: Error creating share: \(error)")
            #endif
        }
    }

    private func regenerateShareLink() async {
        guard !isRegeneratingLink else { return }
        isRegeneratingLink = true
        do {
            try await SplitZoneManager(syncManager: .shared).deleteShare(for: group)
            shareURL = nil
            let (_, ckURL) = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            if let ckURL {
                shareURL = buildBrandedInviteURL(from: ckURL)
            }
            isRegeneratingLink = false
            if shareURL != nil {
                showShareSheet = true
            }
        } catch {
            isRegeneratingLink = false
            #if DEBUG
            print("GroupSettingsView: Error regenerating share: \(error)")
            #endif
        }
    }

    private func buildBrandedInviteURL(from ckURL: URL) -> URL {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let inviterName = name.isEmpty ? "Usuario" : name
        return InviteLinkService.buildInviteURL(
            shareURL: ckURL,
            group: group,
            members: viewModel.members,
            inviterName: inviterName
        ) ?? ckURL
    }

    private func changeRole(_ member: SplitMember) {
        let newRole = member.role == "admin" ? "member" : "admin"
        do {
            try GroupService.shared.changeRole(member, to: newRole, in: group)
            viewModel.loadData()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error changing role: \(error)")
            #endif
        }
    }

    private func removeMember() {
        guard let member = memberToRemove else { return }
        do {
            try GroupService.shared.removeMember(member, from: group)
            viewModel.loadData()
            DS.Haptic.warning()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error removing member: \(error)")
            #endif
        }
        memberToRemove = nil
    }

    private func toggleArchive() {
        do {
            let willArchive = !group.isArchived
            try GroupService.shared.setArchived(group, isArchived: willArchive)
            if willArchive { TelemetryService.track(.groupArchived) }
            DS.Haptic.success()
            viewModel.loadData()
            if group.isArchived {
                dismiss()
            }
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error toggling archive: \(error)")
            #endif
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
            #if DEBUG
            print("GroupSettingsView: Error updating group: \(error)")
            #endif
        }
    }

    private func loadAccountPreferences() {
        do {
            // Get distinct currencies from group expenses
            var currencies = try GroupExpenseService.shared.fetchDistinctCurrencyCodes(for: group)
            // Always include group's preferred currency first
            if let idx = currencies.firstIndex(of: group.currencyCode) {
                currencies.remove(at: idx)
            }
            currencies.insert(group.currencyCode, at: 0)
            groupCurrencies = currencies

            // Load all non-archived accounts
            let descriptor = FetchDescriptor<Account>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.name)]
            )
            let allAccounts = try modelContext.fetch(descriptor)

            // Group accounts by currency
            var byCurrency: [String: [Account]] = [:]
            for code in currencies {
                byCurrency[code] = allAccounts.filter { $0.currencyCode == code }
            }
            accountsByCurrency = byCurrency

            // Load saved preferences
            accountPrefs = GroupPersonalPreferences.allAccountPreferences(
                for: group.cloudKitZoneID,
                currencies: currencies
            )
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error loading account preferences: \(error)")
            #endif
        }
    }
}
