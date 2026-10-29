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
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    /// La lista de cuentas para elegir otro destino (hoja pequeña).
    @State private var isPickingDestination = false

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
                .navigationTitle(L10n.Account.delete)
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

    // MARK: - Elegir (propuesta A de la card rd7z, 2026-10-29)

    /// Una pantalla: la cuenta con lo que tiene, la pregunta y dos tarjetas. La de mover lleva dentro el destino y
    /// cómo queda su saldo; elegir otro destino abre la lista en una hoja pequeña. Las reglas no cambian.
    private var chooseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header

                Text(L10n.Account.Removal.question)
                    .font(DS.Typography.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, DS.Spacing.xs)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    moveCard
                    if viewModel.choice == .move {
                        notes(moveNotes, identifier: "account_removal_move_notes")
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    deleteCard
                    if viewModel.choice == .delete {
                        notes(deleteNotes, identifier: "account_removal_delete_notes")
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .yalaScreenBackground(.subtle)
        .safeAreaInset(edge: .bottom) {
            proceedButton
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(.bar)
        }
        .sheet(isPresented: $isPickingDestination) {
            destinationPicker
        }
    }

    // MARK: Cabecera

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            let color = colorForHex(viewModel.accountColorHex)
            Image(systemName: viewModel.accountIconName)
                .font(DS.Typography.headline)
                .foregroundStyle(theme.onFill(color))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                .background(color, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(viewModel.accountName)
                    .font(DS.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(summaryLine)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("account_removal_count_records")
                if let other = otherCountsLine {
                    Text(other)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("account_removal_count_other")
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// «2 registros · S/ −58.00». Sin saldo en «solo gastos», como la lista de cuentas.
    private var summaryLine: String {
        var parts = [L10n.Account.Removal.recordCount(viewModel.shape?.rows.count ?? 0)]
        if !sessionState.isExpensesOnlyMode, let balance = viewModel.sourceBalance {
            parts.append(appPreferences.currency(
                (balance as NSDecimalNumber).doubleValue, currencyCode: viewModel.sourceCurrencyCode))
        }
        return parts.joined(separator: " · ")
    }

    /// Lo que no es historial (programados, favoritos, borradores, presupuestos), en una línea y solo si hay algo.
    private var otherCountsLine: String? {
        guard let shape = viewModel.shape else { return nil }
        let all: [(String, Int)] = [
            (L10n.Account.Removal.countScheduled, shape.scheduled.count),
            (L10n.Account.Removal.countFavorites, shape.favoriteCount),
            (L10n.Account.Removal.countDrafts, shape.pendingDraftCount),
            (L10n.Account.Removal.countBudgets, shape.budgetCount),
        ]
        let present = all.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }
        return present.isEmpty ? nil : present.joined(separator: " · ")
    }

    // MARK: Tarjetas

    private var moveCard: some View {
        let isSelected = viewModel.choice == .move
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            choiceButton(
                title: L10n.Account.Removal.moveTitle,
                subtitle: viewModel.canMove ? L10n.Account.Removal.moveSubtitle : viewModel.cannotMoveReason,
                isSelected: isSelected,
                isEnabled: viewModel.canMove,
                isDestructive: false,
                identifier: "account_removal_option_move"
            ) { viewModel.choice = .move }

            if viewModel.canMove, let destination = viewModel.selectedDestination {
                destinationChooser(destination)
                if !sessionState.isExpensesOnlyMode, let preview = viewModel.selectedPreview {
                    Text(balanceChange(destination, preview))
                        .font(DS.Typography.captionMono)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("account_removal_balance_change")
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.clear), lineWidth: 1.5)
        }
        .opacity(viewModel.canMove ? 1 : 0.6)
    }

    private var deleteCard: some View {
        let isSelected = viewModel.choice == .delete
        return choiceButton(
            title: L10n.Account.Removal.deleteTitle,
            subtitle: viewModel.canDelete
                ? L10n.Account.Removal.deleteSubtitle
                : L10n.Account.Removal.deleteBlockedGroups,
            isSelected: isSelected,
            isEnabled: viewModel.canDelete,
            isDestructive: true,
            identifier: "account_removal_option_delete"
        ) { viewModel.choice = .delete }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    isSelected ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.clear), lineWidth: 1.5)
        }
        .opacity(viewModel.canDelete ? 1 : 0.6)
    }

    /// El título y el subtítulo de una tarjeta, con la marca de elegida a la derecha.
    private func choiceButton(
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
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(isDestructive && isEnabled
                            ? AnyShapeStyle(DS.Semantic.errorForeground) : AnyShapeStyle(.primary))
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(isSelected
                        ? AnyShapeStyle(isDestructive ? DS.Semantic.errorForeground : theme.accent)
                        : AnyShapeStyle(Color(uiColor: .tertiaryLabel)))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// «A Banco QA · Cambiar ›» dentro de la tarjeta de mover. Lleva el id de siempre del destino elegido.
    private func destinationChooser(_ destination: AccountRemovalViewModel.DestinationOption) -> some View {
        Button {
            viewModel.choice = .move
            isPickingDestination = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(L10n.Account.Removal.destinationLine(destination.name))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                Text(L10n.Account.Removal.change)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.accentText)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(theme.background, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isSelected)
        .accessibilityIdentifier("account_removal_destination_\(destination.name)")
    }

    private func balanceChange(
        _ destination: AccountRemovalViewModel.DestinationOption,
        _ preview: AccountRemovalService.BalancePreview
    ) -> String {
        L10n.Account.Removal.balanceChange(
            destination.name,
            appPreferences.currency((preview.before as NSDecimalNumber).doubleValue, currencyCode: destination.currencyCode),
            appPreferences.currency(
                (preview.after as NSDecimalNumber).doubleValue,
                currencyCode: destination.currencyCode,
                isEstimate: preview.isApproximate))
    }

    /// Los avisos de hoy, uno por línea bajo su tarjeta.
    @ViewBuilder
    private func notes(_ lines: [String], identifier: String) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(DS.Typography.caption)
                            .accessibilityHidden(true)
                        Text(line)
                            .font(DS.Typography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }

    // MARK: Elegir otra cuenta

    private var destinationPicker: some View {
        NavigationStack {
            List {
                ForEach(viewModel.destinations) { option in
                    destinationRow(option)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.Account.Removal.destinationHeader)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) { isPickingDestination = false }
                        .accessibilityIdentifier("account_removal_picker_cancel")
                }
            }
        }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents([.medium, .large])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("account_removal_destination_picker")
    }

    private func destinationRow(_ option: AccountRemovalViewModel.DestinationOption) -> some View {
        Button {
            viewModel.select(option)
            isPickingDestination = false
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(option.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(option.isAllowed ? option.currencyCode : L10n.Account.Removal.destinationBlockedCurrency)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !sessionState.isExpensesOnlyMode, let preview = viewModel.balancePreviews[option.id] {
                    Text("→ " + appPreferences.currency(
                        (preview.after as NSDecimalNumber).doubleValue,
                        currencyCode: option.currencyCode,
                        isEstimate: preview.isApproximate))
                        .font(DS.Typography.captionMono)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                if option.id == viewModel.destinationID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccentText)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.isAllowed)
        .opacity(option.isAllowed ? 1 : 0.6)
        .listRowBackground(theme.card)
        .accessibilityAddTraits(option.id == viewModel.destinationID ? .isSelected : [])
        .accessibilityIdentifier("account_removal_destination_option_\(option.name)")
    }

    private var moveNotes: [String] {
        guard let option = viewModel.selectedDestination,
              case let .allowed(_, convertedRows, collapsed, convertsPlans) = option.verdict else { return [] }
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
        return lines
    }

    private var deleteNotes: [String] {
        guard case let .allowed(_, partnersKept) = viewModel.deleteVerdict,
              let shape = viewModel.shape else { return [] }
        var lines: [String] = []
        if partnersKept > 0 { lines.append(L10n.Account.Removal.partnersNote) }
        if shape.planCount > 0 { lines.append(L10n.Account.Removal.plansNote) }
        if shape.budgetsOnlyThisAccount > 0 { lines.append(L10n.Account.Removal.budgetsOnlyNote) }
        return lines
    }

    @ViewBuilder
    private var proceedButton: some View {
        switch viewModel.choice {
        case .move:
            YalaPrimaryButton(L10n.Account.Removal.moveActionNamed(viewModel.accountName), isDisabled: !viewModel.canProceed) {
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
                ForEach(deleteNotes, id: \.self) { note in
                    Text(note)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
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
