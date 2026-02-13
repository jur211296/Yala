//
//  ExchangeRatesSheet.swift
//  Yala
//
//  Sheet for viewing all exchange rates relative to the preferred currency.
//

import SwiftData
import SwiftUI

struct ExchangeRatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(ExchangeRateService.self) private var exchangeRateService

    let preferredCurrency: CurrencyCode

    /// All currencies except the preferred one, grouped by continent
    private var availableCurrencies: [(continent: Continent, currencies: [CurrencyCode])] {
        CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { $0 != preferredCurrency }
            guard !filtered.isEmpty else { return nil }
            return (continent: group.continent, currencies: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        ForEach(availableCurrencies, id: \.continent) { group in
                            SectionBox(title: group.continent.localizedName) {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(Array(group.currencies.enumerated()), id: \.element) {
                                        index, currency in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        exchangeRateRow(currency: currency)
                                    }
                                }
                            }
                        }

                        // Last updated footer
                        if let latestRate = exchangeRateService.getLatestRate(context: modelContext) {
                            let rateDate: Date? =
                                latestRate.timestamp
                                ?? {
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd"
                                    dateFormatter.timeZone = TimeZone(identifier: "UTC")
                                    return dateFormatter.date(from: latestRate.dateKey)
                                }()

                            if let date = rateDate {
                                Text("\(L10n.Common.lastUpdate) \(formatLastUpdated(date))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, DS.Spacing.sm)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }
            }
            .navigationTitle(L10n.Settings.exchangeRate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Exchange Rate Row

    @ViewBuilder
    private func exchangeRateRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let rate = getDisplayRate(from: currency, to: preferredCurrency)
        let preferredInfo = currencyInfo(for: preferredCurrency)

        HStack(spacing: DS.Spacing.md) {
            Text(info.flag)
                .font(DS.Typography.title)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("1 \(info.code)")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(info.name.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rate = rate {
                Text(String(format: "%.4f %@", rate, preferredInfo.code))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                Text("--")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func getDisplayRate(from: CurrencyCode, to: CurrencyCode) -> Double? {
        currencyConverter.getDisplayRate(from: from.rawValue, to: to.rawValue, context: modelContext)
    }

    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d 'de' MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ExchangeRatesSheet(preferredCurrency: .pen)
        .modelContainer(for: [ExchangeRate.self])
}
