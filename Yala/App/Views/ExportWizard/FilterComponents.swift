//
//  FilterComponents.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Generic Filter Header

struct FilterSectionHeader: View {
    let icon: String
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Text("(\(status))")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Generic Selection Row

struct FilterSelectionRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Text("(\(subtitle))")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Amount Filter View

struct AmountFilterView: View {
    @Binding var condition: AmountFilterCondition
    var currencyCode: CurrencyCode?

    // Estados locales para los campos de texto
    @State private var value1: String = ""
    @State private var value2: String = ""

    // Enum auxiliar para el Picker
    enum AmountConditionType: String, CaseIterable, Identifiable {
        case any
        case greaterThan
        case lessThan
        case between

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .any: return L10n.Export.any
            case .greaterThan: return L10n.Export.greaterThan
            case .lessThan: return L10n.Export.lessThan
            case .between: return L10n.Export.between
            }
        }
    }

    @State private var selectedType: AmountConditionType = .any

    // Sincronizar estados locales con el binding al aparecer
    private func syncState() {
        switch condition {
        case .any:
            value1 = ""
            value2 = ""
        case .greaterThan(let val), .lessThan(let val):
            value1 = NSDecimalNumber(decimal: val).stringValue
            value2 = ""
        case .between(let min, let max):
            value1 = NSDecimalNumber(decimal: min).stringValue
            value2 = NSDecimalNumber(decimal: max).stringValue
        }
    }

    // Actualizar el binding cuando cambian los valores locales o la selección
    private func updateCondition(newType: AmountConditionType) {
        let v1 = Decimal(string: value1) ?? 0
        let v2 = Decimal(string: value2) ?? 0

        switch newType {
        case .any:
            condition = .any
        case .greaterThan:
            condition = .greaterThan(v1)
        case .lessThan:
            condition = .lessThan(v1)
        case .between:
            condition = .between(min: v1, max: v2)
        }
    }

    // Campo de monto grande con estilo "New Account" (Saldo actual)
    private func largeAmountField(text: Binding<String>) -> some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            if let code = currencyCode {
                Text(code.rawValue)
                    .font(DS.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .font(DS.Typography.amountLarge)
                .multilineTextAlignment(.trailing)
                .onChange(of: text.wrappedValue) {
                    updateCondition(newType: selectedType)
                }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if currencyCode == nil {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(L10n.Export.selectSingleCurrency)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Spacing.sm)
            } else {
                // Selector superior (Cualquiera / Mayor a / Menor a / Entre)
                Picker(L10n.Export.condition, selection: $selectedType) {
                    ForEach(AmountConditionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedType) {
                    updateCondition(newType: selectedType)
                }

                // Zona inferior con los montos en grande
                if selectedType != .any {
                    Divider()
                        .padding(.top, DS.Spacing.xs)

                    switch selectedType {
                    case .between:
                        HStack(spacing: DS.Spacing.xxl) {
                            largeAmountField(text: $value1)

                            // Separador visual
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 1, height: 40)

                            largeAmountField(text: $value2)
                        }
                    case .greaterThan, .lessThan, .any:
                        HStack {
                            Spacer()
                            largeAmountField(text: $value1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // Determinar el tipo inicial basado en condition
            switch condition {
            case .any:
                selectedType = .any
            case .greaterThan:
                selectedType = .greaterThan
            case .lessThan:
                selectedType = .lessThan
            case .between:
                selectedType = .between
            }
            syncState()
        }
    }
}

// MARK: - Multi Selection List

struct MultiSelectionList<T: Identifiable & Hashable>: View {
    let title: String
    let items: [T]
    @Binding var selection: Set<T>
    let label: (T) -> String

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    if selection.contains(item) {
                                        selection.remove(item)
                                    } else {
                                        selection.insert(item)
                                    }
                                } label: {
                                    HStack {
                                        Text(label(item))
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if selection.contains(item) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.brandPrimary)
                                                .font(DS.Typography.headline)
                                        }
                                    }
                                    .padding(.horizontal, DS.FormRow.paddingH)
                                    .padding(.vertical, DS.FormRow.paddingV)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
