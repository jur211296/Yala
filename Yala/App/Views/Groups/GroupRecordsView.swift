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

    // Callbacks (optional for backwards compatibility)
    var onTapExpense: ((SplitExpense) -> Void)?
    var onDeleteExpense: ((SplitExpense) -> Void)?
    var onInvite: (() -> Void)?

    @Environment(\.yalaTheme) private var theme
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
                                    .contextMenu {
                                        Button {
                                            onTapExpense?(expense)
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
        HStack(spacing: DS.Spacing.md) {
            // Split type badge
            splitTypeBadge(expense.splitType)

            // Description + payer
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(expense.expenseDescription.isEmpty ? "—" : expense.expenseDescription)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.Groups.Expense.paidBy)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Text(memberNameLookup[expense.paidByMemberID] ?? "?")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Amount
            Text(YalaFormatter.currency(value: expense.amount, currencyCode: expense.currencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
        }
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
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

        return grouped.sorted { lhs, rhs in
            guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
            return lDate > rDate
        }
    }
}
