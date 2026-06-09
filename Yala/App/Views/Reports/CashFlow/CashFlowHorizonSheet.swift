//
//  CashFlowHorizonSheet.swift
//  Yala
//
//  Sheet to configure cash flow plan horizon (months ahead/back).
//

import SwiftUI

struct CashFlowHorizonSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    @State private var monthsAhead: Int = 6
    @State private var monthsBack: Int = 3
    @State private var showAccumulatedBalance: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack {
                        Text(L10n.CashFlowPlan.monthsAhead)
                            .font(DS.Typography.label)
                        Spacer()
                        Stepper("\(monthsAhead)", value: $monthsAhead, in: 1...24)
                            .labelsHidden()
                        Text("\(monthsAhead)")
                            .font(DS.Typography.amount)
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }

                    HStack {
                        Text(L10n.CashFlowPlan.monthsBack)
                            .font(DS.Typography.label)
                        Spacer()
                        Stepper("\(monthsBack)", value: $monthsBack, in: 0...12)
                            .labelsHidden()
                        Text("\(monthsBack)")
                            .font(DS.Typography.amount)
                            .monospacedDigit()
                            .frame(width: 32, alignment: .trailing)
                    }

                    Divider()

                    Toggle(L10n.CashFlowPlan.showAccumulatedBalance, isOn: $showAccumulatedBalance)
                        .font(DS.Typography.label)
                }
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )

                YalaPrimaryButton(L10n.Action.save, icon: "checkmark.circle.fill") {
                    viewModel.updateHorizon(monthsAhead: monthsAhead, monthsBack: monthsBack, showAccumulatedBalance: showAccumulatedBalance)
                    dismiss()
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .yalaScreenBackground(.transparent)
            .navigationTitle(L10n.CashFlowPlan.configureHorizon)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            monthsAhead = viewModel.plan?.defaultMonthsAhead ?? 6
            monthsBack = viewModel.plan?.defaultMonthsBack ?? 3
            showAccumulatedBalance = viewModel.plan?.showAccumulatedBalance ?? true
        }
    }
}
