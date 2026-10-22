//
//  AccountRemovalSheet.swift
//  Yala
//
//  «Eliminar cuenta» cuando la cuenta tiene algo dentro: mover a otra cuenta o borrar.
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`, decisión A de Jürgen (2026-10-15).
//

import SwiftUI
import SwiftData

/// Una sola presentación con fases (elegir → confirmar el borrado → trabajando / error). Encadenar dos
/// `.alert` desde el mismo anchor puede dejar el router retenido para toda la sesión (`swiftui-ds.md`).
struct AccountRemovalSheet: View {

    @State private var viewModel: AccountRemovalViewModel
    /// Elimina la cuenta y guarda (`EntityDeletionService.deleteAccount`): lo inyecta quien presenta.
    let deleteAccount: (Account) throws -> Void
    /// La cuenta quedó eliminada: quien presenta cierra también el formulario.
    let onRemoved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(
        account: Account,
        name: String,
        currencyCode: String,
        deleteAccount: @escaping (Account) throws -> Void,
        onRemoved: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: AccountRemovalViewModel(account: account, name: name, currencyCode: currencyCode))
        self.deleteAccount = deleteAccount
        self.onRemoved = onRemoved
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Account.Removal.title(viewModel.accountName))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.Action.cancel) { dismiss() }
                            .disabled(viewModel.phase == .working)
                            .accessibilityIdentifier("account_removal_cancel")
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.phase == .working)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("account_removal_sheet")
        .onAppear { viewModel.load(context: modelContext) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .choose:
            chooseView
        case .confirmDelete:
            confirmDeleteView
        case .working:
            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                Text(L10n.Account.Removal.working)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yalaScreenBackground(.subtle)
            .accessibilityIdentifier("account_removal_working")
        case .failed(let failure):
            failedView(failure)
        }
    }

    // MARK: - Elegir

    private var chooseView: some View {
        List {
            Section {
                Text(L10n.Account.Removal.intro)
                    .font(DS.Typography.body)
                    .accessibilityIdentifier("account_removal_intro")
                ForEach(countRows, id: \.identifier) { row in
                    LabeledContent(row.label) {
                        Text("\(row.count)")
                            .font(DS.Typography.body.monospacedDigit())
                    }
                    .accessibilityIdentifier(row.identifier)
                }
            }

            Section {
                optionRow(
                    title: L10n.Account.Removal.moveTitle,
                    subtitle: viewModel.canMove
                        ? L10n.Account.Removal.moveSubtitle
                        : viewModel.cannotMoveReason,
                    isSelected: viewModel.choice == .move,
                    isEnabled: viewModel.canMove,
                    isDestructive: false,
                    identifier: "account_removal_option_move"
                ) { viewModel.choice = .move }

                optionRow(
                    title: L10n.Account.Removal.deleteTitle,
                    subtitle: viewModel.canDelete
                        ? L10n.Account.Removal.deleteSubtitle
                        : L10n.Account.Removal.deleteBlockedGroups,
                    isSelected: viewModel.choice == .delete,
                    isEnabled: viewModel.canDelete,
                    isDestructive: true,
                    identifier: "account_removal_option_delete"
                ) { viewModel.choice = .delete }
            } header: {
                Text(L10n.Account.Removal.choiceHeader)
            } footer: {
                if viewModel.choice == .delete, let note = deleteFooter {
                    Text(note)
                }
            }

            if viewModel.choice == .move, !viewModel.destinations.isEmpty {
                Section {
                    ForEach(viewModel.destinations) { option in
                        destinationRow(option)
                    }
                } header: {
                    Text(L10n.Account.Removal.destinationHeader)
                } footer: {
                    if let note = moveFooter {
                        Text(note)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .yalaScreenBackground(.subtle)
        .safeAreaInset(edge: .bottom) {
            proceedButton
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(.bar)
        }
    }

    private struct CountRow {
        let label: String
        let count: Int
        let identifier: String
    }

    private var countRows: [CountRow] {
        guard let shape = viewModel.shape else { return [] }
        let all = [
            CountRow(label: L10n.Account.Removal.countRecords, count: shape.rows.count,
                     identifier: "account_removal_count_records"),
            CountRow(label: L10n.Account.Removal.countScheduled, count: shape.scheduled.count,
                     identifier: "account_removal_count_scheduled"),
            CountRow(label: L10n.Account.Removal.countFavorites, count: shape.favoriteCount,
                     identifier: "account_removal_count_favorites"),
            CountRow(label: L10n.Account.Removal.countDrafts, count: shape.pendingDraftCount,
                     identifier: "account_removal_count_drafts"),
            CountRow(label: L10n.Account.Removal.countBudgets, count: shape.budgetCount,
                     identifier: "account_removal_count_budgets"),
        ]
        return all.filter { $0.count > 0 }
    }

    private func optionRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        isEnabled: Bool,
        isDestructive: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(isDestructive && isEnabled ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.primary))
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func destinationRow(_ option: AccountRemovalViewModel.DestinationOption) -> some View {
        Button { viewModel.select(option) } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(option.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(option.isAllowed ? option.currencyCode : L10n.Account.Removal.destinationBlockedCurrency)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if option.id == viewModel.destinationID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.isAllowed)
        .opacity(option.isAllowed ? 1 : 0.6)
        .accessibilityAddTraits(option.id == viewModel.destinationID ? .isSelected : [])
        .accessibilityIdentifier("account_removal_destination_\(option.name)")
    }

    private var moveFooter: String? {
        guard let option = viewModel.selectedDestination,
              case let .allowed(_, convertedRows, collapsed, convertsPlans) = option.verdict else { return nil }
        var lines: [String] = []
        if convertedRows > 0 || convertsPlans {
            lines.append(L10n.Account.Removal.convertNote(option.currencyCode))
        }
        if collapsed > 0 {
            lines.append(L10n.Account.Removal.collapsedNote(viewModel.accountName, option.name))
        }
        if (viewModel.shape?.budgetCount ?? 0) > 0 {
            lines.append(L10n.Account.Removal.budgetsMovedNote(option.name))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n\n")
    }

    private var deleteFooter: String? {
        guard case let .allowed(_, partnersKept) = viewModel.deleteVerdict,
              let shape = viewModel.shape else { return nil }
        var lines: [String] = []
        if partnersKept > 0 { lines.append(L10n.Account.Removal.partnersNote) }
        if shape.planCount > 0 { lines.append(L10n.Account.Removal.plansNote) }
        if shape.budgetsOnlyThisAccount > 0 { lines.append(L10n.Account.Removal.budgetsOnlyNote) }
        return lines.isEmpty ? nil : lines.joined(separator: "\n\n")
    }

    @ViewBuilder
    private var proceedButton: some View {
        switch viewModel.choice {
        case .move:
            YalaPrimaryButton(L10n.Account.Removal.moveAction, isDisabled: !viewModel.canProceed) {
                Task {
                    if await viewModel.proceed(context: modelContext, deleteAccount: deleteAccount) {
                        finish()
                    }
                }
            }
            .accessibilityIdentifier("account_removal_proceed")
        case .delete:
            YalaSecondaryButton(
                L10n.Account.Removal.deleteAction, isDisabled: !viewModel.canProceed, destructive: true
            ) {
                Task {
                    _ = await viewModel.proceed(context: modelContext, deleteAccount: deleteAccount)
                }
            }
            .accessibilityIdentifier("account_removal_proceed")
        }
    }

    // MARK: - Confirmar el borrado

    private var confirmDeleteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text(L10n.Account.Removal.confirmDeleteTitle)
                    .font(DS.Typography.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LabeledContent(L10n.Account.Removal.confirmDeleteCount) {
                    Text("\(viewModel.shape?.rows.count ?? 0)")
                        .font(DS.Typography.title.monospacedDigit())
                        .foregroundStyle(DS.Semantic.errorForeground)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("account_removal_confirm_count")
                Text(L10n.Account.Removal.confirmDeleteMessage)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                if let note = deleteFooter {
                    Text(note)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.xl)
        }
        .yalaScreenBackground(.subtle)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.md) {
                YalaSecondaryButton(L10n.Account.Removal.confirmDeleteAction, destructive: true) {
                    if viewModel.confirmDelete(context: modelContext, deleteAccount: deleteAccount) {
                        finish()
                    }
                }
                .accessibilityIdentifier("account_removal_confirm_delete")
                Button(L10n.Action.back) { viewModel.back(context: modelContext) }
                    .accessibilityIdentifier("account_removal_back")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)
        }
    }

    // MARK: - Error

    private func failedView(_ failure: AccountRemovalService.Failure) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.Account.Removal.failedTitle)
                .font(DS.Typography.title)
            Text(message(for: failure))
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("account_removal_failed_message")
            Spacer()
            YalaSecondaryButton(L10n.Action.back) { viewModel.back(context: modelContext) }
                .accessibilityIdentifier("account_removal_back")
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .yalaScreenBackground(.subtle)
    }

    private func message(for failure: AccountRemovalService.Failure) -> String {
        switch failure {
        case .unreadable: return L10n.Account.Removal.failedUnreadable
        case .noLongerAllowed: return L10n.Account.Removal.failedChanged
        case .ratesUnavailable: return L10n.Account.Removal.failedRates
        case .saveFailed: return L10n.Common.saveError
        }
    }

    private func finish() {
        onRemoved()
        dismiss()
    }
}
