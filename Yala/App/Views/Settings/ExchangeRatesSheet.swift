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

    /// UX 2.2 · L16-4: buscador arriba. Son 54 divisas y la persona viene a mirar una.
    @State private var searchText = ""

    /// All currencies except the preferred one, grouped by continent (y filtradas por el buscador).
    private var availableCurrencies: [(continent: Continent, currencies: [CurrencyCode])] {
        CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { currency in
                guard currency != preferredCurrency else { return false }
                let info = currencyInfo(for: currency)
                return ExchangeRateRowLogic.matches(query: searchText, code: info.code, name: info.name)
            }
            guard !filtered.isEmpty else { return nil }
            return (continent: group.continent, currencies: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.lg) {
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

                        if availableCurrencies.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }

                        // Last updated footer
                        if let latestRate = exchangeRateService.getLatestRate(context: modelContext) {
                            let rateDate: Date? =
                                latestRate.timestamp
                                ?? Self.dateKeyFormatter.date(from: latestRate.dateKey)

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
            .navigationTitle(L10n.Settings.exchangeRate)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L10n.UXL15.searchCurrency)
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
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
        let display = ExchangeRateRowLogic.display(rate: getDisplayRate(from: currency, to: preferredCurrency))
        let preferredInfo = currencyInfo(for: preferredCurrency)
        let isInverted: Bool = {
            if case .inverted = display { return true }
            return false
        }()

        HStack(spacing: DS.Spacing.md) {
            Text(info.flag)
                .font(DS.Typography.title)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                // Con la tasa invertida la fila ya no empieza por «1 PYG»: el «1» pasa a la principal, a la derecha.
                Text(isInverted ? info.code : "1 \(info.code)")
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(info.name.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // UX 2.2 · L16-4: por debajo de 0,01 la tasa se lee al revés, «1 PEN = 2,183 PYG», y no con cuatro ceros.
            switch display {
            case .direct(let rate):
                Text("\(ExchangeRateDisplayFormatter.string(rate)) \(preferredInfo.code)")
                    .font(DS.Typography.body.monospacedDigit())
                    .foregroundStyle(.primary)
            case .inverted(let units):
                Text("1 \(preferredInfo.code) = \(ExchangeRateRowLogic.invertedString(units)) \(info.code)")
                    .font(DS.Typography.body.monospacedDigit())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("exchange_rate_inverted_\(info.code)")
            case nil:
                Text("--")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

    // MARK: - Static Formatters

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let lastUpdatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        f.timeStyle = .short
        // «hoy a las 10:42» en vez de la fecha larga de hoy.
        f.doesRelativeDateFormatting = true
        return f
    }()

    // MARK: - Helpers

    private func getDisplayRate(from: CurrencyCode, to: CurrencyCode) -> Double? {
        currencyConverter.getDisplayRate(from: from.rawValue, to: to.rawValue, context: modelContext)
    }

    private func formatLastUpdated(_ date: Date) -> String {
        Self.lastUpdatedFormatter.string(from: date)
    }
}

#Preview {
    ExchangeRatesSheet(preferredCurrency: .pen)
        .modelContainer(for: [ExchangeRate.self])
}
