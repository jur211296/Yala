//
//  BridgeActivationSheet.swift
//  Yala
//
//  A0-Bridge V2.0: sheet de activación tardía cuando user activa el toggle
//  personalAutoCreate y el grupo tiene expenses pre-existentes. Ofrece:
//  - Empezar desde ahora (no toca data previa).
//  - Importar todo el historial (corre importGroupHistory async con progress).
//

import SwiftUI

struct BridgeActivationSheet: View {

    // MARK: - Input

    let group: SplitGroup
    let expensesCount: Int
    let onConfirm: (_ importHistory: Bool) -> Void
    let onCancel: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedOption: Option = .fromNow
    @State private var isImporting: Bool = false
    @State private var progressCurrent: Int = 0
    @State private var progressTotal: Int = 0
    @State private var importErrorMessage: String? = nil
    @State private var showImportError: Bool = false

    enum Option: Hashable { case fromNow, importAll }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if isImporting {
                        importingView
                    } else {
                        optionsView
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PanelBackgroundView())
            .navigationTitle(L10n.Groups.Bridge.activateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Action.cancel) {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isImporting)
        .alert(L10n.Common.error, isPresented: $showImportError) {
            Button(L10n.Common.ok, role: .cancel) {
                onCancel()
                dismiss()
            }
        } message: {
            Text(importErrorMessage ?? L10n.Groups.Bridge.importError)
        }
    }

    // MARK: - Options view

    @ViewBuilder
    private var optionsView: some View {
        Text(String(format: L10n.Groups.Bridge.activateBody, expensesCount))
            .font(DS.Typography.body)
            .foregroundStyle(.primary)

        VStack(spacing: DS.Spacing.none) {
            radioRow(
                option: .fromNow,
                title: L10n.Groups.Bridge.activateOptionFromNow,
                hint: L10n.Groups.Bridge.activateOptionFromNowHint
            )
            Divider().padding(.leading, DS.FormRow.paddingH)
            radioRow(
                option: .importAll,
                title: String(format: L10n.Groups.Bridge.activateOptionImportAll, expensesCount),
                hint: String(format: L10n.Groups.Bridge.activateOptionImportAllHint, expensesCount)
            )
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.thCard))

        Text(L10n.Groups.Bridge.activateImportRegenerationNote)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)

        YalaPrimaryButton(L10n.Action.continueAction, icon: "checkmark.circle.fill") {
            handleContinue()
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Importing view

    @ViewBuilder
    private var importingView: some View {
        ProcessingProgressView(
            mode: .determinate(current: progressCurrent, total: progressTotal),
            accentColor: Color(hex: group.colorHex),
            statusText: String(format: L10n.Groups.Bridge.importing, progressTotal)
        )
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Radio row

    private func radioRow(option: Option, title: String, hint: String) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                radioIndicator(isSelected: selectedOption == option)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(hint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func radioIndicator(isSelected: Bool) -> some View {
        if isSelected {
            Image(systemName: "largecircle.fill.circle")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
        } else {
            Image(systemName: "circle")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        if selectedOption == .fromNow {
            onConfirm(false)
            dismiss()
        } else {
            startImport()
        }
    }

    private func startImport() {
        isImporting = true
        progressTotal = expensesCount
        Task { @MainActor in
            do {
                try await GroupTransactionBridge.shared.importGroupHistory(for: group) { current, total in
                    progressCurrent = current
                    progressTotal = total
                }
                onConfirm(true)
                dismiss()
            } catch {
                #if DEBUG
                print("BridgeActivationSheet: import failed: \(error)")
                #endif
                isImporting = false
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
    }
}
