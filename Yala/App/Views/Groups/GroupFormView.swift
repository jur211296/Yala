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
    @State private var membersCanInvite: Bool = true
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""

    // MARK: - Sheet State

    @State private var showIconPicker = false
    @State private var showCurrencyPicker = false

    @FocusState private var isNameFocused: Bool

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

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
            }
            .background(.thBackground)
            .navigationTitle(group == nil ? L10n.Groups.newGroup : L10n.Groups.editGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: save, isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty)
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
            .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 8, x: 0, y: 4)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.thCard)
                    .frame(width: 24, height: 24)
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
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
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
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let currencyCode = showDebtsInSingleCurrency ? selectedCurrency.rawValue : defaultCurrencyCode

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
                    membersCanInvite: membersCanInvite
                )
            } else {
                // Create
                try GroupService.shared.createGroup(
                    name: trimmedName,
                    iconName: iconName,
                    colorHex: colorHex,
                    currencyCode: currencyCode,
                    simplifyDebts: simplifyDebts,
                    showDebtsInSingleCurrency: showDebtsInSingleCurrency,
                    defaultSplitType: defaultSplitType.rawValue,
                    membersCanInvite: membersCanInvite
                )
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
            membersCanInvite = group.membersCanInvite
        } else {
            selectedCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        }
    }
}
