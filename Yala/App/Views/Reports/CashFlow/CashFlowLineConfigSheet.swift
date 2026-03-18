//
//  CashFlowLineConfigSheet.swift
//  Yala
//
//  Configuration sheet for a cash flow line: estimation method, overrides, delete.
//

import SwiftData
import SwiftUI

struct CashFlowLineConfigSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let line: CashFlowLine
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    @State private var selectedMethod: EstimationMethod
    @State private var manualAmount: String
    @State private var showDeleteConfirmation = false

    init(viewModel: CashFlowPlanViewModel, line: CashFlowLine, currencyCode: String) {
        self.viewModel = viewModel
        self.line = line
        self.currencyCode = currencyCode
        _selectedMethod = State(initialValue: line.method)
        _manualAmount = State(initialValue: line.manualAmount.map { String(format: "%.0f", $0) } ?? "")
    }

    private var isPro: Bool {
        FeatureGateService.shared.canAccess(.cashFlowAdvanced)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView().dismissKeyboardOnTap()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        categorySection
                        methodSection
                        if !overrides.isEmpty {
                            overridesSection
                        }
                        deleteSection
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                    .yalaSafeBottomPadding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(line.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: {
                        applyChanges()
                        dismiss()
                    })
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog(
            L10n.CashFlowPlan.resetConfirmation,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Action.delete, role: .destructive) {
                viewModel.removeLine(line)
                dismiss()
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.contextLabel)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            if line.subcategory != nil || line.category != nil {
                let displayName = line.subcategory?.name ?? line.category?.name ?? line.name
                let iconName = line.subcategory?.iconName ?? line.category?.iconName
                let colorHex = line.subcategory?.colorHex ?? line.category?.colorHex ?? AppConstants.defaultColorHex

                HStack(spacing: DS.Spacing.md) {
                    if let iconName {
                        Image(systemName: iconName)
                            .foregroundStyle(Color(hex: colorHex))
                    }
                    Text(displayName)
                        .font(DS.Typography.body)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
            }
        }
    }

    // MARK: - Method Selection

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.estimationMethod)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.none) {
                methodRow(.average6m, label: L10n.CashFlowPlan.average6m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.average3m, label: L10n.CashFlowPlan.average3m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.average12m, label: L10n.CashFlowPlan.average12m)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.lastMonth, label: L10n.CashFlowPlan.lastMonth)
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.manual, label: L10n.CashFlowPlan.manual)
                if selectedMethod == .manual {
                    manualAmountField
                }
                Divider().padding(.leading, DS.Spacing.xxl)
                methodRow(.scheduled, label: L10n.CashFlowPlan.scheduled, enabled: line.scheduledPayment != nil)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .yalaCard(padding: 0)
        }
    }

    private func methodRow(_ method: EstimationMethod, label: String, proOnly: Bool = false, enabled: Bool = true) -> some View {
        Button {
            if proOnly && !isPro { return }
            if !enabled { return }
            selectedMethod = method
        } label: {
            HStack {
                Image(systemName: selectedMethod == method ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selectedMethod == method ? theme.accent : .secondary)
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(enabled ? .primary : .secondary)
                Spacer()
                if proOnly && !isPro {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1.0 : 0.5)
    }

    private var manualAmountField: some View {
        HStack {
            TextField("0", text: $manualAmount)
                .keyboardType(.decimalPad)
                .font(DS.Typography.amount)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Overrides

    private var overrides: [CashFlowOverride] {
        (line.overrides ?? []).sorted { $0.monthKey < $1.monthKey }
    }

    private var overridesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.adjustAmount)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.none) {
                ForEach(overrides, id: \.monthKey) { override in
                    HStack {
                        Text(override.monthKey)
                            .font(DS.Typography.body)
                        Spacer()
                        Text(YalaFormatter.currency(value: override.amount, currencyCode: currencyCode))
                            .font(DS.Typography.amountSmall)
                            .monospacedDigit()
                        if !override.note.isEmpty {
                            Text("(\(override.note))")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            viewModel.removeOverride(line: line, monthKey: override.monthKey)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .yalaCard(padding: 0)
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text(L10n.Action.delete)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Semantic.errorForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply

    private func applyChanges() {
        line.estimationMethod = selectedMethod.rawValue
        if selectedMethod == .manual {
            line.manualAmount = Double(manualAmount.replacing(",", with: "."))
        }
        do {
            try viewModel.plan?.modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowLineConfigSheet: Error saving: \(error)")
            #endif
        }
    }
}
