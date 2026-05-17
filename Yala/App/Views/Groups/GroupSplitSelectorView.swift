//
//  GroupSplitSelectorView.swift
//  Yala
//
//  Picker de tipo de split + inputs por participante — estilo SplitCalculatorSheet.
//

import SwiftUI

struct GroupSplitSelectorView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    @FocusState private var focusedMember: String?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private var currencySymbol: String {
        appPreferences.currencyIdentifier(for: viewModel.currencyCode)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            splitTypePicker

            if !viewModel.selectedMemberIDs.isEmpty && viewModel.amount > 0 {
                memberSharesCard
                resultRow
            }

            tipView
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
    }

    // MARK: - Member Shares Card

    private var memberSharesCard: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(viewModel.selectedMembers, id: \.id) { member in
                let id = member.id.uuidString

                memberRow(member: member, id: id)

                if member.id != viewModel.selectedMembers.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.lg)
                }
            }
        }
        .solidCard(radius: DS.Radius.xl)
    }

    @ViewBuilder
    private func memberRow(member: SplitMember, id: String) -> some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            Text(viewModel.memberNameLookup[id] ?? member.displayName)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

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
        .padding(DS.Spacing.lg)
    }

    // MARK: - Per-Type Displays

    private func equalDisplay(id: String) -> some View {
        let share = viewModel.calculatedShares?.first(where: { $0.memberID == id })?.amount ?? 0
        return HStack(spacing: DS.Spacing.xs) {
            Spacer()
            Text(currencySymbol)
                .font(DS.Typography.title2)
                .foregroundStyle(.tertiary)
            Text(appPreferences.number(share, forceFullPrecision: true))
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
        }
    }

    private func exactInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Spacer()
            Text(currencySymbol)
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)

            splitField(
                id: id,
                placeholder: "0",
                keyPath: \.exactAmounts,
                keyboard: .decimalPad,
                filter: { AmountInputHelper.filterAmountInput($0) }
            )
        }
    }

    private func percentageInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Spacer()

            splitField(
                id: id,
                placeholder: "0",
                keyPath: \.percentages,
                keyboard: .decimalPad,
                filter: { AmountInputHelper.filterAmountInput($0) }
            )

            Text("%")
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
        }
    }

    private func sharesInput(id: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Spacer()

            splitField(
                id: id,
                placeholder: "1",
                keyPath: \.sharesCounts,
                keyboard: .numberPad,
                filter: { AmountInputHelper.filterIntegerInput($0) }
            )

            Text(L10n.Split.sharesParts)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Split Field (shared ZStack + placeholder + filtering)

    @ViewBuilder
    private func splitField(
        id: String,
        placeholder: String,
        keyPath: ReferenceWritableKeyPath<GroupExpenseViewModel, [String: String]>,
        keyboard: UIKeyboardType,
        filter: @escaping (String) -> String
    ) -> some View {
        let memberName = viewModel.memberNameLookup[id] ?? id
        ZStack(alignment: .trailing) {
            if (viewModel[keyPath: keyPath][id] ?? "").isEmpty {
                Text(placeholder)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
            }
            TextField("", text: binding(for: id, in: keyPath))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(DS.Typography.title2)
                .focused($focusedMember, equals: id)
                .onChange(of: viewModel[keyPath: keyPath][id] ?? "") { _, newValue in
                    let filtered = filter(newValue)
                    if filtered != newValue {
                        viewModel[keyPath: keyPath][id] = filtered
                    }
                }
                .accessibilityLabel("\(viewModel.splitType.displayName) \(memberName)")
        }
    }

    // MARK: - Result Row

    private var resultRow: some View {
        HStack {
            if viewModel.splitType == .equal {
                Text(L10n.Groups.Expense.eachPays)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            } else if viewModel.isSharesBalanced {
                Label(L10n.Groups.Expense.balanced, systemImage: "checkmark.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Semantic.successForeground)
            } else {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(L10n.Groups.Expense.remainingAmount(appPreferences.currency(abs(viewModel.remainingToAllocate), currencyCode: viewModel.currencyCode)))
                }
                .font(DS.Typography.headline)
                .foregroundStyle(Color.hotPink)
            }

            Spacer()

            AmountText(
                value: viewModel.sharesTotal,
                currencyCode: viewModel.currencyCode,
                font: DS.Typography.title2,
                tint: .color(resultAccentColor)
            )
        }
        .padding(DS.Spacing.md)
        .background(resultAccentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var resultAccentColor: Color {
        if viewModel.splitType == .equal || viewModel.isSharesBalanced {
            return DS.Semantic.successForeground
        }
        return Color.hotPink
    }

    // MARK: - Tip View

    private var tipView: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(DS.Typography.body)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)
            Text(viewModel.splitType.hintText)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotPink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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
