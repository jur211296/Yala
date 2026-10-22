//
//  GroupFormView.swift
//  Yala
//
//  Sheet para crear o editar un grupo compartido.
//

import SwiftUI
import SwiftData

struct GroupFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var iconName: String = "person.2.fill"
    @State private var colorHex: String = "#8B5CF6"
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var defaultSplitType: SplitType = .equal
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var isSaving: Bool = false

    // MARK: - Sheet State

    @State private var showIconPicker = false
    @State private var showCurrencyPicker = false

    @FocusState private var isNameFocused: Bool

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Icon preview
                    iconPreview

                    // Name
                    nameSection

                    // Options
                    optionsSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(group == nil ? L10n.Groups.newGroup : L10n.Groups.editGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(
                        action: { Task { await saveAsync() } },
                        isDisabled: isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconColorPickerSheet(
                    selectedIconName: $iconName,
                    selectedColorHex: $colorHex
                )
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
            }
            .onAppear {
                populateFromGroup()
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Icon Preview

    private var iconPreview: some View {
        Button {
            showIconPicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 80, height: 80)

                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .medium)) // A11Y-DT: decorative icon preview, fixed size
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: colorHex).opacity(0.4), radius: DS.Shadow.medium.radius, x: DS.Shadow.medium.x, y: DS.Shadow.medium.y)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.thCard)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(Color(hex: colorHex))
                    )
                    .overlay(
                        Circle()
                            .stroke(.thBackground, lineWidth: 2)
                    )
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
        .accessibilityLabel(L10n.Groups.Form.icon)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        SectionBox(title: L10n.Groups.Form.name) {
            TextField(L10n.Groups.Form.namePlaceholder, text: $name)
                .font(DS.Typography.body)
                .focused($isNameFocused)
                .accessibilityIdentifier("group_form_name_input")
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
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

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Show debts in single currency
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.showDebtsInSingleCurrency, isOn: $showDebtsInSingleCurrency)
                        .font(DS.Typography.body)
                        .accessibilityIdentifier("group_form_single_currency_toggle")

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
                            // El `contentShape` va DENTRO del label, NO en el `Button`: el label es un
                            // `HStack` con `Spacer()` y sin fondo relleno, así que ahí el hueco central
                            // no es tocable y solo responden los glifos de los extremos. Ver la regla del
                            // DS en `.claude/rules/swiftui-ds.md`.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("group_form_currency_row")
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)

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

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)
            }
        }
    }

    // MARK: - Actions

    private func saveAsync() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let currencyCode = showDebtsInSingleCurrency ? selectedCurrency.rawValue : appPreferences.defaultCurrencyCode.rawValue

        do {
            if let group {
                // Update
                try GroupService.shared.updateGroup(
                    group,
                    name: trimmedName,
                    iconName: iconName,
                    colorHex: colorHex,
                    currencyCode: currencyCode,
                    simplifyDebts: simplifyDebts,
                    showDebtsInSingleCurrency: showDebtsInSingleCurrency,
                    defaultSplitType: defaultSplitType.rawValue,
                    membersCanInvite: false
                )
            } else {
                // Create — C4: el ÚNICO canal de creación es el backend. El gate canal/consent/sign-in ya
                // corrió en el call-site que abrió el form (GroupsContainerView.requestCreateGroup, que
                // además re-mide el flag con `refreshIfDue(force: true)`); las ramas no-`.backend` de aquí
                // son belt defensivo (no deberían alcanzarse) — las needs* ceden el anchor con dismiss()
                // PRIMERO, y `.channelOff` NO cede: se queda y dice el porqué, porque tras el dismiss no
                // queda nadie que pueda contárselo al usuario.
                switch GroupCreateRoutingLogic.route(
                    flagOn: CloudSyncFlags.groupsBackendEnabled,
                    hasSession: CloudAuthService.shared.hasSession,
                    consentAccepted: GroupsConsentState.isAccepted
                ) {
                case .channelOff:
                    // Cero escrituras: antes de C4 esta rama era `.cloudKit` y acuñaba un `SplitGroup`
                    // local con `isBackendGroup == false` — no invitable y sin vía de migración.
                    DS.Haptic.warning()
                    saveErrorMessage = L10n.Welcome.Groups.channelOffBody
                    showSaveError = true
                    return
                case .backend:
                    // `displayName` no-vacío (patrón defaultName R1: `join`/`create_group` hacen btrim=''
                    // → yala_bad_input permanente si vacío).
                    let profile = UserDefaults.standard.string(forKey: "userName") ?? ""
                    let displayName = profile.isEmpty ? L10n.Profile.defaultName : profile
                    _ = try await GroupBackendMembershipService(
                        client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                        .createGroup(
                            name: trimmedName,
                            iconName: iconName,
                            colorHex: colorHex,
                            currencyCode: currencyCode,
                            displayName: displayName,
                            defaultSplitType: defaultSplitType.rawValue,
                            simplifyDebts: simplifyDebts,
                            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
                            membersCanInvite: false,
                            context: modelContext
                        )
                    // Paridad de side-effects: el servicio backend NO los emite (a diferencia de
                    // GroupService.createGroup) — replicarlos aquí para no regresionar la UX.
                    SessionState.shared.incrementDataVersion()
                    NudgeService.shared.recordGroupJoinIfNeeded()
                case .needsConsent:
                    dismiss()
                    RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
                    return
                case .needsSignIn:
                    dismiss()
                    RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
                    return
                }
            }
            DS.Haptic.success()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupFormView: Error saving group: \(error)")
            #endif
            DS.Haptic.warning()
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func populateFromGroup() {
        if let group {
            name = group.name
            iconName = group.iconName
            colorHex = group.colorHex
            simplifyDebts = group.simplifyDebts
            showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
            selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
            defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        } else {
            selectedCurrency = appPreferences.defaultCurrencyCode
        }
    }
}
