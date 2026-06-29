//
//  GroupSplitSelectorView.swift
//  Yala
//
//  Sheet unificado de división del gasto (estilo Splitwise): segmented de modos
//  arriba, lista de TODOS los miembros activos en medio, y el cuadre de asignación
//  fijo abajo. Es el sheet autocontenido que abre el chip "Dividido" del form.
//
//  Inclusión por modo:
//  - .equal → check por miembro (todos por default); el cuadre muestra "Cada uno paga".
//  - .exact/.percentage/.shares → campo editable por miembro; participa quien tenga un
//    valor (implícito, estilo Splitwise). Llenar incluye, vaciar excluye.
//

import SwiftUI

struct GroupSplitSelectorView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Solo en grupos de 2: vuelve a la pre-pantalla de 4 opciones rápidas. `nil` en 3+ → no aparece.
    var onRequestSimpleOptions: (() -> Void)? = nil
    @FocusState private var focusedMember: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Tipo SALIENTE para la conversión inteligente al tocar otro segmento (el callback
    /// del segmented solo entrega el nuevo). Init en `.onAppear`. El segmented NO dispara
    /// `onTypeChange` en el mount (solo en tap) → no hace falta guard de prefill.
    @State private var lastType: SplitType = .equal

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    private var currencySymbol: String {
        appPreferences.currencyIdentifier(for: viewModel.currencyCode)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.none) {
                SplitTypeSegmentedSelector(selectedType: $viewModel.splitType) { newType in
                    viewModel.convertSplitValues(from: lastType, to: newType)
                    lastType = newType
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        sheetHeader
                        memberSharesCard
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { cuadreFooter }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Expense.dividePayment)
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                // Solo en grupos de 2: volver a la pre-pantalla de 4 opciones rápidas.
                if let onRequestSimpleOptions {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Groups.Expense.TwoPerson.quickOptions) {
                            onRequestSimpleOptions()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { lastType = viewModel.splitType }
        }
        .presentationDetents(DS.Adaptive.sheetDetents([.large]))
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header (título + explicación por tipo)

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(sheetTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(.primary)
            Text(sheetHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sheetTitle: String {
        switch viewModel.splitType {
        case .equal: return L10n.Groups.Expense.SplitSheet.equalTitle
        case .percentage: return L10n.Groups.Expense.SplitSheet.percentageTitle
        case .exact: return L10n.Groups.Expense.SplitSheet.exactTitle
        case .shares: return L10n.Groups.Expense.SplitSheet.sharesTitle
        }
    }

    private var sheetHint: String {
        switch viewModel.splitType {
        case .equal: return L10n.Groups.Expense.SplitSheet.equalHint
        case .percentage: return L10n.Groups.Expense.SplitSheet.percentageHint
        case .exact: return L10n.Groups.Expense.SplitSheet.exactHint
        case .shares: return L10n.Groups.Expense.SplitSheet.sharesHint
        }
    }

    // MARK: - Member list

    private var memberSharesCard: some View {
        // Monto efectivo por miembro calculado UNA sola vez por render (no por fila).
        // SIEMPRE disponible aunque la división no cuadre → cada fila muestra su monto.
        let amounts = viewModel.effectiveAmountsByID
        return VStack(spacing: DS.Spacing.none) {
            ForEach(viewModel.activeSheetMembers, id: \.id) { member in
                memberRow(member: member, id: member.id.uuidString, amount: amounts[member.id.uuidString] ?? 0)

                if member.id != viewModel.activeSheetMembers.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.lg)
                }
            }
            // Última fila SOLO en modo igual: maestro "Seleccionar todos (N)".
            if viewModel.splitType == .equal {
                Divider().padding(.leading, DS.Spacing.lg)
                selectAllRow
            }
        }
        .solidCard(radius: DS.Radius.xl)
    }

    @ViewBuilder
    private func memberRow(member: SplitMember, id: String, amount: Double) -> some View {
        if viewModel.splitType == .equal {
            Button {
                viewModel.toggleMember(id)
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    memberLeading(member, id: id, amount: amount)
                    Spacer()
                    let isSelected = viewModel.selectedMemberIDs.contains(id)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.headline)
                        .foregroundStyle(isSelected ? theme.accent : Color.secondary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: DS.Spacing.md) {
                memberLeading(member, id: id, amount: amount)
                Spacer()
                fieldTrailing(id: id)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    /// Avatar + nombre + monto efectivo debajo (SIEMPRE, aunque no cuadre). En `.exact` se
    /// omite: el campo editable YA es el monto, mostrarlo dos veces sería redundante.
    private func memberLeading(_ member: SplitMember, id: String, amount: Double) -> some View {
        HStack(spacing: DS.Spacing.md) {
            avatar(member)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                memberName(member, id: id)
                if viewModel.splitType != .exact {
                    Text(appPreferences.currency(amount, currencyCode: viewModel.currencyCode))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Maestro "Seleccionar todos (N)" al final de la lista (solo modo igual): al marcar
    /// selecciona a todos; al desmarcar deselecciona a todos.
    private var selectAllRow: some View {
        let total = viewModel.activeSheetMembers.count
        let allSelected = total > 0 && viewModel.selectedMembers.count == total
        return Button {
            if allSelected { viewModel.deselectAllMembers() } else { viewModel.selectAllMembers() }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text("\(L10n.Groups.Expense.selectAll) (\(total))")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(allSelected ? theme.accent : Color.secondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_split_select_all")
    }

    @ViewBuilder
    private func memberName(_ member: SplitMember, id: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(viewModel.memberNameLookup[id] ?? member.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if member.isCurrentUser {
                Text(L10n.Groups.Member.you)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func avatar(_ member: SplitMember) -> some View {
        let hex = viewModel.group.colorHex
        return ZStack {
            Circle()
                .fill(Color(hex: hex).opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)
            Text(String(member.displayName.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: hex))
        }
    }

    // MARK: - Per-type field (trailing)

    @ViewBuilder
    private func fieldTrailing(id: String) -> some View {
        switch viewModel.splitType {
        case .exact:
            HStack(spacing: DS.Spacing.xs) {
                Text(currencySymbol)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                splitField(id: id, keyPath: \.exactAmounts, keyboard: .decimalPad,
                           filter: { AmountInputHelper.filterAmountInput($0) })
            }
        case .percentage:
            HStack(spacing: DS.Spacing.xs) {
                splitField(id: id, keyPath: \.percentages, keyboard: .decimalPad,
                           filter: { AmountInputHelper.filterAmountInput($0) })
                Text("%")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
        case .shares:
            HStack(spacing: DS.Spacing.xs) {
                splitField(id: id, keyPath: \.sharesCounts, keyboard: .numberPad,
                           filter: { AmountInputHelper.filterIntegerInput($0) })
                Text(L10n.Split.sharesParts)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .equal:
            EmptyView()
        }
    }

    // MARK: - Split Field (ZStack + dynamic placeholder + filtering + participation sync)

    @ViewBuilder
    private func splitField(
        id: String,
        keyPath: ReferenceWritableKeyPath<GroupExpenseViewModel, [String: String]>,
        keyboard: UIKeyboardType,
        filter: @escaping (String) -> String
    ) -> some View {
        let memberName = viewModel.memberNameLookup[id] ?? id
        let dynamicPlaceholder = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: id,
            orderedMemberIDs: viewModel.activeSheetMembers.map { $0.id.uuidString },
            currentInputs: viewModel[keyPath: keyPath],
            splitType: viewModel.splitType,
            total: viewModel.amount
        )
        ZStack(alignment: .trailing) {
            if (viewModel[keyPath: keyPath][id] ?? "").isEmpty {
                Text(dynamicPlaceholder)
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
            }
            TextField("", text: binding(for: id, in: keyPath))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.title3)
                .focused($focusedMember, equals: id)
                .onChange(of: viewModel[keyPath: keyPath][id] ?? "") { _, newValue in
                    let filtered = filter(newValue)
                    if filtered != newValue {
                        viewModel[keyPath: keyPath][id] = filtered
                    }
                    // Inclusión implícita: con valor participa, vacío se excluye.
                    viewModel.setParticipation(id, included: !filtered.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .accessibilityLabel("\(viewModel.splitType.displayName) \(memberName)")
        }
        .frame(minWidth: 56, alignment: .trailing)
    }

    // MARK: - Cuadre (footer fijo)

    private var cuadreFooter: some View {
        VStack(spacing: DS.Spacing.none) {
            Divider()
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if viewModel.amount > 0 {
                    // Mismo formato en TODOS los modos: "{asignado} de {total}" + estado.
                    // En iguales asignado == total → "300 de 300" + "Balanceado".
                    HStack {
                        Text("\(appPreferences.currency(viewModel.assignedToAllocate, currencyCode: viewModel.currencyCode)) \(L10n.Split.sharesOf) \(appPreferences.currency(viewModel.amount, currencyCode: viewModel.currencyCode))")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        statusBadge
                    }
                }
                Text(L10n.Groups.Expense.membersSelected(viewModel.selectedMembers.count, viewModel.activeSheetMembers.count))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.lg)
        }
        .background(.thCard)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.isSharesBalanced {
            Label(L10n.Groups.Expense.balanced, systemImage: "checkmark.circle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Semantic.successForeground)
        } else if viewModel.remainingToAllocate < -0.005 {
            Label(
                L10n.Groups.Expense.overAllocated(appPreferences.currency(abs(viewModel.remainingToAllocate), currencyCode: viewModel.currencyCode)),
                systemImage: "exclamationmark.circle.fill"
            )
            .font(DS.Typography.subheadline)
            .foregroundStyle(Color.hotPink)
        } else {
            Label(
                L10n.Groups.Expense.remainingAmount(appPreferences.currency(abs(viewModel.remainingToAllocate), currencyCode: viewModel.currencyCode)),
                systemImage: "exclamationmark.circle.fill"
            )
            .font(DS.Typography.subheadline)
            .foregroundStyle(Color.hotPink)
        }
    }

    // MARK: - Binding Helper

    private func binding(
        for memberID: String,
        in keyPath: ReferenceWritableKeyPath<GroupExpenseViewModel, [String: String]>
    ) -> Binding<String> {
        Binding(
            get: { viewModel[keyPath: keyPath][memberID] ?? "" },
            set: { viewModel[keyPath: keyPath][memberID] = $0 }
        )
    }
}
