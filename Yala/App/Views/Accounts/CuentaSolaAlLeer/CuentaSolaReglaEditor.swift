//
//  CuentaSolaReglaEditor.swift
//  Yala
//
//  «Nueva regla» / «Editar regla» (parte 2 de la cuenta sola al leer, 2026-11-21): «Cuando» (Paga con Apple Pay · El
//  texto dice · El comercio es), el valor, «Todas, en cualquier orden» / «Juntas, tal cual» en las de texto, «Va a» con
//  la cuenta y un ejemplo de lo que hará. Devuelve la regla a quien lo abre; no guarda nada por su cuenta.
//

import SwiftUI

struct CuentaSolaReglaEditor: View {
    let original: AccountCaptureRule?
    let accountName: String
    let onSave: (AccountCaptureRule) -> Void
    /// Solo al editar una regla que ya existe.
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var kind: AccountCaptureRule.Kind
    @State private var value: String
    @State private var mode: AccountCaptureRule.Mode
    @FocusState private var valueFocused: Bool

    init(
        original: AccountCaptureRule?, accountName: String, onSave: @escaping (AccountCaptureRule) -> Void,
        onDelete: (() -> Void)?
    ) {
        self.original = original
        self.accountName = accountName
        self.onSave = onSave
        self.onDelete = onDelete
        _kind = State(initialValue: original?.kind ?? .text)
        _value = State(initialValue: original?.value ?? "")
        _mode = State(initialValue: original?.mode ?? .allWords)
    }

    private var cleanedValue: String {
        String(AccountCaptureRule.cleaned(value).prefix(AccountCaptureRule.maxValueLength))
    }

    private var canSave: Bool { !CuentaSolaAlLeerReglas.palabras(cleanedValue).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    whenSection
                    valueSection
                    goesToSection
                    previewSection
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            DS.Haptic.warning()
                            dismiss()
                        } label: {
                            Text(L10n.CuentaSolaAlLeer.Editor.delete)
                                .font(DS.Typography.body)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Semantic.errorForeground)
                        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                        .accessibilityIdentifier("capture_rule_delete")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
                .readableColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle(original == nil ? L10n.CuentaSolaAlLeer.Editor.newTitle : L10n.CuentaSolaAlLeer.Editor.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: save, isDisabled: !canSave, accessibilityID: "capture_rule_save")
                }
            }
            .yalaScreenBackground(.subtle)
        }
        .onAppear { if original == nil { valueFocused = true } }
    }

    // MARK: - Secciones

    private var whenSection: some View {
        SectionBox(title: L10n.CuentaSolaAlLeer.Editor.when) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(AccountCaptureRule.Kind.allCases, id: \.self) { option in
                    optionRow(
                        title: L10n.CuentaSolaAlLeer.Editor.kind(option), isSelected: kind == option,
                        id: "capture_rule_kind_\(option.rawValue)") {
                        kind = option
                    }
                    if option != AccountCaptureRule.Kind.allCases.last { SubsectionDivider() }
                }
            }
        }
    }

    private var valueSection: some View {
        SectionBox(title: L10n.CuentaSolaAlLeer.Editor.words) {
            VStack(spacing: DS.Spacing.none) {
                TextField(L10n.CuentaSolaAlLeer.Editor.placeholder(kind), text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($valueFocused)
                    .submitLabel(.done)
                    .padding()
                    .accessibilityIdentifier("capture_rule_value")
                if kind == .text {
                    SubsectionDivider()
                    ForEach(AccountCaptureRule.Mode.allCases, id: \.self) { option in
                        optionRow(
                            title: L10n.CuentaSolaAlLeer.Editor.mode(option), isSelected: mode == option,
                            id: "capture_rule_mode_\(option.rawValue)") {
                            mode = option
                        }
                        if option != AccountCaptureRule.Mode.allCases.last { SubsectionDivider() }
                    }
                }
                if kind == .applePayCard {
                    Text(L10n.CuentaSolaAlLeer.Editor.applePayHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
    }

    private var goesToSection: some View {
        SectionBox(title: L10n.CuentaSolaAlLeer.Editor.goesTo) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "creditcard")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(accountName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                Spacer()
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("capture_rule_goes_to")
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.CuentaSolaAlLeer.Editor.preview)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Text(canSave
                 ? L10n.CuentaSolaAlLeer.Editor.previewText(kind, value: cleanedValue, account: accountName)
                 : L10n.CuentaSolaAlLeer.Editor.previewEmpty)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture_rule_preview")
    }

    private func optionRow(title: String, isSelected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccentText)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private func save() {
        guard canSave else { return }
        let rule = AccountCaptureRule(
            id: original?.id ?? UUID(), kind: kind, value: cleanedValue,
            mode: kind == .text ? mode : .allWords, createdAt: original?.createdAt ?? .now)
        DS.Haptic.success()
        onSave(rule)
        dismiss()
    }
}
