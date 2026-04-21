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
                }
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )

                YalaPrimaryButton(L10n.Action.save, icon: "checkmark.circle.fill") {
                    viewModel.updateHorizon(monthsAhead: monthsAhead, monthsBack: monthsBack)
                    dismiss()
                }
            }
            .padding(DS.Spacing.xl)
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
        }
    }
}
