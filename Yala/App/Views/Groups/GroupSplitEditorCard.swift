//
//  GroupSplitEditorCard.swift
//  Yala
//
//  El reparto del gasto dentro del propio formulario (propuesta B de
//  `group-expense-views-redesign`, versión «con aire»): modo, barra por persona, lista de
//  personas y cuadre, sin abrir otra hoja. Es el contenido de la fila «Reparto» abierta;
//  el fondo y el título los pone la tarjeta del formulario. La lista y el estado del cuadre son las mismas piezas que usa la
//  hoja `GroupSplitSelectorView` (pagos planificados), así que la lógica vive en un sitio.
//
//  Inclusión por modo (igual que la hoja):
//  - .equal → check por miembro; el cuadre siempre balancea.
//  - .exact/.percentage/.shares → campo por miembro; participa quien tenga un valor.
//

import SwiftUI

// MARK: - Tarjeta del formulario

struct GroupSplitEditorCard: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Solo en grupos de 2: abre la hoja de cuatro opciones rápidas. `nil` en 3+ → no aparece.
    var onRequestQuickOptions: (() -> Void)? = nil

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Tipo SALIENTE para la conversión al tocar otro segmento (el callback solo entrega el
    /// nuevo). Mismo molde que la hoja: el segmented NO dispara en el mount.
    @State private var lastType: SplitType = .equal

    private var memberColors: [String: Color] {
        GroupMemberPalette.colors(
            for: viewModel.activeSheetMembers.map { $0.id.uuidString },
            currentMemberID: viewModel.currentUserMemberID,
            names: viewModel.memberNameLookup
        )
    }

    var body: some View {
        let colors = memberColors
        let amounts = viewModel.effectiveAmountsByID
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if onRequestQuickOptions != nil {
                quickOptionsLink
            }

            SplitTypeSegmentedSelector(selectedType: $viewModel.splitType) { newType in
                viewModel.convertSplitValues(from: lastType, to: newType)
                lastType = newType
            }

            if viewModel.amount > 0 {
                GroupSplitBar(
                    segments: viewModel.activeSheetMembers.map { member in
                        let id = member.id.uuidString
                        return GroupSplitBarSegment(
                            id: id,
                            amount: viewModel.selectedMemberIDs.contains(id) ? (amounts[id] ?? 0) : 0,
                            color: colors[id] ?? theme.accent
                        )
                    },
                    currencyCode: viewModel.currencyCode
                )
            }

            GroupSplitMemberList(
                viewModel: viewModel,
                showsSelectAll: false,
                rowInset: DS.Spacing.none,
                avatarColor: { colors[$0.id.uuidString] ?? theme.accent }
            )

            if viewModel.amount > 0 {
                cuadreLine
            }
        }
        .onAppear { lastType = viewModel.splitType }
        // El tipo también cambia sin pasar por el segmented: el prefill de la edición (que puede
        // correr después de este onAppear) y las opciones rápidas. Sin esto, el siguiente toque
        // convertiría desde un tipo que ya no es el vigente.
        .onChange(of: viewModel.splitType) { _, newType in lastType = newType }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_expense_split_card")
    }

    /// Grupos de 2: volver a las cuatro opciones rápidas.
    private var quickOptionsLink: some View {
        HStack {
            Spacer()
            Button {
                onRequestQuickOptions?()
            } label: {
                Label(L10n.Groups.Expense.TwoPerson.quickOptions, systemImage: "bolt.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("group_expense_quick_options")
        }
    }

    private var cuadreLine: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("\(appPreferences.currency(viewModel.assignedToAllocate, currencyCode: viewModel.currencyCode)) \(L10n.Split.sharesOf) \(appPreferences.currency(viewModel.amount, currencyCode: viewModel.currencyCode))")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: DS.Spacing.xs)
            GroupSplitStatusBadge(viewModel: viewModel, font: DS.Typography.caption)
        }
    }
}

// MARK: - Lista de personas (compartida con la hoja)

/// Una fila por miembro activo: check en `.equal`, campo editable en los demás modos. Sin
/// fondo: quien la monta pone la tarjeta.
struct GroupSplitMemberList: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Fila maestra «Seleccionar todos (N)» al final, solo en `.equal`.
    var showsSelectAll: Bool = true
    /// Margen lateral de cada fila: la hoja lo pone (lista a sangre en su tarjeta); el
    /// formulario no, porque la tarjeta del reparto ya trae el suyo.
    var rowInset: CGFloat = DS.Spacing.lg
    /// Color del avatar de cada persona. La hoja usa el del grupo; el formulario, el de la
    /// barra del reparto, para que cada tramo y su fila se reconozcan.
    var avatarColor: (SplitMember) -> Color

    @FocusState private var focusedMember: String?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    private var currencySymbol: String {
        appPreferences.currencyIdentifier(for: viewModel.currencyCode)
    }

    var body: some View {
        // Monto efectivo por miembro calculado UNA sola vez por render (no por fila).
        // SIEMPRE disponible aunque la división no cuadre → cada fila muestra su monto.
        let amounts = viewModel.effectiveAmountsByID
        VStack(spacing: DS.Spacing.none) {
            ForEach(viewModel.activeSheetMembers, id: \.id) { member in
                memberRow(member: member, id: member.id.uuidString, amount: amounts[member.id.uuidString] ?? 0)

                if member.id != viewModel.activeSheetMembers.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.lg)
                }
            }
            // Última fila SOLO en modo igual: maestro "Seleccionar todos (N)".
            if showsSelectAll, viewModel.splitType == .equal {
                Divider().padding(.leading, DS.Spacing.lg)
                selectAllRow
            }
        }
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
                .padding(.horizontal, rowInset)
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
            .padding(.horizontal, rowInset)
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
            Text(viewModel.memberNameLookup[id] ?? member.resolvedDisplayName)
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
        let color = avatarColor(member)
        return ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)
            Text(String(member.resolvedDisplayName.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(color)
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

// MARK: - Estado del cuadre (compartido con la hoja)

/// «Balanceado» / «Faltan S/ X» / «Te pasaste por S/ X».
struct GroupSplitStatusBadge: View {

    @Bindable var viewModel: GroupExpenseViewModel
    var font: Font = DS.Typography.subheadline

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if viewModel.isSharesBalanced {
            Label(L10n.Groups.Expense.balanced, systemImage: "checkmark.circle.fill")
                .font(font)
                .foregroundStyle(DS.Semantic.successForeground)
        } else if viewModel.remainingToAllocate < -0.005 {
            Label(
                L10n.Groups.Expense.overAllocated(appPreferences.currency(abs(viewModel.remainingToAllocate), currencyCode: viewModel.currencyCode)),
                systemImage: "exclamationmark.circle.fill"
            )
            .font(font)
            .foregroundStyle(Color.hotPink)
        } else {
            Label(
                L10n.Groups.Expense.remainingAmount(appPreferences.currency(abs(viewModel.remainingToAllocate), currencyCode: viewModel.currencyCode)),
                systemImage: "exclamationmark.circle.fill"
            )
            .font(font)
            .foregroundStyle(Color.hotPink)
        }
    }
}
