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
    /// Si la entrada no existe (auto-match falló o user es .groupInvite), fallback al splitTypeBadge.
    let txBridgeMap: [String: TransactionItem]
    /// Mi share por expense (nil si no participo → render "No participaste").
    let mySharesByExpense: [UUID: SplitShare]
    /// uuidString del current member (para detectar si yo soy el payer).
    let currentMemberID: String?

    // Callbacks (optional for backwards compatibility)
    var onTapExpense: ((SplitExpense) -> Void)?
    /// Edición directa (menú contextual "Editar"); salta la fase de detalle.
    var onEditExpense: ((SplitExpense) -> Void)?
    var onDeleteExpense: ((SplitExpense) -> Void)?
    var onInvite: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var expenseToDelete: SplitExpense?

    var body: some View {
        if expenses.isEmpty {
            YalaEmptyState(
                icon: "receipt",
                title: L10n.Groups.Expense.noExpenses,
                actionTitle: onInvite != nil ? L10n.Groups.Settings.invite : nil,
                action: onInvite
            )
        } else {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg, pinnedViews: .sectionHeaders) {
                    ForEach(groupedByDate, id: \.key) { dateString, dayExpenses in
                        Section {
                            ForEach(dayExpenses, id: \.id) { expense in
                                if onTapExpense != nil {
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
                                } else {
                                    expenseRow(expense)
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

    private func expenseRow(_ expense: SplitExpense) -> some View {
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
            currentMemberID: currentMemberID ?? ""
        )

        return HStack(spacing: DS.Spacing.md) {
            subcategoryBadge(for: expense)

            // Description + payer
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(expense.expenseDescription.isEmpty ? "—" : expense.expenseDescription)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(payerLabel)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            GroupExpenseAmountView(status: status, currencyCode: expense.currencyCode)
        }
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    /// Subcat icon+color del bridge personal, si la auto-match exitosa. Sino → splitTypeBadge.
    @ViewBuilder
    private func subcategoryBadge(for expense: SplitExpense) -> some View {
        if let tx = txBridgeMap[expense.id.uuidString],
           let sub = tx.subcategory,
           !sub.isAnySystem {
            let color = Color(hex: sub.safeCategory.colorHex)
            Image(systemName: sub.iconName ?? "tag.fill")
                .font(DS.Typography.label)
                .foregroundStyle(color)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background(Circle().fill(color.opacity(0.12)))
        } else {
            splitTypeBadge(expense.splitType)
        }
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
            .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
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

    private var groupedByDate: [(key: String, value: [SplitExpense])] {
        let grouped = Dictionary(grouping: expenses) { expense in
            Self.dateFormatter.string(from: expense.date)
        }

        // Días en orden descendente; dentro de cada día el más reciente arriba y
        // el más antiguo abajo (createdAt desc), igual que Records
        // (FilterService.groupByDate).
        return grouped
            .map { (key: $0.key, value: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { lhs, rhs in
                guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
                return lDate > rDate
            }
    }
}
