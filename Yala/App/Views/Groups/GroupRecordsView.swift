//
//  GroupRecordsView.swift
//  Yala
//
//  Lista de gastos compartidos de un grupo, agrupados por fecha.
//

import SwiftUI

struct GroupRecordsView: View {

    let expenses: [SplitExpense]
    let shares: [SplitShare]
    let memberNameLookup: [String: String]
    let currencyCode: String
    /// Per-user bridge: expense.id.uuidString → TX1 con subcat manual asignada por current user.
    /// Si la entrada no existe (auto-match falló o user es .groupInvite), fallback al nombre y luego al splitTypeBadge.
    let txBridgeMap: [String: TransactionItem]
    /// `[nombre normalizado de subcategoría: (icono, colorHex)]` de las subcategorías locales.
    /// Fallback self-contained cuando no hay bridge: casa `SplitExpense.subcategoryName` del creador.
    let subcategoryNameLookup: [String: (iconName: String, colorHex: String)]
    /// Mi share por expense (nil si no participo → render "No participaste").
    let mySharesByExpense: [UUID: SplitShare]
    /// uuidString del current member (para detectar si yo soy el payer).
    let currentMemberID: String?
    /// Liquidaciones del grupo; el feed muestra SOLO las confirmadas (filtro en `GroupFeedItem.feedItems`).
    /// Default vacío → firma retro-compatible.
    var settlements: [SplitSettlement] = []

    // Callbacks (optional for backwards compatibility)
    var onTapExpense: ((SplitExpense) -> Void)?
    /// Edición directa (menú contextual "Editar"); salta la fase de detalle.
    var onEditExpense: ((SplitExpense) -> Void)?
    var onDeleteExpense: ((SplitExpense) -> Void)?
    var onInvite: (() -> Void)?
    /// Banda de balance del header (scrollea junto a los registros). nil → no se muestra.
    var headerBalance: GroupHeaderBalance?
    var debtsWereConverted: Bool = false
    var onTapBalance: (() -> Void)?
    /// Pull-to-refresh: fuerza un fetch de CloudKit. Aplicado aquí (no en GroupDetailView) para
    /// acotar el `.refreshable` a este ScrollView y NO heredarlo por environment a los sheets del
    /// detalle (el pull espurio en el form de gasto que arregló el commit `0643525e`).
    var onRefresh: (() async -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var expenseToDelete: SplitExpense?

    var body: some View {
        if feedItems.isEmpty {
            YalaEmptyState(
                icon: "receipt",
                title: L10n.Groups.Expense.noExpenses,
                actionTitle: onInvite != nil ? L10n.Groups.Settings.invite : nil,
                action: onInvite
            )
        } else {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg, pinnedViews: .sectionHeaders) {
                    // Banda de balance: primer elemento del scroll → se va con los registros (no fija).
                    if let headerBalance, let onTapBalance {
                        GroupHeaderBalanceBar(
                            balance: headerBalance,
                            debtsWereConverted: debtsWereConverted,
                            onTap: onTapBalance
                        )
                    }
                    ForEach(groupedByDate, id: \.key) { dateString, dayItems in
                        Section {
                            ForEach(dayItems, id: \.id) { item in
                                switch item {
                                case .expense(let expense):
                                    if onTapExpense == nil {
                                        expenseRow(expense)
                                    } else if expense.isOpeningBalance {
                                        // Saldo inicial: tap → detalle (owner edita desde ahí).
                                        // Sin context menu (edit/delete owner-only vive en el detalle).
                                        Button {
                                            onTapExpense?(expense)
                                        } label: {
                                            expenseRow(expense)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier("group_opening_balance_row_\(expense.id)")
                                    } else {
                                        Button {
                                            onTapExpense?(expense)
                                        } label: {
                                            expenseRow(expense)
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                        .accessibilityIdentifier("group_expense_row_\(expense.expenseDescription)")
                                        .contextMenu {
                                            Button {
                                                onEditExpense?(expense)
                                            } label: {
                                                Label(L10n.Action.edit, systemImage: "pencil")
                                            }

                                            Button(role: .destructive) {
                                                expenseToDelete = expense
                                            } label: {
                                                Label(L10n.Action.delete, systemImage: "trash")
                                            }
                                        }
                                    }
                                case .settlement(let settlement):
                                    settlementRow(settlement)
                                }
                            }
                        } header: {
                            sectionHeader(dateString)
                        }
                    }
                }
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .scrollViewGlassEdges()
            .refreshable { await onRefresh?() }
            .confirmationDialog(
                L10n.Action.delete,
                isPresented: Binding(
                    get: { expenseToDelete != nil },
                    set: { if !$0 { expenseToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    if let expense = expenseToDelete {
                        onDeleteExpense?(expense)
                        expenseToDelete = nil
                    }
                }
            }
        }
    }

    // MARK: - Expense Row

    @ViewBuilder
    private func expenseRow(_ expense: SplitExpense) -> some View {
        if expense.isOpeningBalance {
            openingBalanceRow(expense)
        } else {
            normalExpenseRow(expense)
        }
    }

    /// Fila descriptiva de saldo inicial ("Saldo inicial · X le debe a Y" + monto neutro).
    /// NO usa el resolver de perspectiva de TX bridgeada — es un arrastre, no un gasto.
    private func openingBalanceRow(_ expense: SplitExpense) -> some View {
        let debtorID = shares.first { $0.expenseID == expense.id }?.memberID
        let debtorName = debtorID.flatMap { memberNameLookup[$0] } ?? "?"
        let creditorName = memberNameLookup[expense.paidByMemberID] ?? "?"
        let amountStr = appPreferences.currency(expense.amount, currencyCode: expense.currencyCode)

        return HStack(spacing: DS.ListRow.spacing) {
            Image(systemName: "arrow.left.arrow.right")
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                .background(Circle().fill(Color(.secondarySystemFill)))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Groups.OpeningBalance.entryDescription)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(L10n.Groups.OpeningBalance.feedRow(debtorName, creditorName))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(amountStr)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .listRowCard()
    }

    /// Fila descriptiva de una liquidación confirmada ("Liquidación · X le pagó a Y" + monto neutro).
    /// Estática (sin tap ni context menu — no existe pantalla de detalle de settlement).
    /// Espejo del layout de `openingBalanceRow`; icono `checkmark.circle` para no confundir familias.
    private func settlementRow(_ settlement: SplitSettlement) -> some View {
        let fromName = memberNameLookup[settlement.fromMemberID] ?? "?"
        let toName = memberNameLookup[settlement.toMemberID] ?? "?"
        let amountStr = appPreferences.currency(settlement.amount, currencyCode: settlement.currencyCode)

        return HStack(spacing: DS.ListRow.spacing) {
            Image(systemName: "checkmark.circle")
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                .background(Circle().fill(Color(.secondarySystemFill)))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Groups.Settlement.entryDescription)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(L10n.Groups.Settlement.feedRow(fromName, toName))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(amountStr)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .listRowCard()
        .accessibilityIdentifier("group_settlement_row_\(settlement.id)")
    }

    private func normalExpenseRow(_ expense: SplitExpense) -> some View {
        let amountStr = appPreferences.currency(expense.amount, currencyCode: expense.currencyCode)
        let isPayer = expense.paidByMemberID == currentMemberID
        let payerLabel: String = {
            if isPayer { return L10n.Groups.Expense.youPaid(amountStr) }
            let name = memberNameLookup[expense.paidByMemberID] ?? "?"
            return L10n.Groups.Expense.memberPaid(name, amountStr)
        }()
        let status = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: mySharesByExpense[expense.id],
            currentMemberID: currentMemberID
        )

        return HStack(spacing: DS.ListRow.spacing) {
            subcategoryBadge(for: expense)

            // Description + payer
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(expense.expenseDescription.isEmpty ? "—" : expense.expenseDescription)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(payerLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            GroupExpenseAmountView(status: status, currencyCode: expense.currencyCode)
        }
        .listRowCard()
    }

    /// Subcat icon+color: bridge personal (gana) → nombre del creador → splitTypeBadge (genérico).
    /// El bridge se resuelve visualmente IDÉNTICO a antes; el nombre es el fallback nuevo que sana
    /// el feed en device fresco / no-participante (H-2026-07-18-9).
    @ViewBuilder
    private func subcategoryBadge(for expense: SplitExpense) -> some View {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: bridgeIcon(for: expense),
            subcategoryName: expense.subcategoryName,
            nameLookup: subcategoryNameLookup,
            fallbackIconName: "tag.fill"
        )
        // Preguntar por `isGeneric` como los demás call-sites (review H-9 M1): hoy `colorHex != nil`
        // ⟺ `!isGeneric` por construcción, pero la señal contractual del resolver es `isGeneric` —
        // no depender del invariante estructural del tuple.
        if !resolved.isGeneric, let colorHex = resolved.colorHex {
            let color = Color(hex: colorHex)
            Image(systemName: resolved.iconName)
                .font(DS.Typography.label)
                .foregroundStyle(color)
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                .background(Circle().fill(color.opacity(0.12)))
        } else {
            splitTypeBadge(expense.splitType)
        }
    }

    /// Icono+color del bridge personal (TX1 con subcat manual no-sistema), o `nil` si no hay bridge.
    /// El fallback de icono `?? "tag.fill"` reproduce el render previo del feed byte a byte.
    private func bridgeIcon(for expense: SplitExpense) -> (iconName: String, colorHex: String)? {
        guard let tx = txBridgeMap[expense.id.uuidString],
              let sub = tx.subcategory,
              !sub.isAnySystem else { return nil }
        return (sub.iconName ?? "tag.fill", sub.safeCategory.colorHex)
    }

    // MARK: - Split Type Badge

    private func splitTypeBadge(_ type: String) -> some View {
        let icon: String = switch type {
        case "equal": "equal.circle.fill"
        case "percentage": "percent"
        case "exact": "number"
        case "shares": "chart.pie.fill"
        default: "equal.circle.fill"
        }

        return Image(systemName: icon)
            .font(DS.Typography.label)
            .foregroundStyle(.thAccent)
            .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
            .background(Circle().fill(.thAccent.opacity(0.12)))
    }

    // MARK: - Section Header

    private func sectionHeader(_ dateString: String) -> some View {
        HStack {
            Text(dateString)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xs)
    }

    // MARK: - Grouping

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Feed mixto: gastos + liquidaciones confirmadas (filtro en `GroupFeedItem.feedItems`).
    private var feedItems: [GroupFeedItem] {
        GroupFeedItem.feedItems(expenses: expenses, settlements: settlements)
    }

    private var groupedByDate: [(key: String, value: [GroupFeedItem])] {
        let grouped = Dictionary(grouping: feedItems) { item in
            Self.dateFormatter.string(from: item.date)
        }

        // Días en orden descendente; dentro de cada día el más reciente arriba y
        // el más antiguo abajo (sortTimestamp desc), igual que Records
        // (FilterService.groupByDate).
        return grouped
            .map { (key: $0.key, value: $0.value.sorted { $0.sortTimestamp > $1.sortTimestamp }) }
            .sorted { lhs, rhs in
                guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
                return lDate > rDate
            }
    }
}
