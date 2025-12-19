//
//  CurrencySettingsView.swift
//  Neto
//
//  Settings view for preferred currency and exchange rates.
//

import SwiftData
import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    private var preferredCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
    }

    /// All currencies to show in exchange rate section (all except the preferred one)
    private var displayedCurrencies: [CurrencyCode] {
        CurrencyCode.allCases.filter { $0 != preferredCurrency }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    preferredCurrencySection
                    exchangeRatesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Divisa y cambio")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Preferred Currency Section

    private var preferredCurrencySection: some View {
        SectionBox(title: "Divisa preferida") {
            VStack(spacing: 0) {
                ForEach(Array(CurrencyCode.allCases.enumerated()), id: \.element) {
                    index, currency in
                    if index > 0 {
                        SubsectionDivider()
                    }
                    preferredCurrencyRow(currency: currency)
                }
            }
        }
    }

    @ViewBuilder
    private func preferredCurrencyRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)

        Button {
            defaultCurrencyCode = currency.rawValue
        } label: {
            HStack(spacing: 12) {
                Text(info.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name.capitalized)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if currency == preferredCurrency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.electricIndigo)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exchange Rates Section

    private var exchangeRatesSection: some View {
        VStack(spacing: 8) {
            SectionBox(title: "Tipo de cambio") {
                VStack(spacing: 0) {
                    ForEach(Array(displayedCurrencies.enumerated()), id: \.element) {
                        index, currency in
                        if index > 0 {
                            SubsectionDivider()
                        }
                        exchangeRateRow(currency: currency)
                    }
                }
            }

            // Last updated disclaimer
            if let latestRate = ExchangeRateService.shared.getLatestRate(context: modelContext) {
                // Use API timestamp if available, otherwise fall back to dateKey
                let rateDate: Date? =
                    latestRate.timestamp
                    ?? {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        dateFormatter.timeZone = TimeZone(identifier: "UTC")
                        return dateFormatter.date(from: latestRate.dateKey)
                    }()

                if let date = rateDate {
                    Text("Última actualización: \(formatLastUpdated(date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d 'de' MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func exchangeRateRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let rate = getDisplayRate(from: currency, to: preferredCurrency)
        let preferredInfo = currencyInfo(for: preferredCurrency)

        HStack(spacing: 12) {
            Text(info.flag)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("1 \(info.code)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(info.name.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rate = rate {
                Text(String(format: "%.4f %@", rate, preferredInfo.code))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                Text("--")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func getDisplayRate(from: CurrencyCode, to: CurrencyCode) -> Double? {
        CurrencyConverter.shared.getDisplayRate(
            from: from.rawValue, to: to.rawValue, context: modelContext)
    }
}

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
    .modelContainer(for: [Account.self, ExchangeRate.self])
}
