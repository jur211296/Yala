//
//  GroupSplitSelectorView.swift
//  Yala
//
//  Picker de tipo de split + inputs por participante según el tipo seleccionado.
//

import SwiftUI

struct GroupSplitSelectorView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    @FocusState private var focusedMember: String?

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Split type picker
            splitTypePicker

            // Per-member rows
            if !viewModel.selectedMemberIDs.isEmpty && viewModel.amount > 0 {
                memberSharesList
                summaryBar
            }
        }
    }

    // MARK: - Split Type Picker

    private var splitTypePicker: some View {
        Picker(L10n.Groups.Expense.splitType, selection: $viewModel.splitType) {
            ForEach(SplitType.allCases) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.FormRow.paddingH)
    }

    // MARK: - Member Shares List

    private var memberSharesList: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(viewModel.selectedMembers, id: \.id) { member in
                let id = member.id.uuidString

                memberRow(member: member, id: id)

                if member.id != viewModel.selectedMembers.last?.id {
                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(.thCardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func memberRow(member: SplitMember, id: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(viewModel.memberNameLookup[id] ?? member.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            switch viewModel.splitType {
            case .equal:
                equalDisplay(id: id)
            case .exact:
                exactInput(id: id)
            case .percentage:
                percentageInput(id: id)
            case .shares:
                sharesInput(id: id)
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Per-Type Displays

    private func equalDisplay(id: String) -> some View {
        let share = viewModel.calculatedShares?.first(where: { $0.memberID == id })?.amount ?? 0
        return Text(YalaFormatter.currency(value: share, currencyCode: viewModel.currencyCode))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
    }

    private func exactInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            TextField("0", text: binding(for: id, in: \.exactAmounts))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.body)
                .frame(width: 100)
                .focused($focusedMember, equals: id)
        }
    }

    private func percentageInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            TextField("0", text: binding(for: id, in: \.percentages))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.body)
                .frame(width: 70)
                .focused($focusedMember, equals: id)

            Text("%")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sharesInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            TextField("1", text: binding(for: id, in: \.sharesCounts))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.body)
                .frame(width: 50)
                .focused($focusedMember, equals: id)

            Text(L10n.Split.sharesParts)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack {
            if viewModel.splitType == .equal {
                Text(L10n.Groups.Expense.eachPays)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            } else {
                let remaining = viewModel.remainingToAllocate
                let isBalanced = viewModel.isSharesBalanced

                if isBalanced {
                    Label(L10n.Groups.Expense.balanced, systemImage: "checkmark.circle.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Semantic.successForeground)
                } else {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("\(L10n.Groups.Expense.remaining): \(YalaFormatter.currency(value: abs(remaining), currencyCode: viewModel.currencyCode))")
                    }
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.hotPink)
                }
            }

            Spacer()

            Text(YalaFormatter.currency(value: viewModel.sharesTotal, currencyCode: viewModel.currencyCode))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
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
