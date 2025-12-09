//
//  FilterComponents.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Generic Selection Row

struct FilterSelectionRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        case any = "Cualquiera"
        case greaterThan = "Mayor a"
        case lessThan = "Menor a"
        case between = "Entre"

        var id: String { rawValue }
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
        VStack(alignment: .trailing, spacing: 4) {
            if let code = currencyCode {
                Text(code.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.trailing)
                .onChange(of: text.wrappedValue) {
                    updateCondition(newType: selectedType)
                }
        }
        .padding(.vertical, 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if currencyCode == nil {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Selecciona una única moneda para filtrar por monto.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                // Selector superior (Cualquiera / Mayor a / Menor a / Entre)
                Picker("Condición", selection: $selectedType) {
                    ForEach(AmountConditionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedType) {
                    updateCondition(newType: selectedType)
                }

                // Zona inferior con los montos en grande
                if selectedType != .any {
                    Divider()
                        .padding(.top, 4)

                    switch selectedType {
                    case .between:
                        HStack(spacing: 24) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

// MARK: - Date Filter View

struct DateFilterView: View {
    @Binding var period: ExportPeriod
    @Binding var customDateFrom: Date?
    @Binding var customDateTo: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Menu para seleccionar el periodo
            Menu {
                Section("Periodos") {
                    Button("Este año") { period = .thisYear }
                    Button("Este mes") { period = .thisMonth }
                    Button("Esta semana") { period = .thisWeek }
                }

                Section("Antelación") {
                    Button("Últimos 90 días") { period = .last90Days }
                    Button("Últimos 30 días") { period = .last30Days }
                    Button("Últimos 7 días") { period = .last7Days }
                }

                Section {
                    Button("Personalizado") { period = .custom }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName(for: period))
                            .foregroundStyle(.primary)

                        if let subtitle = dateRangeSubtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Rango personalizado solo si está seleccionado
            if period == .custom {
                Divider()
                    .padding(.leading, 16)

                customRangeRow()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .onChange(of: customDateFrom) {
            period = .custom
        }
        .onChange(of: customDateTo) {
            period = .custom
        }
    }

    // MARK: - Subvistas

    private var dateRangeSubtitle: String? {
        guard period != .custom else { return nil }
        guard let interval = period.standardDateInterval() else { return nil }

        let calendar = Calendar(identifier: .gregorian)

        // Mostramos el día inclusive final: end exclusivo - 1 día
        // (si por alguna razón falla el cálculo, usamos end tal cual)
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")  // Asegurar español
        formatter.dateFormat = "d MMM yyyy"

        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: displayEnd))"
    }

    private func customRangeRow() -> some View {
        HStack(spacing: 12) {
            let fromBinding = Binding<Date>(
                get: { customDateFrom ?? Date() },
                set: { customDateFrom = $0 }
            )

            let toBinding = Binding<Date>(
                get: { customDateTo ?? Date() },
                set: { customDateTo = $0 }
            )

            datePill(label: "Desde", date: fromBinding)

            Text("-")
                .foregroundStyle(.secondary)

            datePill(label: "Hasta", date: toBinding)
        }
    }

    private func datePill(label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            DatePicker(
                "",
                selection: date,
                displayedComponents: .date
            )
            .labelsHidden()
        }
    }

    private func displayName(for period: ExportPeriod) -> String {
        switch period {
        case .thisYear: return "Este año"
        case .thisMonth: return "Este mes"
        case .thisWeek: return "Esta semana"
        case .last7Days: return "Últimos 7 días"
        case .last30Days: return "Últimos 30 días"
        case .last90Days: return "Últimos 90 días"
        case .custom: return "Personalizado"
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
        List {
            ForEach(items) { item in
                Button {
                    if selection.contains(item) {
                        selection.remove(item)
                    } else {
                        selection.insert(item)
                    }
                } label: {
                    HStack {
                        Text(label(item))
                            .foregroundStyle(.primary)

                        Spacer()

                        if selection.contains(item) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle(title)
    }
}
